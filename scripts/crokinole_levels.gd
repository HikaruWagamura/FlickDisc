extends Node

## Each level is a crokinole layout. Opponent buttons are placed in world
## units on the table, away from the eight pegs.

const LEVELS := [
	{
		"number": 1,
		"difficulty": "Open Board",
		"discs": 8,
		"opponents": [
			Vector2(0.0, -0.40),
			Vector2(-0.24, -0.50),
			Vector2(0.24, -0.50),
		],
	},
	{
		"number": 2,
		"difficulty": "Peg Guard",
		"discs": 8,
		"opponents": [
			Vector2(0.0, -0.42),
			Vector2(-0.24, -0.36),
			Vector2(0.24, -0.36),
			Vector2(0.0, -0.56),
		],
	},
	{
		"number": 3,
		"difficulty": "Far Cluster",
		"discs": 8,
		"opponents": [
			Vector2(-0.16, -0.48),
			Vector2(0.16, -0.48),
			Vector2(0.0, -0.44),
			Vector2(-0.34, -0.66),
			Vector2(0.34, -0.66),
		],
	},
	{
		"number": 4,
		"difficulty": "Split Posts",
		"discs": 8,
		"opponents": [
			Vector2(-0.36, -0.22),
			Vector2(0.36, -0.22),
			Vector2(0.0, -0.5),
			Vector2(-0.46, -0.42),
		],
	},
	{
		"number": 5,
		"difficulty": "Hole Watch",
		"discs": 8,
		"opponents": [
			Vector2(-0.46, -0.20),
			Vector2(0.46, -0.20),
			Vector2(0.0, -0.44),
			Vector2(-0.36, -0.58),
			Vector2(0.36, -0.58),
		],
	},
]

func get_level(level_index: int) -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)]

func get_level_count() -> int:
	return LEVELS.size()
