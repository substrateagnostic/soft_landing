extends Node
## GameState — global progress: current world, per-world dreamling
## collection/return, fort growth stage. Owns no scene nodes; mutated only
## through the methods below so every mutation can emit its signal and
## trigger a save (SPEC.md).

signal dreamling_collected(world_id: String, id: String)
signal dream_returned(world_id: String, id: String)
signal world_completed(world_id: String)
signal setting_changed(key: String, value: Variant)

var current_world_id: String = ""
var fort_stage: int = 0

## world_id -> { "collected": Array[String], "returned": Array[String], "completed": bool }
var dreamlings: Dictionary = {}

## Persisted player-facing options (UI/audio/camera seam, D20/D18). Read by
## SaveManager on load/save (its _default_state()/_apply_to_game_state()/
## save_game() mirror this dict verbatim) and by whichever system owns each
## knob — AudioManager bus volumes, TheMoon's voice_mode, and the camera
## agent's manual-look toggle all read through get_setting() rather than
## duplicating storage. voice_mode is one of "moonsong+text" |
## "moonsong+tts" | "tts_only" | "text_only" (D20).
var settings: Dictionary = {
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"voice_mode": "moonsong+tts",
	"camera_manual": false,
	"camera_sensitivity": 1.0,
}


func get_setting(key: String) -> Variant:
	return settings.get(key)


## set_setting — the only mutator. No-ops (and does not save) on a
## no-change write so slider drag events don't spam SaveManager every frame
## with an identical value; a real value change always saves immediately
## (D14: the world never forgets), matching every other GameState mutator.
func set_setting(key: String, value: Variant) -> void:
	if settings.get(key) == value:
		return
	settings[key] = value
	setting_changed.emit(key, value)
	SaveManager.save_game()


func _ensure_world(world_id: String) -> void:
	if not dreamlings.has(world_id):
		dreamlings[world_id] = {
			"collected": [] as Array[String],
			"returned": [] as Array[String],
			"completed": false,
		}


func set_current_world(world_id: String) -> void:
	current_world_id = world_id
	_ensure_world(world_id)


func collect(world_id: String, id: String) -> void:
	_ensure_world(world_id)
	var collected: Array = dreamlings[world_id]["collected"]
	if not collected.has(id):
		collected.append(id)
	dreamling_collected.emit(world_id, id)


func return_dream(world_id: String, id: String) -> void:
	_ensure_world(world_id)
	var returned: Array = dreamlings[world_id]["returned"]
	if not returned.has(id):
		returned.append(id)
	_update_fort_stage()
	dream_returned.emit(world_id, id)
	SaveManager.save_game()


## The fort grows as dreams come home, wherever they come home from:
## 1 dream -> stage 1, 5 -> stage 2, 10 -> stage 3 (v0.1 thresholds).
func _update_fort_stage() -> void:
	var total: int = total_returned()
	var stage: int = 0
	if total >= 10:
		stage = 3
	elif total >= 5:
		stage = 2
	elif total >= 1:
		stage = 1
	if stage > fort_stage:
		set_fort_stage(stage)


func mark_world_completed(world_id: String) -> void:
	_ensure_world(world_id)
	dreamlings[world_id]["completed"] = true
	world_completed.emit(world_id)
	SaveManager.save_game()


func set_fort_stage(stage: int) -> void:
	fort_stage = stage
	SaveManager.save_game()


func returned_ids(world_id: String) -> Array[String]:
	_ensure_world(world_id)
	var out: Array[String] = []
	for id: String in dreamlings[world_id]["returned"]:
		out.append(id)
	return out


func collected_count(world_id: String) -> int:
	_ensure_world(world_id)
	return (dreamlings[world_id]["collected"] as Array).size()


func returned_count(world_id: String) -> int:
	_ensure_world(world_id)
	return (dreamlings[world_id]["returned"] as Array).size()


func total_returned() -> int:
	var total: int = 0
	for world_id: String in dreamlings.keys():
		total += returned_count(world_id)
	return total


func is_world_completed(world_id: String) -> bool:
	_ensure_world(world_id)
	return dreamlings[world_id]["completed"]
