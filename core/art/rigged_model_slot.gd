class_name RiggedModelSlot
extends ModelSlot
## RiggedModelSlot — D19 ModelSlot v2. Same import-seam contract as
## ModelSlot (silent no-op + primitive fallback if the asset is missing,
## hides sibling primitives once a real asset lands, grounds at
## ground_offset_y), but points at a MERGED rig scene instead of a raw
## generated GLB: `scenes/players/rigs/<model_id>_rig.tscn`, produced by
## `tools/import/merge_character_anims.gd` (mesh + Skeleton3D + one
## AnimationPlayer whose default library holds every named clip -- see that
## script's header for the full pipeline).
##
## Props/static characters keep using plain ModelSlot against
## `assets/models/meshy/generated/<id>.glb` completely unchanged -- this is
## an additive sibling, not a replacement.
##
## Height normalization does NOT reuse ModelSlot._compute_local_aabb()
## (confirmed by direct measurement, see characters-v2-VERIFY.md): that
## walk multiplies mesh.get_aabb() by every ancestor Node3D's own
## `.transform`, which is correct for a STATIC prop hierarchy but wrong for
## a SKINNED character -- the glTF importer bakes an import-time unit-scale
## onto the Armature node (observed: 0.01 on this rig), which the skinning
## pipeline already accounts for via the Skin's bind-pose-inverse matrices.
## Multiplying it in AGAIN double-counts it: measured live, this produced a
## ~100x oversized character (a life-sized Pip rendering as a ~90 m giant).
## Meshy's rigging endpoint was called with `height_meters` equal to each
## character's real target_height (tools/meshy/rig_forge.py), so the merged
## mesh's OWN local AABB (read directly off the MeshInstance3D's Mesh
## resource, no ancestor transforms applied) is already the correct
## real-world size -- scale_factor below still gets computed from it rather
## than hard-coded 1.0, so a future rig that ISN'T pre-scaled exactly still
## self-corrects the same way ModelSlot's prop path does.

## Emitted once the rig scene has been instanced, scaled, and grounded --
## `rig_root` is this slot's one child (the instanced rig scene's root
## Node3D); `anim_player` is the AnimationPlayer found inside it. Consumed
## by core/art/character_animator.gd, which may be a scene sibling ready
## either before or after this node (Godot doesn't order sibling _ready()
## calls for us) -- see has_rig()/rig_root/anim_player below for the
## "already happened" half of that race.
signal rig_ready(rig_root: Node3D, anim_player: AnimationPlayer)

const RIG_DIR: String = "res://scenes/players/rigs/"

## Public once populated (mirrors PlayerBody.state / Callie.state's own
## "public, not `_state`" convention) so a CharacterAnimator whose _ready()
## runs AFTER this node's can just read these directly instead of only
## being able to react to the signal.
var rig_root: Node3D = null
var anim_player: AnimationPlayer = null


func _ready() -> void:
	if model_id.is_empty():
		return
	var rig_path: String = RIG_DIR + model_id + "_rig.tscn"
	if not ResourceLoader.exists(rig_path):
		return # grey-box primitive remains -- no merged rig yet, this is expected
	_swap_in(rig_path)


func has_rig() -> bool:
	return anim_player != null


func _swap_in(rig_path: String) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return

	var packed: PackedScene = load(rig_path)
	if packed == null:
		push_warning("RiggedModelSlot: failed to load %s" % rig_path)
		return

	var instance: Node3D = packed.instantiate() as Node3D
	if instance == null:
		push_warning("RiggedModelSlot: %s did not instantiate as a Node3D" % rig_path)
		return

	var player: AnimationPlayer = _find_animation_player(instance)
	var mesh_instance: MeshInstance3D = _find_mesh_instance(instance)
	if player == null or mesh_instance == null or mesh_instance.mesh == null:
		push_warning("RiggedModelSlot: %s missing AnimationPlayer or skinned mesh" % rig_path)
		add_child(instance) # still show SOMETHING rather than nothing
		return

	# Mesh-local AABB only -- see header docstring for why NOT to walk
	# ancestor transforms (Armature/Skeleton3D) the way ModelSlot's prop
	# path does.
	var aabb: AABB = mesh_instance.mesh.get_aabb()
	if aabb.size.y <= 0.0:
		push_warning("RiggedModelSlot: %s has zero-height mesh AABB, skipping scale/ground" % model_id)
		add_child(instance)
		return

	_hide_sibling_primitives(parent)

	var scale_factor: float = target_height / aabb.size.y
	instance.scale = Vector3.ONE * scale_factor
	var scaled_bottom_y: float = aabb.position.y * scale_factor
	instance.position.y = ground_offset_y - scaled_bottom_y

	add_child(instance)
	if use_plush_material:
		_apply_plush_material(instance)
	print("MODEL_SWAP %s" % JSON.stringify({"id": model_id, "scaled": scale_factor, "rigged": true}))

	rig_root = instance
	anim_player = player
	rig_ready.emit(rig_root, anim_player)


const PLUSH_SHADER: Shader = preload("res://assets/shaders/plush_character.gdshader")

## Director's A/B (evidence/stills/v2_plush vs v2_swap): the plush shader
## currently reads MUDDIER than the imported StandardMaterial at gameplay
## distance — kept opt-in (off) until the shader earns the swap. Texture
## plumbing below already works, so re-testing later is a one-flag flip.
@export var use_plush_material: bool = false


## D22 plush pass (director integration): every skinned mesh gets the
## fresnel-rim + wrap-SSS shader, carrying its own painted texture through
## the shader's albedo_texture slot so faces survive the material swap.
func _apply_plush_material(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi: MeshInstance3D = node
			if mi.mesh != null:
				for surface: int in range(mi.mesh.get_surface_count()):
					var std: StandardMaterial3D = mi.mesh.surface_get_material(surface) as StandardMaterial3D
					var plush := ShaderMaterial.new()
					plush.shader = PLUSH_SHADER
					if std != null and std.albedo_texture != null:
						plush.set_shader_parameter("albedo_texture", std.albedo_texture)
					if std != null:
						plush.set_shader_parameter("albedo_color", std.albedo_color)
					mi.set_surface_override_material(surface, plush)
		for child: Node in node.get_children():
			stack.append(child)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found: MeshInstance3D = _find_mesh_instance(child)
		if found != null:
			return found
	return null
