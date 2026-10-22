extends RefCounted

## Local FlickDisc profile. Wins, challenges, and the disc colour stay on this device.

const COLORS: Array[Color] = [
	Color("#ff3d9a"),
	Color("#ff4b5c"),
	Color("#7af0ff"),
	Color("#ffe27a"),
	Color("#c9a4ff"),
	Color("#f4f4f6"),
]
const COLOR_NAMES: PackedStringArray = ["Club pink", "Hot red", "Ice", "Gold", "Violet", "Chalk"]
const CHALLENGE_XP := {"hole": 25, "fifteen": 15, "draw": 20}

var player_name := "Flicker"
var wins := 0
var losses := 0
var xp := 0
var rounds := 0
var disc_index := 0
var sound := true
var haptics := true
var cleared: PackedStringArray = PackedStringArray()


func level() -> int:
	return 1 + int(xp / 40)


func xp_ratio() -> float:
	return float(xp % 40) / 40.0


func disc_color() -> Color:
	return COLORS[clampi(disc_index, 0, COLORS.size() - 1)]


func disc_name() -> String:
	return COLOR_NAMES[clampi(disc_index, 0, COLOR_NAMES.size() - 1)]


func record_text() -> String:
	return "%dW  ·  %dL" % [wins, losses]


func is_cleared(challenge_id: String) -> bool:
	return challenge_id in cleared


func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://flickdisc.cfg") != OK:
		return
	player_name = str(cfg.get_value("player", "name", "Flicker"))
	if player_name.strip_edges() == "":
		player_name = "Flicker"
	wins = int(cfg.get_value("player", "wins", 0))
	losses = int(cfg.get_value("player", "losses", 0))
	xp = int(cfg.get_value("player", "xp", 0))
	rounds = int(cfg.get_value("player", "rounds", 0))
	disc_index = int(cfg.get_value("player", "disc", 0))
	sound = bool(cfg.get_value("player", "sound", true))
	haptics = bool(cfg.get_value("player", "haptics", true))
	cleared = PackedStringArray()
	var raw := str(cfg.get_value("player", "cleared", ""))
	if raw != "":
		for part in raw.split(","):
			var ident := str(part).strip_edges()
			if ident != "":
				cleared.append(ident)


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "wins", wins)
	cfg.set_value("player", "losses", losses)
	cfg.set_value("player", "xp", xp)
	cfg.set_value("player", "rounds", rounds)
	cfg.set_value("player", "disc", disc_index)
	cfg.set_value("player", "sound", sound)
	cfg.set_value("player", "haptics", haptics)
	cfg.set_value("player", "cleared", ",".join(cleared))
	cfg.save("user://flickdisc.cfg")


func note_round() -> void:
	rounds += 1
	save_profile()


func record_match(you_won: bool) -> void:
	if you_won:
		wins += 1
	else:
		losses += 1
	xp += 8
	save_profile()


func clear_challenge(challenge_id: String) -> bool:
	if challenge_id == "" or challenge_id in cleared:
		return false
	cleared.append(challenge_id)
	xp += int(CHALLENGE_XP.get(challenge_id, 10))
	save_profile()
	return true
