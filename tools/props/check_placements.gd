extends SceneTree
## check_placements.gd — PLACEMENT SANITY property (P2, verify brief). Would
## have caught the two buried-dreamling bugs (d02 in the haunch, d10 in the
## ear bump — see docs/verify/gate2-slice-VERIFY.md §bugs-found and §UNVERIFIED).
##
## Standalone tool, NOT part of the normal boot path. Run headless via:
##   godot_console.exe --headless --path . --script tools/props/check_placements.gd
## Optional `--world=<id>` (after `--`) restricts the check to one world;
## default is every world in DEFAULT_WORLDS.
##
## For each world: instantiates <id>.tscn directly under the live SceneTree
## root (bypassing scenes/main.tscn entirely — no players, no camera, just
## world geometry + Dreamlings), waits a few physics frames so
## PhysicsServer3D has registered every StaticBody3D collider added this
## session, then for every Dreamling descendant runs two physics queries:
##
##   (a) a point query at the dreamling's exact global position, world-
##       geometry layer (1) only — any hit means the dreamling is embedded
##       in solid collision.
##   (b) a downward raycast from that same position, same layer — the
##       vertical gap to the first hit must be within [0, 2.0] m, UNLESS
##       the dreamling is parented to something other than the world root
##       (the moving-platform case: d06 rides Bramble's breathing chest,
##       worlds/bramble/breathing_chest.gd).
##
## CAVEAT (documented, not worked around): PhysicsDirectSpaceState3D.
## intersect_point() does not support concave/trimesh shapes per Godot docs
## — Bramble's paw ramps use ConcavePolygonShape3D
## (mesh.create_trimesh_shape() in bramble.gd _add_paw_ramp), so the
## inside_solid check is blind to embedding specifically inside a paw ramp.
## No current dreamling sits inside a paw ramp (d03/d04 sit ON one, at
## y = ramp rise, not inside it) so this is a latent gap, not a live miss —
## flagging it rather than silently trusting the query.
##
## Resets the in-memory GameState.dreamlings entry for the world under test
## before instancing it, so a dreamling already marked "returned" in the
## player's real user://save.json (WorldBase._wire_dreamlings() queue_frees
## those on _ready(), by design — SPEC.md D14) never disappears from this
## check the way it would in a normal boot. This only mutates the
## already-loaded in-memory autoload dict for this one-shot process; the
## save FILE itself is never opened, read, or written by this tool.
##
## Output: one line per dreamling —
##   PLACEMENT {"world":"bramble","id":"d10","verdict":"PASS","inside_solid":false,"has_ground":true,"ground_gap":0.12,"moving_platform":false,"pos":[...]}
## Exit code 0 if every dreamling in every checked world PASSes, 1 otherwise
## (nonzero exit on any FAIL, per the brief).

const WORLD_SCENE_PATH_FORMAT: String = "res://worlds/%s/%s.tscn"
const DEFAULT_WORLDS: PackedStringArray = ["pillow_fort", "bramble"]
const COLLISION_MASK_WORLD_GEOMETRY: int = 1 # matches core/movement/player_body.gd PLAYER_COLLISION_MASK
const MAX_STANDABLE_GAP: float = 2.0
const RAY_DOWN_DISTANCE: float = 50.0
const SETTLE_PHYSICS_FRAMES: int = 3

var _any_fail: bool = false


func _initialize() -> void:
	# _initialize() can't itself be awaited by the engine, so the actual
	# (coroutine) work is deferred one frame into a normal method — the tree
	# keeps pumping frames regardless, which is what lets `await physics_frame`
	# below actually resume later instead of the process just idling.
	call_deferred("_run")


func _run() -> void:
	# Give the engine's normal boot sequence room to finish registering
	# autoload singletons as recognized GDScript identifiers before we start
	# loading world scripts that reference them (AudioManager, etc.) — under
	# a bare `--script` main loop this isn't settled by the time
	# _initialize()/call_deferred("_run") first runs, unlike the normal
	# boot.tscn -> main.tscn path where plenty of frames pass first.
	for i: int in range(SETTLE_PHYSICS_FRAMES):
		await process_frame
	var worlds: PackedStringArray = _worlds_to_check()
	for world_id: String in worlds:
		await _check_world(world_id)
	print("PLACEMENT_SUMMARY %s" % JSON.stringify({"worlds": Array(worlds), "any_fail": _any_fail}))
	quit(1 if _any_fail else 0)


func _worlds_to_check() -> PackedStringArray:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world="):
			return PackedStringArray([arg.trim_prefix("--world=")])
	return DEFAULT_WORLDS


func _check_world(world_id: String) -> void:
	var scene_path: String = WORLD_SCENE_PATH_FORMAT % [world_id, world_id]
	if not ResourceLoader.exists(scene_path):
		print("PLACEMENT_NOTE world scene not found: %s" % scene_path)
		return

	_forget_saved_returns(world_id)

	var packed: PackedScene = load(scene_path)
	var world: Node3D = packed.instantiate() as Node3D
	get_root().add_child(world)

	for i: int in range(SETTLE_PHYSICS_FRAMES):
		await physics_frame

	var dreamlings: Array = _find_dreamlings(world)
	if dreamlings.is_empty():
		print("PLACEMENT_NOTE %s has zero dreamlings (nothing to check)" % world_id)
	for dreamling: Node3D in dreamlings:
		_check_dreamling(world_id, world, dreamling)

	world.queue_free()
	await physics_frame # let the free land before the next world is added


## See file header: a real save.json can mark this world's dreamlings
## "already returned", which WorldBase would otherwise queue_free() on
## _ready() before we ever get to inspect them.
func _forget_saved_returns(world_id: String) -> void:
	var game_state: Node = get_root().get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var dreamlings_dict: Variant = game_state.get("dreamlings")
	if dreamlings_dict is Dictionary:
		(dreamlings_dict as Dictionary).erase(world_id)


const DREAMLING_SCRIPT_PATH: String = "res://worlds/common/dreamling.gd"


## Duck-typed on purpose (script resource path, not `is Dreamling`): a static
## reference to the Dreamling class would pull dreamling.gd in as a compile
## dependency of THIS file, and dreamling.gd references the AudioManager
## autoload — which is not yet resolvable as a GDScript global identifier at
## the point a bare `--script` main loop's target file is first parsed
## (confirmed empirically: with a static `is Dreamling` check here, loading
## this script itself threw "Compile Error: Identifier not found:
## AudioManager" for dreamling.gd, and the failure was cached, permanently
## breaking every later DreamlingScene.instantiate() call for the rest of
## the process — every Bramble dreamling silently failed to spawn). Normal
## boot (boot.tscn -> main.tscn) never hits this because plenty of engine
## frames pass, with autoloads fully live, before any world script is
## touched; a one-shot `--script` tool has no such runway.
func _find_dreamlings(node: Node) -> Array:
	var found: Array = []
	for child: Node in node.get_children():
		if _is_dreamling(child):
			found.append(child)
		found.append_array(_find_dreamlings(child))
	return found


func _is_dreamling(node: Node) -> bool:
	var s: Script = node.get_script() as Script
	return s != null and s.resource_path == DREAMLING_SCRIPT_PATH


func _check_dreamling(world_id: String, world: Node3D, dreamling: Node3D) -> void:
	var space_state: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var pos: Vector3 = dreamling.global_position

	var point_params := PhysicsPointQueryParameters3D.new()
	point_params.position = pos
	point_params.collision_mask = COLLISION_MASK_WORLD_GEOMETRY
	point_params.collide_with_bodies = true
	point_params.collide_with_areas = false
	var point_hits: Array = space_state.intersect_point(point_params, 8)
	var inside_solid: bool = not point_hits.is_empty()

	var ray_params := PhysicsRayQueryParameters3D.create(pos, pos - Vector3(0.0, RAY_DOWN_DISTANCE, 0.0))
	ray_params.collision_mask = COLLISION_MASK_WORLD_GEOMETRY
	ray_params.collide_with_bodies = true
	ray_params.collide_with_areas = false
	var ray_hit: Dictionary = space_state.intersect_ray(ray_params)
	var has_ground: bool = not ray_hit.is_empty()
	var ground_gap: Variant = null
	if has_ground:
		ground_gap = snappedf(pos.y - (ray_hit["position"] as Vector3).y, 0.01)

	var moving_platform: bool = dreamling.get_parent() != world

	var verdict: String = "PASS"
	if inside_solid:
		verdict = "FAIL"
	elif not moving_platform and (not has_ground or float(ground_gap) < 0.0 or float(ground_gap) > MAX_STANDABLE_GAP):
		verdict = "FAIL"

	if verdict == "FAIL":
		_any_fail = true

	print("PLACEMENT %s" % JSON.stringify({
		"world": world_id,
		"id": str(dreamling.get("id")),
		"verdict": verdict,
		"inside_solid": inside_solid,
		"has_ground": has_ground,
		"ground_gap": ground_gap,
		"moving_platform": moving_platform,
		"pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)],
	}))
