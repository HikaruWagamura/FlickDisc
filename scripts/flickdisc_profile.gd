extends RefCounted

## Local Bowl & Roll profile. Wins, challenges, and the disc colour stay on this device.

const Kit := preload("res://scripts/kit.gd")

const COLORS: Array[Color] = [
	Color("#e12a32"),
	Color("#c41018"),
	Color("#5ad4ea"),
	Color("#d4a017"),
	Color("#7a3dff"),
	Color("#f4f4f6"),
]
const COLOR_NAMES: PackedStringArray = ["Club red", "Match red", "Ice", "Gold", "Violet", "Chalk"]
const CHALLENGE_XP := {"hole": 25, "fifteen": 15, "draw": 20}

var player_name := "Flicker"
var wins := 0
var losses := 0
var xp := 0
var rounds := 0
var disc_index := 1
var bowl_color := 1
var bowl_skin := "club"
var disc_skin := "club"
var bowl_slot := 0
var slot_skins := PackedStringArray(["club", "club", "club", "club"])
var slot_colors := PackedInt32Array([1, 1, 1, 1])
var sound := true
var haptics := true
var cleared: PackedStringArray = PackedStringArray()
var best_drive := 0.0
var best_mark := 9999.0
var solo_cleared := 0
var solo_wins := 0
var best_crazy := 0
var results: PackedStringArray = PackedStringArray()


func level() -> int:
	return 1 + int(xp / 40)


func xp_ratio() -> float:
	return float(xp % 40) / 40.0


func disc_color() -> Color:
	return Kit.palette(disc_index)["a"]


func kit() -> Dictionary:
	if bowl_skin == "photo":
		bowl_skin = "photo_left"
	Kit.active_slot = clampi(bowl_slot, 0, Kit.SLOT_COUNT - 1)
	return {
		"bowl_skin": bowl_skin,
		"bowl_color": bowl_color,
		"disc_skin": disc_skin,
		"disc_color": disc_index,
		"bowl_slot": clampi(bowl_slot, 0, Kit.SLOT_COUNT - 1),
	}


func slot_skin(index: int) -> String:
	var i := clampi(index, 0, slot_skins.size() - 1)
	return str(slot_skins[i])


func slot_color(index: int) -> int:
	var i := clampi(index, 0, slot_colors.size() - 1)
	return int(slot_colors[i])


func set_slot(index: int, skin_id: String, color_index: int) -> void:
	var i := clampi(index, 0, Kit.SLOT_COUNT - 1)
	while slot_skins.size() < Kit.SLOT_COUNT:
		slot_skins.append("club")
	while slot_colors.size() < Kit.SLOT_COUNT:
		slot_colors.append(1)
	slot_skins[i] = skin_id
	slot_colors[i] = color_index
	if i == bowl_slot:
		bowl_skin = skin_id
		bowl_color = color_index


func disc_name() -> String:
	return str(Kit.palette(disc_index)["name"])


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
	bowl_color = int(cfg.get_value("player", "bowl_color", 1))
	bowl_skin = str(cfg.get_value("player", "bowl_skin", "club"))
	disc_skin = str(cfg.get_value("player", "disc_skin", "club"))
	bowl_slot = clampi(int(cfg.get_value("player", "bowl_slot", 0)), 0, Kit.SLOT_COUNT - 1)
	slot_skins = PackedStringArray()
	slot_colors = PackedInt32Array()
	for i in Kit.SLOT_COUNT:
		var fallback_skin := bowl_skin if i == 0 else "club"
		var fallback_color := bowl_color if i == 0 else 1
		slot_skins.append(str(cfg.get_value("player", "slot_%d_skin" % i, fallback_skin)))
		slot_colors.append(int(cfg.get_value("player", "slot_%d_color" % i, fallback_color)))
	bowl_skin = slot_skin(bowl_slot)
	bowl_color = slot_color(bowl_slot)
	if bowl_skin == "split":
		bowl_skin = "club"
	if bowl_skin == "photo":
		bowl_skin = "photo_left"
	if disc_skin == "both":
		disc_skin = "club"
	if disc_skin.begins_with("photo"):
		disc_skin = "club"
	sound = bool(cfg.get_value("player", "sound", true))
	haptics = bool(cfg.get_value("player", "haptics", true))
	best_drive = float(cfg.get_value("player", "best_drive", 0.0))
	best_mark = float(cfg.get_value("player", "best_mark", 9999.0))
	solo_cleared = int(cfg.get_value("player", "solo_cleared", 0))
	solo_wins = int(cfg.get_value("player", "solo_wins", 0))
	best_crazy = int(cfg.get_value("player", "best_crazy", 0))
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
	cfg.set_value("player", "bowl_color", bowl_color)
	cfg.set_value("player", "bowl_skin", bowl_skin)
	cfg.set_value("player", "disc_skin", disc_skin)
	cfg.set_value("player", "bowl_slot", clampi(bowl_slot, 0, Kit.SLOT_COUNT - 1))
	for i in Kit.SLOT_COUNT:
		cfg.set_value("player", "slot_%d_skin" % i, slot_skin(i))
		cfg.set_value("player", "slot_%d_color" % i, slot_color(i))
	cfg.set_value("player", "sound", sound)
	cfg.set_value("player", "haptics", haptics)
	cfg.set_value("player", "cleared", ",".join(cleared))
	cfg.set_value("player", "best_drive", best_drive)
	cfg.set_value("player", "best_mark", best_mark)
	cfg.set_value("player", "solo_cleared", solo_cleared)
	cfg.set_value("player", "solo_wins", solo_wins)
	cfg.set_value("player", "best_crazy", best_crazy)
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


func note_crazy(strokes: int, par: int) -> void:
	if best_crazy <= 0 or strokes < best_crazy:
		best_crazy = strokes
	xp += 16
	var vs := strokes - par
	var line := "EVEN" if vs == 0 else ("%+d" % vs)
	_push_result("Crazy Bowls %d  ·  %s" % [strokes, line])
	save_profile()


func drive_text() -> String:
	if best_drive < 1.0:
		return "NO DRIVE YET"
	return "%d m" % int(round(best_drive))


func crazy_text() -> String:
	if best_crazy <= 0:
		return "NO ROUND YET"
	return "%d STROKES" % best_crazy


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
