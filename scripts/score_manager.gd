class_name ScoreManager
extends Node

var throw_distances: Array[float] = []

func reset() -> void:
	throw_distances.clear()

func record_throw(distance_meters: float) -> void:
	throw_distances.append(distance_meters)

func get_closest_distance() -> float:
	if throw_distances.is_empty():
		return -1.0
	return throw_distances.min()

func get_score() -> int:
	var closest := get_closest_distance()
	if closest < 0.0:
		return 0
	# The playing surface is about 0.66 m across. A puck that finishes within
	# a few centimeters scores high; half a meter away scores nothing.
	return maxi(0, roundi(1000.0 - closest * 2200.0))
