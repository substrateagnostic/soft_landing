extends Node3D
## Main — the play scene. Loads a world into WorldSlot (or a grey-box
## fallback if the world module isn't built yet), places both players at the
## world's spawn points, wires world-contract signals to GameState, and
## stands up a placeholder follow camera if no CameraRig exists under
## CameraRigSlot yet (the camera agent supplies the real rig).

const FALLBACK_WORLD_ID: String = "pillow_fort"
const FALLBACK_SPAWN_PIP: Vector3 = Vector3(-1.0, 0.5, 0.0)
const FALLBACK_SPAWN_OTTO: Vector3 = Vector3(1.0, 0.5, 0.0)
const FALLBACK_CAMERA_OFFSET: Vector3 = Vector3(0.0, 5.5, 8.0)
const CAMERA_FOLLOW_RATE: float = 4.0

const FALLBACK_RESCUE_FLOOR_Y: float = -10.0

@onready var _world_slot: Node3D = $WorldSlot
@onready var _pip: PlayerBody = $Players/Pip
@onready var _otto: PlayerBody = $Players/Otto
@onready var _camera_rig_slot: Node3D = $CameraRigSlot
@onready var _seat_manager: SeatManager = $SeatManager
@onready var _soft_landing: SoftLanding = $SoftLanding
@onready var _game_ui: GameUI = $GameUI

var _world: Node3D = null
var _fallback_camera: Camera3D = null


func _ready() -> void:
	_ensure_moonlight()
	var world_id: String = str(Harness.flags.get("world", FALLBACK_WORLD_ID))
	_load_world(world_id)
	_place_players()
	_setup_camera()
	_setup_coop()
	_setup_quitafter()
	TheMoon.say("new_area")


func _load_world(world_id: String) -> void:
	var scene_path: String = "res://worlds/%s/%s.tscn" % [world_id, world_id]
	if ResourceLoader.exists(scene_path):
		var packed: PackedScene = load(scene_path)
		_world = packed.instantiate()
		_world_slot.add_child(_world)
		if _world.has_signal("objective_collected"):
			_world.objective_collected.connect(_on_objective_collected)
		if _world.has_signal("objective_returned"):
			_world.objective_returned.connect(_on_objective_returned)
		if _world.has_signal("exit_requested_to"):
			_world.exit_requested_to.connect(_switch_world)
		elif _world.has_signal("exit_requested"):
			_world.exit_requested.connect(_on_exit_requested)
		if _world.has_method("world_id"):
			GameState.set_current_world(_world.world_id())
	else:
		print("Main: world scene not found (%s), spawning grey-box fallback" % scene_path)
		_spawn_fallback_world()
		GameState.set_current_world(world_id)

	_update_hud()


## _update_hud — HUD's per-world objective list (D12 pips + numeral). A
## grey-box fallback world (or any world with no objectives, e.g. the
## fort) has none, so the HUD hides itself (hud.gd's own contract).
func _update_hud() -> void:
	var objective_ids: Array[String] = []
	if _world != null and _world.has_method("objective_ids"):
		objective_ids = _world.objective_ids()
	_game_ui.setup_hud(GameState.current_world_id, objective_ids)


## The lullaby grows as dreams come home (PITCH §Audio): layer 1 from the
## first visit, 2 at ≥1 returned, 3 at ≥5, 4 when the world is complete —
## same thresholds as fort growth. Worlds without stem files no-op inside
## AudioManager, so unbuilt stem sets cost nothing.
func _update_stems() -> void:
	AudioManager.stop_stems()
	var world_id: String = GameState.current_world_id
	var returned: int = GameState.returned_count(world_id)
	var layers: int = 1
	if returned >= 1:
		layers = 2
	if returned >= 5:
		layers = 3
	if returned >= 10:
		layers = 4
	for layer: int in range(1, layers + 1):
		AudioManager.play_stem_layer(world_id, layer)


func _spawn_fallback_world() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.55, 0.55, 0.55)
	plane.material = floor_mat

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "FallbackFloor"
	floor_mesh.mesh = plane
	_world_slot.add_child(floor_mesh)

	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 0.1, 40.0)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = box
	floor_shape.position = Vector3(0.0, -0.05, 0.0)

	var floor_body := StaticBody3D.new()
	floor_body.name = "FallbackFloorBody"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.add_child(floor_shape)
	_world_slot.add_child(floor_body)


func _ensure_moonlight() -> void:
	if has_node("Moonlight"):
		return
	var light := DirectionalLight3D.new()
	light.name = "Moonlight"
	light.light_color = Color(0.82, 0.84, 1.0)
	light.light_energy = 0.85
	light.shadow_enabled = true
	light.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	add_child(light)


func _place_players() -> void:
	var points: Dictionary = {}
	if _world != null and _world.has_method("spawn_points"):
		points = _world.spawn_points()

	if points.has("pip"):
		_pip.global_transform = points["pip"]
	else:
		_pip.global_position = FALLBACK_SPAWN_PIP

	if points.has("otto"):
		_otto.global_transform = points["otto"]
	else:
		_otto.global_position = FALLBACK_SPAWN_OTTO


func _setup_camera() -> void:
	var rig: CameraRig = _camera_rig_slot.get_node_or_null("CameraRig") as CameraRig
	if rig != null:
		rig.register_players(_pip, _otto)
		rig.set_solo(not InputRouter.is_coop())
		return # camera agent's rig takes over; no fallback camera needed

	_fallback_camera = Camera3D.new()
	_fallback_camera.name = "FallbackCamera"
	_camera_rig_slot.add_child(_fallback_camera) # must be in-tree before global_position/look_at
	_fallback_camera.global_position = _pip.global_position + FALLBACK_CAMERA_OFFSET
	_fallback_camera.current = true
	_fallback_camera.look_at(_pip.global_position + Vector3(0.0, 0.9, 0.0), Vector3.UP)


func _setup_coop() -> void:
	var carry_toss: CarryToss = _otto.get_node_or_null("CarryToss") as CarryToss
	var buddy_ai: BuddyAI = _otto.get_node_or_null("BuddyAI") as BuddyAI
	var camera_rig: CameraRig = _camera_rig_slot.get_node_or_null("CameraRig") as CameraRig

	if carry_toss != null:
		carry_toss.setup(_pip, _otto)
	if buddy_ai != null and _seat_manager != null:
		buddy_ai.setup(_pip, _otto, _seat_manager)
	if _seat_manager != null:
		_seat_manager.setup(_pip, _otto, camera_rig, buddy_ai, carry_toss)

	if _soft_landing != null:
		_soft_landing.setup(_pip, _otto)
		_soft_landing.reset_history(_pip.global_position, _otto.global_position)
		if _world != null and _world.has_method("rescue_floor_y"):
			_soft_landing.rescue_floor_y = _world.rescue_floor_y()
		else:
			_soft_landing.rescue_floor_y = FALLBACK_RESCUE_FLOOR_Y


func _physics_process(delta: float) -> void:
	if _fallback_camera == null or not is_instance_valid(_pip):
		return
	var target: Vector3 = _pip.global_position + FALLBACK_CAMERA_OFFSET
	var weight: float = 1.0 - exp(-CAMERA_FOLLOW_RATE * delta)
	_fallback_camera.global_position = _fallback_camera.global_position.lerp(target, weight)
	_fallback_camera.look_at(_pip.global_position + Vector3(0.0, 0.9, 0.0), Vector3.UP)


func _setup_quitafter() -> void:
	var quitafter: Variant = Harness.flags.get("quitafter", null)
	if quitafter == null:
		return
	var seconds: float = float(quitafter)
	var timer: SceneTreeTimer = get_tree().create_timer(seconds)
	timer.timeout.connect(func() -> void: get_tree().quit())


func _on_objective_collected(id: String) -> void:
	GameState.collect(GameState.current_world_id, id)


func _on_objective_returned(id: String) -> void:
	GameState.return_dream(GameState.current_world_id, id)


func _on_exit_requested() -> void:
	# Two worlds in the v0.1 slice — the door always leads to the other one.
	var target: String = "bramble" if GameState.current_world_id == "pillow_fort" else "pillow_fort"
	_switch_world(target)


func _switch_world(world_id: String) -> void:
	if _world != null:
		_world.queue_free()
		_world = null
	_load_world(world_id)
	_place_players()
	# Re-wire the pieces that cache per-world state; players/camera/coop
	# survive the swap untouched.
	if _soft_landing != null:
		# Stale safe-ground history from the previous world = bubble-loop
		# soft-lock over the new world's void (Opus review, finding #1).
		_soft_landing.reset_history(_pip.global_position, _otto.global_position)
		if _world != null and _world.has_method("rescue_floor_y"):
			_soft_landing.rescue_floor_y = _world.rescue_floor_y()
		else:
			_soft_landing.rescue_floor_y = FALLBACK_RESCUE_FLOOR_Y
	TheMoon.say("new_area")
