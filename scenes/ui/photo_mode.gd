class_name PhotoMode
extends Node
## PhotoMode — v1 family photo mode (Astro-Bot minimal), reached from the
## pause menu's new camera-icon entry (pause_menu.gd's Photo button). While
## active: gameplay stays paused (PauseMenu already set get_tree().paused =
## true before this ever opens — see enter()'s doc comment), the pause
## overlay/HUD/subtitle ribbon are all hidden so there is never any UI on
## screen to strip before a shot, and a free orbit camera circles whichever
## player is being photographed (always Pip, seat 1 — the "current player"
## for this v1). Left stick orbits (yaw/pitch), right stick adjusts height/
## zoom, jump/A snaps a photo, interact/B returns to the pause menu.
##
## Reuses CameraRig's own SpringArm3D sphere-cast pattern (core/camera/
## camera_rig.gd) for "never through ground": a Node3D pivot at
## player-position + height offset, rotated by yaw, holding a SpringArm3D
## (rotated by pitch, length = zoom) that itself holds the Camera3D — the
## same three-node shape camera_rig.tscn already uses, so collision-pulled-
## in framing behaves identically to the game's own follow camera.
##
## Photo persistence deliberately does NOT touch GameState/SaveManager
## (both outside this pass's territory): the "persistent counter" is
## derived by scanning user://photos/ for the highest existing
## `photo_<n>.png` index at first use, then incrementing in memory for the
## rest of the session — simple, and survives a full app restart because
## it's disk-based, with no new save-file schema required.
##
## process_mode = WHEN_PAUSED (set in _ready(), matching pause_menu.gd's own
## convention) so orbiting/shutter/back all keep working while the tree is
## paused; every other gameplay system (players, CameraRig, world logic)
## stays frozen exactly as the pause menu already leaves it.

const PHOTOS_DIR: String = "user://photos"
const WORLD_GEOMETRY_MASK: int = 1 # matches core/camera/camera_rig.gd's own WORLD_GEOMETRY_MASK
const SPHERE_CAST_RADIUS: float = 0.25
const SPHERE_CAST_MARGIN: float = 0.25

const ORBIT_YAW_SPEED_DEGREES: float = 90.0
const ORBIT_PITCH_SPEED_DEGREES: float = 60.0
const PITCH_MIN_DEGREES: float = -85.0 # looking down, just short of straight-down
const PITCH_MAX_DEGREES: float = 60.0 # looking well up — these giants sleep tens of meters tall

const ZOOM_SPEED: float = 6.0
const ZOOM_MIN: float = 2.0
const ZOOM_MAX: float = 18.0 # wide enough to frame a whole giant, not just Pip

const HEIGHT_SPEED: float = 3.0
const HEIGHT_MIN: float = -0.5
const HEIGHT_MAX: float = 8.0 # room to rise for a look-down-on-the-giant angle

## Matches core/camera/camera_rig.gd's own base_pitch_degrees/arm_length
## exactly, and HEIGHT=0.0 matches its pivot convention too (ground-tracked
## player Y, no added offset) -- so photo mode OPENS on precisely the same
## framing the player already sees from the ordinary follow camera, proven
## to read well in every world, before any orbit input moves it. (A first
## pass used a shallower pitch/added height "for a nicer starting shot" and
## it read as an unrecognizable wide horizon with Pip nowhere in frame —
## caught live via a windowed --shots capture; matching the proven default
## fixed it.)
const DEFAULT_YAW_DEGREES: float = 0.0
const DEFAULT_PITCH_DEGREES: float = -32.0
const DEFAULT_ZOOM: float = 6.0
const DEFAULT_HEIGHT: float = 0.0

const SHUTTER_SFX: String = "photo_shutter" # fails soft (AudioManager convention) until an asset lands

var _hud: HUD = null
var _pause_menu: PauseMenu = null

var _active: bool = false
var _hud_was_visible: bool = true

var _rig_pivot: Node3D = null
var _spring_arm: SpringArm3D = null
var _camera: Camera3D = null
var _prev_cam: Camera3D = null

var _target_player: PlayerBody = null

var _yaw: float = 0.0
var _pitch: float = 0.0
var _zoom: float = DEFAULT_ZOOM
var _height: float = DEFAULT_HEIGHT

var _next_photo_index: int = -1 # -1 = not yet resolved from disk


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func setup(hud: HUD, pause_menu: PauseMenu) -> void:
	_hud = hud
	_pause_menu = pause_menu


func is_active() -> bool:
	return _active


## enter — called on PauseMenu's new Photo button. The pause menu already
## paused the tree and dimmed the game before this ever fires (open()'s own
## job); this just hides that overlay + the HUD/subtitle so composing a shot
## has zero UI on screen, and hands the viewport to a free orbit camera.
func enter() -> void:
	if _active:
		return
	_target_player = _resolve_target_player()
	if _target_player == null:
		return # nothing to orbit (no players in the tree yet) — stay in the pause menu
	_active = true

	_hud_was_visible = _hud.visible
	_hud.visible = false
	var subtitle: Node = TheMoon.get_node_or_null("SubtitleRibbon")
	if subtitle != null:
		subtitle.set("visible", false)
	if _pause_menu != null:
		_pause_menu.visible = false

	_ensure_rig()
	_yaw = DEFAULT_YAW_DEGREES
	_pitch = deg_to_rad(DEFAULT_PITCH_DEGREES)
	_zoom = DEFAULT_ZOOM
	_height = DEFAULT_HEIGHT
	_apply_rig_transform()

	_prev_cam = get_viewport().get_camera_3d()
	_camera.current = true
	print("PHOTO_MODE %s" % JSON.stringify({"phase": "enter"}))


func exit() -> void:
	if not _active:
		return
	_active = false

	_hud.visible = _hud_was_visible
	var subtitle: Node = TheMoon.get_node_or_null("SubtitleRibbon")
	if subtitle != null:
		subtitle.set("visible", true)
	if _pause_menu != null:
		_pause_menu.visible = true

	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	print("PHOTO_MODE %s" % JSON.stringify({"phase": "exit"}))


func _resolve_target_player() -> PlayerBody:
	var pip: Array = get_tree().get_nodes_in_group("player_seat_1")
	for node: Node in pip:
		if node is PlayerBody:
			return node as PlayerBody
	for node: Node in get_tree().get_nodes_in_group("players"):
		if node is PlayerBody:
			return node as PlayerBody
	return null


## _ensure_rig — the whole rig gets process_mode = WHEN_PAUSED explicitly
## (not just PhotoMode itself): it's parented under get_tree().current_scene,
## a sibling of PhotoMode rather than its descendant, so it does NOT inherit
## PhotoMode's own WHEN_PAUSED setting and would otherwise default to
## PROCESS_MODE_INHERIT -> frozen while paused. SpringArm3D's own collision
## shape-cast (the part that actually pushes the camera out along -Z to
## spring_length, clamped by whatever it hits) runs as part of that same
## physics-tied internal processing — caught live via a windowed --shots
## capture: without this, the camera sat frozen at local (0,0,0) (i.e.
## exactly at the pivot, un-pushed-out) for the whole session, reading as
## either "no visible Pip" (pivot up near head height) or "buried in the
## ground" (pivot at foot height) depending on the height offset in use,
## never the intended orbit shot.
func _ensure_rig() -> void:
	if _rig_pivot != null:
		return
	_rig_pivot = Node3D.new()
	_rig_pivot.name = "PhotoModeRig"
	_rig_pivot.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().current_scene.add_child(_rig_pivot)

	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "SpringArm3D"
	_spring_arm.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_spring_arm.spring_length = _zoom
	_spring_arm.margin = SPHERE_CAST_MARGIN
	var shape := SphereShape3D.new()
	shape.radius = SPHERE_CAST_RADIUS
	_spring_arm.shape = shape
	_spring_arm.collision_mask = WORLD_GEOMETRY_MASK
	if _target_player != null:
		_spring_arm.add_excluded_object(_target_player.get_rid())
	_rig_pivot.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_spring_arm.add_child(_camera)


func _process(delta: float) -> void:
	if not _active or _target_player == null:
		return

	_update_orbit(delta)
	_apply_rig_transform()

	if _shutter_just_pressed():
		_capture_photo()
	elif _back_just_pressed():
		exit()


## _update_orbit — left stick orbits (yaw/pitch), right stick adjusts
## height/zoom; both seats' sticks sum (matching camera_rig.gd's own D18
## nudge convention), so whichever controller is in hand works.
func _update_orbit(delta: float) -> void:
	var orbit_stick: Vector2 = _read_stick("p1_move_left", "p1_move_right", "p1_move_up", "p1_move_down",
		"p2_move_left", "p2_move_right", "p2_move_up", "p2_move_down")
	_yaw = wrapf(_yaw + deg_to_rad(ORBIT_YAW_SPEED_DEGREES) * orbit_stick.x * delta, 0.0, TAU)
	_pitch = clampf(
		_pitch - deg_to_rad(ORBIT_PITCH_SPEED_DEGREES) * orbit_stick.y * delta,
		deg_to_rad(PITCH_MIN_DEGREES), deg_to_rad(PITCH_MAX_DEGREES)
	)

	var frame_stick: Vector2 = _read_stick("p1_camera_left", "p1_camera_right", "p1_camera_up", "p1_camera_down",
		"p2_camera_left", "p2_camera_right", "p2_camera_up", "p2_camera_down")
	_height = clampf(_height + HEIGHT_SPEED * frame_stick.x * delta, HEIGHT_MIN, HEIGHT_MAX)
	_zoom = clampf(_zoom - ZOOM_SPEED * frame_stick.y * delta, ZOOM_MIN, ZOOM_MAX)


func _read_stick(p1_left: String, p1_right: String, p1_up: String, p1_down: String,
		p2_left: String, p2_right: String, p2_up: String, p2_down: String) -> Vector2:
	var p1: Vector2 = Input.get_vector(p1_left, p1_right, p1_up, p1_down)
	var p2: Vector2 = Input.get_vector(p2_left, p2_right, p2_up, p2_down)
	return (p1 + p2).limit_length(1.0)


func _apply_rig_transform() -> void:
	if _rig_pivot == null or _target_player == null:
		return
	_rig_pivot.global_position = _target_player.global_position + Vector3(0.0, _height, 0.0)
	_rig_pivot.rotation.y = _yaw
	_spring_arm.rotation.x = _pitch
	_spring_arm.spring_length = _zoom


func _shutter_just_pressed() -> bool:
	return Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump")


func _back_just_pressed() -> bool:
	return Input.is_action_just_pressed("p1_interact") or Input.is_action_just_pressed("p2_interact")


## _capture_photo — screenshot WITHOUT UI (there is none while photo mode is
## active — HUD/subtitle/pause overlay are all hidden for the whole session,
## not just at capture time, so any frame is already clean), saved to
## user://photos/photo_<n>.png, a soft shutter chime (fails soft if the sfx
## isn't registered — see SHUTTER_SFX's own doc note), and a PHOTO receipt.
func _capture_photo() -> void:
	if DisplayServer.get_name() == "headless":
		# Matches tools/harness/harness.gd's own _capture_shot() guard: no
		# viewport texture exists to save headless (harness verification
		# runs are headless by default; this keeps a --debug_photo smoke
		# test honest instead of erroring on a null image).
		print("PHOTO_NOTE screenshot skipped (headless)")
		return
	AudioManager.play_sfx(SHUTTER_SFX)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var index: int = _reserve_next_photo_index()
	var path: String = "%s/photo_%d.png" % [PHOTOS_DIR, index]
	var err: Error = image.save_png(path)
	if err == OK:
		print("PHOTO %s" % JSON.stringify({"path": path}))
	else:
		print("PHOTO_NOTE save failed (err=%d) %s" % [err, path])


func _reserve_next_photo_index() -> int:
	_ensure_photos_dir()
	if _next_photo_index < 0:
		_next_photo_index = _scan_highest_photo_index() + 1
	var index: int = _next_photo_index
	_next_photo_index += 1
	return index


func _ensure_photos_dir() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null and not dir.dir_exists("photos"):
		dir.make_dir_recursive("photos")


func _scan_highest_photo_index() -> int:
	var dir: DirAccess = DirAccess.open(PHOTOS_DIR)
	if dir == null:
		return 0
	var highest: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with("photo_") and file_name.ends_with(".png"):
			var num_str: String = file_name.trim_prefix("photo_").trim_suffix(".png")
			if num_str.is_valid_int():
				highest = maxi(highest, int(num_str))
		file_name = dir.get_next()
	dir.list_dir_end()
	return highest
