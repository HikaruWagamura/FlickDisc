class_name LevelManager
extends Node

## Jack positions are meters on the green: x across the rink, z down the rink.
## The head sits in the far half of the 38 m green, the way a lawn-bowls head does.

const LEVELS := [
	{
		"number": 1,
		"jack_position": Vector2(0.0, -22.0),
		"throws": 3,
		"difficulty": "Practice",
	},
	{
		"number": 2,
		"jack_position": Vector2(-0.8, -20.2),
		"throws": 3,
		"difficulty": "Easy",
	},
	{
		"number": 3,
		"jack_position": Vector2(0.95, -24.0),
		"throws": 3,
		"difficulty": "Easy",
	},
	{
		"number": 4,
		"jack_position": Vector2(-0.55, -23.2),
		"throws": 3,
		"difficulty": "Medium",
	},
	{
		"number": 5,
		"jack_position": Vector2(0.7, -25.4),
		"throws": 3,
		"difficulty": "Medium",
	},
]


func get_level(level_index: int) -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)]


func get_level_count() -> int:
	return LEVELS.size()
