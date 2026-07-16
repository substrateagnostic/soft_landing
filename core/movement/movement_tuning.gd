class_name MovementTuning
extends Resource
## MovementTuning — every movement feel number lives here (D2), never
## hand-set in player_body.gd, so playtest tuning never requires code
## archaeology. Per-character resources: data/tuning/pip_movement.tres,
## data/tuning/otto_movement.tres.

@export var move_speed: float = 4.0
@export var accel: float = 40.0
@export var decel: float = 25.0
@export var jump_height: float = 1.5
@export var time_to_apex: float = 0.45
@export var fall_gravity_mult: float = 1.55
@export var apex_hang_threshold: float = 0.5 # m/s vertical speed below which apex-hang state applies
@export var apex_gravity_mult: float = 0.4
@export var coyote_time: float = 0.20
@export var jump_buffer: float = 0.22
@export var floor_snap: float = 0.45
@export var air_control: float = 0.5
@export var terminal_velocity: float = 20.0
@export var turn_speed: float = 10.0

## Squash-stretch (core-feel agent): stretch while rising fast, squash on
## landing for squash_duration seconds, spring back at squash_spring_decay.
@export var stretch_scale: Vector3 = Vector3(1.0, 1.15, 0.9)
@export var squash_scale: Vector3 = Vector3(1.25, 0.8, 1.25)
@export var squash_duration: float = 0.12
@export var squash_spring_decay: float = 12.0

## Moveset ladder v1 (D17 movement agent): flutter double-jump, glide,
## ground-pound bounce. All three ride the existing jump/interact buttons
## (tap vs. hold vs. context) — no new input floor.
@export var flutter_height_mult: float = 0.6 # fraction of jump_height for the flutter boost
@export var flutter_duration: float = 0.18 # brief FLUTTER animation-hook window before normal apex/fall resumes
@export var glide_gravity_mult: float = 0.4 # applied on top of the derived fall gravity while gliding
@export var glide_terminal_velocity: float = 3.0 # m/s fall-speed cap while gliding
@export var glide_air_control_mult: float = 1.3 # slight forward air-control boost while gliding
@export var pound_hang_duration: float = 0.15 # brief hang before the fast drop
@export var pound_drop_speed: float = 14.0 # fixed fast-drop speed (m/s), under terminal_velocity
@export var pound_radius: float = 3.0 # shockwave radius that launches nearby grounded partners
@export var pound_launch_mult: float = 1.5 # partner launch height as a multiple of THEIR OWN jump_height
