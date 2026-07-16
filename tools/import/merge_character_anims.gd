extends SceneTree
## merge_character_anims.gd — D19 animation merge tool.
##
## Meshy's rigging + animation endpoints (tools/meshy/rig_forge.py) produced
## one fully-skinned GLB per clip, all sharing the SAME skeleton topology
## because every per-clip call reused the same `rig_task_id` (confirmed by
## inspection: assets/models/meshy/rigged/<char>/rigged.glb and every
## anim_<name>.glb share an identical `Armature/Skeleton3D` — 24 bones, same
## names/parents — and each file's lone AnimationPlayer sits as a direct
## sibling of Armature with root_node="..", so every animation's track
## paths ("Armature/Skeleton3D:<Bone>") resolve unchanged against the base
## rig). Because the skeleton is literally identical (not just
## role-compatible), this is a straight copy of Animation resources onto a
## shared AnimationPlayer — no BoneMap/SkeletonProfileHumanoid retargeting
## needed (that machinery, per docs/research/v2/character_pipeline.md §4,
## exists for the *different-skeleton* case, e.g. pulling in Mixamo clips
## later; not exercised here).
##
## For each character: loads rigged.glb (mesh + skeleton + a throwaway
## default pseudo-clip), replaces its AnimationPlayer's default library with
## one clean-named entry per clip (idle/walk/run/fall/wave/cheer/pickup/
## sleep/dance/jump + skip|carry), sets loop flags, and saves:
##   res://scenes/players/rigs/<char>_rig.tscn   -- mesh+skeleton+AnimationPlayer
##   res://scenes/players/rigs/<char>_anim_lib.tres -- the AnimationLibrary alone
##
## Usage:
##   godot_console.exe --headless --path . --script tools/import/merge_character_anims.gd

const RIGGED_DIR: String = "res://assets/models/meshy/rigged/"
const OUT_DIR: String = "res://scenes/players/rigs/"

# name -> loop this clip (Animation.LOOP_LINEAR) vs one-shot (LOOP_NONE).
const LOOPING_CLIPS: Array[String] = ["idle", "walk", "run", "fall", "sleep", "skip", "carry"]

# Already merged on disk (scenes/players/rigs/): pip/otto v1 (provenance),
# pip_v2/otto_v2 (D24 leads, 11 clips each). Current batch: M2 dreamkeepers.
const CHARACTERS: Dictionary = {
	"lamb_keeper": ["idle", "walk", "wave", "sleep", "cheer"],
	"moth_shepherd": ["idle", "walk", "wave", "sleep", "cheer"],
}


func _init() -> void:
	var ok: bool = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for char_id: String in CHARACTERS:
		if not _merge_character(char_id, CHARACTERS[char_id]):
			ok = false
	print("MERGE_ANIMS_DONE %s" % JSON.stringify({"ok": ok}))
	quit(0 if ok else 1)


func _merge_character(char_id: String, clip_names: Array) -> bool:
	var rig_path: String = RIGGED_DIR + char_id + "/rigged.glb"
	var rig_packed: PackedScene = load(rig_path)
	if rig_packed == null:
		push_error("merge_character_anims: could not load %s" % rig_path)
		return false

	var rig: Node3D = rig_packed.instantiate() as Node3D
	if rig == null:
		push_error("merge_character_anims: %s did not instantiate as Node3D" % rig_path)
		return false

	var player: AnimationPlayer = rig.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null:
		push_error("merge_character_anims: %s has no AnimationPlayer" % rig_path)
		rig.free()
		return false

	# Drop the base rig's own throwaway default-pose pseudo-clip (a real
	# clip under every name below replaces it in the same default "" slot).
	if player.has_animation_library(""):
		player.remove_animation_library("")

	var lib := AnimationLibrary.new()
	var all_ok: bool = true
	for clip_name: String in clip_names:
		var anim: Animation = _load_clip_animation(char_id, clip_name)
		if anim == null:
			all_ok = false
			continue
		anim.loop_mode = Animation.LOOP_LINEAR if LOOPING_CLIPS.has(clip_name) else Animation.LOOP_NONE
		lib.add_animation(StringName(clip_name), anim)

	player.add_animation_library("", lib)

	var lib_out_path: String = OUT_DIR + char_id + "_anim_lib.tres"
	var lib_err: Error = ResourceSaver.save(lib, lib_out_path)
	if lib_err != OK:
		push_error("merge_character_anims: failed saving %s (%d)" % [lib_out_path, lib_err])
		all_ok = false

	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(rig)
	if pack_err != OK:
		push_error("merge_character_anims: pack() failed for %s (%d)" % [char_id, pack_err])
		rig.free()
		return false

	var scene_out_path: String = OUT_DIR + char_id + "_rig.tscn"
	var save_err: Error = ResourceSaver.save(packed, scene_out_path)
	if save_err != OK:
		push_error("merge_character_anims: failed saving %s (%d)" % [scene_out_path, save_err])
		all_ok = false

	print("MERGE_ANIMS %s" % JSON.stringify({
		"char": char_id,
		"clips": clip_names,
		"scene": scene_out_path,
		"lib": lib_out_path,
		"ok": all_ok,
	}))

	rig.free()
	return all_ok


## Loads assets/models/meshy/rigged/<char>/anim_<clip>.glb, pulls the single
## Animation out of its AnimationPlayer's default library, and returns a
## deep-duplicated copy (detached from the source scene's resources so
## freeing that temporary instance below can't dangle the copy we keep).
func _load_clip_animation(char_id: String, clip_name: String) -> Animation:
	var clip_path: String = "%s%s/anim_%s.glb" % [RIGGED_DIR, char_id, clip_name]
	var packed: PackedScene = load(clip_path)
	if packed == null:
		push_error("merge_character_anims: could not load %s" % clip_path)
		return null

	var temp: Node = packed.instantiate()
	var player: AnimationPlayer = temp.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null:
		push_error("merge_character_anims: %s has no AnimationPlayer" % clip_path)
		temp.free()
		return null

	var lib: AnimationLibrary = player.get_animation_library("") if player.has_animation_library("") else null
	if lib == null or lib.get_animation_list().is_empty():
		push_error("merge_character_anims: %s has no default-library animation" % clip_path)
		temp.free()
		return null

	# Meshy's animation endpoint is documented as one clip per file — take
	# the first (only) entry regardless of Meshy's own internal clip name
	# (e.g. "Armature|Casual_Walk|baselayer") since we rename to clip_name.
	var source_anim: Animation = lib.get_animation(lib.get_animation_list()[0])
	var anim: Animation = source_anim.duplicate(true) as Animation
	anim.resource_name = clip_name
	_neutralize_root_horizontal_motion(anim)
	temp.free()
	return anim


## Meshy's clips bake actual mocap-style translation onto the root (Hips)
## bone's position track (confirmed by inspection: every clip has a
## TYPE_POSITION_3D track on Armature/Skeleton3D:Hips). Left as-is, a walk/
## run/skip clip would visibly march the mesh away from wherever
## CharacterBody3D physics has placed the capsule -- exactly the "root
## motion fighting code-driven movement" failure mode DIRECTION_V2/D19 and
## the research doc's §6 explicitly call out as wrong for ordinary
## locomotion in this game (root motion off / in-place; CharacterBody3D
## owns velocity). Freezing the horizontal (X/Z) component of every key to
## the first key's value removes net translation while leaving Y (natural
## vertical bob/squat/hop) and the separate rotation/scale Hips tracks
## untouched, so weight-shift/bounce character survives, only the "walking
## across the floor inside its own clip" motion is removed.
func _neutralize_root_horizontal_motion(anim: Animation) -> void:
	var root_path := NodePath("Armature/Skeleton3D:Hips")
	for track_idx: int in anim.get_track_count():
		if anim.track_get_path(track_idx) != root_path:
			continue
		if anim.track_get_type(track_idx) != Animation.TYPE_POSITION_3D:
			continue
		var key_count: int = anim.track_get_key_count(track_idx)
		if key_count == 0:
			continue
		var base: Vector3 = anim.track_get_key_value(track_idx, 0)
		for key_idx: int in key_count:
			var value: Vector3 = anim.track_get_key_value(track_idx, key_idx)
			anim.track_set_key_value(track_idx, key_idx, Vector3(base.x, value.y, base.z))
