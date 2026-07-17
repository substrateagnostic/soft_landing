class_name StretchSequence
extends Node3D
## StretchSequence — Marmalade's one-time transformative body-function: THE
## STRETCH (ROADMAP.md M3: "at 10/10 dreams, Marmalade does one enormous slow
## cat-stretch in her sleep ... and the rooftops shift like plates —
## opening a NEW rooftop route"). Mirrors worlds/bramble/rollover_sequence.gd's
## proven architecture (world_completed trigger + force flag, letterboxed
## cine camera, bubble-lift safety, persistence) — DUPLICATED rather than
## referenced (bramble.gd/rollover_sequence.gd are read-only territory
## tonight; worlds/marmalade/purr_thermal.gd already set the "copy, don't
## import, across world territories" precedent for the same reason).
##
## Trigger: GameState.world_completed("marmalade") — WorldBase already fires
## this the moment all 10 dreamlings return (worlds/common/world_base.gd
## _check_completion), and GameState persists dreamlings[world_id].completed,
## so "once per save" falls straight out of that existing signal exactly the
## way it does for bramble's rollover (see that file's header for the full
## reasoning — identical here, not re-derived).
##
## --stretch (Harness.flags) force-arms the sequence ~3s after load
## regardless of dream count, dev/capture only (STRETCH {"forced":true}) —
## bypasses the completion gate on purpose, confined to the forced dev path.
##
## Safety: every connected player is bubble-lifted (core/rescue/
## bubble_effect.gd — same shared rescue/warp visual vocabulary, never a
## bespoke lift) to the village square BEFORE anything moves. The four
## rooftop plates that relocate (RoofB0-3, worlds/marmalade/marmalade.gd
## _build_rooftop_chain()) are plain StaticBody3D, not AnimatableBody3D —
## nothing carries a rider through the tween, so nobody may still be
## standing on one when it moves. Ground for the new nook goes solid FIRST,
## before any camera/tween work, matching the exact lesson bramble's
## rollover_sequence.gd already learned live (see that file's header): never
## gate new ground behind the full animation length.
##
## The plush cat is a STATIC mesh (M3 brief: quadruped — Meshy can't rig;
## static sculpt + a procedural stretch keystone), so "the stretch" is pure
## Node3D transform choreography on marmalade.gd's CatGiantAnchor — rise
## (lift + pitch), arch (scale-y up ~8%, x/z squash ~4%), hold, resettle,
## ~8s total per the brief — sold by the camera (a slow drift along her body,
## then a push to the newly-opened route/nook) rather than any limb
## animation.

signal stretch_started
signal stretch_finished

## Public (mirrors core/art/rigged_model_slot.gd's rig_root/anim_player
## convention: state a sibling can just read, not only react to a signal for)
## — marmalade.gd's own ambient-breathing _process() checks this so the two
## animations never fight over CatGiantAnchor.scale at the same time.
var playing: bool = false

const BUBBLE_SCENE: PackedScene = preload("res://core/rescue/bubble_effect.tscn")

# --- Cinematic camera (letterboxed wide -> drift along her body -> push to
# the newly-open route -> push to the nook) --------------------------------
const CINE_WIDE_POS: Vector3 = Vector3(-60.0, 14.0, 26.0)
const CINE_WIDE_LOOK: Vector3 = Vector3(-20.0, 6.0, 0.0)
const CINE_DRIFT_POS: Vector3 = Vector3(-5.0, 16.0, 22.0)
const CINE_DRIFT_LOOK: Vector3 = Vector3(10.0, 10.0, 6.0)
const CINE_ROUTE_POS: Vector3 = Vector3(26.0, 22.0, 24.0)
const CINE_ROUTE_LOOK: Vector3 = Vector3(28.0, 16.0, 9.0)
const CINE_NOOK_POS: Vector3 = Vector3(38.0, 24.0, 20.0)
const CINE_NOOK_LOOK: Vector3 = Vector3(31.0, 19.6, 13.0)
const CINE_DRIFT_TIME: float = 4.0
const CINE_ROUTE_TIME: float = 4.0
const CINE_NOOK_TIME: float = 3.0
const CINE_TAIL: float = 3.0 # seconds holding on the nook before letterbox out
const LETTERBOX_FRACTION: float = 0.085 # matches rollover_sequence.gd's tuned value (0.11 clipped the Moon's subtitle)
const LETTERBOX_FADE: float = 0.6

# --- The stretch choreography (~8s total, per the brief) -------------------
const RISE_TIME: float = 2.0
const RISE_LIFT: float = 0.6
const RISE_PITCH_DEGREES: float = -8.0
const ARCH_TIME: float = 3.0
const ARCH_SCALE_Y: float = 1.08 # +8%
const ARCH_SQUASH_XZ: float = 0.96 # -4%, "slight x/z squash" per the brief
const HOLD_TIME: float = 1.0
const RESETTLE_TIME: float = 2.0
# RISE_TIME + ARCH_TIME + HOLD_TIME + RESETTLE_TIME == 8.0s, matching the brief.

const FORCED_DELAY: float = 3.0
const BUBBLE_DURATION: float = 3.0
const BUBBLE_LANDING_SPACING: float = 1.4 # two players never land on the exact same point
const BUBBLE_LANDING: Vector3 = Vector3(-60.0, 0.6, 4.0) # village square — clear of every HOUSE_LAYOUT entry (nearest is >5m away)

# --- The new rooftop route: RoofB0-3 relocate; a fifth hop opens the nook --
# Step vector climbs away from SHELF_POSITION (18,9.6,3, marmalade.gd) — the
# card's own "convergence point," already the spot every player naturally
# reaches via tail-bridge OR flank-steps — up past the ridge/garden mounds
# (checked clear: at the farthest step, x=28.4, the ridge mound's own surface
# (RIDGE_CENTER (26,-3,0) r14) tops out at y=11, well under the new plates'
# y=17.6 there). Horizontal gap per hop = sqrt(2.6^2+2.0^2) = 3.28m, under
# the 3.5m stick+jump floor law.
const CHAIN_ORIGIN: Vector3 = Vector3(18.0, 9.6, 3.0) # marmalade.gd SHELF_POSITION
const CHAIN_STEP: Vector3 = Vector3(2.6, 2.0, 2.0)
const PLATE_NAMES: Array[String] = ["RoofB0", "RoofB1", "RoofB2", "RoofB3"]
const PLATE_SHIFT_TIME: float = 6.0

const NOOK_TOP: Vector3 = Vector3(31.0, 19.6, 13.0) # CHAIN_ORIGIN + CHAIN_STEP*5 — the 5th hop
const NOOK_SIZE: Vector2 = Vector2(4.5, 4.5)
const NOOK_THICKNESS: float = 0.6
const COLOR_NOOK: Color = Color("B4654A") # terracotta — matches marmalade.gd COLOR_ROOF

var _world: Node3D = null
var _cat_anchor: Node3D = null

var _plate_visuals: Array[MeshInstance3D] = []
var _plate_shapes: Array[CollisionShape3D] = []
var _plate_targets: Array[Vector3] = []

var _nook_root: Node3D = null
var _nook_shape: CollisionShape3D = null
var _route_hint_shape: CollisionShape3D = null
var _nook_hint_shape: CollisionShape3D = null

var _cat_rest_position: Vector3 = Vector3.ZERO
var _played: bool = false


## setup — called by marmalade.gd BEFORE add_child (see that file's own
## _build_stretch() comment for why: entering the tree fires _ready()
## synchronously, so a reversed order would run _ready() with _world/
## _cat_anchor still unset).
func setup(world: Node3D, cat_anchor: Node3D) -> void:
	_world = world
	_cat_anchor = cat_anchor


func _ready() -> void:
	_cat_rest_position = _cat_anchor.position
	_index_plates()
	_compute_plate_targets()
	_build_nook_geometry() # built once, hidden+disabled — reveal is a visibility/collision flip, never a rebuild

	if GameState.is_world_completed("marmalade"):
		_apply_already_open_state()
		return

	GameState.world_completed.connect(_on_world_completed)
	if Harness.flag("stretch", false):
		var timer: SceneTreeTimer = get_tree().create_timer(FORCED_DELAY)
		timer.timeout.connect(_on_forced_trigger)


func _on_world_completed(world_id: String) -> void:
	if world_id != "marmalade" or _played:
		return
	_play_sequence(false)


func _on_forced_trigger() -> void:
	if _played:
		return
	_play_sequence(true)


func _index_plates() -> void:
	for plate_name: String in PLATE_NAMES:
		var visual: MeshInstance3D = _world.get_node_or_null(plate_name) as MeshInstance3D
		var body: StaticBody3D = _world.get_node_or_null(plate_name + "Body") as StaticBody3D
		var shape: CollisionShape3D = _find_collision_shape(body)
		if visual == null or shape == null:
			push_warning("StretchSequence: plate '%s' not found or missing its collision shape — skipped" % plate_name)
		_plate_visuals.append(visual)
		_plate_shapes.append(shape)


## marmalade.gd's own platform helpers (_add_box_platform etc.) never set an
## explicit `.name` on the CollisionShape3D child, and add_child()'s
## `force_readable_name` parameter defaults to false — Godot assigns an
## internal auto-generated name (e.g. "@CollisionShape3D@123") to any
## unnamed node rather than the literal class-name string "CollisionShape3D"
## (caught live: a name-based get_node_or_null("CollisionShape3D") lookup
## silently failed for every plate). Find it by TYPE instead, matching this
## codebase's other type-walk helpers (e.g. bramble.gd's _find_first_mesh).
func _find_collision_shape(body: StaticBody3D) -> CollisionShape3D:
	if body == null:
		return null
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null


func _compute_plate_targets() -> void:
	for i: int in range(PLATE_NAMES.size()):
		_plate_targets.append(CHAIN_ORIGIN + CHAIN_STEP * float(i + 1))


func _play_sequence(forced: bool) -> void:
	_played = true
	playing = true
	print("STRETCH %s" % JSON.stringify({"phase": "start", "forced": forced}))
	stretch_started.emit()
	AudioManager.play_sfx("bear_rollover_rumble") # placeholder reuse until a dedicated purr/stretch SFX exists — fails soft (AudioManager convention)
	TheMoon.say("world_complete")

	_reveal_nook_ground()
	_cine_begin()
	_bubble_all_players()

	await _tween_stretch_and_plates()

	print("STRETCH %s" % JSON.stringify({"phase": "route_open"}))
	_cine_route_push()
	var route_tail: SceneTreeTimer = get_tree().create_timer(CINE_ROUTE_TIME)
	await route_tail.timeout

	_cine_nook_push()
	var nook_tail: SceneTreeTimer = get_tree().create_timer(CINE_NOOK_TIME + CINE_TAIL)
	await nook_tail.timeout

	_cine_end()
	playing = false
	print("STRETCH %s" % JSON.stringify({"phase": "end", "forced": forced}))
	stretch_finished.emit()


## Plates shift in the background (PLATE_SHIFT_TIME=6s, fire-and-forget —
## nothing downstream needs to await it specifically); the cat's own
## choreography (8s) is the one this function actually awaits, since it is
## always the longer of the two.
func _tween_stretch_and_plates() -> void:
	_tween_plates()
	await _tween_cat()


func _tween_plates() -> void:
	print("STRETCH %s" % JSON.stringify({"phase": "plates_shifting"}))
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	for i: int in range(_plate_visuals.size()):
		var visual: MeshInstance3D = _plate_visuals[i]
		var shape: CollisionShape3D = _plate_shapes[i]
		var target: Vector3 = _plate_targets[i]
		if visual != null:
			tween.tween_property(visual, "position", target, PLATE_SHIFT_TIME)
		if shape != null:
			tween.tween_property(shape, "position", target, PLATE_SHIFT_TIME)
	tween.chain().tween_callback(func() -> void:
		print("STRETCH %s" % JSON.stringify({"phase": "plates_shifted"}))
	)


func _tween_cat() -> void:
	var rest_pos: Vector3 = _cat_rest_position
	var rest_scale: Vector3 = Vector3.ONE
	var rest_pitch: float = _cat_anchor.rotation_degrees.x

	# Rise: lift + pitch, easing up out of sleep.
	var rise: Tween = create_tween()
	rise.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.set_parallel(true)
	rise.tween_property(_cat_anchor, "position:y", rest_pos.y + RISE_LIFT, RISE_TIME)
	rise.tween_property(_cat_anchor, "rotation_degrees:x", rest_pitch + RISE_PITCH_DEGREES, RISE_TIME)
	await rise.finished

	# Arch: the sssstretch — scale up tall, squash narrow.
	print("STRETCH %s" % JSON.stringify({"phase": "arch"}))
	var arch: Tween = create_tween()
	arch.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arch.tween_property(_cat_anchor, "scale", Vector3(ARCH_SQUASH_XZ, ARCH_SCALE_Y, ARCH_SQUASH_XZ), ARCH_TIME)
	await arch.finished

	var hold: SceneTreeTimer = get_tree().create_timer(HOLD_TIME)
	await hold.timeout

	# Resettle: back to sleep — exact rest-transform constants (never a
	# reversed tween), so no float drift accumulates across a session with
	# --stretch fired more than once in dev/capture.
	print("STRETCH %s" % JSON.stringify({"phase": "resettle"}))
	var settle: Tween = create_tween()
	settle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	settle.set_parallel(true)
	settle.tween_property(_cat_anchor, "position:y", rest_pos.y, RESETTLE_TIME)
	settle.tween_property(_cat_anchor, "rotation_degrees:x", rest_pitch, RESETTLE_TIME)
	settle.tween_property(_cat_anchor, "scale", rest_scale, RESETTLE_TIME)
	await settle.finished


## Reuses the exact rescue/warp visual vocabulary (core/rescue/bubble_effect.gd)
## rather than any bespoke lift. Unconditional (every connected player,
## wherever they stand) — nothing can ever be disturbed out from under
## someone if no one is ever left standing on the relocating plates in the
## first place. Landing at the village square (BUBBLE_LANDING) — proven-safe
## open ground, clear of every house.
func _bubble_all_players() -> void:
	var offset: float = 0.0
	for player: Node in get_tree().get_nodes_in_group("players"):
		if not (player is PlayerBody):
			continue
		var bubble: BubbleEffect = BUBBLE_SCENE.instantiate()
		get_tree().current_scene.add_child(bubble)
		var landing: Vector3 = BUBBLE_LANDING + Vector3(offset, 0.0, 0.0)
		offset += BUBBLE_LANDING_SPACING
		bubble.play(player as PlayerBody, landing, "bubble_catch", BUBBLE_DURATION)


func _apply_already_open_state() -> void:
	for i: int in range(_plate_visuals.size()):
		if _plate_visuals[i] != null:
			_plate_visuals[i].position = _plate_targets[i]
		if _plate_shapes[i] != null:
			_plate_shapes[i].position = _plate_targets[i]
	_reveal_nook_ground()
	# The STRETCH itself doesn't persist (she resettles to sleep every time) —
	# only the permanent world-geometry change (plates + nook) does, matching
	# bramble's rollover: "the world remembers" the transformation, not the
	# animation that caused it.
	_cat_anchor.position = _cat_rest_position
	_cat_anchor.rotation_degrees.x = 0.0
	_cat_anchor.scale = Vector3.ONE


func _reveal_nook_ground() -> void:
	_nook_root.visible = true
	if _nook_shape != null:
		_nook_shape.disabled = false
	if _route_hint_shape != null:
		_route_hint_shape.disabled = false
	if _nook_hint_shape != null:
		_nook_hint_shape.disabled = false
	print("STRETCH %s" % JSON.stringify({"phase": "nook_revealed"}))


# ---------------------------------------------------------------------------
# Geometry — built once at _ready (hidden/disabled), revealed by flipping
# visibility + collision, matching bramble's FarMeadow "toggle, never
# rebuild" convention.
# ---------------------------------------------------------------------------

func _build_nook_geometry() -> void:
	_nook_root = Node3D.new()
	_nook_root.name = "AtticNook"
	_nook_root.visible = false
	_world.add_child(_nook_root)

	# Ledge convention (bramble.gd _add_ascent_ledge): TOP surface sits
	# exactly at NOOK_TOP.y.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(NOOK_SIZE.x, NOOK_THICKNESS, NOOK_SIZE.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_NOOK
	mesh.material = mat
	var center: Vector3 = Vector3(NOOK_TOP.x, NOOK_TOP.y - NOOK_THICKNESS * 0.5, NOOK_TOP.z)

	var visual := MeshInstance3D.new()
	visual.name = "AtticNookPlatform"
	visual.mesh = mesh
	visual.position = center
	_nook_root.add_child(visual)

	var body := StaticBody3D.new()
	body.name = "AtticNookPlatformBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	shape.position = center
	shape.disabled = true # flipped by _reveal_nook_ground()
	body.add_child(shape)
	_nook_root.add_child(body)
	_nook_shape = shape

	_add_nook_props()
	_add_route_hint()
	_add_nook_hint()


## "cozy platform: lantern + cushion + 1-2 props from the Meshy set" — all
## three already exist on disk (tools/meshy/manifest.json target_height_hint:
## lantern 0.5, cushion 0.4, moth_small 0.25), so no new Meshy generation is
## needed for this deliverable.
func _add_nook_props() -> void:
	_add_meshy_prop("NookLantern", "lantern", 0.5, NOOK_TOP + Vector3(-1.2, 0.0, -1.0))
	_add_meshy_prop("NookCushion", "cushion", 0.4, NOOK_TOP + Vector3(0.6, 0.0, 0.8))
	_add_meshy_prop("NookMoth", "moth_small", 0.25, NOOK_TOP + Vector3(1.3, 0.0, -1.1))


func _add_meshy_prop(prop_name: String, model_id: String, height: float, top_position: Vector3) -> void:
	var anchor := Node3D.new()
	anchor.name = prop_name
	anchor.position = top_position
	_nook_root.add_child(anchor)
	var slot := ModelSlot.new()
	slot.name = "ModelSlot"
	slot.model_id = model_id
	slot.target_height = height
	anchor.add_child(slot)


## CameraHint yaw convention: 0 deg = default -Z forward; -90 deg = +X;
## +90 deg = -X (marmalade.gd's own _build_camera_hints() note). The chain
## climbs along a +X/+Z diagonal, so a yaw between -45 and -90 frames it;
## -60 looks along that diagonal toward the nook.
func _add_route_hint() -> void:
	var mid: Vector3 = (CHAIN_ORIGIN + NOOK_TOP) * 0.5
	var hint := CameraHint.new()
	hint.name = "StretchRouteHint"
	hint.priority = 5
	hint.yaw_degrees = -60.0
	hint.blend_time = 0.9
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 14.0, 16.0)
	shape.shape = box
	shape.position = mid
	shape.disabled = true # flipped by _reveal_nook_ground()
	hint.add_child(shape)
	_nook_root.add_child(hint)
	_route_hint_shape = shape


func _add_nook_hint() -> void:
	var hint := CameraHint.new()
	hint.name = "StretchNookHint"
	hint.priority = 6
	hint.yaw_degrees = -60.0
	hint.blend_time = 0.9
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 10.0, 10.0)
	shape.shape = box
	shape.position = NOOK_TOP + Vector3(0.0, 2.0, 0.0)
	shape.disabled = true
	hint.add_child(shape)
	_nook_root.add_child(hint)
	_nook_hint_shape = shape


# --- Cinematic camera --------------------------------------------------------

var _cine_cam: Camera3D = null
var _cine_look: Vector3 = Vector3.ZERO
var _prev_cam: Camera3D = null
var _letterbox: CanvasLayer = null
var _bar_top: ColorRect = null
var _bar_bottom: ColorRect = null


func _cine_begin() -> void:
	_prev_cam = get_viewport().get_camera_3d()
	if _cine_cam == null:
		_cine_cam = Camera3D.new()
		_cine_cam.name = "StretchCineCamera"
		_world.add_child(_cine_cam)
	_cine_cam.position = CINE_WIDE_POS
	_cine_look = CINE_WIDE_LOOK
	_cine_cam.look_at_from_position(CINE_WIDE_POS, CINE_WIDE_LOOK, Vector3.UP)
	_cine_cam.current = true
	_show_letterbox(true)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	tween.tween_property(_cine_cam, "position", CINE_DRIFT_POS, CINE_DRIFT_TIME)
	tween.tween_property(self, "_cine_look", CINE_DRIFT_LOOK, CINE_DRIFT_TIME)


func _cine_route_push() -> void:
	if _cine_cam == null:
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	tween.tween_property(_cine_cam, "position", CINE_ROUTE_POS, CINE_ROUTE_TIME)
	tween.tween_property(self, "_cine_look", CINE_ROUTE_LOOK, CINE_ROUTE_TIME)


func _cine_nook_push() -> void:
	if _cine_cam == null:
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	tween.tween_property(_cine_cam, "position", CINE_NOOK_POS, CINE_NOOK_TIME)
	tween.tween_property(self, "_cine_look", CINE_NOOK_LOOK, CINE_NOOK_TIME)


func _cine_end() -> void:
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	_show_letterbox(false)


func _process(_delta: float) -> void:
	if _cine_cam != null and _cine_cam.current:
		_cine_cam.look_at(_cine_look, Vector3.UP)


func _show_letterbox(shown: bool) -> void:
	if _letterbox == null:
		_letterbox = CanvasLayer.new()
		_letterbox.name = "StretchLetterbox"
		_letterbox.layer = 90
		_world.add_child(_letterbox)
		_bar_top = _make_bar(true)
		_bar_bottom = _make_bar(false)
	var bar_height: float = get_viewport().get_visible_rect().size.y * LETTERBOX_FRACTION
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bar_top, "offset_bottom", bar_height if shown else 0.0, LETTERBOX_FADE)
	tween.tween_property(_bar_bottom, "offset_top", -bar_height if shown else 0.0, LETTERBOX_FADE)


func _make_bar(top: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color(0.05, 0.06, 0.12) # near-black dusk, not pure black
	if top:
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0
		bar.anchor_bottom = 0.0
		bar.offset_bottom = 0.0
	else:
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_top = 0.0
	_letterbox.add_child(bar)
	return bar
