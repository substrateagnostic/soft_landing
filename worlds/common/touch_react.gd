class_name TouchReact
extends Area3D
## TouchReact — Astro-Bot-style "everything is poke-able" (aliveness_wow.md
## §2/§6, Top 12 item #6): a shallow, reusable reaction component. Any prop
## opted into the "poke" group gets one auto-attached by
## worlds/common/world_base.gd's _wire_touch_react() -- a spring-damped
## squash/tilt on the prop's own visual plus a soft chime-adjacent "boop"
## SFX the moment a player runs through or lands on it. No physics
## simulation, no per-prop bespoke code: one component, N re-skinned
## attachments (same "shallow RigidBody + squash/stretch AnimationPlayer +
## one-shot SFX per prop archetype" model the research doc cites).
##
## Self-sufficient: builds its own default CollisionShape3D if the prop it's
## attached to didn't provide one as a direct child named "CollisionShape3D"
## (props opting in are typically plain MeshInstance3D nodes with no
## collision of their own -- world_base.gd's auto-attach wiring covers that
## common case without every prop author needing to hand-build a trigger
## volume).

signal poked

@export var react_target_path: NodePath = NodePath("..") # what visually reacts; defaults to the prop this is attached to
@export var trigger_radius: float = 1.0
@export var cooldown: float = 0.5
@export var squash_amount: float = 0.25
@export var tilt_degrees: float = 12.0
@export var reaction_duration: float = 0.4
@export var sfx_name: String = "poke_boop"

const PLAYERS_GROUP: String = "players"
## audio v2: touch_react's boop reuses ONE source asset (poke_boop.ogg) and
## varies playback pitch across these 3 values rather than baking three
## near-duplicate files ("touch-react boop set (3 pitches)") -- cheap
## variety for a sound that can fire dozens of times a session.
const BOOP_PITCHES: Array[float] = [0.92, 1.0, 1.1]

var _target: Node3D = null
var _base_scale: Vector3 = Vector3.ONE
var _base_rotation: Vector3 = Vector3.ZERO
var _cooldown_timer: float = 0.0


func _ready() -> void:
	add_to_group("touch_react")
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # PlayerBody layer (dreamling.gd / dream_door.gd convention)

	_target = get_node_or_null(react_target_path) as Node3D
	if _target == null:
		_target = get_parent() as Node3D
	if _target != null:
		_base_scale = _target.scale
		_base_rotation = _target.rotation

	if get_node_or_null("CollisionShape3D") == null:
		_add_default_shape()

	body_entered.connect(_on_body_entered)


func _add_default_shape() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = trigger_radius
	shape.shape = sphere
	add_child(shape)


func _physics_process(delta: float) -> void:
	_cooldown_timer = max(_cooldown_timer - delta, 0.0)


func _on_body_entered(body: Node3D) -> void:
	if not (body is PlayerBody):
		return
	if _cooldown_timer > 0.0:
		return
	_cooldown_timer = cooldown
	_react()


func _react() -> void:
	if _target == null:
		return
	poked.emit()
	# audio v2: positional (via worlds/common/positional_audio.gd) instead
	# of AudioManager's flat shared _sfx_player, so a poke reads as coming
	# from the actual prop -- and a random pitch from BOOP_PITCHES so a
	# poke-everything spree doesn't sound like one sample on repeat.
	var pitch: float = BOOP_PITCHES[randi() % BOOP_PITCHES.size()]
	PositionalAudio.play_at(sfx_name, global_position, pitch)
	print("EVT %s" % JSON.stringify({"type": "touch_react_poke", "sfx": sfx_name, "t": Engine.get_physics_frames()}))

	var squash: Vector3 = _base_scale * Vector3(1.0 + squash_amount, 1.0 - squash_amount, 1.0 + squash_amount)
	var tilt: Vector3 = _base_rotation + Vector3(deg_to_rad(tilt_degrees), 0.0, deg_to_rad(tilt_degrees * 0.6))

	var tween: Tween = create_tween()
	tween.tween_property(_target, "scale", squash, reaction_duration * 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_target, "rotation", tilt, reaction_duration * 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_target, "scale", _base_scale, reaction_duration * 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_target, "rotation", _base_rotation, reaction_duration * 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
