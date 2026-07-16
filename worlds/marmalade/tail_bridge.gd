class_name TailBridge
extends AnimatableBody3D
## TailBridge — Marmalade's signature gift (world-cards/marmalade.md: "the
## tail sweeps slowly (+/-25 deg yaw around its base, 8 s cycle,
## AnimatableBody) between two rooftop clusters — a moving bridge you ride
## or time"). Built as a pure ORIGIN sweep (position-driven, like
## worlds/bramble/breathing_chest.gd's sine bob) rather than an actual
## rotation of this physics body: the "yaw around its base" is computed as
## an angle that places the platform's ORIGIN on an arc of radius
## `arm_length` around `pivot`, and only that origin moves each physics
## frame. `sync_to_physics = true` makes the engine derive this body's
## linear velocity from the position delta, exactly the mechanism
## breathing_chest.gd already proves carries/launches CharacterBody3D
## correctly (SPEC.md: "so players ride and jump-inherit correctly") — a
## body that only ever translates sidesteps any open question about how
## CharacterBody3D inherits velocity from a platform's ANGULAR motion at a
## point away from its pivot.
##
## IMPORTANT for callers: unlike breathing_chest.gd (whose owning world sets
## `.position` directly before `add_child`), this node computes its OWN
## starting position from `pivot`/`arm_length` inside `_ready()` — and
## `_ready()` does not run synchronously inside `add_child()`. A node parented
## to this body (e.g. a rides-the-tail Dreamling) that reads `global_position`
## before this body's `_ready()` has run will see the Node3D default (0,0,0),
## not the real arc position — that bug was caught empirically (a d06 spawned
## at world origin briefly overlapped the physics broadphase near a player
## and got "collected" on frame 4 of a cold boot). Callers MUST set
## `.position = TailBridge.arc_position(pivot, arm_length,
## yaw_range_degrees, center_yaw_degrees, 0.0)` themselves before `add_child`
## (mirrors breathing_chest.gd's pattern) — see marmalade.gd's
## `_build_tail_bridge()`.

@export var pivot: Vector3 = Vector3.ZERO
@export var arm_length: float = 11.8
@export var yaw_range_degrees: float = 25.0 # card: "+/-25 deg yaw around its base"
@export var center_yaw_degrees: float = 0.0
@export var period: float = 8.0 # card: "8 s cycle"
@export var footprint: Vector2 = Vector2(2.6, 2.0) # (length along X, width along Z)
@export var thickness: float = 0.5
@export var surface_color: Color = Color("D98E4A") # marmalade orange — it IS the tail

var _time: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	_build_geometry()
	_update_position(0.0) # idempotent re-application; callers already set the correct start (see class doc)


func _physics_process(delta: float) -> void:
	_time += delta
	_update_position(_time)


func _update_position(t: float) -> void:
	position = arc_position(pivot, arm_length, yaw_range_degrees, center_yaw_degrees, period, t)


## Pure helper (no node state) so a caller can compute the correct starting
## position and set it BEFORE add_child — see the class-level "IMPORTANT for
## callers" note above.
static func arc_position(pivot_point: Vector3, arm: float, yaw_range_deg: float, center_yaw_deg: float, sweep_period: float, t: float) -> Vector3:
	var yaw: float = deg_to_rad(center_yaw_deg) + sin(t * TAU / sweep_period) * deg_to_rad(yaw_range_deg)
	return pivot_point + Vector3(sin(yaw), 0.0, cos(yaw)) * arm


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
