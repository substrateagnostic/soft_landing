class_name WakingSequence
extends Node
## WakingSequence — THE WAKING (M4 headline, D28-approved beats): the
## whole-game finale, played in the pillow fort on the first arrival home
## after ALL FOUR giant worlds are complete (or forced with --waking).
##
## The thesis of the title, made playable: the giants NEVER wake — the
## win condition of THE BIG NAP is that the nap holds. Dawn comes, each
## fort door burns once in its giant's color (the door IS that giant's
## presence here) while its keystone's sound echoes far away, and it is
## the KIDS who finally get sleepy: bubbles — the game's gentlest verb —
## carry them to the cushions, they curl up (the rig's own sleep clip),
## and the credits roll over the sunrise, built from THE FAMILY'S OWN
## PHOTOS (photo mode shots first-class, MemoryAlbum candids filling in —
## D28: "if no one used the photo mode there's still memories").
##
## Producer decision still held: post-credits goes to the TITLE (safe
## default); a "quiet morning" dawn-fort visit is an open seam, not built.
## Persistence: GameState setting "waking_seen" (plays once; --waking
## re-runs it any time).
##
## Camera/split handling is free: CineSequence seizes the root viewport,
## CameraDirector's poll collapses split-screen to fullscreen cinema, and
## MemoryAlbum auto-snaps the seizure (the finale photographs itself).

signal waking_finished

const DAWN_DURATION: float = 16.0
const DOOR_BEATS: Array = [
	# [door node name, overlay sfx — each giant's keystone echoing far away]
	["BrambleDoor", "giant_yawn_sigh"],
	["WispDoor", "water_rise_shimmer"],
	["MarmaladeDoor", "roof_slide_soft"],
	["TortoiseDoor", "giant_rumble"],
]
const DOOR_BEAT_GAP: float = 2.4
const BED_CARRY_TIME: float = 3.2
const SLEEP_SETTLE_TIME: float = 2.8

const CINE_WIDE_POS: Vector3 = Vector3(0.0, 3.4, 9.5) # outside the fort mouth, skyline behind it
const CINE_WIDE_LOOK: Vector3 = Vector3(0.0, 1.6, -6.0)
const CINE_DOORS_POS: Vector3 = Vector3(6.5, 4.5, 4.0) # high three-quarter: all four beacons in frame
const CINE_DOORS_LOOK: Vector3 = Vector3(0.0, 1.0, -3.0)
# Through the NORTH doorway (the fort's south face is solid — the first
# recording filmed a wall): the camera stands outside the fort mouth and
# watches the bedroom through its own door. Both sleep spots sit inside
# the 1.6m door gap's sight cone from here (checked against DOOR_WIDTH).
const CINE_BEDS_POS: Vector3 = Vector3(0.0, 1.7, -11.6)
const CINE_BEDS_LOOK: Vector3 = Vector3(0.0, 0.5, -5.8)
const CINE_SUNRISE_POS: Vector3 = Vector3(0.0, 2.6, 6.5) # slow pull back out as credits roll
const CINE_SUNRISE_LOOK: Vector3 = Vector3(0.0, 2.2, -6.0)

const BUBBLE_SCENE: PackedScene = preload("res://core/rescue/bubble_effect.tscn")
const SLEEP_SPOTS: Array = [Vector3(0.75, 0.15, -5.4), Vector3(-0.75, 0.15, -6.4)] # inside the fort, on the rug

const CREDITS_LAYER: int = 96 # above letterbox (90) AND the ribbon (95)
const PHOTO_SECONDS: float = 2.8
const MAX_PHOTOS: int = 14
const PHOTOS_DIR: String = "user://photos"

var _world: Node3D = null
var _cine: CineSequence = null
var _credits_layer: CanvasLayer = null


## setup — before add_child (repo convention). `world` is the fort root.
func setup(world: Node3D) -> void:
	_world = world


func _ready() -> void:
	_cine = CineSequence.new()
	add_child(_cine)
	_cine.setup(_world, "WakingCineCamera", "WakingLetterbox")


func begin(forced: bool) -> void:
	print("WAKING %s" % JSON.stringify({"phase": "start", "forced": forced}))
	AudioManager.stop_stems()

	_cine.begin(CINE_WIDE_POS, CINE_WIDE_LOOK)
	TheMoon.say("waking_dawn")
	var ambience: Node = get_tree().current_scene.get_node_or_null("Ambience")
	if ambience != null and ambience.has_method("begin_dawn"):
		ambience.call("begin_dawn", DAWN_DURATION)
	await _wait(4.0)

	# The giants stir — one door at a time, each keystone echoing far off.
	print("WAKING %s" % JSON.stringify({"phase": "giants"}))
	_cine.dolly_to(CINE_DOORS_POS, CINE_DOORS_LOOK, DOOR_BEAT_GAP * 1.5)
	for beat: Array in DOOR_BEATS:
		var door: Node = _world.get_node_or_null(str(beat[0]))
		if door != null and door.has_method("shine"):
			door.call("shine", DOOR_BEAT_GAP + 0.6)
		AudioManager.play_sfx_overlay(str(beat[1]))
		await _wait(DOOR_BEAT_GAP)
	TheMoon.say("waking_giants")
	await _wait(2.2)

	# The kids' own bedtime: bubble-carry to the cushions, curl up.
	print("WAKING %s" % JSON.stringify({"phase": "beds"}))
	TheMoon.say("waking_sleepy")
	_cine.push_to(CINE_BEDS_POS, CINE_BEDS_LOOK, BED_CARRY_TIME * 0.8)
	var players: Array = _sorted_players()
	for i: int in range(players.size()):
		var spot: Vector3 = SLEEP_SPOTS[mini(i, SLEEP_SPOTS.size() - 1)]
		var bubble: BubbleEffect = BUBBLE_SCENE.instantiate()
		get_tree().current_scene.add_child(bubble)
		bubble.play(players[i], spot, "bubble_catch", BED_CARRY_TIME)
	await _wait(BED_CARRY_TIME + 0.4)
	for player: PlayerBody in players:
		var animator: Node = _find_animator(player)
		if animator != null:
			animator.call("play_gesture", "sleep")
	await _wait(SLEEP_SETTLE_TIME)

	# Credits over the sunrise — the night they actually had.
	TheMoon.hush() # the caption owns the screen now (B12: C2-S3/C1-S4)
	print("WAKING %s" % JSON.stringify({"phase": "credits"}))
	_cine.push_to(CINE_SUNRISE_POS, CINE_SUNRISE_LOOK, 6.0)
	var photo_count: int = await _run_credits()
	TheMoon.say("waking_goodnight")
	await _wait(4.5)

	if not forced:
		# Only the REAL finale marks itself seen — a --waking preview must
		# never eat the family's actual first Waking (Gotcha #10: the
		# shared save contaminates; a forced verify run burned this once).
		GameState.set_setting("waking_seen", true)
	print("WAKING %s" % JSON.stringify({"phase": "end", "photos": photo_count}))
	waking_finished.emit()
	await _fade_to_black(2.0)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


# --- Credits -----------------------------------------------------------------

## _run_credits — polaroid crossfade of the family's photos (deliberate
## photo_*.png first, memory_*.png candids filling to MAX_PHOTOS, each in
## the order they were taken), then the goodnight card. Returns the photo
## count (0 headless / fresh save — the card sequence still plays).
func _run_credits() -> int:
	_credits_layer = CanvasLayer.new()
	_credits_layer.name = "WakingCredits"
	_credits_layer.layer = CREDITS_LAYER
	add_child(_credits_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.12, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_layer.add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.30, 2.0)

	var textures: Array = _collect_photo_textures()
	var frame := TextureRect.new()
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.custom_minimum_size = Vector2(720.0, 405.0)
	frame.position -= frame.custom_minimum_size * 0.5
	frame.pivot_offset = frame.custom_minimum_size * 0.5
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate.a = 0.0
	_credits_layer.add_child(frame)

	var caption := _make_caption("the night you had")
	_credits_layer.add_child(caption)

	for i: int in range(textures.size()):
		frame.texture = textures[i]
		frame.rotation_degrees = [-3.0, 2.0, -1.5, 3.0][i % 4]
		var t_in: Tween = create_tween()
		t_in.tween_property(frame, "modulate:a", 1.0, 0.5)
		await _wait(PHOTO_SECONDS)
		var t_out: Tween = create_tween()
		t_out.tween_property(frame, "modulate:a", 0.0, 0.4)
		await _wait(0.45)

	caption.queue_free()
	frame.queue_free()
	var card := _make_caption("THE BIG NAP\n\nfor Ezra & Caleb\n\nthe nap holds — goodnight")
	# Full-rect + both alignments centered — anchoring a Label's top-left
	# at screen center drifted the card right of the fort in recording 1.
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.position = Vector2.ZERO
	_credits_layer.add_child(card)
	return textures.size()


func _make_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.960784, 0.94902, 0.909804))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.4))
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.position.y = -110.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _collect_photo_textures() -> Array:
	var textures: Array = []
	if DisplayServer.get_name() == "headless":
		return textures
	var deliberate: Array[int] = []
	var candid: Array[int] = []
	for file: String in DirAccess.get_files_at(PHOTOS_DIR):
		if file.begins_with("photo_") and file.ends_with(".png"):
			deliberate.append(file.trim_prefix("photo_").trim_suffix(".png").to_int())
		elif file.begins_with("memory_") and file.ends_with(".png"):
			candid.append(file.trim_prefix("memory_").trim_suffix(".png").to_int())
	deliberate.sort()
	candid.sort()

	var paths: Array[String] = []
	for index: int in deliberate:
		paths.append("%s/photo_%d.png" % [PHOTOS_DIR, index])
	for index: int in candid:
		if paths.size() >= MAX_PHOTOS:
			break
		paths.append("%s/memory_%d.png" % [PHOTOS_DIR, index])
	if paths.size() > MAX_PHOTOS:
		paths = paths.slice(0, MAX_PHOTOS)

	for path: String in paths:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null:
			textures.append(ImageTexture.create_from_image(image))
	return textures


# --- Helpers -----------------------------------------------------------------

func _sorted_players() -> Array:
	var players: Array = []
	for node: Node in get_tree().get_nodes_in_group("players"):
		if node is PlayerBody:
			players.append(node)
	players.sort_custom(func(a: PlayerBody, b: PlayerBody) -> bool: return a.seat < b.seat)
	return players


func _find_animator(player: PlayerBody) -> Node:
	for child: Node in player.get_children():
		if child.has_method("play_gesture"):
			return child
	return null


func _fade_to_black(duration: float) -> void:
	var black := ColorRect.new()
	black.color = Color(0.02, 0.02, 0.05, 0.0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _credits_layer != null:
		_credits_layer.add_child(black)
	var tween: Tween = create_tween()
	tween.tween_property(black, "color:a", 1.0, duration)
	await _wait(duration + 0.1)


func _wait(seconds: float) -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(seconds)
	await timer.timeout
