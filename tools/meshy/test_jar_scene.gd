extends Node3D
## test_jar_scene — throwaway evidence-only scene (tools/meshy/**, this
## agent's territory) that renders the firefly jar in isolation.
##
## Why this exists: PillowFort._build_fort_growth() only builds the jar when
## GameState.fort_stage >= 2, and this machine's shared user://save.json
## (D14 single save slot) currently sits at fort_stage=1 from other agents'
## concurrent test sessions. Mutating that shared file to force stage>=2
## for one screenshot would risk corrupting a concurrent agent's live run,
## so instead this builds the *exact same* anchor + grey-box mesh +
## ModelSlot("firefly_jar") construction as that stage>=2 branch,
## standalone, with its own camera/light — same code path, zero shared
## state touched. See docs/verify/art-pipeline-VERIFY.md.
##
## Not part of the shipped game; not referenced by project.godot's
## run/main_scene or any autoload. Run directly via a scene-path CLI arg:
##   godot_console.exe --path . tools/meshy/test_jar_scene.tscn -- --shots=10 --outdir=...

const FORT_GLOW_COLOR: Color = Color("F2C879") # honey glow, ART_BIBLE.md


func _ready() -> void:
	_build_jar()
	_build_camera()
	_build_environment()


## Identical construction to PillowFort._build_fort_growth()'s stage>=2
## branch (worlds/pillow_fort/pillow_fort.gd) — anchor at local origin
## instead of the fort's world position, everything else unchanged.
func _build_jar() -> void:
	var jar_anchor := Node3D.new()
	jar_anchor.name = "FireflyJarVisual"
	add_child(jar_anchor)

	var jar := MeshInstance3D.new()
	jar.name = "FireflyJar"
	var jar_mesh := CylinderMesh.new()
	jar_mesh.top_radius = 0.18
	jar_mesh.bottom_radius = 0.22
	jar_mesh.height = 0.35
	var jar_mat := StandardMaterial3D.new()
	jar_mat.albedo_color = FORT_GLOW_COLOR
	jar_mat.emission_enabled = true
	jar_mat.emission = FORT_GLOW_COLOR
	jar_mat.emission_energy_multiplier = 1.4
	jar_mesh.material = jar_mat
	jar.mesh = jar_mesh
	jar.position = Vector3(0.0, jar_mesh.height * 0.5, 0.0)
	jar_anchor.add_child(jar)

	var jar_slot := ModelSlot.new()
	jar_slot.name = "FireflyJarModelSlot"
	jar_slot.model_id = "firefly_jar"
	jar_slot.target_height = 0.35 # ART_BIBLE scale rules: firefly_jar 0.35
	jar_anchor.add_child(jar_slot)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "TestCamera"
	# look_at() requires the node to already be inside the tree (it errors
	# otherwise) — add_child() first, then orient.
	add_child(cam)
	cam.position = Vector3(0.4, 0.3, 0.5)
	cam.look_at(Vector3(0.0, 0.14, 0.0), Vector3.UP)
	cam.current = true


func _build_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "TestLight"
	light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	light.light_energy = 2.2
	add_child(light)

	# Close-range fill so the jar's own emissive glow (fireflies) reads
	# clearly, matching how it looks lit from the fort's InteriorGlow in the
	# real scene.
	var fill := OmniLight3D.new()
	fill.name = "TestFill"
	fill.position = Vector3(0.3, 0.25, 0.3)
	fill.light_energy = 1.5
	fill.omni_range = 2.0
	add_child(fill)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2E3B5E") # deep dusk blue, ART_BIBLE sky zenith
	env.tonemap_mode = Environment.TONE_MAPPER_AGX

	var env_node := WorldEnvironment.new()
	env_node.name = "TestEnvironment"
	env_node.environment = env
	add_child(env_node)
