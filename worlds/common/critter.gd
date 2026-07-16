class_name Critter
extends Node3D
## Critter — cheap ambient wildlife (aliveness_wow.md §2/§5, Top 12 item #5:
## "one AmbientCritter system, four skins"). No pathfinding, no physics
## body, no collision -- purely decorative, so it can never block a player
## or gate anything (D21/D23 floor). Three states:
##   IDLE_WANDER  — small lerp-hops within wander_radius of its spawn point.
##   SCATTER      — a player closed within scatter_radius: flutters/runs
##                  directly away from the nearest player.
##   RETURN       — player backed off far enough: eases home, then resumes
##                  wandering.
## Spawned in bulk by worlds/common/world_base.gd from
## data/critters/<world_id>.json (kind/count/center/spread). Re-skinned via
## `kind` ("moth" | "mouse") -- one script, two cheap primitive-mesh looks;
## Meshy models arrive in a later pass (M2) behind the same `kind` seam.

signal scattered

enum State { IDLE, SCATTER, RETURN }

const PLAYERS_GROUP: String = "players"
const SCATTER_RADIUS: float = 2.0
const SCATTER_EXIT_MULT: float = 1.6 # hysteresis: only stop fleeing once well clear
const SCATTER_SPEED: float = 4.0
const WANDER_SPEED: float = 0.6
const RETURN_SPEED_MULT: float = 1.5
const WANDER_RADIUS: float = 1.5
const HOP_INTERVAL_MIN: float = 1.2
const HOP_INTERVAL_MAX: float = 2.6
const RETURN_SETTLE_DISTANCE: float = 0.15
const SCATTER_EVENT_COOLDOWN: float = 3.0 # rate-limits the EVT receipt, not the flee itself
const FLAP_HZ: float = 10.0
const WING_SIDES: Array = [-1.0, 1.0]

@export var kind: String = "moth" # "moth" | "mouse"
## Set by world_base.gd BEFORE add_child (the codebase's established-safe
## ordering, since _ready() is never synchronous inside add_child() --
## see bramble.gd's breathing_chest.gd / tail_bridge.gd comments). NOT read
## from GameState.current_world_id in _ready(): that autoload's write isn't
## guaranteed to have landed yet relative to world instantiation (caught
## live -- a first boot printed `"world":""` on a critter_scatter receipt
## before this fix).
@export var world_id: String = ""

var _home: Vector3 = Vector3.ZERO
var _state: State = State.IDLE
var _hop_timer: float = 0.0
var _hop_target: Vector3 = Vector3.ZERO
var _flap_phase: float = randf() * TAU
var _scatter_event_cooldown: float = 0.0
var _visual: Node3D = null


func _ready() -> void:
	add_to_group("critter")
	_home = position
	_build_visual()
	_pick_new_hop_target()


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	if kind == "mouse":
		_build_mouse(_visual)
	else:
		_build_moth(_visual)


## Two flapping quads (wings) + a small glow sprite (body) -- no textures,
## grey-box primitives per AGENTS.md until Meshy assets land.
func _build_moth(parent: Node3D) -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.05
	body_mesh.height = 0.1
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("F5F2E8")
	body_mat.emission_enabled = true
	body_mat.emission = Color("FFF3C4")
	body_mat.emission_energy_multiplier = 1.2
	body_mesh.material = body_mat
	body.mesh = body_mesh
	parent.add_child(body)

	for side: float in WING_SIDES:
		var wing := MeshInstance3D.new()
		wing.name = "Wing_%s" % ("L" if side < 0.0 else "R")
		var wing_mesh := QuadMesh.new()
		wing_mesh.size = Vector2(0.12, 0.08)
		var wing_mat := StandardMaterial3D.new()
		wing_mat.albedo_color = Color(0.9, 0.9, 0.85, 0.85)
		wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		wing_mesh.material = wing_mat
		wing.mesh = wing_mesh
		wing.position = Vector3(0.06 * side, 0.0, 0.0)
		parent.add_child(wing)


## Capsule body + two small ears, per the brief's "meadow mouse = capsule +
## ears" spec.
func _build_mouse(parent: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8A6552")

	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.09
	body_mesh.height = 0.22
	body_mesh.material = mat
	body.mesh = body_mesh
	body.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	parent.add_child(body)

	for side: float in WING_SIDES:
		var ear := MeshInstance3D.new()
		ear.name = "Ear_%s" % ("L" if side < 0.0 else "R")
		var ear_mesh := SphereMesh.new()
		ear_mesh.radius = 0.035
		ear_mesh.height = 0.07
		ear_mesh.material = mat
		ear.mesh = ear_mesh
		ear.position = Vector3(0.05 * side, 0.09, 0.08)
		parent.add_child(ear)


func _physics_process(delta: float) -> void:
	_scatter_event_cooldown = max(_scatter_event_cooldown - delta, 0.0)
	match _state:
		State.IDLE:
			_process_idle(delta)
		State.SCATTER:
			_process_scatter(delta)
		State.RETURN:
			_process_return(delta)
	_animate_flap(delta)


func _nearest_player_distance() -> float:
	var best: float = INF
	for node: Node in get_tree().get_nodes_in_group(PLAYERS_GROUP):
		var player: Node3D = node as Node3D
		if player == null:
			continue
		best = min(best, player.global_position.distance_to(global_position))
	return best


func _process_idle(delta: float) -> void:
	if _nearest_player_distance() < SCATTER_RADIUS:
		_enter_scatter()
		return
	_hop_timer -= delta
	if _hop_timer <= 0.0:
		_pick_new_hop_target()
	position = position.lerp(_hop_target, WANDER_SPEED * delta)


func _pick_new_hop_target() -> void:
	_hop_timer = randf_range(HOP_INTERVAL_MIN, HOP_INTERVAL_MAX)
	var offset: Vector2 = Vector2(randf_range(-WANDER_RADIUS, WANDER_RADIUS), randf_range(-WANDER_RADIUS, WANDER_RADIUS))
	_hop_target = _home + Vector3(offset.x, 0.0, offset.y)


func _enter_scatter() -> void:
	_state = State.SCATTER
	scattered.emit()
	# audio v2: positional per-kind flee sound -- fires only on genuine
	# IDLE/RETURN -> SCATTER transitions (the state machine itself already
	# gates this, see the doc comment above), never every frame while
	# already fleeing.
	var sfx: String = "moth_flutter" if kind == "moth" else "mouse_squeak"
	PositionalAudio.play_at(sfx, global_position)
	if _scatter_event_cooldown <= 0.0:
		_scatter_event_cooldown = SCATTER_EVENT_COOLDOWN
		print("EVT %s" % JSON.stringify({"type": "critter_scatter", "world": world_id, "kind": kind, "t": Engine.get_physics_frames()}))


func _process_scatter(delta: float) -> void:
	var nearest_dist: float = INF
	var away: Vector3 = Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group(PLAYERS_GROUP):
		var player: Node3D = node as Node3D
		if player == null:
			continue
		var dist: float = player.global_position.distance_to(global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			away = global_position - player.global_position
	if nearest_dist == INF or nearest_dist > SCATTER_RADIUS * SCATTER_EXIT_MULT:
		_state = State.RETURN
		return
	away.y = 0.0
	if away.length() > 0.01:
		position += away.normalized() * SCATTER_SPEED * delta


func _process_return(delta: float) -> void:
	if _nearest_player_distance() < SCATTER_RADIUS:
		_enter_scatter()
		return
	position = position.lerp(_home, WANDER_SPEED * RETURN_SPEED_MULT * delta)
	if position.distance_to(_home) < RETURN_SETTLE_DISTANCE:
		_state = State.IDLE
		_pick_new_hop_target()


func _animate_flap(delta: float) -> void:
	if kind != "moth" or _visual == null:
		return
	_flap_phase = fmod(_flap_phase + delta * FLAP_HZ, TAU)
	var flap: float = sin(_flap_phase) * 0.5
	for child: Node in _visual.get_children():
		if String(child.name).begins_with("Wing_"):
			(child as Node3D).rotation.z = flap * (1.0 if String(child.name).ends_with("R") else -1.0)
