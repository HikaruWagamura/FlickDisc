extends Node

## A 1v1 FlickDisc round. Eight discs each, cream versus brown.

const LEVELS := [
	{
		"number": 1,
		"difficulty": "1v1",
		"discs": 8,
		"opponents": [],
	},
]

func get_level(level_index: int) -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)]

func get_level_count() -> int:
	return LEVELS.size()
