extends SceneTree
## check_missions.gd — MISSION SANITY property (docs/verify/aliveness-v2-VERIFY.md).
## Companion to check_placements.gd, same technique: instantiates a world
## scene directly under the live SceneTree root (no players, no camera, just
## world geometry + Dreamlings), waits a few physics frames, then for every
## entry in that world's data/missions/<id>.json checks three things:
##
##   (a) id_found — the mission's id matches a Dreamling ACTUALLY placed in
##       that world. A stale/typo'd id in the JSON would otherwise silently
##       do nothing (world_base.gd's _attach_mission just never finds a
##       match) — this makes that loud instead.
##   (b) waypoints_ok — for race/ride archetypes, every waypoint's Y
##       (dreamling's own placement Y + the waypoint's local Y) stays above
##       that world's rescue_floor_y(). A path that dips below the Soft
##       Landing floor would be a mission driving its own dreamling into
##       the one place the game promises nothing ever gets stuck.
##   (c) duet_ok — for duet archetypes: duet_radius > 0 and 0 <
##       fallback_seconds <= FALLBACK_SECONDS_MAX, so the "nothing missable
##       solo" escape valve (mission_driver.gd's single-player fallback)
##       can't itself be misconfigured into zero or unreasonably long.
##   (d) moon_line_key_ok — mission-author pass (docs/verify/missions-m2-
##       VERIFY.md): every NON-open archetype now has mission_driver.gd call
##       TheMoon.say(moon_line_key) at its own bloom/start moment, so a blank
##       key there would be a silent, permanent gap (TheMoon.say() fails
##       soft on an unknown/blank key rather than erroring, which is exactly
##       why this needs a loud check instead of trusting the runtime).
##       "open" archetypes are exempt (moon_line_key on "open" is optional
##       data, spoken only via the opt-in params.speak_on_collect seam —
##       see world_base.gd._wire_open_moon_line).
##
## Also prints one MISSION_ARCHETYPE_COUNTS line per world (informational,
## never fails the run): a per-archetype tally, so a design pass ("2 race, 2
## ride, 1 shy, 1 duet, ...") can be eyeballed against the receipt instead of
## re-reading the JSON by hand.
##
## Run headless via:
##   godot_console.exe --headless --path . --script tools/props/check_missions.gd
## Optional `--world=<id>` restricts the check to one world; default is
## every world with dreamlings (DEFAULT_WORLDS). A world with no
## data/missions/<id>.json (pillow_fort; or any world before mission data
## exists) is a documented no-op, not a failure.
##
## Output: one line per mission —
##   MISSION_CHECK {"world":"bramble","id":"d01","archetype":"race","verdict":"PASS",...}
## and a summary:
##   MISSION_SUMMARY {"worlds":[...],"any_fail":false}
## Exit code 0 if every checked mission PASSes, 1 otherwise.

const WORLD_SCENE_PATH_FORMAT: String = "res://worlds/%s/%s.tscn"
const MISSION_DATA_PATH_FORMAT: String = "res://data/missions/%s.json"
const DEFAULT_WORLDS: PackedStringArray = ["bramble", "wisp", "marmalade"]
const SETTLE_PHYSICS_FRAMES: int = 3
const FALLBACK_SECONDS_MAX: float = 30.0
const DREAMLING_SCRIPT_PATH: String = "res://worlds/common/dreamling.gd"

var _any_fail: bool = false


func _initialize() -> void:
	# Same rationale as check_placements.gd: a bare `--script` main loop
	# needs a few frames before autoloads (GameState, etc.) are resolvable
	# globals, before any world script that touches them gets loaded.
	call_deferred("_run")


func _run() -> void:
	for i: int in range(SETTLE_PHYSICS_FRAMES):
		await process_frame
	var worlds: PackedStringArray = _worlds_to_check()
	for world_id: String in worlds:
		await _check_world(world_id)
	print("MISSION_SUMMARY %s" % JSON.stringify({"worlds": Array(worlds), "any_fail": _any_fail}))
	quit(1 if _any_fail else 0)


func _worlds_to_check() -> PackedStringArray:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world="):
			return PackedStringArray([arg.trim_prefix("--world=")])
	return DEFAULT_WORLDS


func _check_world(world_id: String) -> void:
	var mission_path: String = MISSION_DATA_PATH_FORMAT % world_id
	if not FileAccess.file_exists(mission_path):
		print("MISSION_NOTE %s has no mission data (all-open, nothing to check)" % world_id)
		return

	var scene_path: String = WORLD_SCENE_PATH_FORMAT % [world_id, world_id]
	if not ResourceLoader.exists(scene_path):
		print("MISSION_NOTE world scene not found: %s" % scene_path)
		return

	_forget_saved_returns(world_id)

	var packed: PackedScene = load(scene_path)
	var world: Node3D = packed.instantiate() as Node3D
	get_root().add_child(world)

	for i: int in range(SETTLE_PHYSICS_FRAMES):
		await physics_frame

	var dreamling_positions: Dictionary = _index_dreamlings(world) # id -> global_position (Vector3)
	var rescue_floor_y: float = float(world.call("rescue_floor_y"))
	var missions: Dictionary = MissionRegistry.load_for_world(world_id)
	var archetype_counts: Dictionary = {}
	for mission_id: String in missions.keys():
		var mission: Mission = missions[mission_id] as Mission
		archetype_counts[mission.archetype] = int(archetype_counts.get(mission.archetype, 0)) + 1
		_check_mission(world_id, mission, dreamling_positions, rescue_floor_y)
	print("MISSION_ARCHETYPE_COUNTS %s" % JSON.stringify({
		"world": world_id, "counts": archetype_counts, "total": missions.size(),
	}))

	world.queue_free()
	await physics_frame # let the free land before the next world is added


## See check_placements.gd's own header: a real save.json can mark this
## world's dreamlings "already returned", which WorldBase would otherwise
## queue_free() before we ever get to check their mission wiring.
func _forget_saved_returns(world_id: String) -> void:
	var game_state: Node = get_root().get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var dreamlings_dict: Variant = game_state.get("dreamlings")
	if dreamlings_dict is Dictionary:
		(dreamlings_dict as Dictionary).erase(world_id)


func _index_dreamlings(node: Node) -> Dictionary:
	var out: Dictionary = {}
	_collect_dreamlings(node, out)
	return out


## Duck-typed on script resource path (not `is Dreamling`) for the exact
## reason check_placements.gd's own _find_dreamlings is — see that file's
## header comment. dreamling.gd references the AudioManager autoload, which
## isn't yet a resolvable global identifier this early in a bare `--script`
## boot; a static type dependency here would pull it in at parse time.
func _collect_dreamlings(node: Node, out: Dictionary) -> void:
	for child: Node in node.get_children():
		var s: Script = child.get_script() as Script
		if s != null and s.resource_path == DREAMLING_SCRIPT_PATH:
			out[str(child.get("id"))] = (child as Node3D).global_position
		_collect_dreamlings(child, out)


func _check_mission(world_id: String, mission: Mission, dreamling_positions: Dictionary, rescue_floor_y: float) -> void:
	var reasons: Array[String] = []

	var origin: Variant = dreamling_positions.get(mission.id, null)
	var id_found: bool = origin != null
	if not id_found:
		reasons.append("no_matching_dreamling")

	var waypoints_ok: bool = true
	if id_found and (mission.archetype == Mission.ARCHETYPE_RACE or mission.archetype == Mission.ARCHETYPE_RIDE):
		waypoints_ok = _check_waypoints(mission, origin as Vector3, rescue_floor_y)
		if not waypoints_ok:
			reasons.append("waypoint_below_rescue_floor")

	var duet_ok: bool = true
	if mission.archetype == Mission.ARCHETYPE_DUET:
		duet_ok = _check_duet_params(mission, reasons)

	var moon_line_key_ok: bool = true
	if mission.archetype != Mission.ARCHETYPE_OPEN and mission.moon_line_key.is_empty():
		moon_line_key_ok = false
		reasons.append("moon_line_key_missing")

	var verdict: String = "PASS" if reasons.is_empty() else "FAIL"
	if verdict == "FAIL":
		_any_fail = true

	print("MISSION_CHECK %s" % JSON.stringify({
		"world": world_id,
		"id": mission.id,
		"archetype": mission.archetype,
		"verdict": verdict,
		"id_found": id_found,
		"waypoints_ok": waypoints_ok,
		"duet_ok": duet_ok,
		"moon_line_key_ok": moon_line_key_ok,
		"reasons": reasons,
	}))


func _check_waypoints(mission: Mission, origin: Vector3, rescue_floor_y: float) -> bool:
	var raw: Variant = mission.params.get("waypoints", [])
	if not (raw is Array):
		return true # falls back to the driver's own built-in default path — nothing to check here
	for entry: Variant in (raw as Array):
		if entry is Array and (entry as Array).size() >= 3:
			var a: Array = entry as Array
			var world_y: float = origin.y + float(a[1])
			if world_y <= rescue_floor_y:
				return false
	return true


func _check_duet_params(mission: Mission, reasons: Array[String]) -> bool:
	var ok: bool = true
	var radius: float = float(mission.params.get("duet_radius", 0.0))
	var fallback: float = float(mission.params.get("fallback_seconds", 0.0))
	if radius <= 0.0:
		ok = false
		reasons.append("duet_radius_not_positive")
	if fallback <= 0.0 or fallback > FALLBACK_SECONDS_MAX:
		ok = false
		reasons.append("fallback_seconds_out_of_range")
	return ok
