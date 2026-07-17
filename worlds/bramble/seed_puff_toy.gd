class_name SeedPuffToy
extends Node3D
## SeedPuffToy — D26 joy pass #8 (NEXT_STEPS.md §1b, "seed-puff toys: 3-4
## seed_puff props on ledges that burst into a puff of drifting seeds when
## pound-bounced near"). Listens for core/movement/player_body.gd's
## `pound_landed(position: Vector3)` signal — an INSTANCE signal (each
## PlayerBody has its own, not a global/autoload one), so this connects to
## every PlayerBody found in the "players" group, the same discovery pattern
## rollover_sequence.gd's `_bubble_all_players()` already uses. Re-scans on
## every physics tick (cheap: get_nodes_in_group over 2 players) so a player
## who wasn't in the tree yet at this node's own _ready() still gets
## connected once they spawn.
##
## Visual: the existing "seed_puff" ModelSlot (assets/models/meshy/generated/
## seed_puff.glb, already used decoratively elsewhere in this world's
## _build_dressing()) — same primitive-fallback contract, just made
## interactive here.

const BURST_RADIUS: float = 3.5
const COOLDOWN: float = 1.0
const PRIMITIVE_RADIUS: float = 0.17
const MODEL_HEIGHT: float = 0.35
const PARTICLE_COLOR: Color = Color("F5F2E8") # ART_BIBLE.md milk/seed tone

var _connected: Array[PlayerBody] = []
var _cooldown: float = 0.0
var _particles: GPUParticles3D = null


func _ready() -> void:
	_build_visual()
	_build_particles()
	_connect_players()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_connect_players() # a player may spawn/join after this node's own _ready()


func _connect_players() -> void:
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: PlayerBody = node as PlayerBody
		if player == null or _connected.has(player):
			continue
		player.pound_landed.connect(_on_pound_landed)
		_connected.append(player)


func _on_pound_landed(pos: Vector3) -> void:
	if _cooldown > 0.0:
		return
	if pos.distance_to(global_position) > BURST_RADIUS:
		return
	_cooldown = COOLDOWN
	_burst()


func _burst() -> void:
	print("SEED_PUFF %s" % JSON.stringify({"event": "burst", "pos": [global_position.x, global_position.y, global_position.z]}))
	_particles.restart()
	_particles.emitting = true
	AudioManager.play_sfx("seed_puff_burst") # fails soft (AudioManager convention) until an asset lands


func _build_visual() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = PRIMITIVE_RADIUS
	mesh.height = PRIMITIVE_RADIUS * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PARTICLE_COLOR
	mesh.material = mat

	var primitive := MeshInstance3D.new()
	primitive.name = "Primitive"
	primitive.mesh = mesh
	primitive.position = Vector3(0.0, PRIMITIVE_RADIUS, 0.0)
	add_child(primitive)

	var slot := ModelSlot.new()
	slot.name = "ModelSlot"
	slot.model_id = "seed_puff"
	slot.target_height = MODEL_HEIGHT
	add_child(slot)


func _build_particles() -> void:
	_particles = ParticlePresets.make_ambient_glow(
		"SeedBurst", 22, 1.4, PARTICLE_COLOR,
		Vector3(0.25, 0.25, 0.25), 1.0, false, Vector3(0.0, 0.55, 0.0), 0.45
	)
	_particles.position = Vector3(0.0, 0.3, 0.0)
	_particles.emitting = false
	_particles.one_shot = true
	add_child(_particles)
