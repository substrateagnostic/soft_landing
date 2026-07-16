class_name PlayerAudio
extends Node
## PlayerAudio — audio v2. Sibling seam to core/art/character_animator.gd:
## listens to the SAME PlayerBody public signals (state_changed / landed /
## pound_landed) but never touches animation — this script only plays
## sound. Scene wiring: one PlayerAudio child added directly under Pip's
## and Otto's root CharacterBody3D (scenes/players/pip.tscn, otto.tscn) —
## nothing else in either scene was touched, so `get_parent()` IS the
## PlayerBody, exactly like CharacterAnimator resolves its own `_player`.
##
## Owns a small pool of its OWN AudioStreamPlayer nodes (loaded via
## AudioManager.load_sfx_stream, never played through AudioManager's single
## shared `_sfx_player`) so two players' verb sounds in co-op — or a
## player's own footstep landing under a flutter's grace note — can
## overlap without cutting each other off.
##
## Verb -> sound map (docs/design/music-stems-spec.md register: hushed, no
## percussion):
##   FLUTTER          -> one-shot "flutter" (wing-flap chirp + grace note)
##   GLIDE (enter/exit)-> looped "glide_loop", faded in/out here (the baked
##                        loop has no fade of its own -- fading would break
##                        the loop seam, see tools/audio_gen/
##                        generate_audio_v2.py's make_glide_loop() doc)
##   POUND (enter)     -> one-shot "pound_start" (quick inhale whoosh)
##   pound_landed      -> one-shot "pound_land" (deep pillow thump + sparkle);
##                        suppresses that SAME frame's generic `landed` pat
##                        (see _pound_landing_this_frame) so a pound landing
##                        never plays two overlapping thumps
##   landed (any other)-> one-shot "land_soft" (soft felt landing pat --
##                        V1's existing land_soft.ogg, wired here for the
##                        first time)
##   running on ground -> "footstep" one-shots at a speed-scaled cadence
##                        (distance-accumulator, not a fixed-BPM timer --
##                        see _update_footsteps)

const MIN_RUN_SPEED: float = 1.3   # m/s -- below this, no footstep cadence (a slow walk still gets the one-shot landed pat, never a stomp loop)
const STEP_DISTANCE: float = 0.85  # meters per footstep -- cadence scales naturally with speed, no gait-phase tracking needed
const FOOTSTEP_PITCH_RANGE: Vector2 = Vector2(0.94, 1.06) # a little per-step variance so a run doesn't sound like one sample on a loop
const GLIDE_FADE_IN: float = 0.25
const GLIDE_FADE_OUT: float = 0.35
const GLIDE_VOLUME_DB: float = -14.0
const GLIDE_SILENT_DB: float = -80.0 # AudioStreamPlayer has no true -inf volume_db; this reads as silent without the stream ever tripping through zero-linear edge cases

@onready var _player: PlayerBody = get_parent() as PlayerBody

var _oneshot_a: AudioStreamPlayer
var _oneshot_b: AudioStreamPlayer
var _glide_player: AudioStreamPlayer
var _footstep_player: AudioStreamPlayer
var _next_oneshot_is_a: bool = true # alternates so two one-shots fired the same frame (rare, but e.g. a landed pat racing a fresh flutter) never fight over one player

var _footstep_distance_accum: float = 0.0
var _glide_active: bool = false
var _glide_tween: Tween = null
var _pound_landing_this_frame: bool = false # see pound_landed doc above


func _ready() -> void:
	if _player == null:
		push_warning("PlayerAudio: no PlayerBody parent at %s" % get_parent())
		return
	_oneshot_a = _make_player()
	_oneshot_b = _make_player()
	_glide_player = _make_player()
	_glide_player.volume_db = GLIDE_SILENT_DB
	_footstep_player = _make_player()

	_player.state_changed.connect(_on_state_changed)
	_player.landed.connect(_on_landed)
	_player.pound_landed.connect(_on_pound_landed)


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = AudioManager.SFX_BUS
	add_child(p)
	return p


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_update_footsteps(delta)


# ---------------------------------------------------------------------------
# Verb one-shots + glide loop
# ---------------------------------------------------------------------------

func _on_state_changed(new_state: int) -> void:
	match new_state:
		PlayerBody.State.FLUTTER:
			_play_oneshot("flutter")
		PlayerBody.State.GLIDE:
			_start_glide()
		PlayerBody.State.POUND:
			_play_oneshot("pound_start")
	if new_state != PlayerBody.State.GLIDE and _glide_active:
		_stop_glide()


func _on_landed() -> void:
	if _pound_landing_this_frame:
		# pound_landed fired earlier THIS SAME physics frame (player_body.gd
		# calls _land_pound(), which emits pound_landed, before it emits
		# landed -- both synchronous, same call, same frame) and already
		# played the bigger pound_land thump; the generic pat would double
		# up on it.
		_pound_landing_this_frame = false
		return
	_play_oneshot("land_soft")


func _on_pound_landed(_position: Vector3) -> void:
	_pound_landing_this_frame = true
	_play_oneshot("pound_land")


func _play_oneshot(sfx_name: String) -> void:
	var stream: AudioStream = AudioManager.load_sfx_stream(sfx_name)
	if stream == null:
		return
	var target: AudioStreamPlayer = _oneshot_a if _next_oneshot_is_a else _oneshot_b
	_next_oneshot_is_a = not _next_oneshot_is_a
	target.pitch_scale = 1.0
	target.stream = stream
	target.play()


func _start_glide() -> void:
	var stream: AudioStream = AudioManager.load_sfx_stream("glide_loop")
	if stream == null:
		return
	_glide_active = true
	_kill_glide_tween()
	_glide_player.stream = stream
	_glide_player.volume_db = GLIDE_SILENT_DB
	_glide_player.play()
	_glide_tween = create_tween()
	_glide_tween.tween_property(_glide_player, "volume_db", GLIDE_VOLUME_DB, GLIDE_FADE_IN)


func _stop_glide() -> void:
	_glide_active = false
	_kill_glide_tween()
	_glide_tween = create_tween()
	_glide_tween.tween_property(_glide_player, "volume_db", GLIDE_SILENT_DB, GLIDE_FADE_OUT)
	_glide_tween.tween_callback(_glide_player.stop)


func _kill_glide_tween() -> void:
	if _glide_tween != null and _glide_tween.is_valid():
		_glide_tween.kill()


# ---------------------------------------------------------------------------
# Footsteps -- distance-accumulator cadence, not a fixed timer, so a faster
# run naturally steps more often without any tuning-resource coupling.
# ---------------------------------------------------------------------------

func _update_footsteps(delta: float) -> void:
	var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	if _player.is_on_floor() and speed > MIN_RUN_SPEED:
		_footstep_distance_accum += speed * delta
		if _footstep_distance_accum >= STEP_DISTANCE:
			_footstep_distance_accum = fmod(_footstep_distance_accum, STEP_DISTANCE)
			_play_footstep()
	else:
		_footstep_distance_accum = 0.0


func _play_footstep() -> void:
	var stream: AudioStream = AudioManager.load_sfx_stream("footstep")
	if stream == null:
		return
	_footstep_player.stream = stream
	_footstep_player.pitch_scale = randf_range(FOOTSTEP_PITCH_RANGE.x, FOOTSTEP_PITCH_RANGE.y)
	_footstep_player.play()
