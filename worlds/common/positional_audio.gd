class_name PositionalAudio
extends Node
## PositionalAudio — audio v2. A tiny stateless wrapper around
## AudioStreamPlayer3D for one-shot spatial SFX: moth flutter, mouse
## squeak-yawn, door soft chime, dreamling giggle, touch-react boop, etc.
## Reuses AudioManager's own SFX pool (AudioManager.load_sfx_stream) rather
## than a second asset directory or a separate registration step, so every
## "AudioManager-registered" stream in assets/audio/sfx/ is automatically
## playable positionally by name — matching the brief's "via
## AudioManager-registered streams" contract with zero extra bookkeeping.
##
## Each call spawns one ephemeral AudioStreamPlayer3D parented to the
## SceneTree root — deliberately NOT parented to the caller, so a one-shot
## outlives a caller that frees or hides itself mid-sound (a scattering
## critter re-entering IDLE, a released dreamling that queue_frees at the
## end of its return flight). Freed automatically on `finished`.
##
## Adopted so far (worlds/common, this pass's territory): dreamling.gd
## (periodic idle giggle — aliveness_wow.md §2/§6 item 9, "hear a dreamling
## before it's on screen"), touch_react.gd (poke_boop, 3 pitch_scale
## variants), critter.gd (moth_flutter / mouse_squeak on scatter). Any
## other script may call PositionalAudio.play_at(...) directly — no
## instance, no autoload registration needed (GDScript static methods on a
## global class_name are callable exactly like this, project-wide).

const UNIT_SIZE: float = 1.0    # matches this project's human-scale world units (~1 m capsule bodies)
const MAX_DISTANCE: float = 14.0 # inaudible well past a typical world's local play area -- mix-discipline constant, kept here in one place


## play_at — loads `sfx_name` from AudioManager's SFX pool and plays it at
## `world_position` via a fresh, self-freeing AudioStreamPlayer3D.
## `pitch_scale` lets callers cheaply vary one source asset (e.g.
## touch_react.gd's 3-pitch boop set) instead of authoring near-duplicate
## files. Fails soft exactly like AudioManager.play_sfx: a missing asset
## prints one note and no-ops, never errors.
static func play_at(sfx_name: String, world_position: Vector3, pitch_scale: float = 1.0) -> void:
	var stream: AudioStream = AudioManager.load_sfx_stream(sfx_name)
	if stream == null:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = AudioManager.SFX_BUS
	player.unit_size = UNIT_SIZE
	player.max_distance = MAX_DISTANCE
	player.pitch_scale = pitch_scale
	tree.root.add_child(player)
	player.global_position = world_position
	player.play()
	player.finished.connect(player.queue_free)
