class_name FortResident
extends Node3D
## FortResident — Hub Population (aliveness_wow.md Top 12 #11, "hub-as-
## visible-progress-bar": every returned dream takes up visible residence
## in the hub). Spawned one per returned dream by worlds/pillow_fort/
## pillow_fort.gd at an assigned spot from data/fort_residents/spots.json.
## Mirrors dreamling.gd's glowing-orb visual language (see that file's
## Visual mesh/material) at ~60% scale, but carries NONE of its collection
## machinery — a resident is never picked up, never orbits a carrier, never
## flies to a door. It is presence, not a collectible: the sibling pattern
## it borrows its proximity-notice shape from is worlds/common/dreamkeeper.
## gd's ASLEEP/AWAKE state machine, minus the rig (a resident is a small
## light, not a character).
##
## Behavior, entirely local (no world-script wiring beyond spawning this
## node at an assigned `position` before add_child() — the codebase's
## established set-before-add_child ordering; see dreamkeeper.gd's own
## header for why _ready() is never guaranteed synchronous inside
## add_child() here):
##   REST  -- gentle bob in place, plus a slow, small drift within
##            DRIFT_RADIUS of its assigned home (never further — it lives
##            here now, unlike a wild dreamling that homes back to an
##            anchor point).
##   GREET -- a player is within GREET_RADIUS: brightens (emission ramps
##            up), does one happy hop the instant it notices you, and
##            plays a tiny rate-limited positional chime. Eases back to
##            REST once nobody has been close for SETTLE_DELAY seconds.
##
## No collision shape (deliberate, matches dreamkeeper.gd's own reasoning
## and world_base.gd's "generosity floor" for every other small prop in
## this codebase): pure presence, walk-through, can never block a route
## regardless of placement — this is also why
## tools/props/check_placements.gd (which only ever queries Dreamling
## descendants) never needs to know FortResident exists.

const PLAYERS_GROUP: String = "players"
const GREET_RADIUS: float = 3.0
const SETTLE_DELAY: float = 4.0 # eases back to REST after the last player leaves GREET_RADIUS

# dreamling.gd's BOB_AMPLITUDE (0.15) / SPIN_SPEED (1.5) at ~60% scale and a
# calmer settle — a resident has arrived, not searching for a carrier.
const BOB_AMPLITUDE: float = 0.09
const BOB_HZ: float = 0.5
const SPIN_SPEED: float = 0.9

const DRIFT_RADIUS: float = 1.5
const DRIFT_LERP_SPEED: float = 0.35
const DRIFT_INTERVAL_MIN: float = 3.0
const DRIFT_INTERVAL_MAX: float = 7.0

# dreamling.gd's Visual emission_energy_multiplier is 4.5 (its full, actively-
# searching brightness); a settled resident glows softer at rest and only
# brightens to that same full brightness on greet.
const REST_EMISSION: float = 2.0
const GREET_EMISSION: float = 4.5
const EMISSION_LERP_SPEED: float = 5.0

const HOP_HEIGHT: float = 0.22
const HOP_DURATION: float = 0.35

## AudioManager.play_chime(1)'s sfx name (the ladder's lowest, fixed rung) —
## played positionally (worlds/common/positional_audio.gd) rather than on
## AudioManager's single shared _sfx_player, since several residents can
## plausibly greet within the same few frames as a player walks the fort.
const CHIME_SFX: String = "dreamling_chime"
const RECEIPT_COOLDOWN: float = 3.0 # a lingering player doesn't re-trigger the receipt/chime every frame

const RESIDENT_COLOR: Color = Color("F2C879") # honey glow (pillow_fort.gd's FORT_GLOW_COLOR) — a homed dream reads warmer than a wild one (dreamling.gd's pale FFF3C4)
const RESIDENT_RADIUS: float = 0.105 # dreamling.gd Visual SphereMesh radius (0.175) at ~60% scale
const RESIDENT_HEIGHT: float = 0.21

@export var id: String = ""

var _visual: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _home_position: Vector3 = Vector3.ZERO
var _bob_phase: float = randf() * TAU
var _greeting: bool = false
var _away_timer: float = 0.0
var _drift_timer: float = randf_range(DRIFT_INTERVAL_MIN, DRIFT_INTERVAL_MAX)
var _drift_offset: Vector3 = Vector3.ZERO
var _drift_target: Vector3 = Vector3.ZERO
var _receipt_cooldown: float = 0.0
var _hop_tween: Tween = null


func _ready() -> void:
	add_to_group("fort_resident")
	_home_position = position # spawner sets position before add_child (see file header)
	_build_visual()


func _build_visual() -> void:
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	var mesh := SphereMesh.new()
	mesh.radius = RESIDENT_RADIUS
	mesh.height = RESIDENT_HEIGHT
	_material = StandardMaterial3D.new()
	_material.albedo_color = RESIDENT_COLOR
	_material.emission_enabled = true
	_material.emission = RESIDENT_COLOR
	_material.emission_energy_multiplier = REST_EMISSION
	mesh.material = _material
	visual.mesh = mesh
	add_child(visual)
	_visual = visual


func _physics_process(delta: float) -> void:
	_receipt_cooldown = max(_receipt_cooldown - delta, 0.0)
	var nearest_dist: float = _nearest_player_distance()
	_update_greet_state(delta, nearest_dist)
	_update_drift(delta)
	_update_bob(delta)
	_update_emission(delta)


func _nearest_player_distance() -> float:
	var best: float = INF
	for node: Node in get_tree().get_nodes_in_group(PLAYERS_GROUP):
		var player: Node3D = node as Node3D
		if player == null:
			continue
		best = min(best, player.global_position.distance_to(global_position))
	return best


func _update_greet_state(delta: float, nearest_dist: float) -> void:
	if nearest_dist < GREET_RADIUS:
		_away_timer = 0.0
		if not _greeting:
			_enter_greet()
	elif _greeting:
		_away_timer += delta
		if _away_timer >= SETTLE_DELAY:
			_greeting = false


func _enter_greet() -> void:
	_greeting = true
	_fire_hop()
	_emit_receipt()


## A brief up-down bounce on the visual only (not `position`, which
## `_update_bob` already owns every frame) — fires once per fresh approach,
## not every frame a player lingers close.
func _fire_hop() -> void:
	if _visual == null:
		return
	if _hop_tween != null and _hop_tween.is_valid():
		_hop_tween.kill()
	_visual.position.y = 0.0
	_hop_tween = create_tween()
	_hop_tween.tween_property(_visual, "position:y", HOP_HEIGHT, HOP_DURATION * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_visual, "position:y", 0.0, HOP_DURATION * 0.5) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## critter.gd's IDLE_WANDER hop-target shape, clamped to DRIFT_RADIUS of
## home rather than a fresh random home each cycle — a resident never
## wanders away from its assigned spot, only fidgets near it.
func _update_drift(delta: float) -> void:
	_drift_timer -= delta
	if _drift_timer <= 0.0:
		_drift_timer = randf_range(DRIFT_INTERVAL_MIN, DRIFT_INTERVAL_MAX)
		var offset: Vector2 = Vector2(randf_range(-DRIFT_RADIUS, DRIFT_RADIUS), randf_range(-DRIFT_RADIUS, DRIFT_RADIUS))
		_drift_target = Vector3(offset.x, 0.0, offset.y).limit_length(DRIFT_RADIUS)
	_drift_offset = _drift_offset.lerp(_drift_target, DRIFT_LERP_SPEED * delta)


func _update_bob(delta: float) -> void:
	_bob_phase = fmod(_bob_phase + delta * BOB_HZ * TAU, TAU)
	position = _home_position + _drift_offset + Vector3(0.0, sin(_bob_phase) * BOB_AMPLITUDE, 0.0)
	if _visual != null:
		_visual.rotate_y(SPIN_SPEED * delta)


func _update_emission(delta: float) -> void:
	if _material == null:
		return
	var target: float = GREET_EMISSION if _greeting else REST_EMISSION
	_material.emission_energy_multiplier = move_toward(_material.emission_energy_multiplier, target, EMISSION_LERP_SPEED * delta)


func _emit_receipt() -> void:
	if _receipt_cooldown > 0.0:
		return
	_receipt_cooldown = RECEIPT_COOLDOWN
	PositionalAudio.play_at(CHIME_SFX, global_position)
	print("RESIDENT %s" % JSON.stringify({"id": id, "event": "greet"}))
