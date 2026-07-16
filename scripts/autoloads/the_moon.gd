extends Node
## TheMoon — TTS narration seam (D13). Looks up a warm one-line string by
## key, speaks it via DisplayServer TTS when a voice is available, and
## ALWAYS prints a MOON_SAID receipt line so the harness can grep spoken
## lines even headless (where TTS itself is unavailable — guarded, never
## crashes). Lines queue so they never overlap.

const LINES_PATH: String = "res://data/moon_lines.json"

var _lines: Dictionary = {}
var _queue: Array[String] = []
var _speaking: bool = false
var _tts_voice_id: String = ""
var _tts_available: bool = false


func _ready() -> void:
	_load_lines()
	_tts_available = _detect_tts()
	if _tts_available:
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_utterance_ended)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_utterance_ended)


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
	if typeof(parsed) == TYPE_DICTIONARY:
		_lines = parsed


func say(text_key: String) -> void:
	var text: String = str(_lines.get(text_key, ""))
	if text.is_empty():
		text = text_key
	print("MOON_SAID %s" % JSON.stringify({"key": text_key, "text": text}))
	_queue.append(text)
	_try_speak_next()


func _try_speak_next() -> void:
	while not _speaking and not _queue.is_empty():
		var text: String = _queue.pop_front()
		if _tts_available:
			_speaking = true
			DisplayServer.tts_speak(text, _tts_voice_id)
		# else: no voice available (e.g. headless) — receipt already printed above.


func _on_utterance_ended(_id: int) -> void:
	_speaking = false
	_try_speak_next()
