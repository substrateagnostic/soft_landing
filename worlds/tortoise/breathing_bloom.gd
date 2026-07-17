class_name BreathingBloom
extends Node3D
## BreathingBloom — Tortoise's answer to Bramble's snore-geyser / Wisp's
## water-spout / Marmalade's purr-thermal "rides a living breath" tradition
## (world card: "one dream naps right on it"). A small garden bloom, partway
## up the climb, that bobs gently on the shell's own slow breath cycle. d07
## (the "flourish" — open archetype + `speak_on_collect`, worlds/common/
## world_base.gd `_wire_open_moon_line()`) is parented under it as a plain
## child, so it rides the bob for free via ordinary transform composition —
## no physics body needed, since nothing ever stands ON this (unlike
## LilyPad/PurrThermal, which players ride and therefore need
## AnimatableBody3D + sync_to_physics). Deliberately NO collision shape,
## matching dreamkeeper.gd/fort_resident.gd/critter.gd's "presence only,
## walk-through, can never block a route" convention for every small
## decorative prop in this codebase.

@export var bob_amplitude: float = 0.25
@export var bob_period: float = 5.0
@export var radius: float = 0.35
@export var bloom_color: Color = Color("E8B4C8")

var _rest_y: float = 0.0
var _time: float = randf() * 10.0 # phase-varied so it never looks locked to another ambient loop


func _ready() -> void:
	_rest_y = position.y
	_build_visual()


func _process(delta: float) -> void:
	_time += delta
	position.y = _rest_y + sin(_time * TAU / bob_period) * bob_amplitude


func _build_visual() -> void:
	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.05
	stem_mesh.bottom_radius = 0.06
	stem_mesh.height = 0.5
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color("6E8F6A")
	stem_mesh.material = stem_mat
	stem.mesh = stem_mesh
	stem.position = Vector3(0.0, -0.25, 0.0)
	add_child(stem)

	var bloom := MeshInstance3D.new()
	bloom.name = "Bloom"
	var bloom_mesh := SphereMesh.new()
	bloom_mesh.radius = radius
	bloom_mesh.height = radius * 1.3 # squashed, petal-soft
	var bloom_mat := StandardMaterial3D.new()
	bloom_mat.albedo_color = bloom_color
	bloom_mat.emission_enabled = true
	bloom_mat.emission = bloom_color
	bloom_mat.emission_energy_multiplier = 0.8
	bloom_mesh.material = bloom_mat
	bloom.mesh = bloom_mesh
	add_child(bloom)
