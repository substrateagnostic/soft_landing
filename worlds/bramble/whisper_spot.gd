class_name WhisperSpot
extends Node3D
## WhisperSpot — D26 joy pass #6 (NEXT_STEPS.md §1b, "the WHISPER SPOT: an
## alcove near his face — music ducks, the Moon says 'shhh', pure silence
## design"). A small alcove near the summit/head: the first time a player
## enters it, music ducks down and TheMoon speaks a hush line. Once per
## session (no save-file flag — a fresh quiet moment each time the world
## loads, matching the brief's "once per session" wording, not "once ever").
##
## Territory note (read before touching this file's TheMoon.say() line):
## "whisper_shh" is deliberately NOT added to data/moon_lines.json or
## scripts/autoloads/the_moon.gd — both are autoloads/data outside this
## pass's territory (worlds/bramble/** + tools/harness/scripts/bramble_*.json
## + docs/verify/disguise-joy-VERIFY.md + evidence/stills/m3_disguise/**;
## the brief's own territory section: "autoloads — public APIs only").
## TheMoon.say() IS a public API and is called here unmodified; an unknown
## key falls back to printing the raw key as its own spoken/subtitled text
## (the_moon.gd's own documented contract — see _resolve_text()), so the
## MOON_SAID receipt still fires honestly. The hand-written one-word "Shhh."
## line stays a named, honestly-documented gap until a future pass that DOES
## have the_moon.gd/moon_lines.json in scope adds the one line each.
##
## Music ducking uses AudioManager.set_music_volume(linear) — an existing
## PUBLIC autoload API (scripts/autoloads/audio_manager.gd), called here,
## never edited. Additive/restorable: reads GameState.get_setting(
## "music_volume") (also a public API) as the restore target BEFORE ducking,
## so this never clobbers whatever level the player had chosen in options.

const DUCK_TARGET: float = 0.15
const DUCK_SECONDS: float = 0.8
const ALCOVE_RADIUS: float = 3.0

var _triggered: bool = false # the one-time speak, ever (session-scoped)
var _ducked: bool = false # true only during the one duck window
var _restore_volume: float = 1.0


func _ready() -> void:
	var area := Area3D.new()
	area.name = "WhisperArea"
	area.monitoring = true
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 2 # PlayerBody layer
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = ALCOVE_RADIUS
	shape.shape = sphere
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _on_body_entered(body: Node3D) -> void:
	if not (body is PlayerBody) or _triggered:
		return
	_triggered = true
	_ducked = true
	_restore_volume = float(GameState.get_setting("music_volume"))
	var tween: Tween = create_tween()
	tween.tween_method(AudioManager.set_music_volume, _restore_volume, DUCK_TARGET, DUCK_SECONDS)
	print("WHISPER %s" % JSON.stringify({"event": "hush"}))
	TheMoon.say("whisper_shh")


func _on_body_exited(body: Node3D) -> void:
	if not (body is PlayerBody) or not _ducked:
		return
	_ducked = false
	var tween: Tween = create_tween()
	tween.tween_method(AudioManager.set_music_volume, DUCK_TARGET, _restore_volume, DUCK_SECONDS)
	print("WHISPER %s" % JSON.stringify({"event": "restore"}))
