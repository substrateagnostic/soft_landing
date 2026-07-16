class_name GameUI
extends CanvasLayer
## GameUI — the single mount point for scenes/main.tscn (the "one UI
## CanvasLayer scene" main.tscn/main.gd is licensed to add): wraps HUD
## (dreamling counter) and PauseMenu (Start-button pause) as children so
## main.gd only ever talks to one node. Also owns the "pause" input action
## itself — main.gd doesn't need to know pausing exists.

@onready var _hud: HUD = $HUD
@onready var _pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	# Debug seam (docs/verify/ui-VERIFY.md §d): --debug_pause opens the
	# pause menu on boot so a windowed --shots run can screenshot it
	# without a real Start-button press, which the harness cannot script.
	# Flag-presence-only (pass bare --debug_pause, no "=value") — same
	# convention as core/rescue/soft_landing.gd's --testfall: Harness
	# stores a bare flag as a native bool, so the Variant is truthy
	# on its own; wrapping it in bool() breaks the moment anyone writes
	# "=true" instead (Harness would hand back the STRING "true", and
	# GDScript's bool() has no String constructor).
	if Harness.flag("debug_pause", false):
		_pause_menu.open()
	# --debug_options: same seam, one step further in — opens pause AND
	# switches straight to the options subpanel, so a windowed --shots run
	# can capture it without scripting focus-navigation + a button press
	# (the harness's --script format has no raw ui_* input, only p1/p2
	# actions, so there is no other way to reach this panel headlessly).
	if Harness.flag("debug_options", false):
		_pause_menu.open_to_options()
	# --debug_pause_sleep: same seam, focuses Sleep directly, so a
	# harness --script can prove the hold-to-quit gesture (see
	# pause_menu.gd's open_focus_sleep doc comment for why this exists).
	if Harness.flag("debug_pause_sleep", false):
		_pause_menu.open_focus_sleep()


func setup_hud(world_id: String, objective_ids: Array[String]) -> void:
	_hud.setup(world_id, objective_ids)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not get_tree().paused:
		_pause_menu.open()
