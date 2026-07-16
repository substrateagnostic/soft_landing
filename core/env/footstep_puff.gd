class_name FootstepPuff
extends Node3D
## FootstepPuff — one-shot dust/cloud burst (D22 / recipes "Footstep
## puffs": one_shot, explosiveness 1.0, 8-16 burst). Built entirely in code
## (core/env/particle_presets.gd) so the accompanying .tscn only needs to
## reference this script. Out of this agent's territory to wire to real
## player events; the director instances this scene, parents/positions it
## at the contact point, and calls puff() — see graphics-v2-VERIFY.md for
## the one-line wiring note.

@export var particle_color: Color = Color("FFF3C4")
@export var amount: int = 12
@export var lifetime: float = 0.6
@export var particle_size: float = 0.12

var _particles: GPUParticles3D = null


func _ready() -> void:
	_particles = ParticlePresets.make_burst("Burst", amount, lifetime, particle_color, particle_size)
	add_child(_particles)


## Fires the burst at this node's current position. Safe to call again
## before a previous burst finishes — GPUParticles3D.restart() resets a
## one_shot emitter cleanly on its own.
func puff() -> void:
	_particles.restart()
	_particles.emitting = true
