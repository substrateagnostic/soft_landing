class_name TailSeesaw
extends AnimatableBody3D
## TailSeesaw — Wisp's fluke (world_card wisp.md: "the fluke tilts +/-8 deg
## on a 6 s cycle — a slow moving ramp onto the back"). Pivots in place
## around its own local Z axis (a plank running along local X, tilting like
## a real seesaw); `sync_to_physics = true` (breathing_chest.gd pattern) so
## a rider is carried by the engine's kinematic platform motion as it
## rocks. Deliberately gentle: `length` and `amplitude_degrees` are tuned
## together (see wisp.gd placement) so neither end ever swings more than
## about half a metre off its rest height — a toy to rock on, not a timing
## gate (design floor: no fail states, nothing ever blocks solo completion).

@export var length: float = 8.0
@export var width: float = 2.2
@export var thickness: float = 0.4
@export var amplitude_degrees: float = 8.0
@export var period: float = 6.0
@export var plank_color: Color = Color("C9D4E4")

var _time: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	_build_geometry()


func _physics_process(delta: float) -> void:
	_time += delta
	rotation.z = sin(_time * TAU / period) * deg_to_rad(amplitude_degrees)


func _build_geometry() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, thickness, width)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = plank_color
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
