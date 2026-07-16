extends SceneTree
## verify_character_stills.gd — close-up character verification stills.
## Exercises the REAL pip.tscn/otto.tscn scenes, the same RiggedModelSlot ->
## CharacterAnimator -> AnimationTree path the actual game uses, just under
## a close hand-placed camera instead of the game's own far-pulled-back
## world camera (bramble's establishing shots put the characters at a few
## pixels -- useless for an "is this skinned, not T-posed" check). Same
## instantiate-scene-directly-under-root + call_deferred("_run") + `await
## physics_frame` coroutine pattern as tools/props/check_placements.gd (a
## bare `await` inside a MainLoop _physics_process() override does NOT work
## -- confirmed the hard way, first attempt silently stalled after one
## tick).
##
## Usage: D:/Tools/godot/godot_console.exe --path . --resolution 960x540
##   --fixed-fps 60 --script tools/import/verify_character_stills.gd
## Writes 7 PNGs to evidence/stills/v2_characters/ (idle/walk/run/jump/
## fall/wave-gesture for Pip, one locomotion shot for Otto) and prints one
## VERIFY_SHOT receipt line per shot with the exact PlayerBody.state at
## capture time. Windowed (screenshots need a real rasterizer, same
## constraint as tools/harness/'s own --shots), so real time per run is
## several seconds to ~1 minute depending on shader-cache warmth --
## kill any stale/orphaned godot_console.exe processes first if a prior run
## was interrupted, or GPU contention silently multiplies the wall-clock
## cost per frame.

const OUTDIR: String = "evidence/stills/v2_characters/"

var _root3d: Node3D
var _camera: Camera3D
var _pip: CharacterBody3D
var _otto: CharacterBody3D
var _pip_animator: CharacterAnimator
var _otto_animator: CharacterAnimator


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_stage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + OUTDIR))

	for i: int in range(5):
		await physics_frame
	await _shot(_pip, "pip_idle_closeup")

	_pip.set_virtual_input(Vector2(0.0, -0.3)) # partial stick -> walk-speed band
	for i: int in range(50):
		await physics_frame
	await _shot(_pip, "pip_walk_closeup")

	_pip.set_virtual_input(Vector2(0.0, -1.0)) # full stick -> run-speed band
	for i: int in range(50):
		await physics_frame
	await _shot(_pip, "pip_run_closeup")

	_pip.request_jump()
	for i: int in range(8):
		await physics_frame
	await _shot(_pip, "pip_jump_closeup")

	for i: int in range(30):
		await physics_frame
	await _shot(_pip, "pip_fall_closeup")

	_pip.set_virtual_input(Vector2.ZERO)
	for i: int in range(30):
		await physics_frame
	_pip_animator.play_gesture("wave")
	for i: int in range(15):
		await physics_frame
	await _shot(_pip, "pip_wave_gesture_closeup")

	_otto.set_virtual_input(Vector2(0.0, -1.0))
	for i: int in range(45):
		await physics_frame
	await _shot(_otto, "otto_run_closeup")

	print("VERIFY_STILLS_DONE {}")
	quit(0)


func _shot(target: CharacterBody3D, label: String) -> void:
	_camera.global_position = target.global_position + Vector3(1.4, 1.1, 1.6)
	_camera.look_at(target.global_position + Vector3(0, 0.6, 0), Vector3.UP)
	await physics_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_viewport().get_texture().get_image()
	var path: String = OUTDIR + label + ".png"
	img.save_png(ProjectSettings.globalize_path("res://" + path))
	print("VERIFY_SHOT %s" % JSON.stringify({
		"path": path,
		"player_state": (target as PlayerBody).state,
		"target_pos": str(target.global_position),
		"camera_pos": str(_camera.global_position),
	}))


func _build_stage() -> void:
	_root3d = Node3D.new()
	get_root().add_child(_root3d)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 1.2
	_root3d.add_child(light)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.ambient_light_energy = 0.6
	env_node.environment = env
	_root3d.add_child(env_node)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	_root3d.add_child(ground)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.1, 20)
	shape.shape = box
	shape.position.y = -0.05
	body.add_child(shape)
	body.collision_layer = 1
	_root3d.add_child(body)

	_camera = Camera3D.new()
	_camera.current = true
	_root3d.add_child(_camera)

	_pip = (load("res://scenes/players/pip.tscn") as PackedScene).instantiate() as CharacterBody3D
	_pip.position = Vector3(-1.0, 0.0, 0.0)
	_root3d.add_child(_pip)
	_pip_animator = _pip.get_node("Visual/CharacterAnimator") as CharacterAnimator

	_otto = (load("res://scenes/players/otto.tscn") as PackedScene).instantiate() as CharacterBody3D
	_otto.position = Vector3(1.2, 0.0, 0.0)
	_root3d.add_child(_otto)
	_otto_animator = _otto.get_node("Visual/CharacterAnimator") as CharacterAnimator
