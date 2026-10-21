class_name ScoreManager
extends Node

const Metrics = preload("res://scripts/table_metrics.gd")

func points_for(distance_from_center: float, sunk: bool) -> int:
	return Metrics.points_for(distance_from_center, sunk)
