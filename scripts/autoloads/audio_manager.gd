extends Node
## AudioManager — SFX pool + layered lullaby stem player (the viola seam,
## D-PITCH audio). Missing audio files are the expected state until Phase
## 4/5 asset delivery: every load path fails soft (one stdout note, no
## error, no crash).

const SFX_DIR: String = "res://assets/audio/sfx/"
const STEMS_DIR: String = "res://assets/audio/stems/"
const MUSIC_BUS: String = "Music"
const SFX_BUS: String = "SFX"

var _sfx_player: AudioStreamPlayer
var _stem_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SfxPlayer"
	_sfx_player.bus = SFX_BUS
	add_child(_sfx_player)


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
