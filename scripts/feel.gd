class_name Feel
extends Node

## Short synthesized cues, plus Scott's voice when files sit in
## res://assets/audio/commentary. Missing clips fall back to the synth.
## Haptics use the device vibrator and, on the web, navigator.vibrate.

const CommentaryScript := preload("res://scripts/commentary.gd")
const CrowdScript := preload("res://scripts/crowd.gd")
const PRAISE_POOL := {
	0: ["not_bad", "good", "okay"],
	1: ["good", "great", "nice"],
	2: ["great", "good", "fantastic"],
	3: ["amazing", "wow", "excellent"],
	4: ["outstanding", "perfect", "my_god", "incredible"],
}

var roll_amount := 0.0
var _unlocked := false
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _roll: AudioStreamPlayer
var _roll_state := 0.0
var _roll_low := 0.0
var _roll_phase := 0.0
var _streams := {}
var _last_aim_bucket := -1
var voice
var crowd


func _ready() -> void:
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_roll = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.25
	_roll.stream = generator
	_roll.volume_db = -28.0
	add_child(_roll)
	_streams["release"] = _make_whoosh()
	_streams["hit"] = _make_hit(210.0, 0.09, 36.0)
	_streams["jack"] = _make_bell()
	_streams["bank"] = _make_hit(120.0, 0.07, 28.0)
	_streams["tick"] = _make_hit(1480.0, 0.035, 70.0)
	_streams["settle"] = _make_hit(240.0, 0.14, 12.0)
	_streams["chime"] = _make_chime()
	_streams["clap"] = _make_clap()
	_streams["sparkle"] = _make_sparkle()
	_streams["cheer"] = _make_cheer()
	voice = CommentaryScript.new()
	voice.name = "Commentary"
	add_child(voice)
	crowd = CrowdScript.new()
	crowd.name = "Crowd"
	add_child(crowd)


func _process(_delta: float) -> void:
	if not _unlocked or _roll == null or not _roll.playing:
		return
	var playback := _roll.get_stream_playback()
	if playback == null:
		return
	var frames: int = playback.get_frames_available()
	var target := roll_amount
	while frames > 0:
		var noise := randf() * 2.0 - 1.0
		# Brown rumble, then a slow low-pass so the green is a hush, not grit.
		_roll_state = clampf(_roll_state + noise * 0.018, -1.0, 1.0)
		_roll_low = lerpf(_roll_low, _roll_state, 0.045)
		_roll_phase += TAU * lerpf(36.0, 78.0, target) / 22050.0
		var grain := _roll_low * 0.62 + sin(_roll_phase) * _roll_low * 0.16
		var sample := grain * target * 0.28
		playback.push_frame(Vector2(sample, sample))
		frames -= 1


func unlock() -> void:
	if _unlocked or not _allows_sound():
		return
	_unlocked = true
	_roll.play()


func set_roll(speed_ratio: float) -> void:
	var ratio := clampf(speed_ratio, 0.0, 1.0)
	roll_amount = pow(ratio, 1.45) * 0.28


func tap() -> void:
	unlock()
	_play("tick", 1.0, -8.0)
	_vibrate(12)


func aim(power_ratio: float) -> void:
	var bucket := int(power_ratio * 4.0)
	if bucket == _last_aim_bucket:
		return
	_last_aim_bucket = bucket
	if bucket <= 0:
		return
	unlock()
	_play("tick", lerpf(1.15, 0.75, power_ratio), -14.0)
	_vibrate(8 + bucket * 4)


func release(power_ratio: float) -> void:
	unlock()
	_last_aim_bucket = -1
	_play("release", lerpf(1.15, 0.82, power_ratio), -4.0)
	_vibrate(int(round(lerpf(16.0, 36.0, power_ratio))))


func contact(speed: float, hit_jack: bool, hit_bank: bool) -> void:
	unlock()
	var amount := clampf(speed / 12.0, 0.25, 1.0)
	if hit_jack:
		toucher()
		return
	elif hit_bank:
		_play("bank", lerpf(1.2, 0.8, amount), -12.0)
		_vibrate(int(round(lerpf(10.0, 22.0, amount))))
	else:
		_play("hit", lerpf(1.35, 0.78, amount), -9.0)
		_vibrate(int(round(lerpf(14.0, 34.0, amount))))
		if crowd != null:
			if speed > 3.6:
				crowd.play("clap")
			elif speed > 1.4:
				crowd.play("polite")


func toucher() -> String:
	unlock()
	crowd_toucher()
	if line("toucher", true):
		_vibrate_pattern(16, 36, 22)
		return _last_line()
	_play("clap", 1.0, -11.0)
	_play("sparkle", 1.08, -10.0)
	_vibrate_pattern(16, 36, 22)
	return ""


func praise(level: int, skippable: bool = false) -> String:
	unlock()
	crowd_for(level)
	# Quiet bowls still get a crowd, but not a line every time.
	if skippable and level <= 1 and randf() < 0.38:
		return ""
	var said := _say_from(_pool_for(level))
	if said != "":
		if level >= 3:
			_vibrate_pattern(18, 48, 26)
		else:
			_vibrate(18)
		return said
	if level >= 3:
		_play("cheer", 1.0, -8.0)
		_play("sparkle", 1.12, -12.0)
		_vibrate_pattern(18, 48, 26)
	elif level >= 1:
		_play("chime", 1.04, -9.0)
		_vibrate(18)
	else:
		_play("sparkle", 1.0, -11.0)
		_vibrate(12)
	return ""


func crowd_for(level: int) -> String:
	if not _allows_sound() or crowd == null:
		return ""
	unlock()
	var kind := "clap"
	match clampi(level, -1, 4):
		-1:
			kind = "ooh"
		0:
			kind = "polite"
		1:
			kind = "clap" if randf() > 0.28 else "polite"
		2:
			kind = "cheer" if randf() > 0.32 else "clap"
		3:
			kind = "roar" if randf() > 0.42 else "cheer"
		4:
			kind = "roar"
	if crowd.play(kind, true):
		return kind
	return ""


func crowd_toucher() -> String:
	if not _allows_sound() or crowd == null:
		return ""
	unlock()
	crowd.play("gasp", true)
	crowd.play("cheer", true)
	return "gasp"


func crowd_score(key: String) -> String:
	if not _allows_sound() or crowd == null:
		return ""
	unlock()
	var kind := "polite"
	match key:
		"you_win_match", "you_win", "you_win_end", "winner":
			kind = "roar"
		"they_win_match", "they_win_end", "tied_end":
			kind = "ooh"
		"showtime", "last_end", "match_point":
			kind = "cheer"
	if crowd.play(kind, true):
		return kind
	return ""


func _pool_for(level: int) -> Array:
	var clamped := clampi(level, 0, 4)
	if PRAISE_POOL.has(clamped):
		return PRAISE_POOL[clamped]
	return ["great"]


func _say_from(keys: Array) -> String:
	if keys.is_empty():
		return ""
	var order: Array = keys.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp: String = str(order[i])
		order[i] = order[j]
		order[j] = tmp
	for key in order:
		if line(key):
			return _last_line()
	return ""


func _last_line() -> String:
	if voice != null:
		return voice.last_said()
	return ""


func line(key: String, force: bool = false) -> bool:
	if not _allows_sound() or voice == null:
		return false
	unlock()
	return voice.say(key, force)


func mark_found(miss_m: float) -> void:
	unlock()
	if miss_m < 6.0:
		_play("chime", 1.0, -5.0)
		_vibrate_pattern(18, 60, 28)
	elif miss_m < 20.0:
		_play("jack", lerpf(1.1, 0.85, clampf(miss_m / 20.0, 0.0, 1.0)), -4.0)
		_vibrate(22)
	else:
		_play("settle", 0.9, -7.0)
		_vibrate(14)


func settled(closest_m: float) -> void:
	unlock()
	if closest_m >= 0.0 and closest_m < 1.25:
		_play("chime", 1.0, -6.0)
		_vibrate_pattern(18, 70, 28)
	else:
		_play("settle", 1.0, -8.0)
		_vibrate(16)


func _play(key: String, pitch: float, db: float) -> void:
	if not _allows_sound():
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[key]
	player.pitch_scale = pitch
	player.volume_db = db
	player.play()


func _vibrate(duration_ms: int) -> void:
	if not _allows_haptics():
		return
	Input.vibrate_handheld(duration_ms)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate(%d);" % duration_ms, true)


func _vibrate_pattern(first_ms: int, gap_ms: int, second_ms: int) -> void:
	if not _allows_haptics():
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.vibrate && navigator.vibrate([%d,%d,%d]);" % [first_ms, gap_ms, second_ms], true)
		return
	Input.vibrate_handheld(first_ms)
	_pulse_later(second_ms, first_ms + gap_ms)


func _allows_sound() -> bool:
	if not is_inside_tree():
		return true
	var tree_root := get_tree().root
	if tree_root.has_meta("flickdisc_sound"):
		return bool(tree_root.get_meta("flickdisc_sound"))
	return true


func _allows_haptics() -> bool:
	if not is_inside_tree():
		return true
	var tree_root := get_tree().root
	if tree_root.has_meta("flickdisc_haptics"):
		return bool(tree_root.get_meta("flickdisc_haptics"))
	return true


func _pulse_later(duration_ms: int, delay_ms: int) -> void:
	await get_tree().create_timer(delay_ms / 1000.0).timeout
	Input.vibrate_handheld(duration_ms)


func _make_whoosh() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.22)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var env := exp(-t * 10.0) * sin(PI * clampf(t / 0.22, 0.0, 1.0))
		var freq := lerpf(480.0, 140.0, t / 0.22)
		phase += TAU * freq / float(rate)
		var noise := randf() * 2.0 - 1.0
		samples[i] = (sin(phase) * 0.62 + noise * 0.28) * env * 0.72
	return _wav(samples, rate)


func _make_hit(freq: float, seconds: float, decay: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * seconds)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var env := exp(-t * decay)
		phase += TAU * freq / float(rate)
		var noise := randf() * 2.0 - 1.0
		samples[i] = (sin(phase) * 0.72 + noise * 0.28) * env
	return _wav(samples, rate)


func _make_bell() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.28)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var p1 := 0.0
	var p2 := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var env := exp(-t * 7.5)
		p1 += TAU * 740.0 / float(rate)
		p2 += TAU * 1180.0 / float(rate)
		samples[i] = (sin(p1) * 0.62 + sin(p2) * 0.38) * env
	return _wav(samples, rate)


func _make_chime() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.42)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phases := [0.0, 0.0, 0.0]
	var freqs := [523.25, 659.25, 783.99]
	for i in count:
		var t := float(i) / float(rate)
		var sample := 0.0
		for n in 3:
			var start := float(n) * 0.07
			var env := 0.0 if t < start else exp(-(t - start) * 6.0)
			phases[n] += TAU * freqs[n] / float(rate)
			sample += sin(phases[n]) * env
		samples[i] = sample * 0.42
	return _wav(samples, rate)


func _make_clap() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.34)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var bursts := [0.0, 0.042, 0.086, 0.15, 0.21]
	for i in count:
		var t := float(i) / float(rate)
		var env := 0.0
		for n in bursts.size():
			var start := float(bursts[n])
			if t >= start:
				var fall := exp(-(t - start) * 42.0)
				var amp := 1.0 if n < 3 else 0.62
				env = maxf(env, fall * amp)
		var noise := randf() * 2.0 - 1.0
		samples[i] = noise * env * 0.48
	return _wav(samples, rate)


func _make_sparkle() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.28)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phases := [0.0, 0.0, 0.0]
	var freqs := [988.0, 1480.0, 1976.0]
	for i in count:
		var t := float(i) / float(rate)
		var sample := 0.0
		for n in 3:
			var start := float(n) * 0.045
			var env := 0.0 if t < start else exp(-(t - start) * 9.0)
			phases[n] += TAU * freqs[n] / float(rate)
			sample += sin(phases[n]) * env
		samples[i] = sample * 0.28
	return _wav(samples, rate)


func _make_cheer() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.55)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phases := [0.0, 0.0, 0.0, 0.0]
	var freqs := [523.25, 659.25, 783.99, 1046.5]
	for i in count:
		var t := float(i) / float(rate)
		var sample := 0.0
		for n in 4:
			var start := float(n) * 0.055
			var env := 0.0 if t < start else exp(-(t - start) * 5.2)
			phases[n] += TAU * freqs[n] / float(rate)
			sample += sin(phases[n]) * env
		samples[i] = sample * 0.34
	return _wav(samples, rate)


func _wav(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var value := clampi(int(samples[i] * 32767.0), -32768, 32767)
		if value < 0:
			value += 65536
		data[i * 2] = value & 255
		data[i * 2 + 1] = (value >> 8) & 255
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
