class_name HUD
extends CanvasLayer
## HUD — top-left dreamling counter for the CURRENT world (D12: dense
## collectibles, loud warm feedback, count as objects/pips not just a
## numeral). Built entirely in code — house pattern, see worlds/bramble.gd
## — since pip count is world-dependent. main.gd calls
## setup(world_id, objective_ids) on every world load/switch; after that,
## GameState.dreamling_collected / dream_returned signals drive live pip
## updates on their own (no per-frame world polling needed).
##
## Hidden entirely for worlds with zero objectives (the fort, for now —
## fort-growth pips are a Phase 5 follow-up, not this HUD's job).

const MARGIN: float = 20.0
const PANEL_PADDING: float = 10.0
const PIP_SPACING: float = 6.0
const NUMERAL_GAP: float = 10.0
const NUMERAL_FONT_SIZE: int = 34

const FADE_IDLE_SECONDS: float = 4.0
const FADE_DIM_ALPHA: float = 0.4
const FADE_IN_DURATION: float = 0.3
const FADE_OUT_DURATION: float = 1.0

const COLOR_PANEL_BG: Color = Color(0.180392, 0.231373, 0.368627, 0.4) # dusk blue, translucent
const COLOR_NUMERAL: Color = Color(0.960784, 0.94902, 0.909804, 1.0) # milk white

var _panel: PanelContainer = null
var _pip_row: HBoxContainer = null
var _numeral: Label = null

var _world_id: String = ""
var _pip_nodes: Dictionary = {} # id:String -> HudPip
var _pip_states: Dictionary = {} # id:String -> HudPip.PipState

var _idle_timer: float = 0.0
var _dimmed: bool = false
var _fade_tween: Tween = null


func _ready() -> void:
	layer = 5
	_build_ui()
	GameState.dreamling_collected.connect(_on_dreamling_collected)
	GameState.dream_returned.connect(_on_dream_returned)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(MARGIN, MARGIN)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.set_corner_radius_all(18)
	style.content_margin_left = PANEL_PADDING * 1.6
	style.content_margin_right = PANEL_PADDING * 1.6
	style.content_margin_top = PANEL_PADDING
	style.content_margin_bottom = PANEL_PADDING
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(NUMERAL_GAP))
	_panel.add_child(row)

	_pip_row = HBoxContainer.new()
	_pip_row.name = "PipRow"
	_pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pip_row.add_theme_constant_override("separation", int(PIP_SPACING))
	row.add_child(_pip_row)

	_numeral = Label.new()
	_numeral.name = "Numeral"
	_numeral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_numeral.text = "0"
	_numeral.add_theme_font_size_override("font_size", NUMERAL_FONT_SIZE)
	_numeral.add_theme_color_override("font_color", COLOR_NUMERAL)
	_numeral.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_numeral)


## setup — called by main.gd on every world load/switch. objective_ids is
## the world's full dreamling id list (WorldContract.objective_ids());
## empty means "no objectives here" (the fort) — HUD hides entirely.
func setup(world_id: String, objective_ids: Array[String]) -> void:
	_world_id = world_id
	_clear_pips()

	if objective_ids.is_empty():
		visible = false
		print("HUD_READY %s" % JSON.stringify({"world": world_id, "pips": 0}))
		return

	visible = true
	var returned: Array[String] = GameState.returned_ids(world_id)
	for id: String in objective_ids:
		var pip := HudPip.new()
		_pip_row.add_child(pip)
		_pip_nodes[id] = pip
		var initial_state: HudPip.PipState = (
			HudPip.PipState.RETURNED if returned.has(id) else HudPip.PipState.UNTOUCHED
		)
		_pip_states[id] = initial_state
		pip.paint(initial_state)

	_update_numeral()
	_reset_fade()
	print("HUD_READY %s" % JSON.stringify({"world": world_id, "pips": objective_ids.size()}))


func _clear_pips() -> void:
	for child: Node in _pip_row.get_children():
		child.queue_free()
	_pip_nodes.clear()
	_pip_states.clear()


func _on_dreamling_collected(world_id: String, id: String) -> void:
	_set_pip_state(world_id, id, HudPip.PipState.CARRIED)


func _on_dream_returned(world_id: String, id: String) -> void:
	_set_pip_state(world_id, id, HudPip.PipState.RETURNED)


func _set_pip_state(world_id: String, id: String, new_state: HudPip.PipState) -> void:
	if world_id != _world_id or not _pip_nodes.has(id):
		return
	if _pip_states.get(id) == new_state:
		return
	_pip_states[id] = new_state
	(_pip_nodes[id] as HudPip).animate_to(new_state)
	_update_numeral()
	_reset_fade()
	print("HUD_PIP %s" % JSON.stringify({"id": id, "state": _state_name(new_state)}))


func _state_name(state: HudPip.PipState) -> String:
	match state:
		HudPip.PipState.RETURNED:
			return "returned"
		HudPip.PipState.CARRIED:
			return "carried"
		_:
			return "untouched"


func _update_numeral() -> void:
	var count: int = 0
	for id: String in _pip_states.keys():
		if _pip_states[id] == HudPip.PipState.RETURNED:
			count += 1
	_numeral.text = str(count)


## _reset_fade — any change (setup or a live pip update) snaps the counter
## back toward full visibility and restarts the 4 s idle clock.
func _reset_fade() -> void:
	_idle_timer = 0.0
	_dimmed = false
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN_DURATION).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if not visible or _dimmed:
		return
	_idle_timer += delta
	if _idle_timer < FADE_IDLE_SECONDS:
		return
	_dimmed = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_panel, "modulate:a", FADE_DIM_ALPHA, FADE_OUT_DURATION).set_trans(Tween.TRANS_SINE)
