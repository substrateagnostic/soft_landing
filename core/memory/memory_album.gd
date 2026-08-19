class_name MemoryAlbum
extends Node
## MemoryAlbum — D28 (producer, night two, approving the Waking's photo
## credits): "the game should auto snap photos at both triumphant and
## silly/failure moments so that if no one used the photo mode there's
## still memories." Candid screenshots — UI, subtitles and all; these are
## memories, not compositions — saved beside photo mode's own shots as
## user://photos/memory_<n>.png (same disk-scan counter idiom, distinct
## prefix so the two never collide). The Waking's credits will glob both.
##
## Triggers:
##   TRIUMPHANT — dream_returned (delayed to catch the cheer gesture);
##     any cinematic seizure (CameraDirector.seizure_changed: keystones,
##     reveals — snapped mid-beat, one per seizure).
##   SILLY — a player entering BUBBLED (mid-bubble is the cutest frame the
##     game makes; covers every rescue AND every leash-warp descendant);
##     TOSSED (the toddler-toss, mid-air); pound_landed (the launch).
##
## Discipline: one snap per MIN_INTERVAL globally, session-capped, and
## the memory_ pool is pruned oldest-first past POOL_CAP files — photo
## mode's own photo_ files are NEVER touched. PNG encode runs on a worker
## thread so a triumphant frame never hitches.

const PHOTOS_DIR: String = "user://photos"
const MIN_INTERVAL: float = 25.0 # seconds between any two auto-snaps
const SESSION_CAP: int = 40
const POOL_CAP: int = 80 # memory_*.png kept on disk, oldest pruned
const DREAM_RETURN_DELAY: float = 0.55 # the cheer gesture has started by then
const SEIZURE_DELAY: float = 2.5 # mid-keystone beat, past the letterbox fade
const TOSS_DELAY: float = 0.3
const BUBBLE_LAND_DELAY: float = 0.4 # after set-down: kid + ground + partner in frame
const POUND_DELAY: float = 0.4
# Candid floor (B12 gate, C2-M1): the game is night — a rescue over the
# void is a black card. If nothing in frame clears PEAK_LUMA_FLOOR (or the
# whole frame is near-black), skip and refund the session slot. The void
# rescues measured peak ~0.28; every keeper measured ≥0.35.
const PEAK_LUMA_FLOOR: float = 0.33
const MEAN_LUMA_FLOOR: float = 0.10

var _pip: PlayerBody = null
var _otto: PlayerBody = null

var _last_snap_ms: int = -1000000
var _session_count: int = 0
var _next_index: int = -1 # lazy disk scan, photo_mode.gd's own idiom
# Seats armed by a BUBBLED entry, snapped on the LANDED that ends the ride
# (B12 gate, C1-S2: mid-void bubble shots were empty black cards; the
# set-down — kid, ground, partner — is the picture worth keeping).
var _bubble_snap_armed: Dictionary = {}


func setup(pip: PlayerBody, otto: PlayerBody, soft_landing: SoftLanding, director: Node) -> void:
	_pip = pip
	_otto = otto

	GameState.dream_returned.connect(func(_w: String, _id: String) -> void:
		_queue_snap("dream_returned", DREAM_RETURN_DELAY))
	if soft_landing != null:
		# player_rescued fires at rescue END; the BUBBLED state hook below
		# catches the mid-bubble frame, so this is deliberately unused.
		pass
	for player: PlayerBody in [pip, otto]:
		if player == null:
			continue
		player.state_changed.connect(_on_player_state_changed.bind(player))
		player.landed.connect(_on_player_landed.bind(player))
		player.pound_landed.connect(func(_pos: Vector3) -> void:
			_queue_snap("pound_bounce", POUND_DELAY))
	if director != null and director.has_signal("seizure_changed"):
		director.connect("seizure_changed", _on_seizure_changed)


func _on_player_state_changed(new_state: int, player: PlayerBody) -> void:
	if new_state == PlayerBody.State.BUBBLED:
		_bubble_snap_armed[player.seat] = true # snap on the set-down, not the void
	elif new_state == PlayerBody.State.TOSSED:
		_queue_snap("tossed", TOSS_DELAY)


func _on_player_landed(player: PlayerBody) -> void:
	if _bubble_snap_armed.get(player.seat, false):
		_bubble_snap_armed[player.seat] = false
		_queue_snap("bubbled", BUBBLE_LAND_DELAY)


func _on_seizure_changed(seized: bool) -> void:
	if seized:
		_queue_snap("cinematic", SEIZURE_DELAY)


func _queue_snap(trigger: String, delay: float) -> void:
	if DisplayServer.get_name() == "headless":
		return # no viewport texture headless (harness.gd's own guard)
	var now: int = Time.get_ticks_msec()
	if now - _last_snap_ms < int(MIN_INTERVAL * 1000.0):
		return
	if _session_count >= SESSION_CAP:
		return
	_last_snap_ms = now # reserve immediately so overlapping triggers can't double-book
	_session_count += 1
	var timer: SceneTreeTimer = get_tree().create_timer(delay)
	timer.timeout.connect(_capture.bind(trigger))


func _capture(trigger: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		return
	if not _bright_enough(image):
		_session_count = maxi(_session_count - 1, 0) # refund the slot
		print("MEMORY_SNAP_SKIPPED %s" % JSON.stringify({"trigger": trigger, "reason": "luma_floor"}))
		return
	var index: int = _reserve_next_index()
	var path: String = "%s/memory_%d.png" % [PHOTOS_DIR, index]
	WorkerThreadPool.add_task(func() -> void:
		var err: Error = image.save_png(path)
		if err == OK:
			print("MEMORY_SNAP %s" % JSON.stringify({"trigger": trigger, "path": path}))
	)
	_prune_pool()


## A keepsake must contain something to see: probe a 32x18 downsample and
## require one genuinely lit region (peak) and a non-black frame (mean).
func _bright_enough(image: Image) -> bool:
	var probe: Image = image.duplicate()
	probe.resize(32, 18, Image.INTERPOLATE_BILINEAR)
	var peak: float = 0.0
	var total: float = 0.0
	for y: int in range(probe.get_height()):
		for x: int in range(probe.get_width()):
			var c: Color = probe.get_pixel(x, y)
			var luma: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			peak = maxf(peak, luma)
			total += luma
	var mean: float = total / float(probe.get_width() * probe.get_height())
	return peak >= PEAK_LUMA_FLOOR and mean >= MEAN_LUMA_FLOOR


func _reserve_next_index() -> int:
	if _next_index < 0:
		DirAccess.make_dir_recursive_absolute(PHOTOS_DIR)
		var highest: int = 0
		for file: String in DirAccess.get_files_at(PHOTOS_DIR):
			if file.begins_with("memory_") and file.ends_with(".png"):
				highest = maxi(highest, file.trim_prefix("memory_").trim_suffix(".png").to_int())
		_next_index = highest + 1
	var reserved: int = _next_index
	_next_index += 1
	return reserved


## _prune_pool — keep the memory_ pool bounded; NEVER touches photo_*.png
## (the family's deliberate shots are sacred; candids are replaceable).
func _prune_pool() -> void:
	var indices: Array[int] = []
	for file: String in DirAccess.get_files_at(PHOTOS_DIR):
		if file.begins_with("memory_") and file.ends_with(".png"):
			indices.append(file.trim_prefix("memory_").trim_suffix(".png").to_int())
	if indices.size() <= POOL_CAP:
		return
	indices.sort()
	for i: int in range(indices.size() - POOL_CAP):
		DirAccess.remove_absolute("%s/memory_%d.png" % [PHOTOS_DIR, indices[i]])
