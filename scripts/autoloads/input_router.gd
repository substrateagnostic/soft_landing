extends Node
## InputRouter — pad enumeration, seat assignment, co-op/solo mode, hot-swap
## (SPEC.md). Actions are declared in project.godot as p1_*/p2_*, pre-bound
## to joypad device 0/1; on connect/disconnect this rebinds each action's
## live InputMap joypad events to whichever physical device now holds that
## seat, so "seat 1" always tracks the first connected pad and "seat 2" the
## second — no code elsewhere needs to know real device indices.
## Keyboard fallback events (p2 only, D8) are never touched here, so they
## always augment P2 regardless of pad state.
##
## D27 — ACTIVITY-GATED CO-OP (producer playtest, 2026-07-17): merely
## *enumerating* two joypads no longer enters co-op. Steam Input, wireless
## receivers, and DS4-style remappers all enumerate phantom pads, and a
## phantom second seat trapped the producer in co-op with a statue partner
## (camera dragged toward an inert Otto, no buddy AI, warp loop). Now the
## second seat's device must show REAL input — a button press, or a stick
## pushed past 0.6 — before co-op begins. Ghost pads never press anything;
## a real sibling picking up the pad mid-game hot-joins wordlessly (the
## split screen slides in — no menu, no reading, per the design floor).
## Trigger axes are deliberately excluded from the activity check: idle
## Xbox triggers report -1.0 on some drivers and would false-join.
## The pause menu's "Players" row calls set_player_count() as the explicit
## parent-facing override in both directions (including pad+keyboard co-op,
## since P2's keyboard fallback makes the keyboard a real second seat).
## Every enumeration change prints a PADS receipt with device names/GUIDs
## so a phantom device can be identified by name in the console.

enum Mode { COOP, SOLO }

signal mode_changed(mode: int)
signal seat_assigned(seat: int, device: int)

const SEAT_ACTIONS: Dictionary = {
	1: ["p1_move_left", "p1_move_right", "p1_move_up", "p1_move_down", "p1_jump", "p1_interact"],
	2: ["p2_move_left", "p2_move_right", "p2_move_up", "p2_move_down", "p2_jump", "p2_interact"],
}

const ACTIVITY_AXIS_MAX: int = 3 # left/right stick axes only — never triggers (see class doc)
const ACTIVITY_AXIS_THRESHOLD: float = 0.6

var mode: Mode = Mode.SOLO
var seat_devices: Dictionary = {1: -1, 2: -1} # seat -> joypad device index, -1 = unassigned
var _mode_forced: bool = false # harness --pads override; pad hot-swap won't fight it
var _seat2_active: bool = false # D27: second seat has shown real input this session


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_reassign_seats()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_reassign_seats()


## _input — the D27 activity gate. Watches raw joypad events for the seat-2
## device's first real input and promotes to co-op when it arrives.
func _input(event: InputEvent) -> void:
	if _seat2_active or _mode_forced:
		return
	var seat2_device: int = seat_devices.get(2, -1)
	if seat2_device < 0:
		return
	if event is InputEventJoypadButton and event.device == seat2_device and event.pressed:
		_mark_seat2_active()
	elif event is InputEventJoypadMotion and event.device == seat2_device:
		var motion := event as InputEventJoypadMotion
		if motion.axis <= ACTIVITY_AXIS_MAX and absf(motion.axis_value) > ACTIVITY_AXIS_THRESHOLD:
			_mark_seat2_active()


func _mark_seat2_active() -> void:
	_seat2_active = true
	print("SEAT2_JOINED %s" % JSON.stringify({"device": seat_devices.get(2, -1)}))
	_recompute_mode()


func _reassign_seats() -> void:
	var pads: Array = Input.get_connected_joypads()
	pads.sort()

	var device_for_seat: Dictionary = {1: -1, 2: -1}
	if pads.size() >= 1:
		device_for_seat[1] = pads[0]
	if pads.size() >= 2:
		device_for_seat[2] = pads[1]

	for seat: int in device_for_seat.keys():
		var device: int = device_for_seat[seat]
		if seat_devices[seat] != device:
			seat_devices[seat] = device
			_rebind_seat(seat, device)
			seat_assigned.emit(seat, device)

	# Receipt: every enumerated device by name, so a phantom pad (Steam
	# Input virtual device, idle wireless receiver...) is identifiable.
	var listing: Array = []
	for device: int in pads:
		listing.append({
			"device": device,
			"name": Input.get_joy_name(device),
			"guid": Input.get_joy_guid(device),
		})
	print("PADS %s" % JSON.stringify({"connected": listing, "seats": seat_devices}))

	# Losing the second seat's device also revokes its joined state — a
	# fresh press is required after any reconnect.
	if seat_devices.get(2, -1) < 0:
		_seat2_active = false
	_recompute_mode()


func _recompute_mode() -> void:
	if _mode_forced:
		return
	var new_mode: Mode = Mode.COOP if _seat2_active else Mode.SOLO
	if new_mode != mode:
		mode = new_mode
		mode_changed.emit(mode)


## set_player_count — the pause menu's explicit override (D27), both
## directions. 1 clears the second seat's joined state (it can re-join
## with a fresh press); 2 enters co-op even with a single pad, since P2's
## keyboard fallback bindings make the keyboard a real second seat.
func set_player_count(count: int) -> void:
	_seat2_active = count >= 2
	print("PLAYER_COUNT_SET %s" % JSON.stringify({"count": count}))
	_recompute_mode()


## Harness override (--pads=N): pins the mode regardless of physical pads,
## so scripted co-op runs work on a machine with zero controllers plugged in.
## The argument is a SIMULATED PAD COUNT (harness contract), not a Mode:
## 2+ pads -> COOP, 0 or 1 -> SOLO.
func force_mode(pad_count: int) -> void:
	_mode_forced = true
	var forced_mode: Mode = Mode.COOP if pad_count >= 2 else Mode.SOLO
	if forced_mode != mode:
		mode = forced_mode
		mode_changed.emit(mode)


func _rebind_seat(seat: int, device: int) -> void:
	# Fall back to the seat's default device slot (0 for P1, 1 for P2) when
	# unassigned, so a later reconnect at the same physical slot still works.
	var bound_device: int = device if device >= 0 else seat - 1
	for action: String in SEAT_ACTIONS[seat]:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion or event is InputEventJoypadButton:
				event.device = bound_device


func is_coop() -> bool:
	return mode == Mode.COOP


func device_for_seat(seat: int) -> int:
	return seat_devices.get(seat, -1)
