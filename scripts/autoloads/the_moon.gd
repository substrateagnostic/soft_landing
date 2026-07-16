extends Node
## TheMoon — the written narrator (D20, docs/design/NARRATION_BIBLE.md).
## Looks up a warm line by key (now 1-5 hand-written variants per key,
## picked at random each call so a high-frequency line doesn't repeat
## itself into wallpaper), and speaks it through whichever channel(s)
## settings.voice_mode selects:
##   - "moonsong+text" — gibberish "moonsong" syllables + a subtitle.
##   - "moonsong+tts"  — moonsong, THEN real TTS speaks the same line
##     (DEFAULT — the D13 floor still stands: every spoken-objective line
##     must be intelligible, not just charming).
##   - "tts_only"      — TTS alone (accessibility: no moonsong to parse).
##   - "text_only"     — subtitle alone, no audio at all.
## ALWAYS prints a MOON_SAID receipt line — key, the chosen text, and the
## active voice_mode — so the harness can grep spoken lines even headless
## (where TTS/audio playback are unavailable/silent — every path here is
## guarded to fail soft, never crash).
##
## Calls are serialized through a one-job-at-a-time queue (_busy/_queue)
## so two lines fired close together never talk over each other — this is
## the mechanical enforcement of the narrator law (structural beats only,
## rare, one at a time) alongside the *content* discipline of keeping call
## sites sparse (docs/research/v2/ui_writing.md §4, the Fry/Hakim
## contrast).
##
## Self-wired milestone beats: dream-return counts crossing 5 / 10 (the
## same thresholds GameState uses for fort_stage growth) speak
## "fort_grows_5"/"fort_grows_10" on their own via the GameState signal —
## no other file needed to add a call site for this beat.

const LINES_PATH: String = "res://data/moon_lines.json"
const VOICE_DIR: String = "res://assets/audio/voice/"
const VOICE_SYLLABLE_COUNT: int = 10

const VALID_VOICE_MODES: PackedStringArray = [
	"moonsong+text", "moonsong+tts", "tts_only", "text_only",
]
const DEFAULT_VOICE_MODE: String = "moonsong+tts"

# Syllable-stream shaping (docs/research/v2/ui_writing.md §5 "Concrete
# recommendation for the Moon"): ~3-5 syllables/second, clamped total
# 1.5-3.5s, +/-8% per-syllable pitch jitter so it never reads as one
# looped blip.
const SYLLABLES_PER_SECOND: float = 4.0
const MOONSONG_MIN_SECONDS: float = 1.5
const MOONSONG_MAX_SECONDS: float = 3.5
const SECONDS_PER_CHAR: float = 0.045
const PITCH_JITTER: float = 0.08

# Mood pitch bias (Animalese-style: excited runs a little high, gentle/
# sleepy runs a little low) — keyed by MOON_SAID key, not text content, so
# it's exact rather than guessed from wording.
const GENTLE_KEYS: PackedStringArray = [
	"goodnight", "paused", "mission_shy", "callie_dreams",
	"bramble_d09_shy", "wisp_d09_shy", "marmalade_d09_shy", "bramble_d07_geyser",
]
const EXCITED_KEYS: PackedStringArray = [
	"well_done", "world_complete", "fort_grows_5", "fort_grows_10",
	"move_flutter_first", "move_glide_first", "move_pound_first",
	"mission_race", "mission_duet", "rescue",
	"bramble_d01_race", "bramble_d02_race", "bramble_d08_duet",
	"wisp_d01_race", "marmalade_d01_race",
]
const GENTLE_PITCH_BIAS: float = 0.94
const EXCITED_PITCH_BIAS: float = 1.07

var _lines: Dictionary = {} # key:String -> Array[String] (1+ variants)
var _tts_voice_id: String = ""
var _tts_available: bool = false
var _tts_complete_callback: Callable = Callable()

var _voice_streams: Array[AudioStream] = []
var _voice_lengths: Array[float] = []
var _moonsong_player: AudioStreamPlayer = null
var _moonsong_playlist: Array[Dictionary] = []
var _moonsong_index: int = 0
var _moonsong_token: int = 0
var _moonsong_on_complete: Callable = Callable()

var _subtitle: SubtitleRibbon = null

var _busy: bool = false
var _queue: Array[Dictionary] = [] # {text, voice_mode, key}


func _ready() -> void:
	_load_lines()
	_tts_available = _detect_tts()
	if _tts_available:
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_utterance_ended)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_utterance_ended)
	_setup_moonsong()
	_setup_subtitle()
	GameState.dream_returned.connect(_on_dream_returned)


func _detect_tts() -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return false
	var lang_voices: PackedStringArray = DisplayServer.tts_get_voices_for_language("en")
	if not lang_voices.is_empty():
		_tts_voice_id = lang_voices[0]
		return true
	var all_voices: Array = DisplayServer.tts_get_voices()
	if not all_voices.is_empty():
		_tts_voice_id = all_voices[0]["id"]
		return true
	return false


func _load_lines() -> void:
	if not FileAccess.file_exists(LINES_PATH):
		push_error("TheMoon: data/moon_lines.json missing")
		return
	var file: FileAccess = FileAccess.open(LINES_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	# Normalize every entry to Array[String] once at load, so callers never
	# have to care whether a key was authored as a single line or variants.
	for key: String in (parsed as Dictionary).keys():
		var value: Variant = parsed[key]
		if typeof(value) == TYPE_ARRAY:
			var variants: Array[String] = []
			for line: Variant in (value as Array):
				variants.append(str(line))
			if not variants.is_empty():
				_lines[key] = variants
		else:
			_lines[key] = [str(value)]


func _setup_moonsong() -> void:
	_moonsong_player = AudioStreamPlayer.new()
	_moonsong_player.name = "MoonsongPlayer"
	_moonsong_player.bus = AudioManager.VOICE_BUS
	add_child(_moonsong_player)
	_moonsong_player.finished.connect(_on_moonsong_player_finished)
	for i in range(VOICE_SYLLABLE_COUNT):
		var path: String = "%smoon_syl_%02d.ogg" % [VOICE_DIR, i]
		if not ResourceLoader.exists(path):
			print("TheMoon: moonsong syllable not found (no-op): ", path)
			continue
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			continue
		_voice_streams.append(stream)
		_voice_lengths.append(maxf(stream.get_length(), 0.05))


func _setup_subtitle() -> void:
	_subtitle = SubtitleRibbon.new()
	_subtitle.name = "SubtitleRibbon"
	add_child(_subtitle)


func _on_dream_returned(_world_id: String, _id: String) -> void:
	var total: int = GameState.total_returned()
	if total == 5:
		say("fort_grows_5")
	elif total == 10:
		say("fort_grows_10")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## say — resolve a line, print the MOON_SAID receipt immediately (so a
## caller's own receipt-grepping works the instant it calls this, exactly
## like before), then queue the spoken/captioned playback. Unknown keys
## fall back to printing the raw key as its own text (unchanged contract).
func say(text_key: String) -> void:
	var text: String = _resolve_text(text_key)
	var voice_mode: String = _resolve_voice_mode()
	print("MOON_SAID %s" % JSON.stringify({"key": text_key, "text": text, "voice_mode": voice_mode}))
	_queue.append({"text": text, "voice_mode": voice_mode, "key": text_key})
	_advance_queue()


func _resolve_text(text_key: String) -> String:
	var variants: Array = _lines.get(text_key, [])
	if variants.is_empty():
		return text_key
	return str(variants[randi() % variants.size()])


func _resolve_voice_mode() -> String:
	var mode: String = str(GameState.get_setting("voice_mode"))
	if not VALID_VOICE_MODES.has(mode):
		return DEFAULT_VOICE_MODE
	return mode


# ---------------------------------------------------------------------------
# Job queue — one line at a time, regardless of which channel(s) it uses
# ---------------------------------------------------------------------------

func _advance_queue() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	var job: Dictionary = _queue.pop_front()
	_run_job(str(job["text"]), str(job["voice_mode"]), str(job["key"]))


func _on_job_finished() -> void:
	_busy = false
	_advance_queue()


func _run_job(text: String, voice_mode: String, key: String) -> void:
	match voice_mode:
		"moonsong+text":
			var dur: float = _play_moonsong(text, key, _on_job_finished)
			_subtitle.show_line(text, dur)
		"moonsong+tts":
			var dur: float = _play_moonsong(text, key, func() -> void:
				_speak_tts(text, _on_job_finished)
			)
			_subtitle.show_line(text, dur + _estimate_tts_seconds(text))
		"tts_only":
			_subtitle.show_line(text, _estimate_tts_seconds(text))
			_speak_tts(text, _on_job_finished)
		"text_only":
			var read_dur: float = _estimate_text_seconds(text)
			_subtitle.show_line(text, read_dur)
			get_tree().create_timer(read_dur).timeout.connect(_on_job_finished)
		_:
			_on_job_finished() # unreachable (_resolve_voice_mode already validates), fail soft


func _estimate_tts_seconds(text: String) -> float:
	var word_count: int = text.split(" ", false).size()
	return clampf(float(word_count) / 2.3, 1.0, 6.0)


func _estimate_text_seconds(text: String) -> float:
	var word_count: int = text.split(" ", false).size()
	return clampf(float(word_count) / 2.0, 1.5, 6.0)


# ---------------------------------------------------------------------------
# Moonsong — deterministic (seeded by the line's own text) per-syllable
# sample+pitch sequencing, chained through _voice_streams. Advances on
# EITHER the AudioStreamPlayer's `finished` signal OR a matching-duration
# timer, whichever fires first — the timer path guarantees the sequence
# still completes headless / with no audio driver (where `finished` may
# never fire), so a moonsong-containing line can never wedge the queue.
# ---------------------------------------------------------------------------

func _play_moonsong(text: String, key: String, on_complete: Callable) -> float:
	if _voice_streams.is_empty():
		on_complete.call()
		return 0.0

	var syllables: Array[Dictionary] = _derive_syllables(text, key)
	var total: float = 0.0
	for syll: Dictionary in syllables:
		total += _voice_lengths[int(syll["sample"])] / float(syll["pitch"])

	_moonsong_playlist = syllables
	_moonsong_index = 0
	_moonsong_on_complete = on_complete
	_play_next_syllable()
	return total


func _derive_syllables(text: String, key: String) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text) # deterministic: same line text -> same syllable stream

	var target_duration: float = clampf(
		text.length() * SECONDS_PER_CHAR, MOONSONG_MIN_SECONDS, MOONSONG_MAX_SECONDS
	)
	var avg_syllable_seconds: float = 1.0 / SYLLABLES_PER_SECOND
	var syllable_count: int = maxi(4, int(round(target_duration / avg_syllable_seconds)))
	var mood_bias: float = _mood_pitch_bias(key)

	var syllables: Array[Dictionary] = []
	for _i in range(syllable_count):
		var sample_idx: int = rng.randi_range(0, _voice_streams.size() - 1)
		var jitter: float = 1.0 + rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
		syllables.append({"sample": sample_idx, "pitch": mood_bias * jitter})
	return syllables


func _mood_pitch_bias(key: String) -> float:
	if GENTLE_KEYS.has(key):
		return GENTLE_PITCH_BIAS
	if EXCITED_KEYS.has(key):
		return EXCITED_PITCH_BIAS
	return 1.0


func _play_next_syllable() -> void:
	if _moonsong_index >= _moonsong_playlist.size():
		_finish_moonsong()
		return
	var syll: Dictionary = _moonsong_playlist[_moonsong_index]
	_moonsong_index += 1
	_moonsong_token += 1
	var my_token: int = _moonsong_token

	var sample_idx: int = int(syll["sample"])
	var pitch: float = float(syll["pitch"])
	_moonsong_player.stream = _voice_streams[sample_idx]
	_moonsong_player.pitch_scale = pitch
	_moonsong_player.play()

	var expected: float = maxf(_voice_lengths[sample_idx] / pitch, 0.05) + 0.08
	get_tree().create_timer(expected).timeout.connect(_on_syllable_advance.bind(my_token))


func _on_moonsong_player_finished() -> void:
	_on_syllable_advance(_moonsong_token)


func _on_syllable_advance(token: int) -> void:
	if token != _moonsong_token:
		return # stale — the other advance path (signal vs. timer) already fired
	_moonsong_token += 1 # invalidate whichever path didn't win the race
	_play_next_syllable()


func _finish_moonsong() -> void:
	var cb: Callable = _moonsong_on_complete
	_moonsong_on_complete = Callable()
	if cb.is_valid():
		cb.call()


# ---------------------------------------------------------------------------
# TTS — thin wrapper around DisplayServer.tts_*, now with a completion
# callback so the job queue can advance once speech actually ends.
# ---------------------------------------------------------------------------

func _speak_tts(text: String, on_complete: Callable) -> void:
	if not _tts_available:
		on_complete.call() # headless / no voice installed — receipt already printed, no-op
		return
	_tts_complete_callback = on_complete
	DisplayServer.tts_speak(text, _tts_voice_id)


func _on_utterance_ended(_id: int) -> void:
	var cb: Callable = _tts_complete_callback
	_tts_complete_callback = Callable()
	if cb.is_valid():
		cb.call()
