class_name ModelSlot
extends Node3D
## ModelSlot — the D10 Meshy import seam. Attach as a sibling under the same
## small "Visual" container node that holds a grey-box primitive
## (MeshInstance3D). If a matching GLB has been generated
## (assets/models/meshy/generated/<model_id>.glb, via tools/meshy/
## meshy_forge.ps1), this hides the primitive(s) and instances the GLB in
## its place, uniform-scaled to target_height and grounded so its feet/base
## sit at local y = ground_offset_y. If the GLB is missing, this is a
## silent no-op and the grey-box primitive remains fully functional — the
## game must work with zero GLBs on disk (D10 swappable-source
## requirement).

## Manifest id from tools/meshy/manifest.json, also the GLB filename stem.
@export var model_id: String = ""
## Desired world-space height (meters) after uniform scaling — the
## ART_BIBLE.md scale-rules number for this asset.
@export var target_height: float = 1.0
## Vertical offset applied after grounding the GLB's AABB bottom to 0.
## Needed when this ModelSlot's parent isn't sitting at ground level itself
## — e.g. a player's Visual node sits at the capsule's center, not its
## base, so Pip's slot sets this to -(capsule_height / 2).
@export var ground_offset_y: float = 0.0

const MODEL_DIR: String = "res://assets/models/meshy/generated/"


func _ready() -> void:
	if model_id.is_empty():
		return
	var glb_path: String = MODEL_DIR + model_id + ".glb"
	if not ResourceLoader.exists(glb_path):
		return # grey-box primitive remains — no GLB yet, this is expected
	_swap_in(glb_path)


func _swap_in(glb_path: String) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return

	var packed: PackedScene = load(glb_path)
	if packed == null:
		push_warning("ModelSlot: failed to load %s" % glb_path)
		return

	var instance: Node3D = packed.instantiate() as Node3D
	if instance == null:
		push_warning("ModelSlot: %s did not instantiate as a Node3D" % glb_path)
		return

	var aabb: AABB = _compute_local_aabb(instance)
	if aabb.size.y <= 0.0:
		push_warning("ModelSlot: %s has zero-height AABB, skipping scale/ground" % model_id)
		add_child(instance)
		return

	# Only hide the primitive(s) once we know the GLB is usable — a
	# malformed GLB should never leave the scene with nothing visible.
	_hide_sibling_primitives(parent)

	var scale_factor: float = target_height / aabb.size.y
	instance.scale = Vector3.ONE * scale_factor
	# Node3D.scale multiplies all child-local coordinates from this node's
	# own origin, so the AABB's bottom (measured before scaling, in the
	# instance's own local space) lands at aabb.position.y * scale_factor
	# once scale is applied. Shift by position so that point sits at
	# ground_offset_y instead.
	var scaled_bottom_y: float = aabb.position.y * scale_factor
	instance.position.y = ground_offset_y - scaled_bottom_y

	add_child(instance)
	print("MODEL_SWAP %s" % JSON.stringify({"id": model_id, "scaled": scale_factor}))


## Hides (does not free — cheap to toggle back for the fallback receipt)
## every sibling MeshInstance3D directly under `parent`, excluding this
## ModelSlot itself. Callers are expected to give each swappable primitive
## its own small Visual container so this never reaches across into
## unrelated geometry (verified per-caller: pip.tscn's Visual holds only
## Pip's capsule mesh; pillow_fort.gd wraps each lantern/jar/cushion
## primitive in its own anchor node before attaching a ModelSlot).
func _hide_sibling_primitives(parent: Node) -> void:
	for sibling: Node in parent.get_children():
		if sibling == self:
			continue
		if sibling is MeshInstance3D:
			(sibling as MeshInstance3D).visible = false


## Computes the AABB of every MeshInstance3D under `root` (root included),
## in root's own local coordinate space — i.e. as if root.transform were
## identity. This deliberately ignores root's own transform (rather than
## using global_transform) because root.transform is about to be
## overwritten by the scale/position this function's caller applies; the
## AABB must describe the geometry as it will appear once that happens, not
## wherever the freshly-instantiated scene root happened to start.
func _compute_local_aabb(root: Node3D) -> AABB:
	var acc: Dictionary = {"aabb": AABB(), "first": true}
	_accumulate_aabb(root, Transform3D.IDENTITY, acc, true)
	return acc["aabb"]


func _accumulate_aabb(node: Node, accumulated: Transform3D, acc: Dictionary, is_root: bool) -> void:
	var next_transform: Transform3D = accumulated
	if not is_root and node is Node3D:
		next_transform = accumulated * (node as Node3D).transform

	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			var world_aabb: AABB = next_transform * mesh.get_aabb()
			if acc["first"]:
				acc["aabb"] = world_aabb
				acc["first"] = false
			else:
				acc["aabb"] = (acc["aabb"] as AABB).merge(world_aabb)

	for child: Node in node.get_children():
		_accumulate_aabb(child, next_transform, acc, false)
