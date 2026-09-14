class_name LevelManager
extends Node

## Level data is kept in one list so adding many future levels only means
## adding another dictionary here or loading the same shape from a data file.

const LEVELS := [
	{
		"number": 1,
		"jack_position": Vector2(270.0, 270.0),
		"rink_size": Vector2(456.0, 730.0),
		"throws": 3,
		"difficulty": "Practice",
	},
	{
		"number": 2,
		"jack_position": Vector2(178.0, 325.0),
		"rink_size": Vector2(456.0, 730.0),
		"throws": 3,
		"difficulty": "Easy",
	},
	{
		"number": 3,
		"jack_position": Vector2(362.0, 390.0),
		"rink_size": Vector2(456.0, 730.0),
		"throws": 3,
		"difficulty": "Easy",
	},
	{
		"number": 4,
		"jack_position": Vector2(224.0, 465.0),
		"rink_size": Vector2(456.0, 730.0),
		"throws": 3,
		"difficulty": "Medium",
	},
	{
		"number": 5,
		"jack_position": Vector2(410.0, 300.0),
		"rink_size": Vector2(456.0, 730.0),
		"throws": 3,
		"difficulty": "Medium",
	},
]

func get_level(level_index: int) -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)]

func get_level_count() -> int:
	return LEVELS.size()