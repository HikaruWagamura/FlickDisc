class_name LevelManager
extends Node

## The jack is delivered by the player. Each level only sets how far it must
## travel before the bowls are allowed. Distances are metres from the mat.

const LEVELS := [
	{
		"number": 1,
		"min_jack_m": 18.0,
		"throws": 3,
		"difficulty": "Practice",
	},
	{
		"number": 2,
		"min_jack_m": 23.0,
		"throws": 3,
		"difficulty": "Easy",
	},
	{
		"number": 3,
		"min_jack_m": 28.0,
		"throws": 3,
		"difficulty": "Easy",
	},
	{
		"number": 4,
		"min_jack_m": 33.0,
		"throws": 3,
		"difficulty": "Medium",
	},
	{
		"number": 5,
		"min_jack_m": 38.0,
		"throws": 3,
		"difficulty": "Medium",
	},
]


func get_level(level_index: int) -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)]


func get_level_count() -> int:
	return LEVELS.size()
