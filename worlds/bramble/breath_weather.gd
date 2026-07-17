class_name BreathWeather
extends Node3D
## BreathWeather — Bramble's ambient, always-on body-function (Divine-Beast
## pattern, docs/research/v2/aliveness_wow.md §3: "one signature
## controllable body-function... escalating ambient -> interactive ->
## transformative"; DIRECTION_V2.md Pillar 1; ROADMAP.md §M2: "the breath
## becomes weather"). On a slow ~40-60s cycle — distinct from
## BreathingChest's fast continuous bounce (worlds/bramble/breathing_chest.gd,
## period 5s: that's the bear's small steady chest-rise; this is the rarer
## BIG sigh) — the long exhale:
##   (a) lifts players in a broad updraft, via the EXACT SAME eased
##       move_toward-toward-vent_speed / never-push-down math as
##       worlds/bramble/snore_geyser.gd's _lift_bodies ("study how snore
##       geysers already lift players and reuse that pattern" — brief).
##   (b) turns on a drifting warm-mote particle system (fog/seeds).
##   (c) swells a warm point light.
## Prints BREATH receipt lines on every phase transition (harness property:
## tools/harness/scripts/bramble_breath_lift.json).
##
## Placement note: "in front of the snout" is honored directionally — this
## sits near the head's X coordinate, past the geysers — but offset to
## z=24 instead of z=0. Straight ahead of the snout at z=0 is still ON the
## head sphere's sloped surface out to x=64.25 (see HEAD_CENTER/HEAD_RADIUS
## in bramble.gd), which would either bury the updraft in the mound or
## strand it in the last ~5m before the meadow's x=70 edge. z=24 clears
## the head sphere's footprint entirely (its z-reach at y=0 tops out at
## 16.25) while staying on flat, open meadow the kids can walk into "from
## the meadow" with no climb — true to the brief's "soft elevator" framing,
## even though it isn't literally astride the chest platform at x=-5 (see
## docs/verify/bramble-setpieces-VERIFY.md for the height-parity reasoning:
## the lift target is chest-COMPARABLE altitude, not a landing on the
## chest deck itself).

signal exhale_started
signal exhale_ended

@export var updraft_radius: float = 5.0
@export var updraft_height: float = 9.0
@export var cycle_period: float = 44.0 # full weather cycle -- within the brief's 40-60s window
@export var exhale_duration: float = 9.0 # how long the lift/particles/light stay active
@export var start_delay: float = 6.0 # grace before the first exhale -- arrival never gets an instant surprise
@export var vent_speed: float = 8.0 # gentler peak than the snore geyser's quick burst (9.0), held far longer
# Caught live (see docs/verify/bramble-setpieces-VERIFY.md): the geyser's
# own lift_rate (14.0) reads as "gentle" chiefly because a player normally
# ENTERS a geyser already jumping, with real upward velocity as a head
# start. This updraft is meant to also work from a dead stand -- the exact
# scenario the harness property drives -- and PlayerBody's OWN gravity
# (Otto's rise_gravity ~=14.8 m/s^2, data/tuning/otto_movement.tres) fights
# the lift every physics frame it's applied (both are plain per-frame
# velocity.y edits; whichever script's _physics_process happens to run
# second in tree order wins that frame, so effective lift is what SURVIVES
# gravity, not the raw exported number). 10.0 measured as net-negative
# against Otto and only a slow ~0.5 m/s creep against Pip -- both players
# spent the entire window trapped oscillating right at
# MovementTuning.apex_hang_threshold instead of climbing. 18.0 clears
# BOTH players' gravity with real margin (net ~effect: +5 m/s^2 accel while
# ramping toward vent_speed, then a ~7.8-8.0 m/s sustained cruise).
@export var lift_rate: float = 18.0
@export var light_peak_energy: float = 0.85
@export var light_color: Color = Color("F2C879") # honey glow, ART_BIBLE.md lantern tone

const PARTICLE_COLOR: Color = Color("FFF3C4") # dreamling pale gold-white, ART_BIBLE.md
const LIGHT_SWELL_SECONDS: float = 2.0

var _time: float = 0.0
var _active: bool = false
var _bodies_inside: Array[PlayerBody] = []
var _visual: MeshInstance3D = null
var _particles: GPUParticles3D = null
var _light: OmniLight3D = null
var _light_tween: Tween = null


func _ready() -> void:
	_build_area()
	_build_visual()
	_build_particles()
	_build_light()


func _build_area() -> void:
	var area := Area3D.new()
	area.name = "UpdraftArea"
	area.monitoring = true
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 2 # PlayerBody layer
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = updraft_radius
	cyl.height = updraft_height
	shape.shape = cyl
	shape.position = Vector3(0.0, updraft_height * 0.5, 0.0)
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _build_visual() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = updraft_radius
	mesh.bottom_radius = updraft_radius * 1.1 # slight flare -- reads as a soft fountain, not a hard pipe
	mesh.height = updraft_height
	var mat := StandardMaterial3D.new()
	# Milk-white, well below the geyser's 0.45 alpha -- a volume this broad
	# reads as "soft weather," not "solid column," at low opacity.
	mat.albedo_color = Color(0.961, 0.949, 0.910, 0.20)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat

	_visual = MeshInstance3D.new()
	_visual.name = "Visual"
	_visual.mesh = mesh
	_visual.position = Vector3(0.0, updraft_height * 0.5, 0.0)
	_visual.visible = false
	add_child(_visual)


func _build_particles() -> void:
	_particles = ParticlePresets.make_ambient_glow(
		"BreathMotes", 70, 6.0, PARTICLE_COLOR,
		Vector3(updraft_radius, updraft_height * 0.5, updraft_radius), 1.4, true, Vector3(0.0, 0.15, 0.0), 0.14
	)
	_particles.position = Vector3(0.0, updraft_height * 0.5, 0.0)
	_particles.emitting = false
	add_child(_particles)


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "BreathGlow"
	_light.light_color = light_color
	_light.light_energy = 0.0
	_light.omni_range = updraft_radius * 3.0
	_light.position = Vector3(0.0, updraft_height * 0.4, 0.0)
	add_child(_light)


func _physics_process(delta: float) -> void:
	_time += delta
	# Shifts the cycle so the FIRST exhale lands start_delay seconds after
	# world load, not immediately at t=0 -- same idiom as SnoreGeyser's own
	# phase_offset (worlds/bramble/snore_geyser.gd), just solved for a
	# fixed startup grace instead of a stagger between two instances.
	var elapsed: float = fmod(_time + (cycle_period - start_delay), cycle_period)
	var should_be_active: bool = elapsed < exhale_duration
	if should_be_active != _active:
		_set_active(should_be_active)
	if _active:
		_lift_bodies(delta)


## force_gust — D25 finale reveal (rollover_sequence.gd): fires one exhale
## (lift/particles/light/audio) on demand, WITHOUT touching _time/
## cycle_period — the ambient cycle keeps ticking underneath exactly as
## before, so this never corrupts it (per the D25 brief's explicit
## requirement). _set_active(true)/(false) is idempotent either way: the
## regular _physics_process cycle may also call _set_active around this
## forced beat (harmless overlap — the world is mid-finale, not mid-
## playtest, by the time this ever fires; no player is present to notice a
## redundant light-tween restart).
func force_gust() -> void:
	print("BREATH %s" % JSON.stringify({"phase": "force_gust"}))
	AudioManager.play_sfx("gust_breath") # audio pass 3: the exhale
	if not _active:
		_set_active(true)
	var timer: SceneTreeTimer = get_tree().create_timer(exhale_duration)
	timer.timeout.connect(func() -> void:
		if _active:
			_set_active(false)
	)


func _set_active(is_active: bool) -> void:
	_active = is_active
	_visual.visible = is_active
	_particles.emitting = is_active
	_tween_light(is_active)
	if is_active:
		AudioManager.play_sfx("breath_exhale") # fails soft (AudioManager convention) until an asset lands
		print("BREATH %s" % JSON.stringify({"phase": "exhale_start"}))
		exhale_started.emit()
	else:
		print("BREATH %s" % JSON.stringify({"phase": "exhale_end"}))
		exhale_ended.emit()


func _tween_light(is_active: bool) -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	_light_tween = create_tween()
	var target: float = light_peak_energy if is_active else 0.0
	_light_tween.tween_property(_light, "light_energy", target, LIGHT_SWELL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerBody and not _bodies_inside.has(body):
		_bodies_inside.append(body as PlayerBody)


func _on_body_exited(body: Node3D) -> void:
	_bodies_inside.erase(body)


## Identical easing law to SnoreGeyser._lift_bodies: move_toward the
## vertical velocity up toward vent_speed, then max() it against whatever
## the player already had -- never snaps, never pushes down, only ever
## lifts. (worlds/bramble/snore_geyser.gd, "the pattern to reuse.")
func _lift_bodies(delta: float) -> void:
	for body: PlayerBody in _bodies_inside:
		if not is_instance_valid(body):
			continue
		var eased: float = move_toward(body.velocity.y, vent_speed, lift_rate * delta)
		body.velocity.y = max(body.velocity.y, eased)
