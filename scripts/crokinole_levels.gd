extends Node

## A 1v1 Crokinole round. Twelve discs each, empty board, same seats
## every end. Match length lives on the Play sheet, not here.

const LEVELS := [
	{
		"number": 1,
		"difficulty": "1v1",
		"discs": 12,
		"opponents": [],
	},
]

func get_level(level_index: int) -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)]

func get_level_count() -> int:
	return LEVELS.size()
