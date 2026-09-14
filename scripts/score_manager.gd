class_name ScoreManager
extends Node

var throw_distances: Array[float] = []

func reset() -> void:
	throw_distances.clear()

func record_throw(distance: float) -> void:
	throw_distances.append(distance)

func get_closest_distance() -> float:
	if throw_distances.is_empty():
		return -1.0
	return throw_distances.min()

func get_score() -> int:
	var closest := get_closest_distance()
	if closest < 0.0:
		return 0
	# A forgiving score curve keeps early attempts encouraging while making
	# very close throws feel meaningfully better.
	return maxi(0, roundi(1000.0 - closest * 7.0))