class_name Commentary
extends Node

## Scott's voice, dropped in as WAV or OGG. Missing files stay silent and
## the synthesized clap / chime still covers the shot.

const FOLDER := "res://assets/audio/commentary"
const KEYS := [
	"toucher", "amazing", "great_shot", "fantastic", "magnificent", "incredible",
	"down_1", "down_2", "down_3", "up_1", "up_2", "up_3",
	"tied_end", "you_win_end", "they_win_end", "you_win_match", "they_win_match",
	"last_end", "match_point",
]

var _clips := {}
var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -3.0
	add_child(_player)
	_load_bank()


func has_line(key: String) -> bool:
	return _clips.has(key) and not _clips[key].is_empty()


func say(key: String) -> bool:
	if not has_line(key):
		return false
	var takes: Array = _clips[key]
	var clip: AudioStream = takes[randi() % takes.size()]
	if clip == null:
		return false
	_player.stop()
	_player.stream = clip
	_player.pitch_scale = 1.0
	_player.play()
	return true


func _load_bank() -> void:
	_clips.clear()
	for key in KEYS:
		_clips[key] = []
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
	var key: String = _key_for(file_name.get_basename())
	if key == "":
		return
	var stream: Resource = load("%s/%s" % [FOLDER, file_name])
	if stream is AudioStream:
		_clips[key].append(stream)


func _key_for(stem: String) -> String:
	if KEYS.has(stem):
		return stem
	var under := stem.rfind("_")
	if under <= 0:
		return ""
	var tail := stem.substr(under + 1)
	var prefix := stem.substr(0, under)
	if tail.is_valid_int() and KEYS.has(prefix):
		return prefix
	return ""
