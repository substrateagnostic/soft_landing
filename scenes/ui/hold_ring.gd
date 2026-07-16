class_name HoldRing
extends Control
## HoldRing — a radial progress ring for a hold-to-confirm gesture (pause
## menu v2's "Sleep" quit, D20 UI pass — "confirm = hold-to-quit ring like
## kids' games" per the build brief; pre-reader-safe "no
## quit-without-confirm"). `progress` is 0..1, drawn as an arc from the
## top (-PI/2) sweeping clockwise. Purely a drawing helper — the caller
## (pause_menu.gd) owns the actual hold-timing/input logic and just writes
## to `progress` every frame.

const COLOR: Color = Color(0.94902, 0.784314, 0.474510, 1.0) # honey glow (matches pause focus color)
const RING_WIDTH: float = 6.0
const RING_INSET: float = 4.0

var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if progress <= 0.0:
		return
	var center: Vector2 = size * 0.5
	var radius: float = min(size.x, size.y) * 0.5 - RING_INSET
	var start_angle: float = -PI * 0.5
	var end_angle: float = start_angle + TAU * progress
	draw_arc(center, radius, start_angle, end_angle, 48, COLOR, RING_WIDTH, true)
