extends SceneTree
## test_play_ui.gd — audio v2's "harness-adjacent test call" receipt for
## AudioManager.play_ui() (scenes/ui wiring belongs to whoever owns
## scenes/ui later; this only proves the API itself loads and plays every
## registered menu sound). NOT part of tools/harness/** (that vocabulary is
## fixed by harness.gd's _execute_event() match, which is outside this
## pass's territory to extend) -- a standalone SceneTree script instead,
## run via Godot's own `-s` flag, which still boots every autoload
## (AudioManager included) without loading scenes/main.tscn.
##
## Usage:
##   godot_console.exe --headless --path . -s res://tools/audio_gen/test_play_ui.gd

const UI_NAMES: Array[String] = ["focus_tick", "confirm_bloom", "pause_open", "pause_close"]


func _initialize() -> void:
	print("TEST_PLAY_UI_START")
	# Looked up by absolute autoload path, not the global `AudioManager`
	# identifier: GDScript's static analyzer resolves that identifier
	# against the project's autoload list at COMPILE time, which a script
	# run standalone via `-s` (no scene loaded yet) hits before autoloads
	# are registered -- get_node("/root/...") resolves at runtime instead,
	# after _initialize() has already added every autoload as a child.
	var audio_manager: Node = root.get_node_or_null("AudioManager")
	if audio_manager == null:
		print("TEST_PLAY_UI_FAIL AudioManager autoload not found")
		quit(1)
		return
	# _initialize() runs before autoloads' own _ready() has processed (their
	# AudioStreamPlayer children -- _ui_player included -- don't exist yet),
	# so wait one process frame before exercising the API.
	await process_frame
	for ui_name: String in UI_NAMES:
		audio_manager.call("play_ui", ui_name)
		print("TEST_PLAY_UI %s" % JSON.stringify({"name": ui_name}))
	print("TEST_PLAY_UI_DONE")
	quit()
