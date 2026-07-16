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
