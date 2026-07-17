class_name CineSequence
extends Node
## CineSequence — core/cinematic/cine_sequence.gd (M4 card, called out by
## name in worlds/bramble/rollover_sequence.gd, worlds/wisp/dive_sequence.gd
## and worlds/marmalade/stretch_sequence.gd's own header comments as "an M4
## card, not tonight's"). Extracts the letterbox + cinematic-camera
## machinery that was byte-for-byte duplicated across those three files
## (each one's own header explicitly names the duplication and points here)
## into one reusable node: letterbox bars show/hide, cine-camera create/
## activate/restore, a look-target tween driven every frame via
## Camera3D.look_at() (never a raw rotation tween — re-deriving the look_at
## basis each frame is what keeps the camera's up-vector sane mid-tween,
## exactly as all three originals already relied on), and position tweens
## with caller-supplied waypoints/durations.
##
## Usage — one instance per world-sequence, added as a child of whichever
## Node owns the sequence (RolloverSequence/DiveSequence/StretchSequence),
## itself already a child of the world by the time _ready() runs (see each
## of those files' own `setup()` doc comments for why setup() must be
## called before add_child()):
##   var cine := CineSequence.new()
##   add_child(cine)
##   cine.setup(_world, "MyCineCamera", "MyLetterbox")
##   ...
##   cine.begin(WIDE_POS, WIDE_LOOK)                      # snap + bars in
##   cine.dolly_to(NEXT_POS, NEXT_LOOK, TIME)              # first tween
##   cine.push_to(LATER_POS, LATER_LOOK, TIME)             # any later beat
##   cine.end()                                            # restore + bars out
##
## API:
##   setup(host, cam_name, letterbox_name) — `host` is the Node (a world's
##     root Node3D in every current caller) that the cine Camera3D and
##     letterbox CanvasLayer are added to as direct children, matching all
##     three originals' own `_world.add_child(...)` convention exactly
##     (never a child of this CineSequence node itself, so hierarchy/
##     receipts/screenshots look identical to before the refactor).
##   begin(wide_pos, wide_look) — snaps the camera to wide_pos, aims it at
##     wide_look, makes it `current`, and shows the letterbox. Call once
##     per sequence, before any dolly_to()/push_to().
##   dolly_to(pos, look, time, look_time=-1.0) / push_to(...) — tweens the
##     camera position to `pos` over `time` seconds (TRANS_SINE/EASE_IN_OUT,
##     matching every original tween) and the look-target to `look` over
##     `look_time` seconds, defaulting to `time` when omitted or negative
##     (every original call site except bramble's own opening dolly — which
##     eases its look-target faster than its position, CINE_DOLLY_TIME*0.6
##     vs CINE_DOLLY_TIME — used one shared duration for both, hence the
##     optional second parameter rather than folding them into one). The
##     two method names are mechanically identical; kept distinct only
##     because the task brief's requested API names the mid-sequence tween
##     `dolly_to` and the later reveal-beat tween(s) `push_to`, matching how
##     the three originals' own call sites read (_cine_begin's own internal
##     tween vs. _cine_meadow_push/_cine_push_routes/_cine_route_push/
##     _cine_nook_push).
##   end() — restores whichever Camera3D was `current` before begin() ran
##     and hides the letterbox.

const LETTERBOX_FRACTION: float = 0.085 # 0.11 clipped the Moon's subtitle (bramble's own tuned value; matched by wisp/marmalade)
const LETTERBOX_FADE: float = 0.6
const LETTERBOX_LAYER: int = 90
const BAR_COLOR: Color = Color(0.05, 0.06, 0.12) # near-black dusk, not pure black

var _host: Node = null
var _cam_name: String = "CineCamera"
var _letterbox_name: String = "CineLetterbox"

var _cine_cam: Camera3D = null
var _cine_look: Vector3 = Vector3.ZERO
var _prev_cam: Camera3D = null
var _letterbox: CanvasLayer = null
var _bar_top: ColorRect = null
var _bar_bottom: ColorRect = null


## setup — call once, before begin(). `host` is the Node the cine camera
## and letterbox get parented under (a world's root Node3D in every current
## caller); `cam_name`/`letterbox_name` are purely cosmetic node names,
## preserved per-world for readable scene trees / debugging, matching each
## original's own unique names ("RolloverCineCamera", "DiveLetterbox", etc.).
func setup(host: Node, cam_name: String = "CineCamera", letterbox_name: String = "CineLetterbox") -> void:
	_host = host
	_cam_name = cam_name
	_letterbox_name = letterbox_name


func begin(wide_pos: Vector3, wide_look: Vector3) -> void:
	_prev_cam = get_viewport().get_camera_3d()
	if _cine_cam == null:
		_cine_cam = Camera3D.new()
		_cine_cam.name = _cam_name
		_host.add_child(_cine_cam)
	_cine_cam.position = wide_pos
	_cine_look = wide_look
	_cine_cam.look_at_from_position(wide_pos, wide_look, Vector3.UP)
	_cine_cam.current = true
	_show_letterbox(true)


func dolly_to(pos: Vector3, look: Vector3, time: float, look_time: float = -1.0) -> void:
	_tween_camera(pos, look, time, look_time)


func push_to(pos: Vector3, look: Vector3, time: float, look_time: float = -1.0) -> void:
	_tween_camera(pos, look, time, look_time)


func end() -> void:
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	_show_letterbox(false)


func _process(_delta: float) -> void:
	if _cine_cam != null and _cine_cam.current:
		_cine_cam.look_at(_cine_look, Vector3.UP)


func _tween_camera(pos: Vector3, look: Vector3, time: float, look_time: float) -> void:
	if _cine_cam == null:
		return
	var effective_look_time: float = time if look_time < 0.0 else look_time
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(true)
	tween.tween_property(_cine_cam, "position", pos, time)
	tween.tween_property(self, "_cine_look", look, effective_look_time)


func _show_letterbox(shown: bool) -> void:
	if _letterbox == null:
		_letterbox = CanvasLayer.new()
		_letterbox.name = _letterbox_name
		_letterbox.layer = LETTERBOX_LAYER
		_host.add_child(_letterbox)
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
	bar.color = BAR_COLOR
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
