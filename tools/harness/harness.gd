extends Node
## Harness — the autoplay/receipt harness (SPEC.md "Autoplay harness", D11).
## Owns tools/harness/** only; never touches core/**, scenes/**, worlds/**,
## or project.godot. Everything below reaches the game through the
## documented autoload/signal/group surface, never by editing another
## agent's files.
##
## Two-phase boot:
##   `_init()` — flags + seed only, no tree/other-autoload access (this
##   Node's `_init()` runs before the scene tree exists, so boot.gd can
##   read `Harness.flags` on frame one, per the existing contract).
##   `_ready()` — everything that needs the tree or a sibling autoload
##   (InputRouter/GameState), deferred one step further where noted.
##
## KNOWN ORDERING NOTE: project.godot registers Harness LAST among autoloads
## (GameState, InputRouter, AudioManager, SaveManager, TheMoon, Harness), so
## `--seed=N` cannot retroactively seed any randomness an earlier autoload's
## own `_init()`might already have consumed. None of the current autoloads
## use randomness at `_init()`/`_ready()` time (checked), so this is a latent
## constraint, not an active bug — flagging it since reordering autoloads is
## a project.godot edit, out of scope here.
##
## Determinism contract: every emitted line's "when" comes from
## `Engine.get_physics_frames()` only — never a wall-clock read (no
## `Time.*`, no `OS.get_ticks_msec()`) — so events.jsonl is byte-identical
## run to run under `--fixed-fps` (see docs/verify/harness-VERIFY.md).
##
## MOON_SAID / RESCUE / WARP / TOSS lines are printed directly by their
## owning systems (TheMoon, the core-feel agent's rescue/carry code) via
## plain `print()`. GDScript has no engine-wide print-interception hook, and
## adding one would mean editing those files (or project.godot for
## boot-time file logging) — both out of bounds for this harness. Those
## lines still land in the process's stdout exactly as before; for a
## complete transcript alongside events.jsonl, pass Godot's own native
## `--log-file <path>` engine flag (verified real flag, see README.md) —
## that captures everything at the OS/engine level regardless of which
## script printed it, with no collision with events.jsonl as long as the
## two paths differ.

var flags: Dictionary = {}

var _outdir_abs: String = ""
var _log_file: FileAccess = null

var _quit_requested: bool = false

var _script_description: String = ""
var _pending_events: Array = []
var _event_cursor: int = 0
var _playback_start_frame: int = 0

var _shot_frames: Dictionary = {} # frame:int -> true; erased once captured

var _connected_player_ids: Dictionary = {} # instance_id:int -> true


func _init() -> void:
	_parse_flags()
	_apply_seed()
	_resolve_outdir()
	_emit("HARNESS_FLAGS %s" % JSON.stringify(flags))


func _ready() -> void:
	_playback_start_frame = Engine.get_physics_frames()
	_parse_shots()
	_setup_quitafter_fallback()
	get_tree().physics_frame.connect(_on_physics_frame)
	# Deferred: touches other autoloads / the live tree, so it runs after
	# this frame's setup has fully settled rather than mid-boot.
	call_deferred("_connect_gamestate_signals")
	call_deferred("_watch_players")
	call_deferred("_apply_pads_override")
	call_deferred("_load_script_if_flagged")


func flag(flag_name: String, default: Variant = null) -> Variant:
	return flags.get(flag_name, default)


# ---------------------------------------------------------------------------
# Flags / seed / outdir / shots
# ---------------------------------------------------------------------------

func _parse_flags() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var key: String = arg.trim_prefix("--")
		var value: Variant = true
		if key.contains("="):
			var parts: PackedStringArray = key.split("=", true, 1)
			key = parts[0]
			value = parts[1]
		flags[key] = value


func _apply_seed() -> void:
	if not flags.has("seed"):
		return
	seed(int(flags["seed"])) # global RNG (randi/randf/…) — deterministic replay


func _resolve_outdir() -> void:
	var outdir_flag: String = str(flags.get("outdir", ""))
	if outdir_flag.is_empty():
		return
	var base: String = ProjectSettings.globalize_path("res://")
	_outdir_abs = base.path_join(outdir_flag)


func _parse_shots() -> void:
	var shots_flag: String = str(flags.get("shots", ""))
	if shots_flag.is_empty():
		return
	for token: String in shots_flag.split(",", false):
		if token.is_valid_int():
			_shot_frames[int(token)] = true
		else:
			_emit("HARNESS_NOTE ignoring malformed --shots frame token: %s" % token)


# ---------------------------------------------------------------------------
# --pads=0|1|2 (simulated seat count)
# ---------------------------------------------------------------------------

func _apply_pads_override() -> void:
	if not flags.has("pads"):
		return
	var pads_value: int = int(flags["pads"])
	if InputRouter.has_method("force_mode"):
		InputRouter.call("force_mode", pads_value)
		_emit("HARNESS_NOTE pads override applied via InputRouter.force_mode(%d)" % pads_value)
	else:
		_emit(
			"HARNESS_NOTE pads flag pending integration (InputRouter.force_mode not found) — requested pads=%d"
			% pads_value
		)


# ---------------------------------------------------------------------------
# --script=<path> input playback
# ---------------------------------------------------------------------------

func _load_script_if_flagged() -> void:
	if not flags.has("script"):
		return
	var script_path: String = str(flags["script"])
	var res_path: String = script_path if script_path.begins_with("res://") else "res://" + script_path

	if not FileAccess.file_exists(res_path):
		push_error("Harness: --script path not found: %s" % res_path)
		_emit("HARNESS_NOTE script not found: %s" % res_path)
		return

	var file: FileAccess = FileAccess.open(res_path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("events"):
		push_error("Harness: --script JSON malformed (expected {description, events}): %s" % res_path)
		_emit("HARNESS_NOTE script malformed: %s" % res_path)
		return

	var parsed_dict: Dictionary = parsed as Dictionary
	_script_description = str(parsed_dict.get("description", ""))

	var events: Array = (parsed_dict["events"] as Array).duplicate()
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("frame", 0)) < int(b.get("frame", 0))
	)
	_pending_events = events
	_event_cursor = 0
	_emit(
		"HARNESS_NOTE script loaded: %s (%d events) - %s"
		% [res_path, _pending_events.size(), _script_description]
	)


func _on_physics_frame() -> void:
	var elapsed: int = Engine.get_physics_frames() - _playback_start_frame
	_execute_due_events(elapsed)
	_maybe_capture_shot(elapsed)


func _execute_due_events(elapsed: int) -> void:
	# `<=` (not `==`) so a tick the signal handler missed still fires late
	# rather than silently dropping the event.
	while _event_cursor < _pending_events.size():
		var event: Dictionary = _pending_events[_event_cursor]
		if int(event.get("frame", 0)) > elapsed:
			break
		_execute_event(event)
		_event_cursor += 1


func _execute_event(event: Dictionary) -> void:
	var seat: int = int(event.get("seat", 1))
	var action_name: String = str(event.get("action", ""))
	var prefix: String = "p%d_" % seat

	if action_name == "move":
		var vec: Array = event.get("vec", [0.0, 0.0])
		var vx: float = float(vec[0]) if vec.size() > 0 else 0.0
		var vy: float = float(vec[1]) if vec.size() > 1 else 0.0
		# negative y = up/forward (-Z); release the opposite action first.
		_apply_move_component(prefix + "move_left", prefix + "move_right", vx)
		_apply_move_component(prefix + "move_up", prefix + "move_down", vy)
	elif action_name.is_empty():
		push_error("Harness: script event missing 'action': %s" % JSON.stringify(event))
	else:
		var full_action: String = prefix + action_name
		var event_type: String = str(event.get("type", "press"))
		if event_type == "press":
			Input.action_press(full_action)
		else:
			Input.action_release(full_action)

	# JSON.parse_string always yields float for JSON numbers, so echo frame/
	# seat back as int (they're always whole numbers) for a cleaner receipt;
	# "vec" stays float, correctly, since stick components are fractional.
	var log_event: Dictionary = event.duplicate()
	if log_event.has("frame"):
		log_event["frame"] = int(log_event["frame"])
	if log_event.has("seat"):
		log_event["seat"] = int(log_event["seat"])
	_emit("HARNESS_EVENT %s" % JSON.stringify(log_event))


func _apply_move_component(neg_action: String, pos_action: String, value: float) -> void:
	if value < 0.0:
		Input.action_release(pos_action)
		Input.action_press(neg_action, clamp(absf(value), 0.0, 1.0))
	elif value > 0.0:
		Input.action_release(neg_action)
		Input.action_press(pos_action, clamp(absf(value), 0.0, 1.0))
	else:
		Input.action_release(neg_action)
		Input.action_release(pos_action)


# ---------------------------------------------------------------------------
# --shots=N,M,…
# ---------------------------------------------------------------------------

func _maybe_capture_shot(elapsed: int) -> void:
	if not _shot_frames.has(elapsed):
		return
	_shot_frames.erase(elapsed)
	_capture_shot(elapsed) # fire-and-forget coroutine; does not block physics_frame

func _capture_shot(frame: int) -> void:
	if DisplayServer.get_name() == "headless":
		_emit("HARNESS_NOTE screenshots skipped (headless) frame=%d" % frame)
		return
	if _outdir_abs.is_empty():
		_emit("HARNESS_NOTE screenshot skipped (no --outdir given) frame=%d" % frame)
		return

	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _outdir_abs.path_join("shot_%d.png" % frame)
	var err: Error = image.save_png(path)
	if err == OK:
		_emit("HARNESS_NOTE screenshot saved %s" % path)
	else:
		_emit("HARNESS_NOTE screenshot save failed (err=%d) %s" % [err, path])


# ---------------------------------------------------------------------------
# Event log: GameState progress signals + every PlayerBody's jumped/landed
# ---------------------------------------------------------------------------

func _connect_gamestate_signals() -> void:
	if not GameState.dreamling_collected.is_connected(_on_dreamling_collected):
		GameState.dreamling_collected.connect(_on_dreamling_collected)
	if not GameState.dream_returned.is_connected(_on_dream_returned):
		GameState.dream_returned.connect(_on_dream_returned)
	if not GameState.world_completed.is_connected(_on_world_completed):
		GameState.world_completed.connect(_on_world_completed)


func _on_dreamling_collected(world_id: String, id: String) -> void:
	_emit_evt("dreamling_collected", {"world_id": world_id, "id": id})


func _on_dream_returned(world_id: String, id: String) -> void:
	_emit_evt("dream_returned", {"world_id": world_id, "id": id})


func _on_world_completed(world_id: String) -> void:
	_emit_evt("world_completed", {"world_id": world_id})


func _watch_players() -> void:
	_scan_for_players(get_tree().root)
	if not get_tree().node_added.is_connected(_on_node_added):
		# Catches every future scene load (rescan-on-scene-change), not just
		# whatever already exists at this deferred call.
		get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is PlayerBody:
		_connect_player(node as PlayerBody)


func _scan_for_players(node: Node) -> void:
	if node is PlayerBody:
		_connect_player(node as PlayerBody)
	for child: Node in node.get_children():
		_scan_for_players(child)


func _connect_player(player: PlayerBody) -> void:
	var id: int = player.get_instance_id()
	if _connected_player_ids.has(id):
		return
	_connected_player_ids[id] = true
	player.jumped.connect(_on_player_jumped.bind(player))
	player.landed.connect(_on_player_landed.bind(player))


func _on_player_jumped(player: PlayerBody) -> void:
	_emit_evt("jumped", {"seat": player.seat})


func _on_player_landed(player: PlayerBody) -> void:
	_emit_evt("landed", {"seat": player.seat})


func _emit_evt(evt_type: String, extra: Dictionary) -> void:
	var payload: Dictionary = {"t": Engine.get_physics_frames(), "type": evt_type}
	for key: String in extra.keys():
		payload[key] = extra[key]
	_emit("EVT %s" % JSON.stringify(payload))


# ---------------------------------------------------------------------------
# --quitafter=SECONDS fallback (main.gd already honors it for scenes.tscn=
# main; this makes it work from ANY scene, e.g. still sitting on title)
# ---------------------------------------------------------------------------

func _setup_quitafter_fallback() -> void:
	if not flags.has("quitafter"):
		return
	var seconds: float = float(flags["quitafter"])
	var timer: SceneTreeTimer = get_tree().create_timer(seconds)
	timer.timeout.connect(_on_quitafter_fallback)


func _on_quitafter_fallback() -> void:
	if _quit_requested:
		return
	_quit_requested = true
	_emit("HARNESS_NOTE quitafter fallback fired (harness-level timer, %.1fs)" % float(flags["quitafter"]))
	get_tree().quit()


# ---------------------------------------------------------------------------
# Shared emit: stdout + (if --outdir) mirrored into events.jsonl
# ---------------------------------------------------------------------------

func _emit(line: String) -> void:
	print(line)
	_mirror_to_file(line)


func _mirror_to_file(line: String) -> void:
	if _outdir_abs.is_empty():
		return
	if _log_file == null:
		var made: Error = DirAccess.make_dir_recursive_absolute(_outdir_abs)
		if made != OK and not DirAccess.dir_exists_absolute(_outdir_abs):
			push_error("Harness: could not create --outdir %s (error %d)" % [_outdir_abs, made])
			_outdir_abs = "" # stop retrying every subsequent line
			return
		_log_file = FileAccess.open(_outdir_abs.path_join("events.jsonl"), FileAccess.WRITE)
		if _log_file == null:
			push_error("Harness: could not open events.jsonl for write in %s" % _outdir_abs)
			_outdir_abs = ""
			return
	_log_file.store_line(line)
	_log_file.flush() # receipts must survive a crash
