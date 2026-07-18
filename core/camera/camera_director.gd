class_name CameraDirector
extends Node3D
## CameraDirector — camera v3 (D27). Owns HOW the game is framed:
##
##   SOLO   -> one fullscreen SubViewportContainer, Pip's OrbitCameraRig.
##   CO-OP  -> static vertical split: two half-width containers, one rig
##             per seat, soft divider stripe. (Dynamic merge/split is the
##             planned v2 upgrade on top of this exact structure.)
##
## Gameplay always renders through SubViewports on a CanvasLayer BELOW all
## UI (HUD=5, subtitles=6, pause=10, letterbox=90 — this layer is -5, so
## every existing UI element spans the full window above the halves). The
## SubViewports set no world_3d of their own, so find_world_3d() resolves
## to the root viewport's World3D — same scene, same lights, same physics.
##
## THE STAGE CAMERA + SEIZURE POLL (the load-bearing trick): the root
## viewport keeps 3D rendering DISABLED during normal play, with a passive
## "stage camera" holding `current` (mirroring Pip's rig every frame — it
## is also the root viewport's positional-audio listener). Every cutscene,
## establishing shot, and photo mode in the codebase seizes the ROOT
## viewport via `cam.current = true` / restores via `_prev_cam.current =
## true` (CineSequence, photo_mode.gd, the worlds' reveal cams). This node
## polls the root viewport's current camera each frame: the moment it is
## not the stage camera, someone is directing — the split UI hides and
## root 3D re-enables (fullscreen cinematic); when the stage camera gets
## restored, the split returns. ZERO changes needed in any sequence code,
## and any future camera-stealing code gets fullscreen for free.
##
## Co-op join is activity-based (see InputRouter D27): the split slides in
## on mode_changed the moment the second pad shows real input.

## Fired on every fullscreen-cinematic transition (a camera seizing /
## releasing the root viewport). MemoryAlbum snaps keystone beats off it.
signal seizure_changed(seized: bool)

const SPLIT_LAYER_INDEX: int = -5
const DIVIDER_WIDTH: float = 4.0
const DIVIDER_COLOR: Color = Color(0.05, 0.06, 0.12, 1.0) # near-black dusk (letterbox bar color)

var _pip: PlayerBody = null
var _otto: PlayerBody = null

var _stage_cam: Camera3D = null
var _split_layer: CanvasLayer = null
var _pip_container: SubViewportContainer = null
var _otto_container: SubViewportContainer = null
var _pip_viewport: SubViewport = null
var _otto_viewport: SubViewport = null
var _divider: ColorRect = null
var _pip_rig: OrbitCameraRig = null
var _otto_rig: OrbitCameraRig = null

var _built: bool = false
var _seized: bool = false


func _ready() -> void:
	# Must keep polling under get_tree().paused — photo mode lives inside
	# the pause menu and seizes the root camera while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


## register_players — call once from main.gd after both bodies exist.
func register_players(pip: PlayerBody, otto: PlayerBody) -> void:
	_pip = pip
	_otto = otto
	_build()
	InputRouter.mode_changed.connect(_on_mode_changed)
	_apply_mode()


func _build() -> void:
	_stage_cam = Camera3D.new()
	_stage_cam.name = "StageCamera"
	add_child(_stage_cam)

	_split_layer = CanvasLayer.new()
	_split_layer.name = "SplitLayer"
	_split_layer.layer = SPLIT_LAYER_INDEX
	add_child(_split_layer)

	var split_root := Control.new()
	split_root.name = "SplitRoot"
	split_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	split_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split_layer.add_child(split_root)

	var row := HBoxContainer.new()
	row.name = "Halves"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	split_root.add_child(row)

	_pip_rig = OrbitCameraRig.new()
	_pip_rig.name = "PipRig"
	_pip_rig.setup(_pip, _otto, 1)
	var pip_parts: Array = _make_half(row, "PipHalf", _pip_rig)
	_pip_container = pip_parts[0]
	_pip_viewport = pip_parts[1]

	_divider = ColorRect.new()
	_divider.name = "Divider"
	_divider.color = DIVIDER_COLOR
	_divider.custom_minimum_size = Vector2(DIVIDER_WIDTH, 0.0)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_divider)

	_otto_rig = OrbitCameraRig.new()
	_otto_rig.name = "OttoRig"
	_otto_rig.setup(_otto, _pip, 2)
	var otto_parts: Array = _make_half(row, "OttoHalf", _otto_rig)
	_otto_container = otto_parts[0]
	_otto_viewport = otto_parts[1]

	# The stage camera holds `current` in the root viewport: cutscenes
	# capture it as their _prev_cam and hand it back on end().
	_stage_cam.current = true
	get_viewport().disable_3d = true
	_built = true


## _make_half — one [SubViewportContainer, SubViewport] pair with `rig`
## inside. Returned as an untyped pair purely for the two-value hand-back.
func _make_half(row: HBoxContainer, half_name: String, rig: OrbitCameraRig) -> Array:
	var container := SubViewportContainer.new()
	container.name = half_name
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(container)

	var viewport := SubViewport.new()
	viewport.name = half_name + "Viewport"
	# No world_3d assigned -> find_world_3d() walks up to the root viewport:
	# both halves render the one shared scene.
	viewport.audio_listener_enable_3d = false # the stage camera is the one listener
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	viewport.add_child(rig)
	return [container, viewport]


func _on_mode_changed(_mode: int) -> void:
	_apply_mode()


func _apply_mode() -> void:
	if not _built:
		return
	var coop: bool = InputRouter.is_coop()

	_otto_container.visible = coop
	_divider.visible = coop
	_otto_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if coop else SubViewport.UPDATE_DISABLED
	)
	_otto_rig.set_physics_process(coop)

	# Split-screen steering: each kid pushes the stick relative to THEIR
	# half's camera (player_body.gd's _camera_relative_dir prefers this).
	_pip.control_camera = _pip_rig.camera()
	_otto.control_camera = _otto_rig.camera() if coop else null

	print("CAMERA_DIRECTOR %s" % JSON.stringify({"mode": "split" if coop else "solo"}))


func _process(_delta: float) -> void:
	if not _built:
		return

	var root_cam: Camera3D = get_viewport().get_camera_3d()
	var seized: bool = root_cam != null and root_cam != _stage_cam
	if seized != _seized:
		_seized = seized
		_split_layer.visible = not seized
		get_viewport().disable_3d = not seized
		seizure_changed.emit(seized)
		print("CAMERA_DIRECTOR %s" % JSON.stringify({"seized": seized}))

	# Mirror Pip's live camera so the root viewport's audio listener (and
	# any code sampling the root camera) tracks the primary half's view.
	if not _seized and _pip_rig != null:
		var live: Camera3D = _pip_rig.camera()
		if live != null:
			_stage_cam.global_transform = live.global_transform
			_stage_cam.fov = live.fov
