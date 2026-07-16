class_name LilyPad
extends AnimatableBody3D
## LilyPad — one pad in Wisp's hop chain (world_card wisp.md: "8-10 broad
## pads... bob 0.2 m on offset sine phases"). Position-driven sine on Y,
## `sync_to_physics = true` (breathing_chest.gd pattern) so a player standing
## on top rides the bob via the engine's kinematic platform motion. Builds
## its own flattened-disc visual + cylinder collision from `radius` so
## wisp.gd only has to place, size, and phase-offset it.

@export var radius: float = 1.8
@export var thickness: float = 0.3
@export var amplitude: float = 0.2
@export var period: float = 3.5
@export var phase_offset: float = 0.0
@export var pad_color: Color = Color("C9D4E4")

var _rest_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	_rest_y = position.y
	_build_geometry()


func _physics_process(delta: float) -> void:
	_time += delta
	position.y = _rest_y + sin(_time * TAU / period + phase_offset) * amplitude


func _build_geometry() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.92 # a hair of taper so it reads as a pad, not a puck
	mesh.height = thickness
	var mat := StandardMaterial3D.new()
	mat.albedo_color = pad_color
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = mesh
	add_child(visual)

	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = radius
	cyl_shape.height = thickness
	shape.shape = cyl_shape
	add_child(shape)
