extends Node3D
## preview_model — evidence-only viewer for judging a generated GLB in
## isolation before spending rig/animation credits on it (director's rule:
## no credits ride on unseen geometry). Generalizes test_jar_scene.gd.
##
## Not part of the shipped game. Run windowed (screenshots skip headless):
##   godot_console.exe --path . tools/meshy/preview_model.tscn \
##     -- --model=pip_v2 --shots=20,40 --outdir=evidence/stills/art_v2
## Frame 20 = front three-quarter, frame 40 = back three-quarter (the
## camera orbits slowly, so two shots give both sides).

const ORBIT_SPEED: float = 1.6 # rad/s — front at ~f20, back by ~f40 @60fps

var _target_center: Vector3 = Vector3.ZERO
var _orbit_radius: float = 1.5
var _cam: Camera3D = null


func _ready() -> void:
	var model_id: String = str(Harness.flags.get("model", ""))
	if model_id.is_empty():
		push_error("preview_model: pass -- --model=<id>")
		get_tree().quit(1)
		return
	var glb_path: String = "res://assets/models/meshy/generated/%s.glb" % model_id
	if not ResourceLoader.exists(glb_path):
		push_error("preview_model: not found: " + glb_path)
		get_tree().quit(1)
		return
	var packed: PackedScene = load(glb_path)
	var inst: Node3D = packed.instantiate()
	add_child(inst)

	var aabb: AABB = _merged_aabb(inst)
	_target_center = aabb.get_center()
	_orbit_radius = maxf(aabb.size.length() * 1.1, 0.6)
	print("PREVIEW_MODEL id=%s aabb_size=%s" % [model_id, aabb.size])

	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	light.light_energy = 2.2
	add_child(light)
	var fill := OmniLight3D.new()
	fill.position = _target_center + Vector3(0.6, 0.4, 0.6)
	fill.light_energy = 1.2
	fill.omni_range = 4.0
	add_child(fill)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2E3B5E")
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.9
	var env_node := WorldEnvironment.new()
	env_node.environment = env
	add_child(env_node)


func _process(_delta: float) -> void:
	if _cam == null:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	var angle: float = t * ORBIT_SPEED
	_cam.position = _target_center + Vector3(
		sin(angle) * _orbit_radius, _orbit_radius * 0.35, cos(angle) * _orbit_radius)
	_cam.look_at(_target_center, Vector3.UP)


func _merged_aabb(root: Node) -> AABB:
	var merged := AABB()
	var first: bool = true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n
			var box: AABB = mi.global_transform * mi.get_aabb()
			merged = box if first else merged.merge(box)
			first = false
		for c: Node in n.get_children():
			stack.append(c)
	return merged
