extends Node
## Boot — one-frame gate that reads Harness flags then routes straight to
## main (--skipmenu, for the autoplay harness and CI receipts) or to title.

func _ready() -> void:
	await get_tree().process_frame
	if Harness.flags.has("skipmenu"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/title.tscn")
