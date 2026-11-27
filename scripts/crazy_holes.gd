class_name CrazyHoles
extends RefCounted

## Eighteen bowls-golf holes. Same grass as the rink, a bit wider, with
## lumps, water, and a cup. Course par 70.

const COURSE_PAR := 70
const HOLE_COUNT := 18
const NAMES := [
	"Opening Green", "The Shoulder", "Water Meadow", "Long Bank",
	"The Wedge", "Twin Trees", "Far Ditch", "The Hollow",
	"Cross Pond", "High Ridge", "The Keyhole", "Offset Cup",
	"The Hook", "Narrow Gate", "The Bean", "Double Carry",
	"The Fan", "Home Green",
]


static func deal(round_seed: int) -> Array:
	var holes: Array = []
	for index in HOLE_COUNT:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([round_seed, index, 441001])
		holes.append(_make(index, rng))
	return holes


static func _make(index: int, rng: RandomNumberGenerator) -> Dictionary:
	if index == 0:
		return _hero_hole()
	var par := _par_for(index)
	var length := _length_for(par, rng)
	var half := 7.6 + rng.randf_range(0.2, 1.4)
	if par == 5:
		half += 0.6
	var tee := Vector3(rng.randf_range(-0.8, 0.8), 0.0, -1.55)
	var cup := _place_cup(length, half, par, rng)
	var cup_r := 0.78 if par == 3 else (0.68 if par == 4 else 0.60)
	cup_r += rng.randf_range(-0.04, 0.05)
	return {
		"index": index,
		"number": index + 1,
		"name": NAMES[index],
		"par": par,
		"length": length,
		"half": half,
		"tee": tee,
		"cup": cup,
		"cup_radius": cup_r,
		"bumps": _bumps(length, half, tee, cup, rng),
		"waters": _waters(index, length, half, tee, cup, rng),
		"trees": _trees(length, half, tee, cup, rng),
	}


static func _hero_hole() -> Dictionary:
	# One readable par 3: clean left fairway, water on the right,
	# a collecting green, and a cup you can see. Same grass as the rink.
	var tee := Vector3(0.0, 0.0, -1.55)
	var cup := Vector3(-1.15, 0.0, -24.6)
	var half := 8.4
	var length := 28.0
	return {
		"index": 0,
		"number": 1,
		"name": "Opening Green",
		"par": 3,
		"length": length,
		"half": half,
		"tee": tee,
		"cup": cup,
		"cup_radius": 0.92,
		"bumps": [
			{"pos": Vector3(2.15, 0.0, -12.4), "radius": 4.6, "height": 0.20},
			{"pos": Vector3(-3.35, 0.0, -16.2), "radius": 3.8, "height": 0.12},
			{"pos": Vector3(-0.4, 0.0, -21.0), "radius": 4.4, "height": -0.14},
			{"pos": cup, "radius": 4.2, "height": -0.08},
		],
		"waters": [
			{"pos": Vector3(3.85, 0.0, -14.8), "radius": 3.55},
		],
		"trees": [
			{"pos": Vector3(-9.2, 0.0, -6.5), "radius": 0.42, "scale": 1.18},
			{"pos": Vector3(-9.6, 0.0, -13.2), "radius": 0.46, "scale": 1.32},
			{"pos": Vector3(-9.0, 0.0, -21.4), "radius": 0.40, "scale": 1.08},
			{"pos": Vector3(9.4, 0.0, -5.8), "radius": 0.44, "scale": 1.22},
			{"pos": Vector3(9.8, 0.0, -18.6), "radius": 0.48, "scale": 1.36},
			{"pos": Vector3(9.1, 0.0, -25.2), "radius": 0.40, "scale": 1.12},
			{"pos": Vector3(-4.6, 0.0, -10.8), "radius": 0.36, "scale": 0.92},
			{"pos": Vector3(5.9, 0.0, -22.4), "radius": 0.38, "scale": 1.02},
		],
	}


static func _par_for(index: int) -> int:
	# Six par 3s, eight par 4s, four par 5s = 70.
	var threes := [0, 2, 4, 7, 10, 13]
	var fives := [3, 9, 15, 17]
	if index in threes:
		return 3
	if index in fives:
		return 5
	return 4


static func _length_for(par: int, rng: RandomNumberGenerator) -> float:
	if par == 3:
		return rng.randf_range(24.0, 31.0)
	if par == 5:
		return rng.randf_range(52.0, 62.0)
	return rng.randf_range(38.0, 47.0)


static func _place_cup(length: float, half: float, par: int, rng: RandomNumberGenerator) -> Vector3:
	var along := length * rng.randf_range(0.78, 0.92)
	var side_span := half * (0.22 if par == 3 else 0.38)
	var side := rng.randf_range(-side_span, side_span)
	return Vector3(side, 0.0, -along)


static func _clear_of(at: Vector3, keepers: Array, gap: float) -> bool:
	for item in keepers:
		if at.distance_to(item) < gap:
			return false
	return true


static func _bumps(length: float, half: float, tee: Vector3, cup: Vector3, rng: RandomNumberGenerator) -> Array:
	var bumps: Array = []
	var count := 5 + rng.randi() % 4
	for _i in count:
		var at := Vector3(
			rng.randf_range(-half + 1.4, half - 1.4),
			0.0,
			rng.randf_range(-length + 3.0, -4.0)
		)
		if at.distance_to(tee) < 4.0 or at.distance_to(cup) < 3.2:
			continue
		bumps.append({
			"pos": at,
			"radius": rng.randf_range(2.4, 5.6),
			"height": rng.randf_range(-0.22, 0.42),
		})
	# A collecting dish around the cup, like a real green.
	bumps.append({
		"pos": cup,
		"radius": rng.randf_range(3.2, 4.6),
		"height": rng.randf_range(-0.10, -0.04),
	})
	return bumps


static func _waters(index: int, length: float, half: float, tee: Vector3, cup: Vector3, rng: RandomNumberGenerator) -> Array:
	var waters: Array = []
	if index in [0, 4, 7, 10, 13, 17]:
		return waters
	var count := 1 if index % 3 != 0 else 2
	for _i in count:
		var at := Vector3(
			rng.randf_range(-half + 2.2, half - 2.2),
			0.0,
			rng.randf_range(-length * 0.72, -length * 0.28)
		)
		if at.distance_to(tee) < 8.0 or at.distance_to(cup) < 5.5:
			continue
		waters.append({
			"pos": at,
			"radius": rng.randf_range(2.1, 3.6),
		})
	return waters


static func _trees(length: float, half: float, tee: Vector3, cup: Vector3, rng: RandomNumberGenerator) -> Array:
	var trees: Array = []
	var count := 10 + rng.randi() % 6
	for i in count:
		var side := 1.0 if i % 2 == 0 else -1.0
		var in_play := rng.randf() < 0.22
		var x := side * (half + rng.randf_range(0.6, 2.2))
		if in_play:
			x = rng.randf_range(-half + 1.8, half - 1.8)
		var z := rng.randf_range(-length + 2.0, -3.5)
		var at := Vector3(x, 0.0, z)
		if at.distance_to(tee) < 5.0 or at.distance_to(cup) < 4.0:
			continue
		trees.append({
			"pos": at,
			"radius": rng.randf_range(0.32, 0.52),
			"scale": rng.randf_range(0.9, 1.35),
		})
	return trees
