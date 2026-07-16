extends Node
## SaveManager — single JSON save slot at user://save.json (D14). Auto-saves
## on every GameState progress signal. A corrupt file never crashes the
## game: it is quarantined to save.bak.json and a fresh state takes its
## place, silently (no scary message to the player).

const SAVE_PATH: String = "user://save.json"
const SCHEMA_VERSION: int = 1

var _data: Dictionary = {}


func _ready() -> void:
	load_game()
	GameState.dreamling_collected.connect(_on_progress_changed)
	GameState.dream_returned.connect(_on_progress_changed)
	GameState.world_completed.connect(_on_progress_changed)


func _on_progress_changed(_a: Variant = null, _b: Variant = null) -> void:
	save_game()


func _default_state() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"total_dreams": 0,
		"worlds": {},
		"fort_stage": 0,
		"settings": GameState.settings.duplicate(),
	}


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_data = _default_state()
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_data = _default_state()
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_quarantine_corrupt_save()
		_data = _default_state()
		return

	_data = _merge_defaults(parsed)
	_apply_to_game_state()


func _quarantine_corrupt_save() -> void:
	print("SaveManager: save.json unreadable, quarantining as save.bak.json")
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		if dir.file_exists("save.bak.json"):
			dir.remove("save.bak.json")
		dir.rename("save.json", "save.bak.json")


func _merge_defaults(parsed: Dictionary) -> Dictionary:
	var merged: Dictionary = _default_state()
	for key: String in parsed.keys():
		merged[key] = parsed[key] # unknown keys preserved (forward-compat)
	# settings is merged per-key (not replaced wholesale) so a save written
	# before a new setting existed (e.g. voice_mode, D20) still picks up
	# that key's default instead of silently losing it.
	if typeof(parsed.get("settings")) == TYPE_DICTIONARY:
		var merged_settings: Dictionary = GameState.settings.duplicate()
		for key: String in (parsed["settings"] as Dictionary).keys():
			merged_settings[key] = parsed["settings"][key]
		merged["settings"] = merged_settings
	return merged


func _apply_to_game_state() -> void:
	GameState.fort_stage = int(_data.get("fort_stage", 0))
	var worlds: Dictionary = _data.get("worlds", {})
	for world_id: String in worlds.keys():
		var w: Dictionary = worlds[world_id]
		GameState.dreamlings[world_id] = {
			"collected": (w.get("collected", []) as Array),
			"returned": (w.get("returned", []) as Array),
			"completed": bool(w.get("completed", false)),
		}
	var settings: Dictionary = _data.get("settings", {})
	for key: String in settings.keys():
		GameState.settings[key] = settings[key]

	# AudioManager (autoload #3) applies its own defensive default-volume
	# read at _ready(), but it runs BEFORE SaveManager (#4) in project.godot's
	# autoload order, so any *persisted* volume can only take effect once it
	# lands here, after the real save data is in GameState.settings.
	AudioManager.set_music_volume(float(GameState.get_setting("music_volume")))
	AudioManager.set_sfx_volume(float(GameState.get_setting("sfx_volume")))


func save_game() -> void:
	_data["version"] = SCHEMA_VERSION
	_data["fort_stage"] = GameState.fort_stage
	_data["worlds"] = GameState.dreamlings
	_data["total_dreams"] = GameState.total_returned()
	_data["settings"] = GameState.settings.duplicate()

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open save.json for write")
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
