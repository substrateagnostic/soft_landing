class_name LandingRing
extends MeshInstance3D
## LandingRing — predicted-landing reticle (D9). Instanced under each
## character's ReadabilityAnchor. While airborne, raycasts straight down
## from the character and places an unshaded emissive ring at the hit
## point, scaling with fall height; hidden while grounded. Full contrast,
## exempt from mood/lighting rules — this is a HUD element, not a prop.

@export var min_scale: float = 0.4
@export var max_scale: float = 0.9
@export var height_for_max_scale: float = 8.0
@export var ray_length: float = 40.0
@export var ring_color: Color = Color(0.960784, 0.949020, 0.909804) # milk white #F5F2E8

const WORLD_GEOMETRY_MASK: int = 1

var _character: Node3D = null


func _ready() -> void:
	_character = get_parent().get_parent() as Node3D # ReadabilityAnchor -> character
	mesh = _make_ring_mesh()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = ring_color
	mat.emission_enabled = true
	mat.emission = ring_color
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	set_surface_override_material(0, mat)
	top_level = true # world-space position set manually each frame below
	visible = false


func _make_ring_mesh() -> TorusMesh:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.5
	torus.rings = 6
	torus.ring_segments = 24
	return torus


func _process(_delta: float) -> void:
	if _character == null or not (_character is PlayerBody):
		return
	var player: PlayerBody = _character as PlayerBody
	if player.is_on_floor():
		visible = false
		return

	var origin: Vector3 = player.global_position
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * ray_length)
	query.collision_mask = WORLD_GEOMETRY_MASK
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		visible = false
		return

	var hit_pos: Vector3 = result["position"]
	var height: float = origin.y - hit_pos.y
	var scale_amount: float = lerpf(min_scale, max_scale, clampf(height / height_for_max_scale, 0.0, 1.0))
	global_position = hit_pos + Vector3.UP * 0.02
	scale = Vector3.ONE * scale_amount
	visible = true
