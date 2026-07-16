class_name SparkleTrail
extends Node3D
## SparkleTrail — continuous point-emission trail for carried dreamlings/
## moves (D22 / recipes "Sparkle trail": lifetime 0.5-1s, shrink-to-zero,
## additive). Built in code (core/env/particle_presets.gd); the director
## parents this under whatever's being carried/tossed and toggles
## set_emitting() around the motion — out of this agent's territory to
## wire directly, see graphics-v2-VERIFY.md for the one-line note.

@export var particle_color: Color = Color("FFF3C4")
@export var amount: int = 20
@export var lifetime: float = 0.75
@export var particle_size: float = 0.08

var _particles: GPUParticles3D = null


func _ready() -> void:
	_particles = ParticlePresets.make_trail("Trail", amount, lifetime, particle_color, particle_size)
	add_child(_particles)


func set_emitting(value: bool) -> void:
	_particles.emitting = value
