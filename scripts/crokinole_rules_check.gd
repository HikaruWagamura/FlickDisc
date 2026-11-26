extends SceneTree

## Headless NCA scoring checks for FlickDisc.

const Metrics = preload("res://scripts/table_metrics.gd")

func _init() -> void:
	var failed := 0
	failed += _expect("hole is 20", Metrics.points_for(0.0, true) == 20)
	failed += _expect("inside 15 is 15", Metrics.points_for(Metrics.RING_15 - Metrics.DISC_RADIUS - 0.001, false) == 15)
	failed += _expect("on 15 line is 10", Metrics.points_for(Metrics.RING_15 - Metrics.DISC_RADIUS + 0.001, false) == 10)
	failed += _expect("inside 10 is 10", Metrics.points_for(Metrics.RING_10 - Metrics.DISC_RADIUS - 0.001, false) == 10)
	failed += _expect("on 10 line is 5", Metrics.points_for(Metrics.RING_10 - Metrics.DISC_RADIUS + 0.001, false) == 5)
	failed += _expect("inside 5 is 5", Metrics.points_for(Metrics.RING_5 - Metrics.DISC_RADIUS - 0.001, false) == 5)
	failed += _expect("on 5 line is 0", Metrics.points_for(Metrics.RING_5 - Metrics.DISC_RADIUS + 0.001, false) == 0)
	failed += _expect("ditch is out", Metrics.in_ditch(Metrics.SURFACE_RADIUS - Metrics.DISC_RADIUS + 0.001))
	failed += _expect("surface is in", not Metrics.in_ditch(Metrics.SURFACE_RADIUS - Metrics.DISC_RADIUS - 0.001))
	failed += _expect("still 20 must sit in the cup", Metrics.in_twenty_hole(0.0, 0.2))
	failed += _expect("moving disc is not a 20", not Metrics.in_twenty_hole(0.0, 1.4))
	failed += _expect("must hit if an opponent is on", not Metrics.shot_is_valid(true, false, true))
	failed += _expect("a hit is valid", Metrics.shot_is_valid(true, true, false))
	failed += _expect("no hiding needs the 15", not Metrics.shot_is_valid(false, false, false))
	failed += _expect("a 20 counts as 15", Metrics.shot_is_valid(false, false, true))
	if failed > 0:
		push_error("%d crokinole rule checks failed" % failed)
		quit(1)
	print("crokinole rule checks passed")
	quit(0)

func _expect(label: String, ok: bool) -> int:
	if ok:
		print("ok  ", label)
		return 0
	push_error("fail  " + label)
	return 1
