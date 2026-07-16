class_name WorldDoor
extends Area3D
## WorldDoor — a world's exit doorframe (SPEC.md: "exit_requested() — player
## chose to leave"). Builds its own simple doorframe (two posts + a lintel)
## so worlds don't need a hand-authored scene file for it. Any player
## standing inside who presses either seat's interact button requests an
## exit: emits exit_requested() and prints one DOOR receipt line so the
## harness/director can grep world switches. main.gd (outside worlds/**)
## owns the actual scene swap — see the worlds-VERIFY integration notes.

signal exit_requested()

@export var target_world: String = "bramble"
@export var frame_width: float = 2.4
@export var frame_height: float = 2.8
@export var post_thickness: float = 0.3
@export var frame_color: Color = Color("F5F2E8")

var _bodies_inside: Array[PlayerBody] = []


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # PlayerBody layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_geometry()


func _build_geometry() -> void:
	var trigger_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(frame_width, frame_height, 1.5)
	trigger_shape.shape = box
	trigger_shape.position = Vector3(0.0, frame_height * 0.5, 0.0)
	add_child(trigger_shape)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = frame_color

	var half_width: float = frame_width * 0.5
	_add_post(Vector3(-half_width, frame_height * 0.5, 0.0), mat)
	_add_post(Vector3(half_width, frame_height * 0.5, 0.0), mat)

	var lintel := MeshInstance3D.new()
	lintel.name = "Lintel"
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(frame_width + post_thickness, post_thickness, post_thickness)
	lintel_mesh.material = mat
	lintel.mesh = lintel_mesh
	lintel.position = Vector3(0.0, frame_height, 0.0)
	add_child(lintel)


func _add_post(post_position: Vector3, mat: StandardMaterial3D) -> void:
	var post := MeshInstance3D.new()
	post.name = "Post"
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(post_thickness, frame_height, post_thickness)
	post_mesh.material = mat
	post.mesh = post_mesh
	post.position = post_position
	add_child(post)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerBody and not _bodies_inside.has(body):
		_bodies_inside.append(body as PlayerBody)


func _on_body_exited(body: Node3D) -> void:
	_bodies_inside.erase(body)


func _physics_process(_delta: float) -> void:
	if _bodies_inside.is_empty():
		return
	if Input.is_action_just_pressed("p1_interact") or Input.is_action_just_pressed("p2_interact"):
		_request_exit()


func _request_exit() -> void:
	print("DOOR %s" % JSON.stringify({"to": target_world}))
	exit_requested.emit()
