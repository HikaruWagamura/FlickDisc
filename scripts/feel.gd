class_name Feel
extends Node

## Short synthesized cues. No imported audio files, so the phone and the
## browser build both have the same release, roll, hit, and settle sounds.
## Haptics use the device vibrator and, on the web, navigator.vibrate.

var roll_amount := 0.0
var _unlocked := false
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _roll: AudioStreamPlayer
var _roll_state := 0.0
var _streams := {}
var _last_aim_bucket := -1


func _ready() -> void:
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_roll = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.2
	_roll.stream = generator
	_roll.volume_db = -16.0
	add_child(_roll)
	_streams["release"] = _make_whoosh()
	_streams["hit"] = _make_hit(210.0, 0.09, 36.0)
	_streams["jack"] = _make_bell()
	_streams["bank"] = _make_hit(120.0, 0.07, 28.0)
	_streams["tick"] = _make_hit(1480.0, 0.035, 70.0)
	_streams["settle"] = _make_hit(240.0, 0.14, 12.0)
	_streams["chime"] = _make_chime()


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
		_roll_state = lerpf(_roll_state, noise, 0.18)
		var sample := _roll_state * target
		playback.push_frame(Vector2(sample, sample))
		frames -= 1


func unlock() -> void:
	if _unlocked or not _allows_sound():
		return
	_unlocked = true
	_roll.play()


func set_roll(speed_ratio: float) -> void:
	roll_amount = clampf(speed_ratio, 0.0, 1.0) * 0.55


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
		_play("jack", lerpf(1.25, 0.82, amount), -3.0)
		_vibrate(int(round(lerpf(18.0, 46.0, amount))))
	elif hit_bank:
		_play("bank", lerpf(1.2, 0.8, amount), -8.0)
		_vibrate(int(round(lerpf(10.0, 22.0, amount))))
	else:
		_play("hit", lerpf(1.35, 0.78, amount), -5.0)
		_vibrate(int(round(lerpf(14.0, 34.0, amount))))


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
		samples[i] = (sin(phase) * 0.35 + noise * 0.65) * env
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
