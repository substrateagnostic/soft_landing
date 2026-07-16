extends Node
## InputRouter — pad enumeration, seat assignment, co-op/solo mode, hot-swap
## (SPEC.md). Actions are declared in project.godot as p1_*/p2_*, pre-bound
## to joypad device 0/1; on connect/disconnect this rebinds each action's
## live InputMap joypad events to whichever physical device now holds that
## seat, so "seat 1" always tracks the first connected pad and "seat 2" the
## second — no code elsewhere needs to know real device indices.
## Keyboard fallback events (p2 only, D8) are never touched here, so they
## always augment P2 regardless of pad state.

enum Mode { COOP, SOLO }

signal mode_changed(mode: int)
signal seat_assigned(seat: int, device: int)

const SEAT_ACTIONS: Dictionary = {
	1: ["p1_move_left", "p1_move_right", "p1_move_up", "p1_move_down", "p1_jump", "p1_interact"],
	2: ["p2_move_left", "p2_move_right", "p2_move_up", "p2_move_down", "p2_jump", "p2_interact"],
}

var mode: Mode = Mode.SOLO
var seat_devices: Dictionary = {1: -1, 2: -1} # seat -> joypad device index, -1 = unassigned


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_reassign_seats()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_reassign_seats()


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

	var new_mode: Mode = Mode.COOP if pads.size() >= 2 else Mode.SOLO
	if new_mode != mode:
		mode = new_mode
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
