extends Control
## Title — the whole menu: title text + "press A" prompt, both spoken by the
## Moon on load (D13). Any jump press, either seat, proceeds to main.tscn.
## No other menu items exist — the design floor forbids reading to play.

func _ready() -> void:
	TheMoon.say("welcome")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p1_jump") or event.is_action_pressed("p2_jump"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")
