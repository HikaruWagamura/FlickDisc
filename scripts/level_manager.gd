class_name LevelManager
extends Node

## Each end is the same green. The player chooses a short or long jack.

const LEVELS := [
	{"number": 1, "throws": 3, "difficulty": "Practice"},
	{"number": 2, "throws": 3, "difficulty": "Easy"},
	{"number": 3, "throws": 3, "difficulty": "Easy"},
	{"number": 4, "throws": 3, "difficulty": "Medium"},
	{"number": 5, "throws": 3, "difficulty": "Medium"},
]


func get_level(level_index: int) -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)]


func get_level_count() -> int:
	return LEVELS.size()
