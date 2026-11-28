class_name Crowd
extends Node

## Reaction beds for the green. Drop WAVs in res://assets/audio/crowd
## named the kind (Roar.wav, Cheer 2.wav, Applause.wav). Missing kinds
## stay silent; Feel still has a quiet synth clap behind the voice.

const FOLDER := "res://assets/audio/crowd"
const KEYS := ["polite", "clap", "cheer", "roar", "gasp", "ooh"]
const ALIASES := {
	"polite": "polite",
	"polite clap": "polite",
	"light clap": "polite",
	"golf clap": "polite",
	"clap": "clap",
	"claps": "clap",
	"applause": "clap",
	"crowd clap": "clap",
	"cheer": "cheer",
	"cheers": "cheer",
	"crowd cheer": "cheer",
	"heavy cheer": "roar",
	"roar": "roar",
	"crowd roar": "roar",
	"big cheer": "roar",
	"gasp": "gasp",
	"ooh": "ooh",
	"ooo": "ooh",
	"oooh": "ooh",
	"ohh": "ooh",
	"crowd ooh": "ooh",
}
const VOLUME := {
	"polite": -16.0,
	"clap": -13.0,
	"cheer": -10.0,
	"roar": -7.0,
	"gasp": -14.0,
	"ooh": -15.0,
}
const MIN_GAP := 0.85

var _clips := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_kind := ""
var _last_at := -99.0


func _ready() -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_load_bank()


func has_kind(kind: String) -> bool:
	return _clips.has(kind) and not _clips[kind].is_empty()


func last_kind() -> String:
	return _last_kind


func loaded_kinds() -> PackedStringArray:
	var out := PackedStringArray()
	for kind in KEYS:
		if has_kind(kind):
			out.append(kind)
	return out


func play(kind: String, force: bool = false) -> bool:
	if not has_kind(kind):
		return false
	var now := Time.get_ticks_msec() * 0.001
	if not force and now - _last_at < MIN_GAP and kind != "gasp":
		return false
	var takes: Array = _clips[kind]
	var clip: AudioStream = takes[randi() % takes.size()]
	if clip == null:
		return false
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stop()
	player.stream = clip
	player.pitch_scale = randf_range(0.97, 1.04)
	player.volume_db = float(VOLUME.get(kind, -12.0))
	player.play()
	_last_kind = kind
	_last_at = now
	return true


func _load_bank() -> void:
	_clips.clear()
	for kind in KEYS:
		_clips[kind] = []
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir():
			_try_add(name)
		name = dir.get_next()
	dir.list_dir_end()


func _try_add(file_name: String) -> void:
	if file_name.ends_with(".import"):
		return
	var ext := file_name.get_extension().to_lower()
	if ext != "ogg" and ext != "wav" and ext != "mp3":
		return
	var key := _key_for(file_name.get_basename())
	if key == "":
		return
	var stream: Resource = load("%s/%s" % [FOLDER, file_name])
	if stream is AudioStream:
		_clips[key].append(stream)


func _key_for(stem: String) -> String:
	var folded := _fold(stem)
	if ALIASES.has(folded):
		return str(ALIASES[folded])
	var underscored := folded.replace(" ", "_")
	if KEYS.has(underscored):
		return underscored
	var parts := folded.split(" ")
	if parts.size() >= 2 and str(parts[parts.size() - 1]).is_valid_int():
		var base := " ".join(parts.slice(0, parts.size() - 1))
		if ALIASES.has(base):
			return str(ALIASES[base])
		var u := base.replace(" ", "_")
		if KEYS.has(u):
			return u
	return ""


func _fold(text: String) -> String:
	var s := text.to_lower().replace("'", "").replace("’", "")
	var words: PackedStringArray = PackedStringArray()
	var word := ""
	for i in s.length():
		var code := s.unicode_at(i)
		var alnum := (code >= 97 and code <= 122) or (code >= 48 and code <= 57)
		if alnum:
			word += String.chr(code)
		elif word != "":
			words.append(word)
			word = ""
	if word != "":
		words.append(word)
	return " ".join(words)
