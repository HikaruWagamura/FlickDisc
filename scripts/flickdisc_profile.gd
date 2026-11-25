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
var best_drive := 0.0
var best_mark := 9999.0
var solo_cleared := 0
var solo_wins := 0
var results: PackedStringArray = PackedStringArray()


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
	best_drive = float(cfg.get_value("player", "best_drive", 0.0))
	best_mark = float(cfg.get_value("player", "best_mark", 9999.0))
	solo_cleared = int(cfg.get_value("player", "solo_cleared", 0))
	solo_wins = int(cfg.get_value("player", "solo_wins", 0))
	results = PackedStringArray()
	var history := str(cfg.get_value("player", "results", ""))
	if history != "":
		for part in history.split("|"):
			var line := str(part).strip_edges()
			if line != "":
				results.append(line)
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
	cfg.set_value("player", "best_drive", best_drive)
	cfg.set_value("player", "best_mark", best_mark)
	cfg.set_value("player", "solo_cleared", solo_cleared)
	cfg.set_value("player", "solo_wins", solo_wins)
	cfg.set_value("player", "results", "|".join(results))
	cfg.save("user://flickdisc.cfg")


func note_round() -> void:
	rounds += 1
	save_profile()


func record_match(you_won: bool) -> void:
	if you_won:
		wins += 1
		_push_result("Match won  ·  %d wins" % wins)
	else:
		losses += 1
		_push_result("Match lost  ·  %d losses" % losses)
	xp += 8
	save_profile()


func note_drive(metres: float, miss: float) -> void:
	var posted := false
	if metres > best_drive + 0.5:
		best_drive = metres
		posted = true
	if miss < best_mark - 0.05:
		best_mark = miss
		posted = true
	if posted:
		var near := "mark %.1f m" % miss
		_push_result("Drive %d m  ·  %s" % [int(round(metres)), near])
		xp += 2
		save_profile()


func note_solo(end_number: int) -> void:
	solo_wins += 1
	if end_number > solo_cleared:
		solo_cleared = end_number
	xp += 12
	_push_result("Solo end %d cleared" % end_number)
	save_profile()


func drive_text() -> String:
	if best_drive < 1.0:
		return "NO DRIVE YET"
	return "%d m" % int(round(best_drive))


func mark_text() -> String:
	if best_mark > 500.0:
		return "MARK NOT FOUND"
	return "%.1f m" % best_mark


func _push_result(line: String) -> void:
	results.insert(0, line)
	while results.size() > 8:
		results.remove_at(results.size() - 1)


func clear_challenge(challenge_id: String) -> bool:
	if challenge_id == "" or challenge_id in cleared:
		return false
	cleared.append(challenge_id)
	xp += int(CHALLENGE_XP.get(challenge_id, 10))
	save_profile()
	return true
