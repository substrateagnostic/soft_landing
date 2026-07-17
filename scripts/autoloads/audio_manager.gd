extends Node
## AudioManager — SFX pool + layered lullaby stem player (the viola seam,
## D-PITCH audio). Missing audio files are the expected state until Phase
## 4/5 asset delivery: every load path fails soft (one stdout note, no
## error, no crash).
##
## audio pass 3 (tools/audio_gen/generate_audio_v3.py) added seven keystone
## set-piece one-shots to the flat assets/audio/sfx/ pool play_sfx() already
## reads by name — no new directory or API needed: giant_rumble (all three
## keystone-sequence starts), giant_yawn_sigh (bear wake / whale settle /
## cat stretch apex), debris_soft_tumble (mountain_dressing reveal),
## water_rise_shimmer (dive flood beat), roof_slide_soft (stretch plate
## shift), heartbeat_thump (HeartbeatCrossing pulse), gust_breath
## (BreathWeather.force_gust()).

const SFX_DIR: String = "res://assets/audio/sfx/"
const STEMS_DIR: String = "res://assets/audio/stems/"
const AMBIENCE_DIR: String = "res://assets/audio/ambience/" # audio v2 -- per-world ambience beds
const UI_DIR: String = "res://assets/audio/ui/" # audio v2 -- menu sounds (play_ui)
const MUSIC_BUS: String = "Music"
const SFX_BUS: String = "SFX"
const VOICE_BUS: String = "Voice" # TheMoon's moonsong syllables (UI/writing pass, D20)

var _sfx_player: AudioStreamPlayer
var _stem_players: Array[AudioStreamPlayer] = []
var _ambience_player: AudioStreamPlayer # audio v2
var _ui_player: AudioStreamPlayer # audio v2 -- separate from _sfx_player so a menu tick never cuts off a world sfx mid-play

## audio v2 world-ambience auto-adoption: GameState has no world-changed
## signal (checked; set_current_world() just assigns the var) and editing
## GameState/main.gd is outside this pass's territory, so this polls
## GameState.current_world_id once per frame (a String compare -- cheap)
## entirely from within this autoload. Every world switch — including the
## very first one at boot — is picked up within one frame with zero
## wiring required from any other script.
var _polled_world_id: String = ""


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_ensure_bus(VOICE_BUS)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SfxPlayer"
	_sfx_player.bus = SFX_BUS
	add_child(_sfx_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = MUSIC_BUS
	add_child(_ambience_player)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UiPlayer"
	_ui_player.bus = SFX_BUS
	add_child(_ui_player)

	# Apply whatever volumes were last persisted (GameState/SaveManager both
	# ready before AudioManager per project.godot's autoload order) so a
	# saved preference holds from the very first frame, not just after the
	# options panel first touches a slider.
	set_music_volume(float(GameState.get_setting("music_volume")))
	set_sfx_volume(float(GameState.get_setting("sfx_volume")))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		var new_index: int = AudioServer.bus_count
		AudioServer.add_bus(new_index)
		AudioServer.set_bus_name(new_index, bus_name)


func play_sfx(sfx_name: String) -> void:
	var path: String = SFX_DIR + sfx_name + ".ogg"
	if not ResourceLoader.exists(path):
		print("AudioManager: sfx not found (no-op): ", path)
		return
	_sfx_player.stream = load(path) as AudioStream
	_sfx_player.play()


## play_sfx_overlay — audio pass 3, additive. Same lookup/fail-soft-print
## convention as play_sfx(), but spawns an ephemeral AudioStreamPlayer
## (freed on `finished`) instead of reusing the shared _sfx_player, so this
## call never cuts off whatever _sfx_player is already mid-playback (and a
## later plain play_sfx()/play_sfx_overlay() call never cuts THIS one off
## either). Mirrors core/audio/player_audio.gd's own established "own
## AudioStreamPlayer pool... never AudioManager's shared _sfx_player"
## convention (audio v2), lifted to a one-line AudioManager call for
## call sites — the keystone set-piece sequences — where two real one-shots
## legitimately fire within the same synchronous frame and both need to be
## heard, not just whichever call happened to run last.
func play_sfx_overlay(sfx_name: String) -> void:
	var path: String = SFX_DIR + sfx_name + ".ogg"
	if not ResourceLoader.exists(path):
		print("AudioManager: sfx not found (no-op): ", path)
		return
	var player := AudioStreamPlayer.new()
	player.bus = SFX_BUS
	player.stream = load(path) as AudioStream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## load_sfx_stream — audio v2. Same lookup/fail-soft-print as play_sfx, but
## returns the AudioStream instead of playing it on the shared _sfx_player.
## For callers that own their OWN AudioStreamPlayer(s) so overlapping plays
## never cut each other off — core/audio/player_audio.gd (two players' verb
## sounds in co-op must never fight over one shared player) and
## worlds/common/positional_audio.gd (every "AudioManager-registered"
## stream in SFX_DIR is playable positionally for free, no second asset
## directory or registry needed).
func load_sfx_stream(sfx_name: String) -> AudioStream:
	var path: String = SFX_DIR + sfx_name + ".ogg"
	if not ResourceLoader.exists(path):
		print("AudioManager: sfx not found (no-op): ", path)
		return null
	return load(path) as AudioStream


## play_ui — audio v2 menu-sound API (assets/audio/ui/*.ogg): focus_tick,
## confirm_bloom, pause_open, pause_close. Scene wiring (pause_menu.gd etc.)
## belongs to whoever owns scenes/ui; this only guarantees the API loads
## and plays a stream when called.
func play_ui(ui_name: String) -> void:
	var path: String = UI_DIR + ui_name + ".ogg"
	if not ResourceLoader.exists(path):
		print("AudioManager: ui sfx not found (no-op): ", path)
		return
	_ui_player.stream = load(path) as AudioStream
	_ui_player.play()


## play_ambience / stop_ambience — audio v2 per-world ambience beds
## (assets/audio/ambience/<world_id>.ogg). Also called automatically by
## _process() below on every GameState.current_world_id change, so no
## other script needs to call this directly for the common case — it's
## public because a future scene (e.g. a hub preview) may want to force a
## specific bed regardless of GameState.
func play_ambience(world_id: String) -> void:
	var path: String = AMBIENCE_DIR + world_id + ".ogg"
	if not ResourceLoader.exists(path):
		print("AudioManager: ambience not found (no-op): ", path)
		return
	_ambience_player.stream = load(path) as AudioStream
	_ambience_player.play()


func stop_ambience() -> void:
	_ambience_player.stop()


## Polls GameState.current_world_id once a frame (see _polled_world_id's
## doc comment) and swaps the ambience bed the instant it changes,
## including the very first world load at boot.
func _process(_delta: float) -> void:
	var world_id: String = GameState.current_world_id
	if world_id == _polled_world_id:
		return
	_polled_world_id = world_id
	if world_id.is_empty():
		stop_ambience()
	else:
		play_ambience(world_id)


## Maps a dreamling-count step (1-based) to the matching rung of the
## dreamling_chime pentatonic ladder (dreamling_chime, dreamling_chime_2..8)
## and plays it via play_sfx — counting climbs, pitch carries the joy.
## Steps above 8 clamp to the top rung rather than erroring or repeating.
func play_chime(step: int) -> void:
	var clamped_step: int = clampi(step, 1, 8)
	var sfx_name: String = "dreamling_chime" if clamped_step == 1 else "dreamling_chime_%d" % clamped_step
	play_sfx(sfx_name)


func play_stem_layer(world_id: String, layer: int) -> void:
	var path: String = "%s%s/layer_%d.ogg" % [STEMS_DIR, world_id, layer]
	if not ResourceLoader.exists(path):
		print("AudioManager: stem layer not found (no-op): ", path)
		return

	while _stem_players.size() <= layer:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "StemLayer%d" % _stem_players.size()
		player.bus = MUSIC_BUS
		add_child(player)
		_stem_players.append(player)

	var target: AudioStreamPlayer = _stem_players[layer]
	target.stream = load(path) as AudioStream
	target.play()


func stop_stems() -> void:
	for player: AudioStreamPlayer in _stem_players:
		player.stop()


## --- Bus volumes (pause options v2, D18/D20) ---------------------------
## linear is 0.0..1.0 (slider space); converted to dB for AudioServer. 0.0
## maps to true silence (linear_to_db(0.0) is -inf, which AudioServer
## accepts as a mute, not a crash) rather than clamping to some audible
## floor — a parent muting the SFX bus expects actual silence.

func set_music_volume(linear: float) -> void:
	_set_bus_volume(MUSIC_BUS, linear)


func set_sfx_volume(linear: float) -> void:
	_set_bus_volume(SFX_BUS, linear)


func set_voice_volume(linear: float) -> void:
	_set_bus_volume(VOICE_BUS, linear)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)))
