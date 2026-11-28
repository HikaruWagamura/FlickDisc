class_name Commentary
extends Node

## Scott's voice. Name the file the words he said, e.g. "Great shot.ogg"
## or "Down by one.wav". Extra takes: "Incredible 2.ogg". Missing clips
## stay silent and the synth clap / chime still covers the shot.

const FOLDER := "res://assets/audio/commentary"
const KEYS := [
	"toucher", "amazing", "great", "great_shot", "fantastic", "magnificent", "incredible",
	"wow", "my_god", "not_bad", "that_was_close", "showtime", "winner", "you_win",
	"brilliant", "perfect", "okay", "nice", "good", "unlucky", "excellent", "superb",
	"well_done", "so_close",
	"down_1", "down_2", "down_3", "up_1", "up_2", "up_3",
	"tied_end", "you_win_end", "they_win_end", "you_win_match", "they_win_match",
	"last_end", "match_point",
]
const FALLBACK := {
	"toucher": ["wow"],
	"amazing": ["not_bad", "okay"],
	"great_shot": ["great", "nice"],
	"fantastic": ["great", "brilliant"],
	"magnificent": ["wow", "brilliant"],
	"incredible": ["my_god", "perfect", "wow"],
	"brilliant": ["wow", "great"],
	"perfect": ["my_god", "incredible", "wow"],
	"okay": ["not_bad"],
	"nice": ["great"],
	"good": ["great", "nice"],
	"unlucky": ["that_was_close"],
	"so_close": ["that_was_close"],
	"excellent": ["wow", "brilliant", "great"],
	"superb": ["wow", "incredible"],
	"well_done": ["great", "nice"],
	"you_win_match": ["you_win", "winner"],
	"you_win_end": ["winner"],
	"last_end": ["showtime"],
	"match_point": ["showtime"],
}
const ALIASES := {
	"toucher": "toucher",
	"toucha": "toucher",
	"amazing": "amazing",
	"great": "great",
	"great 2": "great",
	"great shot": "great_shot",
	"wow": "wow",
	"my god": "my_god",
	"oh my god": "my_god",
	"not bad": "not_bad",
	"that was close": "that_was_close",
	"so close": "so_close",
	"brilliant": "brilliant",
	"perfect": "perfect",
	"okay": "okay",
	"ok": "okay",
	"nice": "nice",
	"nice shot": "nice",
	"good": "good",
	"good shot": "good",
	"unlucky": "unlucky",
	"excellent": "excellent",
	"superb": "superb",
	"well done": "well_done",
	"showtime": "showtime",
	"show time": "showtime",
	"winner": "winner",
	"you win": "you_win",
	"fantastic": "fantastic",
	"magnificent": "magnificent",
	"incredible": "incredible",
	"down by one": "down_1",
	"down by 1": "down_1",
	"down one": "down_1",
	"youre down by one": "down_1",
	"youre down by 1": "down_1",
	"down by two": "down_2",
	"down by 2": "down_2",
	"down two": "down_2",
	"youre down by two": "down_2",
	"down by three": "down_3",
	"down by 3": "down_3",
	"youre down by three": "down_3",
	"up by one": "up_1",
	"up by 1": "up_1",
	"up one": "up_1",
	"youre up by one": "up_1",
	"up by two": "up_2",
	"up by 2": "up_2",
	"youre up by two": "up_2",
	"up by three": "up_3",
	"up by 3": "up_3",
	"tied end": "tied_end",
	"its a tie": "tied_end",
	"tie": "tied_end",
	"you win the end": "you_win_end",
	"you take the end": "you_win_end",
	"they win the end": "they_win_end",
	"you win the match": "you_win_match",
	"they win": "they_win_match",
	"they win the match": "they_win_match",
	"last end": "last_end",
	"final end": "last_end",
	"match point": "match_point",
}
const MIN_GAP := 3.6

var _clips := {}
var _player: AudioStreamPlayer
var _last_key := ""
var _last_at := -99.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -3.0
	add_child(_player)
	_load_bank()


func has_line(key: String) -> bool:
	return _clips.has(key) and not _clips[key].is_empty()


func can_say(key: String) -> bool:
	if has_line(key):
		return true
	if FALLBACK.has(key):
		for alt in FALLBACK[key]:
			if has_line(str(alt)):
				return true
	return false


func is_talking() -> bool:
	return _player != null and _player.playing


func last_said() -> String:
	return _last_key


func say(key: String, force: bool = false) -> bool:
	if _play_key(key, force):
		return true
	if FALLBACK.has(key):
		for alt in FALLBACK[key]:
			if _play_key(str(alt), force):
				return true
	return false


func _play_key(key: String, force: bool) -> bool:
	if not has_line(key):
		return false
	var now := Time.get_ticks_msec() * 0.001
	if not force:
		if is_talking():
			return false
		if now - _last_at < MIN_GAP:
			return false
		if key == _last_key and now - _last_at < 12.0:
			return false
	var takes: Array = _clips[key]
	var clip: AudioStream = takes[randi() % takes.size()]
	if clip == null:
		return false
	_player.stop()
	_player.stream = clip
	_player.pitch_scale = 1.0
	_player.play()
	_last_key = key
	_last_at = now
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
