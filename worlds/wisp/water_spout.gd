class_name WaterSpout
extends Area3D
## WaterSpout — Wisp's blowhole updraft (world_card wisp.md: "the blowhole
## erupts a tall gentle spout on the breath cycle (geyser pattern, but 14 m
## tall, lifting to the head)"). Adapted directly from
## worlds/bramble/snore_geyser.gd: on a repeating cycle it goes active for a
## window; while active, any overlapping PlayerBody's vertical velocity is
## eased up toward `vent_speed` — never snapped, never allowed to push
## velocity.y down. Builds its own translucent pale-cyan column visual +
## detection collider from `radius`/`height` so wisp.gd only has to place it
## as a child of the whale's drift group (WhaleDrift) — being a plain Area3D
## (not a physics body), it rides the parent's motion for free the moment
## it's parented under WhaleDrift, no extra sync code needed.

signal activated
signal deactivated

@export var radius: float = 1.5
@export var height: float = 14.0
@export var active_duration: float = 3.0
@export var cycle_period: float = 20.0
@export var phase_offset: float = 0.0
@export var vent_speed: float = 9.0
@export var lift_rate: float = 14.0 # m/s^2 easing toward vent_speed while active

var _visual: MeshInstance3D = null
var _time: float = 0.0
var _active: bool = false
var _bodies_inside: Array[PlayerBody] = []


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # PlayerBody layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_geometry()


func _build_geometry() -> void:
	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = radius
	cyl_shape.height = height
	shape.shape = cyl_shape
	shape.position = Vector3(0.0, height * 0.5, 0.0)
	add_child(shape)

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.624, 0.910, 0.878, 0.4) # pale cyan #9FE8E0, translucent
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color("9FE8E0")
	mat.emission_energy_multiplier = 0.6
	mesh.material = mat

	_visual = MeshInstance3D.new()
	_visual.name = "Visual"
	_visual.mesh = mesh
	_visual.position = Vector3(0.0, height * 0.5, 0.0)
	_visual.visible = false
	add_child(_visual)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerBody and not _bodies_inside.has(body):
		_bodies_inside.append(body as PlayerBody)


func _on_body_exited(body: Node3D) -> void:
	_bodies_inside.erase(body)


func _physics_process(delta: float) -> void:
	_time += delta
	var phase: float = fmod(_time + phase_offset, cycle_period)
	var should_be_active: bool = phase < active_duration
	if should_be_active != _active:
		_set_active(should_be_active)
	if _active:
		_lift_bodies(delta)


func _set_active(is_active: bool) -> void:
	_active = is_active
	if _visual != null:
		_visual.visible = is_active
	if is_active:
		AudioManager.play_sfx("snore_geyser") # SFX reuse per world card, until a dedicated sound exists
		activated.emit()
	else:
		deactivated.emit()


func _lift_bodies(delta: float) -> void:
	for body: PlayerBody in _bodies_inside:
		if not is_instance_valid(body):
			continue
		var eased: float = move_toward(body.velocity.y, vent_speed, lift_rate * delta)
		body.velocity.y = max(body.velocity.y, eased) # gentle, no snap — only ever lifts
