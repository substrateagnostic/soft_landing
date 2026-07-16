class_name PurrThermal
extends Area3D
## PurrThermal — Marmalade's purr updraft (world-cards/marmalade.md: "two
## chimneys puff warm updrafts on the purr cycle ... 6 m lift, cozy
## smoke-wisp visual"). Adapted from worlds/bramble/snore_geyser.gd (same
## proven pattern: repeating active window, gentle upward ease on any
## overlapping PlayerBody, never a downward snap) — copied rather than
## reused-by-reference per territory rules (worlds/marmalade/** only).
## SFX intentionally reuses "snore_geyser" (card: "SFX reuse: snore_geyser
## for thermals until dedicated").

signal activated
signal deactivated

@export var radius: float = 1.1
@export var height: float = 6.0 # card: "6 m lift"
@export var active_duration: float = 1.2
@export var cycle_period: float = 5.0
@export var phase_offset: float = 0.0
@export var vent_speed: float = 8.0
@export var lift_rate: float = 13.0 # m/s^2 easing toward vent_speed while active

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
	mat.albedo_color = Color(0.949, 0.784, 0.475, 0.4) # honey smoke-wisp, translucent
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
		AudioManager.play_sfx("snore_geyser") # reuse, per card, until a dedicated purr SFX exists
		activated.emit()
	else:
		deactivated.emit()


func _lift_bodies(delta: float) -> void:
	for body: PlayerBody in _bodies_inside:
		if not is_instance_valid(body):
			continue
		var eased: float = move_toward(body.velocity.y, vent_speed, lift_rate * delta)
		body.velocity.y = max(body.velocity.y, eased) # gentle, no snap — only ever lifts
