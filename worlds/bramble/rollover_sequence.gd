class_name RolloverSequence
extends Node3D
## RolloverSequence — Bramble's one-time transformative body-function: THE
## ROLL-OVER (docs/research/v2/aliveness_wow.md §3, Top 12 #1: "her paw
## curls open... she rolls over in her sleep... turning what was a wall of
## tall grass into new walkable ground"; DIRECTION_V2.md Pillar 1: "once
## per world the giant MOVES and the level transforms while you're on it —
## gently, hugely, safely").
##
## Trigger: GameState.world_completed("bramble") -- WorldBase already fires
## this the moment all 10 dreamlings return (worlds/common/world_base.gd
## _check_completion), and GameState persists dreamlings[world_id].completed
## (SaveManager mirrors GameState.dreamlings verbatim), so "once per save"
## falls straight out of that existing signal: it only fires the FIRST time
## this world instance crosses 10/10 in a session, and a fresh visit after
## a save that already completed it never re-fires (no dreamling is left to
## return). On a revisit after a PRIOR session already completed the world,
## GameState.is_world_completed("bramble") is already true at _ready() --
## the far meadow is built straight into its FINAL resting state with no
## rumble/Moon-line/animation, matching SPEC.md D14 ("the world remembers").
##
## --rollover (Harness.flags) force-arms the sequence ~3s after load
## regardless of dream count, dev/capture only (ROLLOVER {"forced":true}) --
## this bypasses the completion gate on purpose, so a forced capture run may
## still show uncollected dreamlings on the haunch after it settles; that is
## expected and confined to the forced dev path (see
## docs/verify/bramble-setpieces-VERIFY.md).
##
## Safety: EVERY connected player is bubble-lifted (core/rescue/
## bubble_effect.tscn -- the same rescue/warp visual vocabulary; "reuse the
## pattern... a dreamling-bubble visual flourish", never a custom rescue)
## off the bear and onto the far meadow BEFORE anything moves, so nothing a
## player is standing on is ever disturbed under them. Only the haunch
## mound (its visual + its own StaticBody3D collision) settles a short,
## gentle distance -- the chest (BreathingChest, already its own moving
## platform), the shoulder shelf (d08's former perch), and the whole
## head/ear/geysers (d07's SnoreGeyser parent, the DreamDoor return point
## every future visit depends on) are never touched, per the brief's "NOT
## collision underneath existing dreamling placements... keep d07's geyser
## parent stable."

signal rollover_started
signal rollover_finished

const BUBBLE_SCENE: PackedScene = preload("res://core/rescue/bubble_effect.tscn")

# --- Cinematic camera (producer note 2026-07-16: "didn't see something
# that clearly read as the bear rolling over" — the gameplay camera never
# frames the whole giant, so the roll read as a slab shifting. The
# sequence now takes the lens: letterboxed wide shot of the full bear,
# slow dolly through the settle, then a push to the far-meadow reveal).
# Machinery (letterbox + cine-camera create/tween/restore) lives in
# core/cinematic/cine_sequence.gd (M4 card, generalized out of this file —
# see _cine's doc comment below); only this world's own waypoints stay
# here. --
const CINE_WIDE_POS: Vector3 = Vector3(9.0, 40.0, 88.0)
const CINE_WIDE_LOOK: Vector3 = Vector3(9.0, 6.0, 0.0)
const CINE_DOLLY_POS: Vector3 = Vector3(28.0, 34.0, 76.0)
const CINE_MEADOW_POS: Vector3 = Vector3(-20.0, 24.0, -16.0)
const CINE_MEADOW_LOOK: Vector3 = Vector3(-20.0, 1.0, -52.0)
const CINE_TAIL: float = 3.0 # seconds on the meadow after the settle
const CINE_DOLLY_TIME: float = 16.0 # slow creep spanning the keystone clips
const CINE_BEAR_LOOK: Vector3 = Vector3(46.0, 8.0, 28.0) # drift toward HIM

# Optional visual shell: if the world has a node named "BearShellAnchor"
# (the Meshy giant-bear model), the sequence rolls IT — the readable bear —
# in sync with the haunch mound underneath.
const SHELL_ROLL_DEGREES: float = -26.0
const SHELL_SETTLE_SINK: float = 0.8

# --- Haunch settle (the one moving body part) -------------------------------
const HAUNCH_SETTLE_OFFSET: Vector3 = Vector3(0.0, -1.0, 4.0) # sinks 1m, shifts toward the far meadow
const HAUNCH_SETTLE_YAW_DEGREES: float = 35.0 # the mound is a sphere -- spinning it is invisible on its own
# (perfectly symmetric), but the brief's language is "rotates/settles"; the
# settle (translation) above is what actually reads, and the spin costs
# nothing extra while keeping "rotates" literally true too.
const ROTATE_DURATION: float = 8.0 # brief: "over ~8 seconds"
const FORCED_DELAY: float = 3.0
const BUBBLE_DURATION: float = 4.0 # slower/more majestic than the rescue default (2.5s) -- "gently, hugely"
const BUBBLE_LANDING_SPACING: float = 1.4 # two players never land on the exact same point

# --- Far meadow (new ground beyond the existing meadow's z=-40 edge) -------
const COLOR_MEADOW: Color = Color("7C9082")
const COLOR_MOSS: Color = Color("8C9463")
const COLOR_FUR_DARK: Color = Color("6E4F3E")
const COLOR_LANTERN: Color = Color("F2C879")
const COLOR_ROSE: Color = Color("D9A5B3")
const COLOR_MILK: Color = Color("F5F2E8")

# South of the existing meadow's z=-40 edge, staying within the moat
# backdrop's z=-65 bound (worlds/bramble/bramble.gd MOAT_SIZE) so the new
# ground never pokes past the world's existing void-backdrop layer.
const FAR_MEADOW_CENTER: Vector2 = Vector2(-20.0, -51.5) # (x, z)
const FAR_MEADOW_SIZE: Vector2 = Vector2(50.0, 23.0) # x: -45..5, z: -40..-63
const BRIDGE_CENTER: Vector2 = Vector2(-20.0, -40.0) # the seam -- a low fur ridge, never a gate/barrier
const BRIDGE_SIZE: Vector2 = Vector2(30.0, 4.0)
const FAR_MEADOW_LANDING: Vector3 = Vector3(-20.0, 0.6, -52.0)
const FLOWER_RNG_SEED: int = 7 # deterministic decorative jitter -- GrassField's own convention (core/env/grass_field.gd), never the shared global RNG stream

var _world: Node3D = null
var _haunch_visual: MeshInstance3D = null
var _haunch_body: StaticBody3D = null
var _haunch_rest_position: Vector3 = Vector3.ZERO
var _haunch_body_rest_position: Vector3 = Vector3.ZERO

var _far_meadow_root: Node3D = null
var _played: bool = false

## core/cinematic/cine_sequence.gd (M4 card, generalized out of this file --
## see that class's own header) -- owns the letterbox + cine-camera
## machinery; this file only supplies waypoints (CINE_* consts above) via
## begin()/dolly_to()/push_to()/end().
var _cine: CineSequence = null


func setup(world: Node3D, haunch_visual: MeshInstance3D, haunch_body: StaticBody3D) -> void:
	_world = world
	_haunch_visual = haunch_visual
	_haunch_body = haunch_body


func _ready() -> void:
	_haunch_rest_position = _haunch_visual.position
	_haunch_body_rest_position = _haunch_body.position
	_cine = CineSequence.new()
	_cine.name = "RolloverCine"
	add_child(_cine)
	_cine.setup(_world, "RolloverCineCamera", "RolloverLetterbox")
	_build_far_meadow_geometry() # built once, hidden+disabled -- reveal is a visibility/collision flip, never a rebuild

	if GameState.is_world_completed("bramble"):
		_apply_already_open_state()
		return

	GameState.world_completed.connect(_on_world_completed)
	if Harness.flag("rollover", false):
		var timer: SceneTreeTimer = get_tree().create_timer(FORCED_DELAY)
		timer.timeout.connect(_on_forced_trigger)


func _on_world_completed(world_id: String) -> void:
	if world_id != "bramble" or _played:
		return
	_play_sequence(false)


func _on_forced_trigger() -> void:
	if _played:
		return
	_play_sequence(true)


func _play_sequence(forced: bool) -> void:
	_played = true
	print("ROLLOVER %s" % JSON.stringify({"phase": "start", "forced": forced}))
	rollover_started.emit()
	AudioManager.play_sfx_overlay("giant_rumble") # audio pass 3: the ground remembering it's alive -- overlay so bubble_catch/gust_breath (fired moments later, same frame) don't cut it off
	TheMoon.say("world_complete")

	# Ground goes solid FIRST, immediately -- caught live (see
	# docs/verify/bramble-setpieces-VERIFY.md): gating the far meadow's
	# collision behind the full ROTATE_DURATION wait left a window where
	# BUBBLE_DURATION's shorter flight already set players down onto still-
	# disabled collision, and they fell through into a generic RESCUE
	# instead of landing on the new ground. "Never let the floor vanish
	# beneath anyone without the catch" cuts both ways -- the floor must
	# also never be MISSING beneath where the catch sets them down. The
	# haunch settle (the only thing actually moving) still plays out over
	# the full ROTATE_DURATION in parallel underneath the already-solid
	# far meadow.
	_reveal_far_meadow()
	_cine.begin(CINE_WIDE_POS, CINE_WIDE_LOOK)
	_cine.dolly_to(CINE_DOLLY_POS, CINE_BEAR_LOOK, CINE_DOLLY_TIME, CINE_DOLLY_TIME * 0.6)
	_bubble_all_players()
	_tween_haunch_settle()

	# D25 THE REVEAL: at sequence start, right after the letterbox comes in —
	# his breath-gust blows the disguise clouds away. mountain_dressing's own
	# reveal() is NOT called here (see _play_keystone()/the fallback branch
	# below): its debris-fall portion is timed to land during the "wake"
	# clip specifically, per the brief.
	_trigger_breath_gust()

	# The keystone (producer direction): the giant stirs, sits up, takes
	# one enormous breath, tosses-and-turns, and settles back to sleep —
	# played by the rigged bear if present, rigid-roll fallback otherwise.
	var keystone: AnimationPlayer = _find_shell_anim_player()
	if keystone != null:
		await _play_keystone(keystone)
	else:
		# No rig clip to time against — trigger the mountain reveal here,
		# alongside the rigid-roll fallback, instead of mid-clip.
		_trigger_dressing_reveal()
		_ascent_tumble_out() # D27: same excursion, timed against the rigid roll
		_tween_shell_roll()
		var timer: SceneTreeTimer = get_tree().create_timer(ROTATE_DURATION * 0.65)
		await timer.timeout
		_ascent_settle_back()
		var settle_timer: SceneTreeTimer = get_tree().create_timer(ROTATE_DURATION * 0.35)
		await settle_timer.timeout

	_cine.push_to(CINE_MEADOW_POS, CINE_MEADOW_LOOK, CINE_TAIL * 0.8)
	var tail: SceneTreeTimer = get_tree().create_timer(CINE_TAIL)
	await tail.timeout
	_cine.end()

	print("ROLLOVER %s" % JSON.stringify({"phase": "end", "forced": forced}))
	rollover_finished.emit()


const KEYSTONE_CLIPS: Array[String] = ["wake", "breathe", "toss_turn"]
const KEYSTONE_CLIP_CAP: float = 8.0 # per-clip safety net; never hang the sequence

# D27 — the ascent rides the mountain (producer's race video showed the
# trail's grey ledge stack piercing the bear's torso as he sat up). The
# trail IS part of the mountain resting on him: when he rises it tumbles
# outward and down off his flank (staggered, tilting), and when he flops
# back to sleep it settles home with a soft overshoot — dream physics, the
# path lands with him. VISUALS ONLY: every ramp/ledge keeps its separate
# StaticBody3D exactly where collision has always been (players are
# bubble-lifted for the whole cine, and the path must be back in place,
# collision never having moved, when control returns).
const ASCENT_TUMBLE_PREFIXES: Array[String] = ["AscentRamp", "AscentLedge", "SummitPlatform"]
const ASCENT_TUMBLE_OUT_TIME: float = 1.6
const ASCENT_SETTLE_TIME: float = 1.4
const ASCENT_TUMBLE_DROP: float = 3.2
const ASCENT_TUMBLE_OUTWARD: float = 4.5
const ASCENT_TUMBLE_TILT_DEG: float = 24.0
const ASCENT_STAGGER: float = 0.07

var _ascent_visuals: Array[Node3D] = []
var _ascent_rest: Array[Transform3D] = []


func _find_shell_anim_player() -> AnimationPlayer:
	var shell: Node3D = _world.get_node_or_null("BearShellAnchor") as Node3D
	if shell == null:
		return null
	var rig: Node = shell.get_node_or_null("BearRig")
	if rig == null:
		return null
	for child: Node in rig.get_children():
		if child is AnimationPlayer:
			return child
	return null


## D25 THE REVEAL: fires breath_weather.force_gust() (D25's public API,
## worlds/bramble/breath_weather.gd) via duck-typed Object.call() rather than
## a static `as BreathWeather` cast — camera_rig.gd's own class member
## resolution note (a node fetched at runtime and cast to an externally
## class_name'd type fails to resolve members under --headless in Godot
## 4.6.2) applies just the same here, so this sidesteps it the same way.
## Fails soft if BreathWeather isn't present (dev/test scenes, older saves).
func _trigger_breath_gust() -> void:
	var weather: Node = _world.get_node_or_null("BreathWeather")
	if weather != null and weather.has_method("force_gust"):
		weather.call("force_gust")


## D25 THE REVEAL: mountain_dressing.gd's reveal() — clouds blow away, then
## debris falls, staggered ~2.5s. Same duck-typed call() as _trigger_breath_
## gust() above, same reason. Idempotent (MountainDressing guards _revealed
## itself) so it is safe to call from either the keystone or fallback path,
## never both in the same run.
func _trigger_dressing_reveal() -> void:
	var dressing: Node = _world.get_node_or_null("MountainDressing")
	if dressing != null and dressing.has_method("reveal"):
		dressing.call("reveal")
		AudioManager.play_sfx_overlay("debris_soft_tumble") # audio pass 3: the mountain dressing falling away -- overlay so it layers under giant_yawn_sigh's wake beat instead of cutting it off


func _play_keystone(player: AnimationPlayer) -> void:
	for clip: String in KEYSTONE_CLIPS:
		if not player.has_animation(clip):
			continue
		player.play(clip)
		print("ROLLOVER %s" % JSON.stringify({"phase": "keystone", "clip": clip}))
		if clip == "wake":
			AudioManager.play_sfx("giant_yawn_sigh") # audio pass 3: the wake beat
			# Timed so the debris-fall portion of reveal() lands DURING this
			# clip, per the brief — clouds already blew away at sequence
			# start (_trigger_breath_gust(), called right after the
			# letterbox came in), so only the prop-fall half fires here.
			_trigger_dressing_reveal()
			_ascent_tumble_out() # D27: the trail tumbles off his rising flank
		elif clip == "toss_turn":
			_ascent_settle_back() # D27: ...and lands home as he flops back down
		var cap: SceneTreeTimer = get_tree().create_timer(
			minf(player.get_animation(clip).length + 0.3, KEYSTONE_CLIP_CAP))
		await cap.timeout
	if player.has_animation("sleep"):
		player.play("sleep")


# --- Ascent excursion (D27, see ASCENT_TUMBLE_* constants) --------------------

func _collect_ascent_visuals() -> void:
	if not _ascent_visuals.is_empty():
		return
	for child: Node in _world.get_children():
		if not (child is Node3D):
			continue
		for prefix: String in ASCENT_TUMBLE_PREFIXES:
			if String(child.name).begins_with(prefix):
				_ascent_visuals.append(child as Node3D)
				_ascent_rest.append((child as Node3D).transform)
				break


func _ascent_tumble_out() -> void:
	_collect_ascent_visuals()
	print("ASCENT_TUMBLE %s" % JSON.stringify({"phase": "out", "pieces": _ascent_visuals.size()}))
	var shell: Node3D = _world.get_node_or_null("BearShellAnchor") as Node3D
	var center: Vector3 = shell.global_position if shell != null else Vector3.ZERO
	for i: int in range(_ascent_visuals.size()):
		var visual: Node3D = _ascent_visuals[i]
		if not is_instance_valid(visual):
			continue
		var rest: Transform3D = _ascent_rest[i]
		var outward: Vector3 = rest.origin - center
		outward.y = 0.0
		outward = outward.normalized() if outward.length_squared() > 0.01 else Vector3.RIGHT
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.set_parallel(true)
		tween.tween_property(visual, "position",
			rest.origin + outward * ASCENT_TUMBLE_OUTWARD + Vector3.DOWN * ASCENT_TUMBLE_DROP,
			ASCENT_TUMBLE_OUT_TIME).set_delay(i * ASCENT_STAGGER)
		tween.tween_property(visual, "rotation_degrees:x",
			visual.rotation_degrees.x + ASCENT_TUMBLE_TILT_DEG * side,
			ASCENT_TUMBLE_OUT_TIME).set_delay(i * ASCENT_STAGGER)
		tween.tween_property(visual, "rotation_degrees:z",
			visual.rotation_degrees.z - ASCENT_TUMBLE_TILT_DEG * 0.6 * side,
			ASCENT_TUMBLE_OUT_TIME).set_delay(i * ASCENT_STAGGER)


func _ascent_settle_back() -> void:
	print("ASCENT_TUMBLE %s" % JSON.stringify({"phase": "back", "pieces": _ascent_visuals.size()}))
	for i: int in range(_ascent_visuals.size()):
		var visual: Node3D = _ascent_visuals[i]
		if not is_instance_valid(visual):
			continue
		var rest: Transform3D = _ascent_rest[i]
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) # tiny overshoot: it LANDS
		tween.set_parallel(true)
		tween.tween_property(visual, "transform", rest,
			ASCENT_SETTLE_TIME).set_delay(i * ASCENT_STAGGER * 0.6)


# --- Bear shell roll (optional, present once the giant model lands) ----------

func _tween_shell_roll() -> void:
	var shell: Node3D = _world.get_node_or_null("BearShellAnchor") as Node3D
	if shell == null:
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	tween.tween_property(shell, "rotation_degrees:x",
		shell.rotation_degrees.x + SHELL_ROLL_DEGREES, ROTATE_DURATION)
	tween.tween_property(shell, "position:y",
		shell.position.y - SHELL_SETTLE_SINK, ROTATE_DURATION)
	tween.tween_property(shell, "position:z",
		shell.position.z + HAUNCH_SETTLE_OFFSET.z, ROTATE_DURATION)


## Reuses the exact rescue/warp visual vocabulary (core/rescue/
## bubble_effect.gd, already shared by soft_landing.gd's rescue and
## seat_manager.gd's carry-lag warp) rather than any bespoke lift --
## "emit no custom rescue" per the brief. Unconditional (every connected
## player, wherever they stand) is the simplest SAFE reading of "players
## anywhere on moving parts get caught": nothing can ever be disturbed out
## from under someone if no one is ever left standing on the moving parts
## in the first place.
func _bubble_all_players() -> void:
	var offset: float = 0.0
	for player: Node in get_tree().get_nodes_in_group("players"):
		if not (player is PlayerBody):
			continue
		var bubble: BubbleEffect = BUBBLE_SCENE.instantiate()
		get_tree().current_scene.add_child(bubble)
		var landing: Vector3 = FAR_MEADOW_LANDING + Vector3(offset, 0.0, 0.0)
		offset += BUBBLE_LANDING_SPACING
		bubble.play(player as PlayerBody, landing, "bubble_catch", BUBBLE_DURATION)


func _tween_haunch_settle() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_haunch_visual, "position", _haunch_rest_position + HAUNCH_SETTLE_OFFSET, ROTATE_DURATION)
	tween.tween_property(_haunch_body, "position", _haunch_body_rest_position + HAUNCH_SETTLE_OFFSET, ROTATE_DURATION)
	tween.tween_property(_haunch_visual, "rotation_degrees:y", HAUNCH_SETTLE_YAW_DEGREES, ROTATE_DURATION)


func _apply_already_open_state() -> void:
	_haunch_visual.position = _haunch_rest_position + HAUNCH_SETTLE_OFFSET
	_haunch_body.position = _haunch_body_rest_position + HAUNCH_SETTLE_OFFSET
	_haunch_visual.rotation_degrees.y = HAUNCH_SETTLE_YAW_DEGREES
	# Shell (if the world built one before this ran — bramble.gd's _ready
	# ordering guarantees it) rests in the rolled pose on revisit.
	var shell: Node3D = _world.get_node_or_null("BearShellAnchor") as Node3D
	if shell != null:
		shell.rotation_degrees.x += SHELL_ROLL_DEGREES
		shell.position.y -= SHELL_SETTLE_SINK
		shell.position.z += HAUNCH_SETTLE_OFFSET.z
	_reveal_far_meadow()


func _reveal_far_meadow() -> void:
	_far_meadow_root.visible = true
	for shape: CollisionShape3D in _collect_collision_shapes(_far_meadow_root):
		shape.disabled = false


func _collect_collision_shapes(node: Node) -> Array[CollisionShape3D]:
	var found: Array[CollisionShape3D] = []
	for child: Node in node.get_children():
		if child is CollisionShape3D:
			found.append(child as CollisionShape3D)
		found.append_array(_collect_collision_shapes(child))
	return found


# ---------------------------------------------------------------------------
# Geometry — built once at _ready (hidden/disabled), revealed by flipping
# visibility + collision, matching SnoreGeyser's own "toggle, never rebuild"
# convention.
# ---------------------------------------------------------------------------

func _build_far_meadow_geometry() -> void:
	_far_meadow_root = Node3D.new()
	_far_meadow_root.name = "FarMeadow"
	_far_meadow_root.visible = false
	_world.add_child(_far_meadow_root)

	_add_ground_slab("FarMeadowGround", FAR_MEADOW_SIZE, 0.0, 1.0, COLOR_MEADOW, FAR_MEADOW_CENTER)
	var moss_mat: ShaderMaterial = _ground_patch_material(COLOR_MEADOW, COLOR_MOSS)
	(_far_meadow_root.get_node("FarMeadowGround") as MeshInstance3D).set_surface_override_material(0, moss_mat)

	# The "wall of tall grass... turned into new walkable ground" callback
	# (aliveness_wow.md Top 12 #1) as a low fur-colored threshold ridge --
	# cosmetic seam marker only, never a barrier (design floor: no gates).
	_add_ground_slab("FurRidge", BRIDGE_SIZE, 0.3, 0.9, COLOR_FUR_DARK, BRIDGE_CENTER)

	_add_camera_hint_far_meadow()
	_add_decorative_props()


func _add_ground_slab(slab_name: String, size: Vector2, top_y: float, thickness: float, color: Color, xz_center: Vector2) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, thickness, size.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

	var center: Vector3 = Vector3(xz_center.x, top_y - thickness * 0.5, xz_center.y)

	var visual := MeshInstance3D.new()
	visual.name = slab_name
	visual.mesh = mesh
	visual.position = center
	_far_meadow_root.add_child(visual)

	var body := StaticBody3D.new()
	body.name = slab_name + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	shape.position = center
	shape.disabled = true # flipped by _reveal_far_meadow()
	body.add_child(shape)
	_far_meadow_root.add_child(body)


func _ground_patch_material(tint_a: Color, tint_b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground_patches.gdshader") as Shader
	mat.set_shader_parameter("tint_a", tint_a)
	mat.set_shader_parameter("tint_b", tint_b)
	return mat


func _add_camera_hint_far_meadow() -> void:
	var hint := CameraHint.new()
	hint.name = "FarMeadowHint"
	hint.priority = 1
	hint.yaw_degrees = 180.0 # facing back north, toward the seam/bridge
	hint.blend_time = 1.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FAR_MEADOW_SIZE.x, 8.0, FAR_MEADOW_SIZE.y)
	shape.shape = box
	shape.position = Vector3(FAR_MEADOW_CENTER.x, 3.0, FAR_MEADOW_CENTER.y)
	shape.disabled = true # flipped by _reveal_far_meadow()
	hint.add_child(shape)
	_far_meadow_root.add_child(hint)


## A quiet vista, not a new gameplay space -- 2-3 decorative primitives per
## the brief ("primitives fine; Meshy props land later"), ART_BIBLE.md
## palette only, no collision drama (a single walkable boulder, everything
## else is scenery).
func _add_decorative_props() -> void:
	_add_toadstool(FAR_MEADOW_CENTER + Vector2(-12.0, -6.0))
	_add_boulder(FAR_MEADOW_CENTER + Vector2(8.0, 4.0))
	_add_flower_cluster(FAR_MEADOW_CENTER + Vector2(2.0, -8.0))
	# M2 batch-2 Meshy props (director dressing pass): the reward vista
	# deserves real art. All under _far_meadow_root so they hide/reveal
	# with the sequence; all visual-only walk-through (fort convention).
	_add_meshy_prop("FarBerryBushA", "berry_bush", 0.9, FAR_MEADOW_CENTER + Vector2(-16.0, 4.0))
	_add_meshy_prop("FarBerryBushB", "berry_bush", 0.9, FAR_MEADOW_CENTER + Vector2(14.0, -5.0))
	_add_meshy_prop("FarSoftPine", "soft_pine", 3.0, FAR_MEADOW_CENTER + Vector2(-20.0, -8.0))
	_add_meshy_prop("FarMoonDaisyA", "moon_daisy", 0.4, FAR_MEADOW_CENTER + Vector2(-5.0, 6.0))
	_add_meshy_prop("FarMoonDaisyB", "moon_daisy", 0.4, FAR_MEADOW_CENTER + Vector2(6.0, -9.0))
	_add_meshy_prop("FarMoonDaisyC", "moon_daisy", 0.4, FAR_MEADOW_CENTER + Vector2(11.0, 7.0))
	_add_meshy_prop("FarCloverA", "clover_tuft", 0.3, FAR_MEADOW_CENTER + Vector2(-9.0, -2.0))
	_add_meshy_prop("FarCloverB", "clover_tuft", 0.3, FAR_MEADOW_CENTER + Vector2(4.0, 3.0))
	# Offset from center: FAR_MEADOW_LANDING is the bubble-drop point --
	# nothing sits where a child lands.
	_add_meshy_prop("FarPicnic", "picnic_basket", 0.4, FAR_MEADOW_CENTER + Vector2(9.0, 9.0))


func _add_meshy_prop(prop_name: String, prop_model_id: String, prop_height: float, xz: Vector2) -> void:
	var anchor := Node3D.new()
	anchor.name = prop_name
	anchor.position = Vector3(xz.x, 0.0, xz.y)
	_far_meadow_root.add_child(anchor)
	var slot := ModelSlot.new()
	slot.name = "ModelSlot"
	slot.model_id = prop_model_id
	slot.target_height = prop_height
	anchor.add_child(slot)


func _add_toadstool(xz: Vector2) -> void:
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.5
	stem_mesh.bottom_radius = 0.6
	stem_mesh.height = 2.2
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = COLOR_MILK
	stem_mesh.material = stem_mat
	var stem := MeshInstance3D.new()
	stem.name = "ToadstoolStem"
	stem.mesh = stem_mesh
	stem.position = Vector3(xz.x, 1.1, xz.y)
	_far_meadow_root.add_child(stem)

	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 1.3
	cap_mesh.height = 1.6
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = COLOR_LANTERN
	cap_mesh.material = cap_mat
	var cap := MeshInstance3D.new()
	cap.name = "ToadstoolCap"
	cap.mesh = cap_mesh
	cap.position = Vector3(xz.x, 2.3, xz.y)
	_far_meadow_root.add_child(cap)


func _add_boulder(xz: Vector2) -> void:
	const RADIUS: float = 1.6
	var mesh := SphereMesh.new()
	mesh.radius = RADIUS
	mesh.height = RADIUS * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_FUR_DARK
	mesh.material = mat

	var center: Vector3 = Vector3(xz.x, RADIUS * 0.5, xz.y) # half-buried, like the mound anatomy elsewhere in this world

	var visual := MeshInstance3D.new()
	visual.name = "Boulder"
	visual.mesh = mesh
	visual.position = center
	_far_meadow_root.add_child(visual)

	var body := StaticBody3D.new()
	body.name = "BoulderBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = RADIUS
	shape.shape = sphere_shape
	shape.position = center
	shape.disabled = true # flipped by _reveal_far_meadow()
	body.add_child(shape)
	_far_meadow_root.add_child(body)


func _add_flower_cluster(xz: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FLOWER_RNG_SEED

	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = COLOR_MEADOW
	var bloom_mat := StandardMaterial3D.new()
	bloom_mat.albedo_color = COLOR_ROSE

	for i: int in range(4):
		var offset: Vector2 = Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
		var stem_height: float = rng.randf_range(0.9, 1.3)

		var stem_mesh := BoxMesh.new()
		stem_mesh.size = Vector3(0.12, stem_height, 0.12)
		stem_mesh.material = stem_mat
		var stem := MeshInstance3D.new()
		stem.name = "FlowerStem_%d" % i
		stem.mesh = stem_mesh
		stem.position = Vector3(xz.x + offset.x, stem_height * 0.5, xz.y + offset.y)
		_far_meadow_root.add_child(stem)

		var bloom_mesh := SphereMesh.new()
		bloom_mesh.radius = 0.35
		bloom_mesh.height = 0.5
		bloom_mesh.material = bloom_mat
		var bloom := MeshInstance3D.new()
		bloom.name = "FlowerBloom_%d" % i
		bloom.mesh = bloom_mesh
		bloom.position = Vector3(xz.x + offset.x, stem_height, xz.y + offset.y)
		_far_meadow_root.add_child(bloom)
