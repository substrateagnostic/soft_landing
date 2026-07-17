class_name HeartbeatCrossing
extends Node3D
## HeartbeatCrossing — D26 joy pass #5 (NEXT_STEPS.md §1b, "the HEARTBEAT
## CROSSING: a stretch where the ground thumps softly underfoot"). Rides one
## mid-ascent ledge (bramble.gd wires it onto AscentLedge3/ASCENT_L3):
## while any player stands on it, a slow resting-heartbeat rhythm ("lub-dub")
## drives a warm light pulse + a gentle 1-2% scale breathe of the ledge
## itself — foreshadowing the sleeping giant underfoot, before the reveal
## ever confirms it.
##
## Audio: heartbeat_thump (audio pass 3, generate_audio_v3.py) — a
## pillow-muffled lub-dub matched to this crossing's own pulse shape,
## played at the pulse trigger under the existing cooldown.

const PULSE_PERIOD: float = 0.9 # ~66bpm, a slow resting heartbeat
const SCALE_AMPLITUDE: float = 0.018 # ~1.8%, within the brief's 1-2% ask
const LIGHT_PEAK_ENERGY: float = 0.55
const LIGHT_FADE_RATE: float = 2.0 # energy/sec when nobody's standing on it
const RECEIPT_COOLDOWN: float = 2.0 # rate-limits the HEARTBEAT receipt while occupied

var _footprint: Vector2 = Vector2(8.0, 8.0)
var _target: Node3D = null # the ledge MeshInstance3D to breathe
var _light: OmniLight3D = null
var _time: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
var _bodies: Array[PlayerBody] = []
var _receipt_cooldown: float = 0.0


## setup — called BEFORE add_child (this file's own established convention;
## see rollover_sequence.gd/mountain_dressing.gd's own setup() notes).
## footprint: the ledge's world-space (x, z) size, for the detection Area3D.
## ledge_visual: the AscentLedge MeshInstance3D whose .scale this breathes —
## NOT reparented under it (the ledge's own StaticBody3D collision must stay
## exactly where bramble.gd's _add_ascent_ledge put it; this node sits
## alongside it at the same world position instead).
func setup(footprint: Vector2, ledge_visual: Node3D) -> void:
	_footprint = footprint
	_target = ledge_visual


func _ready() -> void:
	_base_scale = _target.scale if _target != null else Vector3.ONE
	_build_area()
	_build_light()


func _build_area() -> void:
	var area := Area3D.new()
	area.name = "HeartbeatArea"
	area.monitoring = true
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 2 # PlayerBody layer (SnoreGeyser/BreathWeather convention)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_footprint.x, 3.0, _footprint.y)
	shape.shape = box
	shape.position = Vector3(0.0, 1.5, 0.0)
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "HeartbeatGlow"
	_light.light_color = Color("D9A5B3") # warm rose pulse, distinct from the honey breath-weather glow
	_light.light_energy = 0.0
	_light.omni_range = maxf(_footprint.x, _footprint.y) * 1.3
	_light.position = Vector3(0.0, 1.0, 0.0)
	add_child(_light)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerBody and not _bodies.has(body):
		_bodies.append(body as PlayerBody)


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)


func _physics_process(delta: float) -> void:
	_receipt_cooldown = maxf(_receipt_cooldown - delta, 0.0)
	if _bodies.is_empty():
		_light.light_energy = move_toward(_light.light_energy, 0.0, LIGHT_FADE_RATE * delta)
		if _target != null:
			_target.scale = _base_scale
		return

	_time += delta
	var phase: float = fmod(_time, PULSE_PERIOD) / PULSE_PERIOD
	# "Lub-dub": a sharp primary beat early in the cycle, a softer second
	# beat partway through — cubic falloff reads punchier than a plain sine.
	var pulse: float = pow(1.0 - phase, 3.0) if phase < 0.35 else 0.0
	if phase > 0.45 and phase < 0.8:
		var p2: float = (phase - 0.45) / 0.35
		pulse = maxf(pulse, pow(1.0 - p2, 3.0) * 0.6)

	_light.light_energy = LIGHT_PEAK_ENERGY * pulse
	if _target != null:
		_target.scale = _base_scale * (1.0 + SCALE_AMPLITUDE * pulse)

	if pulse > 0.85 and _receipt_cooldown <= 0.0:
		_receipt_cooldown = RECEIPT_COOLDOWN
		AudioManager.play_sfx("heartbeat_thump") # audio pass 3: rate-limited by the receipt cooldown above
		print("HEARTBEAT %s" % JSON.stringify({"seat": _bodies[0].name}))
