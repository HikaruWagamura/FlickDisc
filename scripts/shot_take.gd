extends Node

## The shared shot. Pulling back fills a resisted spring, and the needle
## sweeps faster as that power climbs. The disc and the power bar both
## read this same power, so the wind-up stays in one piece.

signal changed(power: float, needle: float)
signal fired(power: float, needle: float)

const PULL_PIXELS := 228.0
const CURVE := 1.62
const FIRE_POWER := 0.08

var live := false
var pulling := false
var power := 0.0
var needle := 0.0

var _target := 0.0
var _phase := 0.0


func open() -> void:
	live = true
	pulling = false
	_target = 0.0


func close() -> void:
	live = false
	pulling = false
	power = 0.0
	needle = 0.0
	_target = 0.0
	_phase = 0.0


func begin_pull() -> void:
	if not live:
		open()
	pulling = true
	# Start on the left edge so the mark has to be timed, not tapped.
	_phase = -PI * 0.5
	needle = -1.0
	power = 0.0
	_target = 0.0


func drag(pixels: float) -> void:
	if not pulling:
		return
	var travel := clampf(maxf(pixels, 0.0) / PULL_PIXELS, 0.0, 1.0)
	# The last of the pull is where the power arrives, so a flick
	# cannot fill the bar. The spring below keeps the disc behind
	# the finger, which is the resistance.
	_target = pow(travel, CURVE)


func release() -> void:
	if not pulling:
		return
	pulling = false
	var shot_power := power
	var shot_needle := needle
	_target = 0.0
	if shot_power >= FIRE_POWER:
		fired.emit(shot_power, shot_needle)
		close()
		return
	power = 0.0
	needle = 0.0
	_phase = 0.0
	changed.emit(0.0, 0.0)


func advance(delta: float) -> void:
	if not live or not pulling:
		return
	var stiffness := lerpf(18.0, 7.5, _target)
	power = lerpf(power, _target, 1.0 - exp(-stiffness * delta))
	# Slower than the first strike cursor. A heavy pull still hurries it.
	var cycles := lerpf(0.48, 1.85, power)
	_phase += cycles * TAU * delta
	needle = sin(_phase)
	changed.emit(power, needle)
