class_name MissionDriver
extends Node
## MissionDriver — archetype behavior for one Dreamling (D21/D23; taxonomy
## per docs/research/v2/structure_progression.md TOP 12 #1). Attached as a
## CHILD of a Dreamling by worlds/common/world_base.gd, for any id whose
## mission archetype is not "open" -- "open" ids get no driver at all,
## which is what makes the default truly zero-behavior-change (D21).
##
## Drives the dreamling's position via Dreamling.mission_set_local_offset(),
## an ADDITIVE offset layered on top of its own idle bob/magnetism anchor
## (worlds/common/dreamling.gd) -- never the anchor itself. That single
## design choice is what keeps this component safe against
## tools/props/check_placements.gd's LAW (30/30 green): even a buggy or
## deleted driver can only ever leave the dreamling at its unmodified
## placement, never somewhere it's never been. Per-archetype guarantee:
##   race — never moves the offset until a player is within trigger_radius
##          (so it's motionless at placement the instant a placement check
##          samples it, no player present); loops a CLOSED path (implicitly
##          closing waypoints[-1] back to waypoints[0]) so it only ever
##          revisits points already inside its own loop, then eases the
##          offset back to zero and hands off to normal magnetism.
##   ride  — loops a small CLOSED path forever, starting the offset at
##           Vector3.ZERO on frame 0 (waypoints[0] is placement itself by
##           convention) -- a placement check sampling within the first few
##           physics frames (check_placements.gd's SETTLE_PHYSICS_FRAMES=3)
##           sees a displacement of a few centimeters at most.
##   shy/duet — never move the offset at all; only gate `monitoring`
##              (catchable or not) and the visual's scale/glow.
##
## D23 floor: every archetype is celebration-only. race/ride are ALWAYS
## catchable via the dreamling's own unmodified Area3D collision (this
## driver never touches that) -- "zips away" is flavor, not evasion that
## can fail. shy/duet gate WHEN something becomes catchable, never whether;
## duet's single-player fallback timer is the explicit "nothing missable
## solo" escape valve the brief calls for.
##
## Moon wiring (mission-author pass, docs/verify/missions-m2-VERIFY.md):
## _speak_bloom_line() calls TheMoon.say(mission.moon_line_key) exactly once
## at each archetype's own bloom/start moment (race: trigger_radius entry;
## ride: first proximity within RIDE_DEFAULT_TRIGGER_RADIUS -- a NEW,
## purely-observational proximity check added this pass that never gates
## the loop itself; shy/duet: reveal/bloom) -- never on every catch, per
## NARRATION_BIBLE.md's "rare, structural beats only" law. A missing/empty
## moon_line_key is a silent no-op (see mission.gd).

const PLAYERS_GROUP: String = "players"
const OFFSET_SETTLE_DURATION: float = 0.6
const GATE_HIDDEN_SCALE: float = 0.5
const GATE_HIDDEN_DIM: float = 0.35
const GATE_REVEAL_TWEEN_TIME: float = 0.5

# --- Race --------------------------------------------------------------------
enum RaceState { WAITING, RUNNING, SETTLING, DONE }
const RACE_DEFAULT_SPEED: float = 3.5
const RACE_DEFAULT_TRIGGER_RADIUS: float = 3.0
const RACE_DEFAULT_LAPS: int = 2
const RACE_CATCHUP_DISTANCE: float = 5.0 # beyond this, path progress crawls -- rubber-band
const RACE_SLOW_FACTOR: float = 0.25
const RACE_DEFAULT_WAYPOINTS: Array = [
	Vector3(0.0, 0.0, 0.0), Vector3(2.5, 0.0, 2.0), Vector3(3.0, 0.0, -1.5), Vector3(0.5, 0.0, -2.5),
]

# --- Ride ----------------------------------------------------------------------
const RIDE_DEFAULT_SPEED: float = 1.1
const RIDE_DEFAULT_TRIGGER_RADIUS: float = 3.0 # bloom/Moon-line proximity gate (mission-author pass) -- never gates the loop itself
const RIDE_DEFAULT_WAYPOINTS: Array = [
	Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.15, 0.7), Vector3(0.2, 0.25, 1.3), Vector3(-0.9, 0.15, 0.6),
]

# --- Shy -----------------------------------------------------------------------
const SHY_DEFAULT_REVEAL_RADIUS: float = 4.0
const SHY_DEFAULT_REVEAL_TIME: float = 1.5

# --- Duet ------------------------------------------------------------------------
const DUET_DEFAULT_RADIUS: float = 3.0
const DUET_DEFAULT_FALLBACK_SECONDS: float = 10.0

var _dreamling: Dreamling = null
var _mission: Mission = null
var _world_id: String = ""
var _caught: bool = false

# Race state
var _race_state: RaceState = RaceState.WAITING
var _race_waypoints: Array = RACE_DEFAULT_WAYPOINTS
var _race_speed: float = RACE_DEFAULT_SPEED
var _race_trigger_radius: float = RACE_DEFAULT_TRIGGER_RADIUS
var _race_laps_target: int = RACE_DEFAULT_LAPS
var _race_path_length: float = 0.0
var _race_distance_traveled: float = 0.0
var _race_settle_elapsed: float = 0.0
var _race_settle_start: Vector3 = Vector3.ZERO

# Ride state
var _ride_waypoints: Array = RIDE_DEFAULT_WAYPOINTS
var _ride_speed: float = RIDE_DEFAULT_SPEED
var _ride_path_length: float = 0.0
var _ride_distance: float = 0.0
var _ride_trigger_radius: float = RIDE_DEFAULT_TRIGGER_RADIUS
var _ride_bloomed: bool = false

# Shy state
var _shy_revealed: bool = false
var _shy_reveal_radius: float = SHY_DEFAULT_REVEAL_RADIUS
var _shy_reveal_time: float = SHY_DEFAULT_REVEAL_TIME
var _shy_watch_timer: float = 0.0
var _shy_visual: Node3D = null
var _shy_base_scale: Vector3 = Vector3.ONE
var _shy_material: StandardMaterial3D = null
var _shy_base_emission: float = 1.0

# Duet state
var _duet_bloomed: bool = false
var _duet_radius: float = DUET_DEFAULT_RADIUS
var _duet_fallback_seconds: float = DUET_DEFAULT_FALLBACK_SECONDS
var _duet_single_timer: float = 0.0
var _duet_visual: Node3D = null
var _duet_base_scale: Vector3 = Vector3.ONE
var _duet_material: StandardMaterial3D = null
var _duet_base_emission: float = 1.0


func setup(dreamling: Dreamling, mission: Mission, world_id: String) -> void:
	_dreamling = dreamling
	_mission = mission
	_world_id = world_id
	_dreamling.collected.connect(_on_dreamling_collected)
	match mission.archetype:
		Mission.ARCHETYPE_RACE:
			_setup_race(mission.params)
		Mission.ARCHETYPE_RIDE:
			_setup_ride(mission.params)
		Mission.ARCHETYPE_SHY:
			_setup_shy(mission.params)
		Mission.ARCHETYPE_DUET:
			_setup_duet(mission.params)
		_:
			pass # open — world_base.gd shouldn't attach a driver for this at all


func _on_dreamling_collected(_id: String) -> void:
	_caught = true
	set_physics_process(false)
	print("EVT %s" % JSON.stringify({
		"type": "mission_caught", "world": _world_id, "id": _mission.id, "archetype": _mission.archetype,
		"t": Engine.get_physics_frames(),
	}))


func _physics_process(delta: float) -> void:
	if _caught or _dreamling == null or not is_instance_valid(_dreamling):
		return
	match _mission.archetype:
		Mission.ARCHETYPE_RACE:
			_process_race(delta)
		Mission.ARCHETYPE_RIDE:
			_process_ride(delta)
		Mission.ARCHETYPE_SHY:
			_process_shy(delta)
		Mission.ARCHETYPE_DUET:
			_process_duet(delta)


func _players() -> Array:
	return get_tree().get_nodes_in_group(PLAYERS_GROUP)


func _nearest_player_distance() -> float:
	var best: float = INF
	for node: Node in _players():
		var player: Node3D = node as Node3D
		if player == null:
			continue
		var dist: float = player.global_position.distance_to(_dreamling.global_position)
		best = min(best, dist)
	return best


## Shared by every archetype's own bloom/start moment (race trigger, ride
## first-proximity, shy reveal, duet bloom) -- each call site above reaches
## this exactly once (state-guarded), which IS the "once per mission per
## session" contract; a missing/empty key is a documented no-op, not an
## error (see mission.gd's moon_line_key doc comment).
func _speak_bloom_line() -> void:
	if _mission.moon_line_key.is_empty():
		return
	TheMoon.say(_mission.moon_line_key)


# ---------------------------------------------------------------------------
# RACE
# ---------------------------------------------------------------------------

func _setup_race(params: Dictionary) -> void:
	var parsed: Array = _parse_waypoints(params.get("waypoints", []))
	_race_waypoints = parsed if not parsed.is_empty() else RACE_DEFAULT_WAYPOINTS
	_race_speed = float(params.get("speed", RACE_DEFAULT_SPEED))
	_race_trigger_radius = float(params.get("trigger_radius", RACE_DEFAULT_TRIGGER_RADIUS))
	_race_laps_target = int(params.get("laps", RACE_DEFAULT_LAPS))
	_race_path_length = _closed_path_length(_race_waypoints)


func _process_race(delta: float) -> void:
	match _race_state:
		RaceState.WAITING:
			if _nearest_player_distance() <= _race_trigger_radius:
				_race_state = RaceState.RUNNING
				_dreamling.mission_suppress_magnetism = true
				print("EVT %s" % JSON.stringify({
					"type": "mission_race_started", "world": _world_id, "id": _mission.id, "archetype": "race",
					"t": Engine.get_physics_frames(),
				}))
				_speak_bloom_line()
		RaceState.RUNNING:
			_advance_race(delta)
		RaceState.SETTLING:
			_settle_race(delta)
		RaceState.DONE:
			pass


func _advance_race(delta: float) -> void:
	var speed: float = _race_speed
	if _nearest_player_distance() > RACE_CATCHUP_DISTANCE:
		speed *= RACE_SLOW_FACTOR # rubber-band: never outrun a small kid for long
	_race_distance_traveled += speed * delta
	var laps_done: float = _race_distance_traveled / max(_race_path_length, 0.01)
	if laps_done >= float(_race_laps_target):
		_race_state = RaceState.SETTLING
		_race_settle_elapsed = 0.0
		_race_settle_start = _dreamling.mission_current_offset()
		return
	_dreamling.mission_set_local_offset(_sample_closed_path(_race_waypoints, _race_distance_traveled))


func _settle_race(delta: float) -> void:
	_race_settle_elapsed += delta
	var t: float = clamp(_race_settle_elapsed / OFFSET_SETTLE_DURATION, 0.0, 1.0)
	_dreamling.mission_set_local_offset(_race_settle_start.lerp(Vector3.ZERO, t))
	if t >= 1.0:
		_dreamling.mission_suppress_magnetism = false
		_race_state = RaceState.DONE
		set_physics_process(false) # race is spent -- normal magnetism/catch takes it from here


# ---------------------------------------------------------------------------
# RIDE — magnetism deliberately stays ON (never suppressed): "generous
# magnetism stays on" per the brief, so a nearby player pulls the whole
# floating loop toward them, additive with the loop's own offset.
# ---------------------------------------------------------------------------

func _setup_ride(params: Dictionary) -> void:
	var parsed: Array = _parse_waypoints(params.get("waypoints", []))
	_ride_waypoints = parsed if not parsed.is_empty() else RIDE_DEFAULT_WAYPOINTS
	_ride_speed = float(params.get("speed", RIDE_DEFAULT_SPEED))
	_ride_trigger_radius = float(params.get("trigger_radius", RIDE_DEFAULT_TRIGGER_RADIUS))
	_ride_path_length = _closed_path_length(_ride_waypoints)


## The loop itself never gates on proximity (it's been drifting since frame 0,
## magnetism always on, per the archetype's own contract above) -- this ONLY
## marks the first moment a player notices it, for a one-shot EVT + Moon line,
## mirroring race's own trigger-radius bloom without touching the motion.
func _process_ride(delta: float) -> void:
	_ride_distance = fmod(_ride_distance + _ride_speed * delta, max(_ride_path_length, 0.01))
	_dreamling.mission_set_local_offset(_sample_closed_path(_ride_waypoints, _ride_distance))
	if not _ride_bloomed and _nearest_player_distance() <= _ride_trigger_radius:
		_ride_bloomed = true
		print("EVT %s" % JSON.stringify({
			"type": "mission_bloomed", "world": _world_id, "id": _mission.id, "archetype": "ride", "trigger": "proximity",
			"t": Engine.get_physics_frames(),
		}))
		_speak_bloom_line()


# ---------------------------------------------------------------------------
# SHY — hides (small + dim) until a player stands still nearby for
# reveal_time, then peeks out and brightens; `monitoring` (Dreamling's own
# public "still catchable" flag) is false the entire time it's hidden.
# Callie's own uncollected-dream scan (core/companion/callie.gd
# _nearest_sniffable_dreamling) filters on `candidate.monitoring` already --
# a hidden dream is invisible to her sniff-and-mew for free, no callie.gd
# change needed, and that reads as INTENTIONAL (she doesn't point at a dream
# that isn't ready to be found yet).
# ---------------------------------------------------------------------------

func _setup_shy(params: Dictionary) -> void:
	_shy_reveal_radius = float(params.get("reveal_radius", SHY_DEFAULT_REVEAL_RADIUS))
	_shy_reveal_time = float(params.get("reveal_time", SHY_DEFAULT_REVEAL_TIME))
	var hidden_scale: float = float(params.get("hidden_scale", GATE_HIDDEN_SCALE))
	var hidden_dim: float = float(params.get("hidden_dim", GATE_HIDDEN_DIM))

	_dreamling.monitoring = false
	_shy_visual = _dreamling.get_node_or_null("Visual") as Node3D
	if _shy_visual == null:
		return
	_shy_base_scale = _shy_visual.scale
	_shy_visual.scale = _shy_base_scale * hidden_scale
	_shy_material = _override_material(_shy_visual)
	if _shy_material != null:
		_shy_base_emission = _shy_material.emission_energy_multiplier
		_shy_material.emission_energy_multiplier = _shy_base_emission * hidden_dim


func _process_shy(delta: float) -> void:
	if _shy_revealed:
		return
	if _nearest_player_distance() <= _shy_reveal_radius:
		_shy_watch_timer += delta
		if _shy_watch_timer >= _shy_reveal_time:
			_reveal_shy()
	else:
		_shy_watch_timer = 0.0


func _reveal_shy() -> void:
	_shy_revealed = true
	_dreamling.monitoring = true
	if _shy_visual != null:
		var tween: Tween = create_tween()
		tween.tween_property(_shy_visual, "scale", _shy_base_scale, GATE_REVEAL_TWEEN_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _shy_material != null:
		var glow_tween: Tween = create_tween()
		glow_tween.tween_property(_shy_material, "emission_energy_multiplier", _shy_base_emission, GATE_REVEAL_TWEEN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	print("EVT %s" % JSON.stringify({
		"type": "mission_bloomed", "world": _world_id, "id": _mission.id, "archetype": "shy", "trigger": "stillness",
		"t": Engine.get_physics_frames(),
	}))
	_speak_bloom_line()


# ---------------------------------------------------------------------------
# DUET — wants two players near at once to bloom catchable; a single-player
# fallback timer guarantees nothing is missable solo, per the brief's own
# generous-fallback instruction (buddy_ai.gd's follow_distance is 2.5 m,
# tighter than a plausible duet_radius, so dual-proximity likely succeeds
# often in solo mode too, but the fallback is the one thing this driver
# actually GUARANTEES rather than merely expects -- see aliveness-v2-VERIFY.md).
# ---------------------------------------------------------------------------

func _setup_duet(params: Dictionary) -> void:
	_duet_radius = float(params.get("duet_radius", DUET_DEFAULT_RADIUS))
	_duet_fallback_seconds = float(params.get("fallback_seconds", DUET_DEFAULT_FALLBACK_SECONDS))
	var hidden_scale: float = float(params.get("hidden_scale", GATE_HIDDEN_SCALE))
	var hidden_dim: float = float(params.get("hidden_dim", GATE_HIDDEN_DIM))

	_dreamling.monitoring = false
	_duet_visual = _dreamling.get_node_or_null("Visual") as Node3D
	if _duet_visual == null:
		return
	_duet_base_scale = _duet_visual.scale
	_duet_visual.scale = _duet_base_scale * hidden_scale
	_duet_material = _override_material(_duet_visual)
	if _duet_material != null:
		_duet_base_emission = _duet_material.emission_energy_multiplier
		_duet_material.emission_energy_multiplier = _duet_base_emission * hidden_dim


func _process_duet(delta: float) -> void:
	if _duet_bloomed:
		return
	var within: int = 0
	for node: Node in _players():
		var player: Node3D = node as Node3D
		if player == null:
			continue
		if player.global_position.distance_to(_dreamling.global_position) <= _duet_radius:
			within += 1
	if within >= 2:
		_bloom_duet("dual_proximity")
		return
	if within >= 1:
		_duet_single_timer += delta
		if _duet_single_timer >= _duet_fallback_seconds:
			_bloom_duet("fallback_timer")
	else:
		_duet_single_timer = 0.0


func _bloom_duet(trigger: String) -> void:
	_duet_bloomed = true
	_dreamling.monitoring = true
	if _duet_visual != null:
		var tween: Tween = create_tween()
		tween.tween_property(_duet_visual, "scale", _duet_base_scale, GATE_REVEAL_TWEEN_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _duet_material != null:
		var glow_tween: Tween = create_tween()
		glow_tween.tween_property(_duet_material, "emission_energy_multiplier", _duet_base_emission, GATE_REVEAL_TWEEN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	print("EVT %s" % JSON.stringify({
		"type": "mission_bloomed", "world": _world_id, "id": _mission.id, "archetype": "duet", "trigger": trigger,
		"t": Engine.get_physics_frames(),
	}))
	_speak_bloom_line()


# ---------------------------------------------------------------------------
# Shared path / material helpers
# ---------------------------------------------------------------------------

func _parse_waypoints(raw: Variant) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for entry: Variant in (raw as Array):
		if entry is Array and (entry as Array).size() >= 3:
			var a: Array = entry as Array
			out.append(Vector3(float(a[0]), float(a[1]), float(a[2])))
	return out


## Length of the loop that implicitly closes waypoints[-1] back to
## waypoints[0] -- every race/ride path is a closed loop by construction, so
## it only ever revisits points already inside it (waypoints[0] is expected
## to be Vector3.ZERO by convention: the path then starts exactly at the
## dreamling's own placement).
func _closed_path_length(points: Array) -> float:
	if points.size() < 2:
		return 0.01
	var total: float = 0.0
	for i: int in range(points.size()):
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()]
		total += a.distance_to(b)
	return max(total, 0.01)


## Position along the closed loop at arclength `distance` (caller wraps via
## fmod) -- constant-speed segment lerp, no easing.
func _sample_closed_path(points: Array, distance: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	if points.size() == 1:
		return points[0]
	var length: float = _closed_path_length(points)
	var remaining: float = fmod(distance, length)
	for i: int in range(points.size()):
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()]
		var seg_len: float = a.distance_to(b)
		if remaining <= seg_len or i == points.size() - 1:
			var t: float = 0.0 if seg_len < 0.0001 else clamp(remaining / seg_len, 0.0, 1.0)
			return a.lerp(b, t)
		remaining -= seg_len
	return points[0]


## Returns a per-instance StandardMaterial3D override on surface 0 of
## `visual` (creating one, duplicated from the shared mesh material, on
## first use) so dimming ONE hidden dreamling never dims every dreamling
## sharing that base SphereMesh resource.
func _override_material(visual: Node3D) -> StandardMaterial3D:
	var mesh_instance: MeshInstance3D = visual as MeshInstance3D
	if mesh_instance == null:
		return null
	var existing: StandardMaterial3D = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if existing != null:
		return existing
	var base: Material = mesh_instance.mesh.surface_get_material(0) if mesh_instance.mesh != null else null
	var mat: StandardMaterial3D = (base.duplicate() as StandardMaterial3D) if base is StandardMaterial3D else StandardMaterial3D.new()
	mesh_instance.set_surface_override_material(0, mat)
	return mat
