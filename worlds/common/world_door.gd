class_name WorldDoor
extends Area3D
## WorldDoor — a world's exit doorframe (SPEC.md: "exit_requested() — player
## chose to leave"). Builds its own simple doorframe (two posts + a lintel)
## so worlds don't need a hand-authored scene file for it. Any player
## standing inside who presses either seat's interact button requests an
## exit: emits exit_requested() and prints one DOOR receipt line so the
## harness/director can grep world switches. main.gd (outside worlds/**)
## owns the actual scene swap — see the worlds-VERIFY integration notes.
##
## D27 legibility (producer playtest: "couldn't figure out how to get out
## of the first area"): every door now carries a BEACON — a soft rising
## light column + pulsing tinted glow in the door's own frame_color, so
## all four fort doors read across the clearing at night — and the glow
## swells when a player steps inside the trigger (the wordless "you're in
## the right spot" cue). First trigger-entry each session asks the Moon
## for "door_ready" (the press-to-knock hint, pre-reader phrasing).

signal exit_requested()

static var _hint_said: bool = false # once per session, across ALL doors

@export var target_world: String = "bramble"
@export var frame_width: float = 2.4
@export var frame_height: float = 2.8
@export var post_thickness: float = 0.3
@export var frame_color: Color = Color("F5F2E8")

const BEACON_HEIGHT: float = 6.5
const BEACON_RADIUS: float = 0.55
const BEACON_ALPHA: float = 0.16
const GLOW_IDLE_MIN: float = 0.35
const GLOW_IDLE_MAX: float = 0.8
const GLOW_OCCUPIED: float = 1.7
const GLOW_PULSE_PERIOD: float = 2.6 # slow lighthouse breathing, nothing flashy
const GLOW_EASE_RATE: float = 3.0

var _bodies_inside: Array[PlayerBody] = []
var _glow: OmniLight3D = null
var _beacon_mat: StandardMaterial3D = null
var _pulse_time: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # PlayerBody layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_geometry()
	_build_beacon()


func _build_geometry() -> void:
	var trigger_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(frame_width, frame_height, 1.5)
	trigger_shape.shape = box
	trigger_shape.position = Vector3(0.0, frame_height * 0.5, 0.0)
	add_child(trigger_shape)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = frame_color
	# D27: the frame itself carries a faint self-glow in its world's tint,
	# so a pre-reader can match door color to giant from across the fort.
	mat.emission_enabled = true
	mat.emission = frame_color
	mat.emission_energy_multiplier = 0.35

	var half_width: float = frame_width * 0.5
	_add_post(Vector3(-half_width, frame_height * 0.5, 0.0), mat)
	_add_post(Vector3(half_width, frame_height * 0.5, 0.0), mat)

	var lintel := MeshInstance3D.new()
	lintel.name = "Lintel"
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(frame_width + post_thickness, post_thickness, post_thickness)
	lintel_mesh.material = mat
	lintel.mesh = lintel_mesh
	lintel.position = Vector3(0.0, frame_height, 0.0)
	add_child(lintel)


func _add_post(post_position: Vector3, mat: StandardMaterial3D) -> void:
	var post := MeshInstance3D.new()
	post.name = "Post"
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(post_thickness, frame_height, post_thickness)
	post_mesh.material = mat
	post.mesh = post_mesh
	post.position = post_position
	add_child(post)


## _build_beacon — the D27 rising light column + pulsing glow (class doc).
## Additive-blended cylinder, no depth write, so it reads as light, not a
## solid; the OmniLight is the actual night-time signpost.
func _build_beacon() -> void:
	var beacon := MeshInstance3D.new()
	beacon.name = "Beacon"
	var cyl := CylinderMesh.new()
	cyl.top_radius = BEACON_RADIUS * 0.55 # tapers upward like a lantern shaft
	cyl.bottom_radius = BEACON_RADIUS
	cyl.height = BEACON_HEIGHT
	_beacon_mat = StandardMaterial3D.new()
	_beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beacon_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beacon_mat.no_depth_test = false
	_beacon_mat.albedo_color = Color(frame_color.r, frame_color.g, frame_color.b, BEACON_ALPHA)
	_beacon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = _beacon_mat
	beacon.mesh = cyl
	beacon.position = Vector3(0.0, BEACON_HEIGHT * 0.5, 0.0)
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beacon)

	_glow = OmniLight3D.new()
	_glow.name = "BeaconGlow"
	_glow.light_color = frame_color
	_glow.light_energy = GLOW_IDLE_MIN
	_glow.omni_range = 6.0
	_glow.position = Vector3(0.0, frame_height * 0.65, 0.0)
	_glow.shadow_enabled = false
	add_child(_glow)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerBody and not _bodies_inside.has(body):
		_bodies_inside.append(body as PlayerBody)
		if not _hint_said:
			_hint_said = true
			TheMoon.say("door_ready")


func _on_body_exited(body: Node3D) -> void:
	_bodies_inside.erase(body)


func _physics_process(delta: float) -> void:
	_update_beacon(delta)
	if _bodies_inside.is_empty():
		return
	if Input.is_action_just_pressed("p1_interact") or Input.is_action_just_pressed("p2_interact"):
		_request_exit()


func _update_beacon(delta: float) -> void:
	if _glow == null:
		return
	_pulse_time += delta
	var wave: float = 0.5 + 0.5 * sin(_pulse_time * TAU / GLOW_PULSE_PERIOD)
	var target: float = lerpf(GLOW_IDLE_MIN, GLOW_IDLE_MAX, wave)
	if not _bodies_inside.is_empty():
		target = GLOW_OCCUPIED
	_glow.light_energy = move_toward(_glow.light_energy, target, GLOW_EASE_RATE * delta)
	if _beacon_mat != null:
		var alpha: float = BEACON_ALPHA * (1.6 if not _bodies_inside.is_empty() else 0.75 + 0.5 * wave)
		_beacon_mat.albedo_color.a = alpha


func _request_exit() -> void:
	print("DOOR %s" % JSON.stringify({"to": target_world}))
	exit_requested.emit()
