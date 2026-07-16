class_name BreathingChest
extends AnimatableBody3D
## BreathingChest — Bramble's chest plateau (PITCH.md: "a slow warm
## trampoline"; GAME_BRIEF: "bouncy at every point of its cycle"). A slow
## sine drives its Y position (not velocity — `sync_to_physics = true` so
## players standing on it ride it via the engine's kinematic platform
## motion). Builds its own visual + collision from `footprint`/`thickness`
## so bramble.gd only has to place it, not hand-author a mesh.

@export var footprint: Vector2 = Vector2(12.0, 8.0) # (length along X, width along Z)
@export var thickness: float = 1.5
@export var amplitude: float = 0.6
@export var period: float = 5.0
@export var surface_color: Color = Color("8A6552")

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
	position.y = _rest_y + sin(_time * TAU / period) * amplitude


func _build_geometry() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(footprint.x, thickness, footprint.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = surface_color
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = mesh
	add_child(visual)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	add_child(shape)
