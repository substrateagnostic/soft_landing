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
	for dreamling: Dreamling in _find_dreamlings(self):
		if already_home.has(dreamling.id):
			dreamling.queue_free()
			continue
		dreamling.add_to_group(DREAMLING_GROUP)
		dreamling.collected.connect(_on_dreamling_collected)
	for id: String in already_home:
		if not _returned_ids.has(id):
			_returned_ids.append(id)


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
