class_name WorldBase
extends WorldContract
## WorldBase — the bookkeeping every world module needs (SPEC.md World
## Module Contract). A concrete world (pillow_fort, bramble) extends this,
## builds its scene with Dreamling descendants and at most one DreamDoor,
## and only has to override world_id() / spawn_points() / objective_ids() /
## rescue_floor_y(). WorldBase finds its own dreamlings (registers them into
## the "dreamling" group), re-emits their collected/returned as the
## contract's objective_collected(id) / objective_returned(id), wires the
## DreamDoor if one exists, speaks the Moon's return lines, and marks the
## world complete through GameState once every objective that exists has
## come home. A world with zero objectives (the hub, pre-fort-growth) never
## auto-completes — there is nothing to complete.

@export var world_display_name: String = ""

const DREAMLING_GROUP: String = "dreamling"
const POKE_GROUP: String = "poke"
const CRITTER_DATA_PATH_FORMAT: String = "res://data/critters/%s.json"
const _WORLD_CONTRACT_SCRIPT_PATH: String = "res://core/world_contract.gd"
const _REQUIRED_OVERRIDES: PackedStringArray = [
	"world_id", "spawn_points", "objective_ids", "rescue_floor_y",
]

var _total_objectives: int = 0
var _returned_ids: Array[String] = []
var _has_spoken_first_return: bool = false
var _has_completed: bool = false


func _ready() -> void:
	_check_required_overrides()
	_total_objectives = objective_ids().size()
	_wire_dreamlings()
	_wire_dream_door()
	_wire_touch_react()
	_wire_critters()
	print("WORLD_READY %s" % JSON.stringify({"id": world_id(), "objectives": _total_objectives}))


## Tools-free contract check: a required method is "overridden" if it is
## declared more than once across the script inheritance chain — the
## contract's own stub always accounts for exactly one declaration, so a
## count of 1 means nothing below WorldContract defines it. This is
## value-independent (unlike comparing return values to a sentinel), which
## matters because a world's real rescue_floor_y() can legitimately equal
## the contract stub's -10.0 default.
func _check_required_overrides() -> void:
	var leaf_script: Script = get_script() as Script
	if leaf_script == null:
		return
	for method_name: String in _REQUIRED_OVERRIDES:
		if not _is_overridden(leaf_script, method_name):
			push_warning("WorldBase: required override missing: %s() on %s" % [method_name, leaf_script.resource_path])


func _is_overridden(leaf_script: Script, method_name: String) -> bool:
	var declarations: int = 0
	for method: Dictionary in leaf_script.get_script_method_list():
		if method["name"] == method_name:
			declarations += 1
	return declarations > 1


func _wire_dreamlings() -> void:
	# The world remembers across visits (D14): dreams already carried home
	# stay home — they never respawn. Seeding _returned_ids keeps completion
	# honest for partially-finished worlds re-entered mid-session or after
	# a save/load.
	var already_home: Array[String] = GameState.returned_ids(world_id())
	var missions: Dictionary = MissionRegistry.load_for_world(world_id())
	for dreamling: Dreamling in _find_dreamlings(self):
		if already_home.has(dreamling.id):
			dreamling.queue_free()
			continue
		dreamling.add_to_group(DREAMLING_GROUP)
		dreamling.collected.connect(_on_dreamling_collected)
		_attach_mission(dreamling, missions)
	for id: String in already_home:
		if not _returned_ids.has(id):
			_returned_ids.append(id)


## D21: attaches a MissionDriver only for a NON-open archetype. An id with
## no entry in data/missions/<world_id>.json, or an entry whose archetype is
## "open", gets no driver at all — that omission (not a no-op driver) is
## what guarantees the zero-behavior-change floor for every classic dreamling.
func _attach_mission(dreamling: Dreamling, missions: Dictionary) -> void:
	var mission: Mission = missions.get(dreamling.id) as Mission
	if mission == null or mission.archetype == Mission.ARCHETYPE_OPEN:
		return
	var driver := MissionDriver.new()
	driver.name = "MissionDriver"
	dreamling.add_child(driver)
	driver.setup(dreamling, mission, world_id())


func _find_dreamlings(node: Node) -> Array[Dreamling]:
	var found: Array[Dreamling] = []
	for child: Node in node.get_children():
		if child is Dreamling:
			found.append(child as Dreamling)
		found.append_array(_find_dreamlings(child))
	return found


func _wire_dream_door() -> void:
	var door: DreamDoor = _find_dream_door(self)
	if door == null:
		return
	door.returned.connect(_on_dreamling_returned)


func _find_dream_door(node: Node) -> DreamDoor:
	for child: Node in node.get_children():
		if child is DreamDoor:
			return child as DreamDoor
		var nested: DreamDoor = _find_dream_door(child)
		if nested != null:
			return nested
	return null


func _on_dreamling_collected(id: String) -> void:
	objective_collected.emit(id)


func _on_dreamling_returned(id: String) -> void:
	if not _returned_ids.has(id):
		_returned_ids.append(id)
	objective_returned.emit(id)
	if not _has_spoken_first_return:
		_has_spoken_first_return = true
		TheMoon.say("dream_home")
	_check_completion()


func _check_completion() -> void:
	if _has_completed:
		return
	if _total_objectives <= 0:
		return # nothing placed yet (the hub, pre-fort-growth) — never auto-completes
	if _returned_ids.size() < _total_objectives:
		return
	_has_completed = true
	TheMoon.say("well_done")
	GameState.mark_world_completed(world_id())


## How many objectives still await return. Not part of the contract; a
## convenience for future HUD/fort-growth work.
func remaining() -> int:
	return max(_total_objectives - _returned_ids.size(), 0)


## Aliveness Top 12 #6 ("poke-everything pass"): auto-attaches a TouchReact
## to every Node3D under this world already in the "poke" group. A prop
## opts in by calling `add_to_group("poke")` on itself (worlds/common/
## dream_door.gd does this for its own return-disk Visual — see that file);
## nothing else needs to change for a future prop to gain the same wobble +
## boop for free. Idempotent (skips a node that already has a TouchReact
## child) and scoped to THIS world instance only (get_tree() sees the whole
## live tree, but only one world is ever loaded at a time in normal play —
## the ancestry check keeps it correct under tools/props/check_placements.gd
## too, which can have a previous world mid-queue_free() when this runs).
func _wire_touch_react() -> void:
	for node: Node in get_tree().get_nodes_in_group(POKE_GROUP):
		if not is_ancestor_of(node):
			continue
		if node.get_node_or_null("TouchReact") != null:
			continue
		var reactor := TouchReact.new()
		reactor.name = "TouchReact"
		if node.has_meta("touch_react_radius"):
			reactor.trigger_radius = float(node.get_meta("touch_react_radius"))
		if node.has_meta("touch_react_sfx"):
			reactor.sfx_name = String(node.get_meta("touch_react_sfx"))
		(node as Node3D).add_child(reactor)


## Aliveness Top 12 #5 ("one AmbientCritter system, four skins"): spawns
## Critter instances from data/critters/<world_id>.json. Missing file =
## no critters for that world (same generosity-by-default convention as
## MissionRegistry) — a world with no file needs no code change here.
func _wire_critters() -> void:
	var path: String = CRITTER_DATA_PATH_FORMAT % world_id()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("WorldBase: %s did not parse to a Dictionary" % path)
		return
	var list: Variant = (parsed as Dictionary).get("critters", [])
	if not (list is Array):
		return
	for entry: Variant in (list as Array):
		if entry is Dictionary:
			_spawn_critter_group(entry as Dictionary)


func _spawn_critter_group(entry: Dictionary) -> void:
	var kind: String = String(entry.get("kind", "moth"))
	var count: int = int(entry.get("count", 0))
	var center_raw: Variant = entry.get("center", [])
	if not (center_raw is Array) or (center_raw as Array).size() < 3:
		push_warning("WorldBase: critter group '%s' has no valid 'center' — skipped" % kind)
		return
	var center_arr: Array = center_raw as Array
	var center: Vector3 = Vector3(float(center_arr[0]), float(center_arr[1]), float(center_arr[2]))
	var spread: float = float(entry.get("spread", 2.0))
	for i: int in range(count):
		var critter := Critter.new()
		critter.name = "Critter_%s_%d" % [kind, i]
		critter.kind = kind
		critter.world_id = world_id()
		var offset: Vector2 = Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		critter.position = center + Vector3(offset.x, 0.0, offset.y)
		add_child(critter)
