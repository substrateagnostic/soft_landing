class_name Bramble
extends WorldBase
## Bramble — the first world (PITCH.md, GAME_BRIEF.md): a bear the size of
## a hill, asleep in a dusk meadow. D25 ("THE MOUNTAIN IS THE BEAR",
## docs/DECISIONS.md): a rescaled (~42m) rigged bear now sits sunk/half-
## buried as the world's central-east massif (see _build_bear_shell()), an
## authored switchback path (_build_ascent()) climbs his back to a summit
## platform at his ear/DreamDoor (_build_ear_and_door()), and
## worlds/bramble/mountain_dressing.gd dresses him as terrain. The ORIGINAL
## haunch -> chest -> shoulder -> head mound chain along +X is left in place
## unmoved (seven of the ten dreamlings pin to those exact coordinates — see
## _build_dreamlings()) and now reads as a string of low foothills at the
## massif's western base. Two snore geysers near the old head anchor, two
## foreleg paw ramps flanking the chest, ten dreamlings placed per the D12
## dense-cadence rule (see docs/verify/worlds-VERIFY.md for the original
## d01-d10 route table and docs/verify/mountain-m3-VERIFY.md for the D25
## relocation of d04/d06/d10). Grey-box: primitive meshes, flat
## StandardMaterial3D colors from ART_BIBLE.md only.

const DREAMLING_SCENE: PackedScene = preload("res://worlds/common/dreamling.tscn")
const DREAM_DOOR_SCENE: PackedScene = preload("res://worlds/common/dream_door.tscn")

# --- Palette (ART_BIBLE.md) ---------------------------------------------
const COLOR_MEADOW: Color = Color("7C9082") # sage in moonlight
const COLOR_MOAT: Color = Color(0.404, 0.463, 0.420) # darker sage, the boundary dip
const COLOR_FUR: Color = Color("8A6552") # warm umber
const COLOR_FUR_DARK: Color = Color("6E4F3E") # darker umber (paws, fur patches, ear)

# --- Meadow ---------------------------------------------------------------
const MEADOW_SIZE: Vector2 = Vector2(140.0, 80.0) # X: -70..70, Z: -40..40
const MOAT_SIZE: Vector2 = Vector2(190.0, 130.0)
# Below RESCUE_FLOOR_Y on purpose: stepping off the meadow must always end
# in the Soft Landing, never in a pit a 1.5 m jump can't escape (design
# floor: gentle rescue, no stuck states). The dark ring reads as the night
# beyond the meadow.
const MOAT_TOP_Y: float = -9.0
const MOAT_THICKNESS: float = 1.0
const RESCUE_FLOOR_Y: float = -8.0

# --- Spawns (meadow edge, arriving from the fort direction, facing +X) ---
const SPAWN_PIP: Vector3 = Vector3(-55.0, 0.5, 0.0)
const SPAWN_OTTO: Vector3 = Vector3(-57.0, 0.5, 2.0)

# --- Bear anatomy, along +X (tail/haunch -> head) --------------------------
const HAUNCH_CENTER: Vector3 = Vector3(-30.0, -6.0, 0.0)
const HAUNCH_RADIUS: float = 16.0 # top height = center.y + radius = 10.0 m

const CHEST_POSITION: Vector3 = Vector3(-5.0, 6.75, 0.0) # box center; rest top = 7.5 m
const CHEST_FOOTPRINT: Vector2 = Vector2(12.0, 8.0) # ~8 m wide, per brief
const CHEST_THICKNESS: float = 1.5
const CHEST_AMPLITUDE: float = 0.6
const CHEST_PERIOD: float = 5.0
const CHEST_PEDESTAL_MARGIN: float = 1.0
const CHEST_PEDESTAL_CLEARANCE: float = 0.3 # below the chest's lowest travel
const CHEST_PEDESTAL_THICKNESS: float = 2.0

const SHOULDER_CENTER: Vector3 = Vector3(20.0, -4.5, 0.0)
const SHOULDER_RADIUS: float = 14.0 # top height = 9.5 m

const HEAD_CENTER: Vector3 = Vector3(48.0, -5.0, 0.0)
const HEAD_RADIUS: float = 17.0 # top height = 12.0 m

# Ear anchor point on the head surface, plus a small bump rising to it.
const EAR_ANCHOR_X: float = 50.0
const EAR_ANCHOR_Z: float = 6.0
const EAR_BUMP_HEIGHT: float = 2.2 # anchor surface + this ~= 13 m, per brief
const EAR_BUMP_RADIUS: float = 1.8

# Snore geysers near the snout (front-top of the head).
const GEYSER_ANCHOR_X: float = 54.0
const GEYSER_ANCHOR_Z: float = 4.0
const GEYSER_RADIUS: float = 1.2
const GEYSER_HEIGHT: float = 8.0
const GEYSER_ACTIVE_DURATION: float = 1.2
const GEYSER_CYCLE_PERIOD: float = 5.0

# Foreleg paw ramps flanking the chest — the natural walk-up.
const PAW_RUN: float = 20.0 # horizontal length
const PAW_RISE: float = 2.6 # within the 1-3 m brief
const PAW_WIDTH: float = 5.0
const PAW_START_X: float = -15.0
const PAW_Z_OFFSET: float = 16.0

# Shoulder shelf (d08) — reachable by Otto-toss (~2.2 m apex, SPEC.md) or a
# chest-bounce jump; never toss-only, per the solo-completable floor rule.
const SHELF_ANCHOR_X: float = 24.0
const SHELF_ANCHOR_Z: float = 6.0
const SHELF_HEIGHT_ABOVE_ANCHOR: float = 3.2
const SHELF_SIZE: Vector3 = Vector3(3.0, 0.6, 3.0)

# Fur patches (tall-grass placeholders; d09 hides in the first one).
const FUR_PATCH_HAUNCH_X: float = -27.0
const FUR_PATCH_HAUNCH_Z: float = 6.0
const FUR_PATCH_BACK_X: float = -18.0
const FUR_PATCH_BACK_Z: float = -10.0
const FUR_BLADE_COUNT: int = 7
const FUR_PATCH_SPREAD: float = 1.6
const FUR_BLADE_HEIGHT: float = 0.9

# --- Ambient warm fill + wind grass (D22 graphics-v2, visual-only) ---------
const FIREFLY_FILL_POSITION: Vector3 = Vector3(-22.0, 3.6, -2.0) # matches core/env/ambience.gd's firefly_center
const FIREFLY_FILL_COLOR: Color = Color("F2C879")
# Both clear of the haunch mound's footprint (r16 from x=-30,z=0 — the same
# hazard bramble.gd's own d02 comment already flags for prop placement).
const GRASS_PATCH_A_CENTER: Vector3 = Vector3(-52.0, 0.0, -8.0) # meadow approach, near spawn
const GRASS_PATCH_B_CENTER: Vector3 = Vector3(-2.0, 0.0, 25.0) # open meadow flank, past the geysers/paw ramps
const GRASS_PATCH_SIZE: Vector2 = Vector2(14.0, 10.0)
const GRASS_DENSITY: int = 220

# --- Breath-becomes-weather (M2 set piece #1, worlds/bramble/breath_weather.gd) --
# Flat meadow near the snout's X coordinate but offset in Z -- see
# breath_weather.gd's own placement-note comment for why z=24 instead of
# z=0 (dead ahead of the snout is still on the head sphere's slope).
const BREATH_UPDRAFT_POSITION: Vector3 = Vector3(58.0, 0.0, 24.0)

# --- ROUND 2 additions: bear-direction warm fill + patchy meadow ground ----
# Note 5 ("warm bramble up"): a sleeping animal is warm -- a broad, low-
# energy warm wash centered over the chest/back, distinct from the small
# tight FireflyAreaGlow above (that one lights the fireflies cloud; this one
# is meant to read as ambient warmth radiating off the bear's whole body).
const BEAR_WARM_FILL_POSITION: Vector3 = Vector3(CHEST_POSITION.x, CHEST_POSITION.y + 3.0, CHEST_POSITION.z)
const BEAR_WARM_FILL_COLOR: Color = Color("D9A468") # between umber fur and honey firefly glow
const BEAR_WARM_FILL_ENERGY: float = 0.4
const BEAR_WARM_FILL_RANGE: float = 42.0
# Note 2 ("flat single-color ground"): sage <-> warm moss, a near-neighbor
# pair per the recipe (assets/shaders/ground_patches.gdshader).
const GROUND_TINT_A: Color = COLOR_MEADOW
const GROUND_TINT_B: Color = Color("8C9463")

var _chest: BreathingChest = null
var _geyser_a: SnoreGeyser = null # d07 rides this column (placement exemption)


func _ready() -> void:
	_build_meadow()
	_build_haunch()
	_build_chest()
	_build_shoulder()
	# _build_head() retired (D25): the old grey-box Head sphere is gone —
	# the rigged massif (_build_bear_shell()) IS the head/ear now. Its
	# math survives read-only in GEYSER_ANCHOR_*'s _sphere_surface_y() call
	# below (d07 pinned to the old formula, not to the mound rendering it).
	_build_geysers()
	_build_paw_ramps()
	_build_fur_patches()
	_build_dreamlings()
	_build_camera_hints()
	_build_home_door()
	_build_ambient_lighting()
	_build_grass_fields()
	_build_bear_shell() # before _build_rollover: the sequence looks it up
	_build_base_skirts() # D26 disguise pass: foothill masses merging his base into the ground
	_build_ascent()
	_build_ear_and_door() # D25: now builds at the summit platform, not the old head mound
	_build_breath_weather()
	_build_rollover()
	_build_dreamkeepers()
	_build_dreamkeeper_picnic() # D26 joy pass #7: relocate the moth keeper to a mid-ascent landing
	_build_whisper_spot() # D26 joy pass #6
	_build_dressing()
	_build_mountain_dressing()
	_build_dev_camera()
	# BUG FIX (found live during D25 work, not a D25 change itself): this call
	# had gone missing from _ready() proper -- stranded as dead code after a
	# `return` inside _dressing_cone() instead (removed there). Without it,
	# WorldBase._ready() (dreamling wiring, DreamDoor.returned connection,
	# mission attachment, critters, the WORLD_READY receipt) never ran for
	# Bramble at all -- world completion only ever worked via the forced
	# --rollover dev flag, never via natural 10/10 play. wisp.gd/
	# pillow_fort.gd both already call this as the last line of their own
	# _ready() (confirmed by grep) -- this restores the same contract here.
	super._ready()


# --- D25 THE MOUNTAIN IS THE BEAR (docs/DECISIONS.md D25) --------------------
# The rig is not lying flat: the "sleep" clip is a hunched, curled-forward
# SIT (rump down, head bowed low between raised knees/paws — confirmed by
# still, evidence/stills/m3_mountain/baseline*), which reads as a rounded
# hill on its own even before dressing. Central-east placement, sunk so the
# haunches/legs vanish below the meadow plane and only mid-torso-up shows
# (half-buried). At BEAR_SHELL_YAW_DEGREES=90 his local forward (+Z, verified
# by still — camera south of him at yaw 0 saw his face) points +X, so his
# BACK faces -X/west, toward the spawn approach: arriving players see his
# back rising up first and climb it, per the brief's "authored ascent."
# The old haunch/chest/shoulder/paw-ramp/fur-patch mound chain is UNTOUCHED
# (d01/d02/d03/d05/d07/d08/d09 pin to those exact coordinates — see
# _build_dreamlings()); they now read as low foothills scattered at his
# western flank/base rather than "the bear" themselves. The old Head mound +
# ear bump are retired (see _build_ear_and_door() below — replaced by the
# summit anchor on the new rig); GEYSER_ANCHOR_* still derives its Y from the
# old HEAD_CENTER/HEAD_RADIUS sphere math on purpose (d07 pinned) even though
# that sphere is no longer rendered.
const BEAR_SHELL_POSITION: Vector3 = Vector3(38.0, -5.0, 10.0) # sunk ~5m: half-buried
const BEAR_SHELL_HEIGHT: float = 19.0 # static-fallback sitting height (x1.5 of old 13.0 lying fallback)
const BEAR_SHELL_RIG_STANDING_HEIGHT: float = 42.0 # rig is T-pose; sleep clip curls him into the massif (+50% per D25)
const BEAR_SHELL_YAW_DEGREES: float = 90.0 # back to spawn/west — see header note above; tuned by still
const BEAR_SHELL_RIG_SCENE: String = "res://scenes/players/rigs/bramble_bear_rig_rig.tscn"

# Collision-blocker stack approximating the curled sit (torso capsule + head
# sphere — his head reads as the single largest mass in the pose, per still)
# in BearShellAnchor-local space, i.e. before the anchor's own sink/yaw.
# Not mesh-hugging (no primitive in this codebase is, see haunch/shoulder/
# head sphere mounds elsewhere in this file) — generous enough that a child
# can never clip into the visual mesh; the ascent ramps (_build_ascent())
# carry the actual walkable surface on top of/around this blocker.
const BEAR_TORSO_CAPSULE_RADIUS: float = 13.0
const BEAR_TORSO_CAPSULE_HEIGHT: float = 30.0
const BEAR_TORSO_CAPSULE_LOCAL_Y: float = 10.0
const BEAR_HEAD_SPHERE_RADIUS: float = 12.0
const BEAR_HEAD_SPHERE_LOCAL: Vector3 = Vector3(0.0, 25.0, 4.0) # forward-and-up: the bowed head
# World-space read of the head sphere (anchor + local, yaw=90 maps local +Z to
# world +X — see header note): used by _build_ascent()/_build_mountain_dressing()
# to anchor the summit without re-deriving the rotation each time.
const BEAR_HEAD_WORLD_CENTER: Vector3 = Vector3(
	BEAR_SHELL_POSITION.x + BEAR_HEAD_SPHERE_LOCAL.z,
	BEAR_SHELL_POSITION.y + BEAR_HEAD_SPHERE_LOCAL.y,
	BEAR_SHELL_POSITION.z + BEAR_HEAD_SPHERE_LOCAL.x
)


func _build_bear_shell() -> void:
	var anchor := Node3D.new()
	anchor.name = "BearShellAnchor"
	anchor.position = BEAR_SHELL_POSITION
	anchor.rotation_degrees.y = BEAR_SHELL_YAW_DEGREES
	add_child(anchor)

	# Soft collision so nobody clips into him (visual mesh has none of its
	# own) — a torso capsule plus a head sphere, not one long lying capsule
	# (D25: he sits/curls, he does not lie flat — see header note).
	var body := StaticBody3D.new()
	body.name = "BearShellBody"
	body.collision_layer = 1
	body.collision_mask = 0

	var torso_shape := CollisionShape3D.new()
	var torso_capsule := CapsuleShape3D.new()
	torso_capsule.radius = BEAR_TORSO_CAPSULE_RADIUS
	torso_capsule.height = BEAR_TORSO_CAPSULE_HEIGHT
	torso_shape.shape = torso_capsule
	torso_shape.position = Vector3(0.0, BEAR_TORSO_CAPSULE_LOCAL_Y, 0.0)
	body.add_child(torso_shape)

	var head_shape := CollisionShape3D.new()
	var head_sphere := SphereShape3D.new()
	head_sphere.radius = BEAR_HEAD_SPHERE_RADIUS
	head_shape.shape = head_sphere
	head_shape.position = BEAR_HEAD_SPHERE_LOCAL
	body.add_child(head_shape)

	anchor.add_child(body)

	# Rigged giant preferred (keystone clips); static GLB shell fallback.
	if ResourceLoader.exists(BEAR_SHELL_RIG_SCENE):
		var packed: PackedScene = load(BEAR_SHELL_RIG_SCENE)
		var rig: Node3D = packed.instantiate() as Node3D
		if rig != null:
			rig.name = "BearRig"
			var mesh_instance: MeshInstance3D = _find_first_mesh(rig)
			if mesh_instance != null and mesh_instance.mesh != null:
				# Mesh-local AABB only — the glTF importer bakes a 0.01
				# scale on the Armature that skinning already accounts for
				# (rigged_model_slot.gd's 90m-giant lesson).
				var aabb: AABB = mesh_instance.mesh.get_aabb()
				if aabb.size.y > 0.0:
					var s: float = BEAR_SHELL_RIG_STANDING_HEIGHT / aabb.size.y
					rig.scale = Vector3.ONE * s
					rig.position.y = -aabb.position.y * s * 0.0 # clips keep feet at origin
			anchor.add_child(rig)
			var player: AnimationPlayer = rig.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if player == null:
				for child: Node in rig.get_children():
					if child is AnimationPlayer:
						player = child
						break
			if player != null and player.has_animation("sleep"):
				player.play("sleep")
			print("MODEL_SWAP %s" % JSON.stringify({"id": "bramble_bear_rig", "rigged": true, "keystone": true}))
			return

	var slot := ModelSlot.new()
	slot.name = "BearShellSlot"
	slot.model_id = "bramble_bear"
	slot.target_height = BEAR_SHELL_HEIGHT
	anchor.add_child(slot)


func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child: Node in node.get_children():
		var found: MeshInstance3D = _find_first_mesh(child)
		if found != null:
			return found
	return null


# --- D26 disguise pass: "merge him into the ground" (item 3) ----------------
# The director's verdict on v4_wide_disguised/shot_150.png: "the exposed
# silhouette against sky reads as a sitting figure." The old west-side mound
# chain (Haunch/Chest/Shoulder) already reads as foothills at HIS OWN base
# (bramble.gd's own header note), but the NEW massif's base (BEAR_SHELL_
# POSITION, further east) has nothing snuggled against it — its outline
# floats free against the sky from most angles. Three low, half-buried,
# rock-tinted hill masses (same _add_mound helper the Haunch/Shoulder mounds
# already use) close that gap, kept clear of the ascent's own south-flank
# footprint (z>=14 throughout _build_ascent()) by staying at z<=2.
const COLOR_BASE_SKIRT: Color = Color(0.42, 0.47, 0.40) # grey-green-umber, between COLOR_MEADOW and COLOR_FUR_DARK
const BASE_SKIRT_A: Vector3 = Vector3(26.0, -7.0, 2.0) # bridges the old Shoulder mound into the new massif
const BASE_SKIRT_B: Vector3 = Vector3(48.0, -7.0, -2.0) # east/face-facing side — the named disguise gap
const BASE_SKIRT_C: Vector3 = Vector3(34.0, -7.0, -10.0) # north side
const BASE_SKIRT_RADIUS: float = 8.5


func _build_base_skirts() -> void:
	_add_mound("BaseSkirtA", BASE_SKIRT_A, BASE_SKIRT_RADIUS, COLOR_BASE_SKIRT)
	_add_mound("BaseSkirtB", BASE_SKIRT_B, BASE_SKIRT_RADIUS, COLOR_BASE_SKIRT)
	_add_mound("BaseSkirtC", BASE_SKIRT_C, BASE_SKIRT_RADIUS, COLOR_BASE_SKIRT)


# --- D25 ascent: authored switchback path up his back to the summit --------
# Waypoints are world-space; each ramp is a straight PrismMesh slope (same
# primitive _add_paw_ramp already uses) between two waypoints, with a flat
# landing ledge at every turn, ending in a summit platform the DreamDoor sits
# on (_build_ear_and_door()). Placed against the sunk/rescaled
# BearShellAnchor by still (evidence/stills/m3_mountain/v1_*) — not
# mesh-hugging (nothing in this file mesh-hugs an organic surface; see the
# haunch/shoulder sphere mounds), generous enough that the small gap between
# a ledge and his visual fur reads as "resting against him," not "floating
# in open air." d04/d06/d10 ride this path (_build_dreamlings());
# d01/d02/d03/d05/d07/d08/d09 are untouched (D25 brief: pinned coordinates).
# v2 (still-corrected, evidence/stills/m3_mountain/v2_ascent_*): v1's
# waypoints swept east far enough (x up to 58) to visually cross his FACE
# (he faces +X — see BEAR_SHELL_YAW_DEGREES note) instead of climbing his
# back/south flank as intended — caught live in v2_ascent_east/shot_150.png,
# ramps clearly cutting across his snout. v2 keeps Z generously south
# (>=14 throughout, clear of the Shoulder mound's z:-14..14 band at the
# base) and caps X well short of the head's forward reach, ending the
# summit beside/atop his head's south side rather than in front of it.
const ASCENT_BASE: Vector3 = Vector3(18.0, 0.0, 22.0) # meadow trailhead, clear of the Shoulder mound footprint
const ASCENT_L1: Vector3 = Vector3(28.0, 6.0, 32.0)
const ASCENT_L2: Vector3 = Vector3(36.0, 13.0, 36.0)
const ASCENT_L3: Vector3 = Vector3(42.0, 20.0, 30.0)
const ASCENT_L4: Vector3 = Vector3(46.0, 27.0, 20.0)
const ASCENT_SUMMIT: Vector3 = Vector3(44.0, 32.0, 14.0) # platform TOP surface; door rests on it

# v3 (evidence/_scratch/ascent_run2): 4.5m was too narrow for a camera-
# relative un-teleported walk to reliably land on — a still-blending camera
# yaw (or the leash fallback) drifts the diagonal a few meters over a run
# this long, and a narrow ramp gets missed entirely (walked past on the flat
# meadow beside it). 9.0m keeps well past the brief's 3m floor while giving
# real tolerance for that drift.
const ASCENT_RAMP_WIDTH: float = 9.0
# v4 (evidence/_scratch/ascent_run4): widening these to match the ramp
# (9x9) backfired — a ledge box centered ON the waypoint extends back far
# enough along the ramp's own rise to poke its underside (y=top-thickness)
# BELOW the ramp's still-climbing surface a couple meters before the ramp
# actually reaches that height, trapping a walking player against it as a
# low ceiling. Kept modest instead; the ramp's own width (9m) is what
# needed the margin, not the landing.
const ASCENT_LEDGE_SIZE: Vector2 = Vector2(8.0, 8.0)
const ASCENT_LEDGE_THICKNESS: float = 2.5
const ASCENT_SUMMIT_SIZE: Vector2 = Vector2(9.0, 9.0)
# D26 disguise pass (director verdict on v4_wide_disguised/shot_150.png:
# "dark chocolate slabs reading as scaffolding, not a mountain trail"): the
# old flat COLOR_PATH_DIRT tan is gone — ramps/ledges now carry the SAME
# ground_patches.gdshader patchy-tint treatment the meadow already uses
# (_ground_patch_material(), below), with a grey-umber stone pair instead of
# a single flat brown, so the trail reads as a worn stone path rather than a
# painted plank.
const COLOR_PATH_STONE_A: Color = Color("8C8478") # warm grey stone
const COLOR_PATH_STONE_B: Color = Color("6E6355") # darker grey-umber, patch B

# Per-segment CameraHint yaw (degrees; same convention as _build_camera_hints:
# 0=-Z forward, -90=+X, +90=-X), one per ramp segment below, computed from
# that segment's own direction of travel so the auto-camera looks up-slope
# while a player climbs it (the "on-rails-ish" framing, D25/D18).
const ASCENT_HINT_YAWS: Array[float] = [-135.0, -117.0, -45.0, -22.0, 18.0]


func _build_ascent() -> void:
	# Bridges a real gap between the two pre-existing hints (MeadowApproach-
	# Hint: x<0 any z; ClimbHint: |z|<20 any x within its box) and the new
	# ASCENT_BASE trailhead at z=22 -- caught live running bramble_ascent.
	# json (--poslog): with no hint covering x:0..20,z~22, CameraRig falls
	# back to its velocity leash, whose heading formula (camera_rig.gd,
	# core/**, out of this file's territory) yawed the camera to face BACK
	# the way the player came, producing a walk-into-reverse oscillation
	# instead of a straight climb toward the trailhead. Same yaw (-90, +X)
	# as its neighbors, so ties where boxes overlap are harmless.
	_add_camera_hint("AscentApproachHint", Vector3(5.0, 7.5, 22.0), Vector3(40.0, 15.0, 16.0), -90.0, 1, 0.9)

	var waypoints: Array[Vector3] = [ASCENT_BASE, ASCENT_L1, ASCENT_L2, ASCENT_L3, ASCENT_L4, ASCENT_SUMMIT]
	for i: int in range(waypoints.size() - 1):
		_add_ascent_ramp("AscentRamp%d" % (i + 1), waypoints[i], waypoints[i + 1])
		var mid: Vector3 = (waypoints[i] + waypoints[i + 1]) * 0.5
		var span: Vector3 = (waypoints[i + 1] - waypoints[i]).abs()
		# v6 (evidence/_scratch/ascent_run5): a walking player veered off
		# past L1 instead of settling on it — root cause wasn't the ramp/
		# ledge seam (thickening the ledge, v5, made no difference); it was
		# THIS hint's box overlapping AscentHint2's box with the SAME
		# priority, so CameraRig._find_active_hint ties between them near
		# every segment boundary and the yaw can land on whichever the
		# physics query returns first — neither -135 nor a clean -117, some
		# unstable blend of both. Two changes: tighter padding (span+6, not
		# +12) shrinks the overlap; a strictly increasing priority per
		# segment (2,3,4,5,6) makes every tie resolve toward the segment
		# the player has actually progressed into, not an arbitrary pick.
		_add_camera_hint("AscentHint%d" % (i + 1), mid + Vector3(0.0, 3.0, 0.0),
			Vector3(span.x + 6.0, 12.0, span.z + 6.0), ASCENT_HINT_YAWS[i], 2 + i, 0.9)
	var ledges: Dictionary = {} # index -> the ledge's MeshInstance3D (for dressing/heartbeat below)
	for i: int in range(1, waypoints.size() - 1):
		ledges[i] = _add_ascent_ledge("AscentLedge%d" % i, waypoints[i], ASCENT_LEDGE_SIZE)
	_add_ascent_ledge("SummitPlatform", ASCENT_SUMMIT, ASCENT_SUMMIT_SIZE)
	_add_camera_hint("SummitHint", ASCENT_SUMMIT + Vector3(0.0, 4.0, 0.0), Vector3(16.0, 12.0, 16.0), 180.0, 8, 0.9)

	# D26 disguise pass: rock curbs + a couple of dressed landings along the
	# trail (item 4, "trail, not scaffolding").
	_build_ascent_dressing(waypoints)
	# D26 joy pass #5 (NEXT_STEPS.md §1b): the heartbeat crossing rides
	# AscentLedge3 (ASCENT_L3, roughly mid-ascent — the 3rd of 4 switchback
	# landings) so it lands partway up the climb, not at the very base or top.
	if ledges.has(3) and is_instance_valid(ledges[3]):
		_build_heartbeat_crossing(ASCENT_L3, ledges[3] as Node3D)


## Straight sloped ramp between two waypoints (differing only in height —
## every ASCENT_* pair here climbs). Rotation derived from the segment's own
## horizontal direction: PrismMesh's local +X (the "ridge rises this way"
## axis _add_paw_ramp already uses, left_to_right=1.0) maps to world
## (cos(yaw), 0, -sin(yaw)) under a plain Y-rotation, so yaw =
## atan2(-delta.z, delta.x) points local +X at the target — confirmed
## against _add_paw_ramp's own zero-rotation case (delta=(RUN,0), yaw=0).
func _add_ascent_ramp(ramp_name: String, from_point: Vector3, to_point: Vector3) -> MeshInstance3D:
	var delta: Vector3 = to_point - from_point
	var run: float = Vector2(delta.x, delta.z).length()
	var rise: float = delta.y
	var yaw: float = atan2(-delta.z, delta.x)

	var mesh := PrismMesh.new()
	mesh.size = Vector3(run, absf(rise), ASCENT_RAMP_WIDTH)
	mesh.left_to_right = 1.0 if rise >= 0.0 else 0.0

	var center: Vector3 = (from_point + to_point) * 0.5
	center.y = minf(from_point.y, to_point.y) + absf(rise) * 0.5

	var visual := MeshInstance3D.new()
	visual.name = ramp_name
	visual.mesh = mesh
	visual.position = center
	visual.rotation.y = yaw
	add_child(visual)
	# D26 stone retint (see COLOR_PATH_STONE_* comment above) — PrimitiveMesh
	# only exposes one `.material` slot, so the patchy tint goes on the
	# MeshInstance3D's surface override, same as _build_meadow()'s own Meadow
	# slab does for the ground_patches shader.
	visual.set_surface_override_material(0, _ground_patch_material(COLOR_PATH_STONE_A, COLOR_PATH_STONE_B))

	var body := StaticBody3D.new()
	body.name = ramp_name + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	shape.position = center
	shape.rotation.y = yaw
	body.add_child(shape)
	add_child(body)
	return visual


## Flat landing ledge whose TOP surface sits exactly at top_point.y — matches
## _add_ground_slab's own top_y/thickness convention so a dreamling or the
## summit door can anchor directly to the waypoint constant with no extra
## surface-height lookup. Returns the visual MeshInstance3D so callers (the
## heartbeat crossing, dressing) can attach to a specific ledge without a
## second get_node_or_null lookup.
func _add_ascent_ledge(ledge_name: String, top_point: Vector3, size: Vector2) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, ASCENT_LEDGE_THICKNESS, size.y)

	var center: Vector3 = Vector3(top_point.x, top_point.y - ASCENT_LEDGE_THICKNESS * 0.5, top_point.z)

	var visual := MeshInstance3D.new()
	visual.name = ledge_name
	visual.mesh = mesh
	visual.position = center
	add_child(visual)
	visual.set_surface_override_material(0, _ground_patch_material(COLOR_PATH_STONE_A, COLOR_PATH_STONE_B))

	var body := StaticBody3D.new()
	body.name = ledge_name + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	shape.position = center
	body.add_child(shape)
	add_child(body)
	return visual


# --- D26 disguise item 4 ("trail, not scaffolding") + joy pass items 5/8/9 --
# Curb stones along the ramps' outer edges, a couple of dressed switchback
# landings, the ascent's seed-puff toys, and the wordless trailhead sign —
# all visual-only walk-through (the fort convention: _add_dressing_prop
# never adds collision), so none of this can ever narrow the actual
# ASCENT_RAMP_WIDTH a player walks on.
const CURB_STONES_PER_SIDE: int = 3
const CURB_OFFSET: float = ASCENT_RAMP_WIDTH * 0.5 + 1.0
const COLOR_CURB_STONE: Color = Color(0.55, 0.58, 0.52)


func _build_ascent_dressing(waypoints: Array[Vector3]) -> void:
	for i: int in range(waypoints.size() - 1):
		_add_ramp_curbs(waypoints[i], waypoints[i + 1], i)
	# A pine and a lantern at two of the switchback landings, offset off the
	# natural walk-through line (same convention d04/d06 already use for
	# their own ledge offsets in _build_dreamlings()).
	_add_dressing_prop("AscentLandingPine", "soft_pine_small", 1.8, waypoints[2] + Vector3(2.6, 0.0, -2.6),
		_dressing_cone(0.6, 1.8, Color("7C9082")))
	_add_dressing_prop("AscentLandingLamp", "mushroom_lamp", 0.5, waypoints[4] + Vector3(2.6, 0.0, -2.6),
		_dressing_sphere(0.25, Color("F2C879")))
	_build_ascent_seed_puffs(waypoints)
	_build_trailhead_sign(waypoints[0])


func _add_ramp_curbs(from_point: Vector3, to_point: Vector3, ramp_index: int) -> void:
	var delta: Vector3 = to_point - from_point
	var horizontal: Vector2 = Vector2(delta.x, delta.z)
	if horizontal.length() < 0.01:
		return
	var dir: Vector2 = horizontal.normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var sides: Array[float] = [-1.0, 1.0]
	for i: int in range(1, CURB_STONES_PER_SIDE + 1):
		var t: float = float(i) / float(CURB_STONES_PER_SIDE + 1)
		var along: Vector3 = from_point.lerp(to_point, t)
		for side: float in sides:
			var offset: Vector2 = perp * CURB_OFFSET * side
			var pos: Vector3 = along + Vector3(offset.x, 0.15, offset.y)
			_add_dressing_prop("AscentCurb%d_%d_%d" % [ramp_index, i, int(side)], "stone_soft", 0.5, pos,
				_dressing_sphere(0.25, COLOR_CURB_STONE))


func _build_ascent_seed_puffs(waypoints: Array[Vector3]) -> void:
	# BUG FIX (caught live via tools/harness/scripts/bramble_disguise_joy.json:
	# a pounding Otto teleported next to the original (waypoints[0] + (2,-2))
	# offset slid ~40m off course instead of landing where placed). That
	# offset's dot product with Ramp1's own travel direction ((1,1)
	# normalized, base->L1) was POSITIVE and its perpendicular distance from
	# the ramp centerline (2.83m) was well inside the ramp's own 4.5m
	# half-width -- the toy (and anyone standing on it) was sitting on the
	# SLOPED ramp surface, not flat meadow ground; Jolt + the pound's hard
	# "committed drop" evidently turned that slope into a slide/launch.
	# (-3,-3) has a NEGATIVE dot product with the same direction -- behind
	# the ramp's own start edge entirely, on flat pre-climb meadow.
	_add_seed_puff_toy("SeedPuffToyBase", waypoints[0] + Vector3(-3.0, 0.4, -3.0))
	_add_seed_puff_toy("SeedPuffToyL2", waypoints[2] + Vector3(1.8, 0.4, 1.8))
	_add_seed_puff_toy("SeedPuffToyL4", waypoints[4] + Vector3(-1.8, 0.4, -1.8))


func _add_seed_puff_toy(toy_name: String, pos: Vector3) -> void:
	var toy := SeedPuffToy.new()
	toy.name = toy_name
	toy.position = pos
	add_child(toy)


## HeartbeatCrossing rides a specific ledge (bramble.gd's own AscentLedge3,
## ASCENT_L3 — see _build_ascent()'s wiring). ledge_top: the waypoint itself
## (already the ledge's TOP surface y, per _add_ascent_ledge's own
## top_point.y convention), so no thickness math needed here.
func _build_heartbeat_crossing(ledge_top: Vector3, ledge_visual: Node3D) -> void:
	var heartbeat := HeartbeatCrossing.new()
	heartbeat.name = "HeartbeatCrossing"
	# setup() BEFORE add_child() -- this file's established ordering rule.
	heartbeat.setup(ASCENT_LEDGE_SIZE, ledge_visual)
	heartbeat.position = ledge_top
	add_child(heartbeat)


## A tiny wordless trailhead sign (joy pass #9): a wooden post + flat sign
## face bearing a crescent-moon-and-zzz icon built from primitives only (per
## the brief: "a drawn texture is overkill"). Offset off the walkable
## centerline so it never intrudes on the ascent's own approach.
func _build_trailhead_sign(trailhead: Vector3) -> void:
	var base: Vector3 = trailhead + Vector3(-3.2, 0.0, 0.6)

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.09
	post_mesh.bottom_radius = 0.12
	post_mesh.height = 1.6
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = COLOR_FUR_DARK
	post_mesh.material = post_mat
	var post := MeshInstance3D.new()
	post.name = "TrailheadPost"
	post.mesh = post_mesh
	post.position = base + Vector3(0.0, 0.8, 0.0)
	add_child(post)

	var face_mesh := CylinderMesh.new()
	face_mesh.top_radius = 0.42
	face_mesh.bottom_radius = 0.42
	face_mesh.height = 0.06
	var face_color: Color = COLOR_FUR_DARK
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = face_color
	face_mesh.material = face_mat
	var face := MeshInstance3D.new()
	face.name = "TrailheadSignFace"
	face.mesh = face_mesh
	face.position = base + Vector3(0.0, 1.55, 0.0)
	face.rotation_degrees = Vector3(0.0, 0.0, 90.0) # disc facing outward, toward the trailhead approach
	add_child(face)

	# Crescent moon: a pale sphere with a second, sign-colored sphere offset
	# to bite a shadow out of it -- primitive-only, no texture.
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 0.14
	moon_mesh.height = 0.28
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_color = Color("F5F2E8")
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mesh.material = moon_mat
	var moon := MeshInstance3D.new()
	moon.name = "TrailheadMoon"
	moon.mesh = moon_mesh
	moon.position = base + Vector3(0.06, 1.6, -0.35)
	add_child(moon)

	var bite_mesh := SphereMesh.new()
	bite_mesh.radius = 0.13
	bite_mesh.height = 0.26
	var bite_mat := StandardMaterial3D.new()
	bite_mat.albedo_color = face_color
	bite_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bite_mesh.material = bite_mat
	var bite := MeshInstance3D.new()
	bite.name = "TrailheadMoonBite"
	bite.mesh = bite_mesh
	bite.position = base + Vector3(0.14, 1.62, -0.32)
	add_child(bite)

	# Three small "zzz" blocks, wordless sleep icon, shrinking on a diagonal.
	var zzz_sizes: Array[float] = [0.07, 0.05, 0.035]
	for i: int in range(zzz_sizes.size()):
		var s: float = zzz_sizes[i]
		var z_mesh := BoxMesh.new()
		z_mesh.size = Vector3(s * 2.2, s * 0.5, 0.02)
		var z_mat := StandardMaterial3D.new()
		z_mat.albedo_color = Color("F2C879")
		z_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		z_mesh.material = z_mat
		var z := MeshInstance3D.new()
		z.name = "TrailheadZ%d" % i
		z.mesh = z_mesh
		z.position = base + Vector3(-0.05 + float(i) * 0.09, 1.62 + float(i) * 0.11, -0.32)
		z.rotation_degrees = Vector3(0.0, 0.0, -25.0)
		add_child(z)


# --- Dreamkeepers (M2, director wire-up of the dormant data file) ------------

const DREAMKEEPER_SCENE: PackedScene = preload("res://worlds/common/dreamkeeper.tscn")
const DREAMKEEPER_DATA_PATH_FORMAT: String = "res://data/dreamkeepers/%s.json"


func _build_dreamkeepers() -> void:
	var path: String = DREAMKEEPER_DATA_PATH_FORMAT % world_id()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("Bramble: dreamkeeper data at %s did not parse to a Dictionary" % path)
		return
	var list: Variant = (parsed as Dictionary).get("dreamkeepers", [])
	if not (list is Array):
		return
	for entry: Variant in (list as Array):
		if entry is Dictionary:
			_spawn_dreamkeeper(entry as Dictionary)


func _spawn_dreamkeeper(entry: Dictionary) -> void:
	var pos_raw: Variant = entry.get("pos", [])
	if not (pos_raw is Array) or (pos_raw as Array).size() < 3:
		push_warning("Bramble: dreamkeeper entry '%s' has no valid 'pos' -- skipped" % String(entry.get("id", "?")))
		return
	var pos_arr: Array = pos_raw as Array
	var keeper: Dreamkeeper = DREAMKEEPER_SCENE.instantiate() as Dreamkeeper
	keeper.name = "Dreamkeeper_%s" % String(entry.get("id", "keeper"))
	# Set BEFORE add_child (established codebase ordering -- see
	# dreamkeeper.gd's own header).
	keeper.keeper_id = String(entry.get("id", ""))
	keeper.rig_id = String(entry.get("rig", ""))
	keeper.face_yaw_degrees = float(entry.get("face_yaw", 0.0))
	keeper.position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
	add_child(keeper)


## D26 joy pass #7 ("Dreamkeeper picnic"): moves the moth-shepherd
## dreamkeeper (data/dreamkeepers/bramble.json, spawned at the old meadow
## position by _build_dreamkeepers() above) to a mid-ascent landing, with a
## picnic_basket prop beside it. data/** stays untouched (out of this pass's
## territory, autoloads/data being public-API-only per the brief) -- this
## repositions the ALREADY-SPAWNED node instead, entirely in bramble.gd.
const DREAMKEEPER_PICNIC_ID: String = "moth_meadow_shepherd"
const DREAMKEEPER_PICNIC_OFFSET: Vector3 = Vector3(-2.0, 0.0, 1.8) # ASCENT_L2, opposite corner from d04


func _build_dreamkeeper_picnic() -> void:
	var keeper: Dreamkeeper = get_node_or_null("Dreamkeeper_%s" % DREAMKEEPER_PICNIC_ID) as Dreamkeeper
	if keeper == null:
		return # data file missing/renamed elsewhere -- fail soft, never crash
	var new_pos: Vector3 = ASCENT_L2 + DREAMKEEPER_PICNIC_OFFSET
	keeper.position = new_pos
	# Face back down the trail toward arriving climbers -- same atan2(x,z)
	# convention dreamkeeper.gd's own _update_facing() uses to turn toward a
	# nearby player. face_yaw_degrees is the class's public @export "resting
	# orientation" field, so setting it (not just .rotation) keeps the new
	# facing even after it wakes/sleeps and eases back toward "resting."
	var to_l1: Vector3 = ASCENT_L1 - new_pos
	keeper.face_yaw_degrees = rad_to_deg(atan2(to_l1.x, to_l1.z))
	keeper.rotation.y = deg_to_rad(keeper.face_yaw_degrees)

	_add_dressing_prop("DreamkeeperPicnicBasket", "picnic_basket", 0.4, new_pos + Vector3(0.9, 0.0, 0.6),
		_dressing_sphere(0.2, Color("E8C97A")))


## D26 joy pass #6: a small hush alcove near the summit/head. See worlds/
## bramble/whisper_spot.gd for the full behavior and the territory note on
## why "whisper_shh" isn't added to data/moon_lines.json here.
const WHISPER_SPOT_OFFSET: Vector3 = Vector3(-3.0, 1.0, -3.0) # clear of the DreamDoor's own trigger box (3.6x4.6x3.6) and d10


func _build_whisper_spot() -> void:
	var spot := WhisperSpot.new()
	spot.name = "WhisperSpot"
	spot.position = ASCENT_SUMMIT + WHISPER_SPOT_OFFSET
	add_child(spot)


# --- Dressing (M2 batch-2 props; all visual-only walk-through, fort's
# convention -- zero route interference with harness choreography) -----------

const MOON_DAISY_POSITIONS: Array[Vector3] = [
	Vector3(-52.0, 0.0, -6.0), Vector3(-45.0, 0.0, 20.0),
	Vector3(-35.0, 0.0, 26.0), Vector3(-58.0, 0.0, 18.0),
]
const CLOVER_POSITIONS: Array[Vector3] = [
	Vector3(-50.0, 0.0, -20.0), Vector3(-38.0, 0.0, 18.0),
	Vector3(-25.0, 0.0, -30.0), Vector3(-15.0, 0.0, 32.0),
]
const MUSHROOM_LAMP_POSITIONS: Array[Vector3] = [
	Vector3(-60.0, 0.0, -8.0), Vector3(-48.0, 0.0, 14.0), Vector3(-62.0, 0.0, 10.0),
]
const SEED_PUFF_POSITIONS: Array[Vector3] = [
	Vector3(55.0, 0.0, 20.0), Vector3(60.0, 0.0, 28.0), Vector3(52.0, 0.0, 26.0),
]
const PINE_BIG_POSITIONS: Array[Vector3] = [
	Vector3(-66.0, 0.0, -30.0), Vector3(-66.0, 0.0, 30.0),
]
const PINE_SMALL_POSITIONS: Array[Vector3] = [
	Vector3(-64.0, 0.0, -18.0), Vector3(-30.0, 0.0, 34.0), Vector3(5.0, 0.0, -36.0),
]
const STONE_POSITIONS: Array[Vector3] = [
	Vector3(10.0, 0.0, -34.0), Vector3(-8.0, 0.0, 36.0),
]


func _build_dressing() -> void:
	for i: int in MOON_DAISY_POSITIONS.size():
		_add_dressing_prop("MoonDaisy%d" % i, "moon_daisy", 0.4, MOON_DAISY_POSITIONS[i],
			_dressing_sphere(0.15, Color("FFF3C4")))
	for i: int in CLOVER_POSITIONS.size():
		_add_dressing_prop("CloverTuft%d" % i, "clover_tuft", 0.3, CLOVER_POSITIONS[i],
			_dressing_sphere(0.15, Color("6E8F6A")))
	for i: int in MUSHROOM_LAMP_POSITIONS.size():
		_add_dressing_prop("MushroomLamp%d" % i, "mushroom_lamp", 0.5, MUSHROOM_LAMP_POSITIONS[i],
			_dressing_sphere(0.25, Color("F2C879")))
	for i: int in SEED_PUFF_POSITIONS.size():
		_add_dressing_prop("SeedPuff%d" % i, "seed_puff", 0.35, SEED_PUFF_POSITIONS[i],
			_dressing_sphere(0.17, Color("F5F2E8")))
	for i: int in PINE_BIG_POSITIONS.size():
		_add_dressing_prop("SoftPine%d" % i, "soft_pine", 3.0, PINE_BIG_POSITIONS[i],
			_dressing_cone(1.0, 3.0, Color("7C9082")))
	for i: int in PINE_SMALL_POSITIONS.size():
		_add_dressing_prop("SoftPineSmall%d" % i, "soft_pine_small", 1.8, PINE_SMALL_POSITIONS[i],
			_dressing_cone(0.6, 1.8, Color("7C9082")))
	for i: int in STONE_POSITIONS.size():
		_add_dressing_prop("StoneSoft%d" % i, "stone_soft", 0.7, STONE_POSITIONS[i],
			_dressing_sphere(0.35, Color(0.55, 0.58, 0.52)))
	_add_dressing_prop("StumpDoor", "stump_door", 0.8, Vector3(-68.0, 0.0, 0.0),
		_dressing_sphere(0.4, Color("6E4F3E")))
	_add_dressing_prop("HaystackPillow", "haystack_pillow", 0.8, Vector3(30.0, 0.0, 28.0),
		_dressing_sphere(0.4, Color("E8C97A")))


func _add_dressing_prop(anchor_name: String, prop_model_id: String, prop_height: float, prop_position: Vector3, primitive_mesh: Mesh) -> void:
	var anchor := Node3D.new()
	anchor.name = anchor_name
	anchor.position = prop_position
	add_child(anchor)

	var visual := MeshInstance3D.new()
	visual.name = "Primitive"
	visual.mesh = primitive_mesh
	visual.position = Vector3(0.0, prop_height * 0.5, 0.0)
	anchor.add_child(visual)

	var slot := ModelSlot.new()
	slot.name = "ModelSlot"
	slot.model_id = prop_model_id
	slot.target_height = prop_height
	anchor.add_child(slot)


func _dressing_sphere(radius: float, color: Color) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	return mesh


func _dressing_cone(radius: float, height: float, color: Color) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	return mesh


## D25: the terrain-disguise registry (worlds/bramble/mountain_dressing.gd) —
## stones/pines/snow-caps/cloud-ring dressing the massif + ascent path, with
## the reveal() API the finale calls (rollover_sequence.gd, timed to the
## "wake" keystone clip). D26 disguise pass: the cloud ring now wreathes
## BEAR_HEAD_WORLD_CENTER directly (not the shell anchor) — see mountain_
## dressing.gd's own header for why that's what makes it read as a bank
## hiding the head instead of a ring near the shoulders.


func _build_mountain_dressing() -> void:
	var dressing := MountainDressing.new()
	dressing.name = "MountainDressing"
	var waypoints: Array[Vector3] = [ASCENT_BASE, ASCENT_L1, ASCENT_L2, ASCENT_L3, ASCENT_L4, ASCENT_SUMMIT]
	# setup() BEFORE add_child() — established ordering rule in this file
	# (see _build_rollover()'s own comment: entering the tree fires _ready()
	# synchronously, so a reversed order runs _ready() before setup() lands).
	dressing.setup(self, world_id(), BEAR_HEAD_WORLD_CENTER, waypoints)
	add_child(dressing)


## Warm practical fill at the fireflies area (recipe: "warm fill lights at
## practicals ... bramble fireflies area") — bramble had no warm light
## source before this (only the cool moon key from core/env/ambience.gd),
## so this is the one this world's own script needed to add, unlike
## pillow_fort/marmalade whose porch/window lights already existed.
func _build_ambient_lighting() -> void:
	var light := OmniLight3D.new()
	light.name = "FireflyAreaGlow"
	light.light_color = FIREFLY_FILL_COLOR
	light.light_energy = 0.5
	light.omni_range = 7.0
	light.position = FIREFLY_FILL_POSITION
	add_child(light)

	# ROUND 2 (director's note 5): broad warm wash from the bear's own body,
	# distinct from the point-source firefly glow above.
	var bear_fill := OmniLight3D.new()
	bear_fill.name = "BearWarmFill"
	bear_fill.light_color = BEAR_WARM_FILL_COLOR
	bear_fill.light_energy = BEAR_WARM_FILL_ENERGY
	bear_fill.omni_range = BEAR_WARM_FILL_RANGE
	bear_fill.position = BEAR_WARM_FILL_POSITION
	add_child(bear_fill)


## Wind-swayed grass patches (assets/shaders/wind_sway.gdshader via
## core/env/grass_field.gd) — visual only, no collision, planted in the
## meadow the way the recipe asks ("plant fields in bramble's meadow
## areas"). Deterministic seeds so screenshot/harness receipts stay stable.
func _build_grass_fields() -> void:
	_add_grass_patch("GrassPatchA", GRASS_PATCH_A_CENTER, 1)
	_add_grass_patch("GrassPatchB", GRASS_PATCH_B_CENTER, 2)


## ROUND 2 (director's note 1, "grass reads as cold dark spikes"): dropped
## the fur-lerp tint (it muddied toward COLOR_FUR_DARK, a big part of why
## this read cold/brown instead of like sage lawn) and the taller 0.4 m
## override -- GrassField's own class defaults are now exactly the spec's
## "#7C9082 base toward #9DB39A tips", short/wide/clumped, so this patch
## just uses them.
func _add_grass_patch(patch_name: String, center: Vector3, rng_seed: int) -> void:
	var field := GrassField.new()
	field.name = patch_name
	add_child(field)
	field.scatter(center, GRASS_PATCH_SIZE, GRASS_DENSITY, rng_seed)


## M2 set piece #1 ("the breath becomes weather"): the ambient, always-on
## Divine-Beast body-function. See worlds/bramble/breath_weather.gd.
func _build_breath_weather() -> void:
	var weather := BreathWeather.new()
	weather.name = "BreathWeather"
	weather.position = BREATH_UPDRAFT_POSITION
	add_child(weather)


## M2 set piece #2 ("THE ROLL-OVER"): the one-time transformative
## Divine-Beast body-function. See worlds/bramble/rollover_sequence.gd.
## Wired after _build_haunch() (called earlier in _ready()) so the Haunch/
## HaunchBody nodes it settles already exist.
func _build_rollover() -> void:
	var rollover := RolloverSequence.new()
	rollover.name = "RolloverSequence"
	# setup() BEFORE add_child(): entering the tree fires _ready()
	# synchronously, so a reversed order would run _ready() with _world/
	# _haunch_visual/_haunch_body still unset (caught live: SCRIPT ERROR
	# "Invalid access to property... on a base object of type 'Nil'" at
	# rollover_sequence.gd's _ready(), see bramble-setpieces-VERIFY.md).
	rollover.setup(self, get_node("Haunch") as MeshInstance3D, get_node("HaunchBody") as StaticBody3D)
	add_child(rollover)


# --- D25 layout-iteration tool: a static free camera for framing stills while
# placing the massif/ascent/dressing blind (no editor, headless CLI only).
# Inert unless --devcam is passed; never affects normal play. Reads
# --devcam_pos=x,y,z / --devcam_look=x,y,z (comma floats) so a still can be
# re-aimed per capture without a code edit each time.
func _build_dev_camera() -> void:
	var devcam_flag: Variant = Harness.flag("devcam", false)
	if devcam_flag == false or devcam_flag == null:
		return
	var cam := Camera3D.new()
	cam.name = "DevCam"
	add_child(cam)
	cam.position = _parse_vec3(str(Harness.flag("devcam_pos", "")), Vector3(20.0, 45.0, 95.0))
	cam.look_at(_parse_vec3(str(Harness.flag("devcam_look", "")), Vector3(20.0, 10.0, 0.0)), Vector3.UP)
	cam.fov = float(str(Harness.flag("devcam_fov", "60")))
	cam.current = true
	print("DEVCAM %s" % JSON.stringify({"pos": [cam.position.x, cam.position.y, cam.position.z]}))


func _parse_vec3(s: String, fallback: Vector3) -> Vector3:
	var parts: PackedStringArray = s.split(",")
	if parts.size() < 3:
		return fallback
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func world_id() -> String:
	return "bramble"


func spawn_points() -> Dictionary:
	var facing_bear: Basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP) # +X, toward the bear
	return {
		"pip": Transform3D(facing_bear, SPAWN_PIP),
		"otto": Transform3D(facing_bear, SPAWN_OTTO),
	}


func objective_ids() -> Array[String]:
	return ["d01", "d02", "d03", "d04", "d05", "d06", "d07", "d08", "d09", "d10"] as Array[String]


func rescue_floor_y() -> float:
	return RESCUE_FLOOR_Y


## The way home: a doorframe at the meadow edge behind spawn, facing the
## bear, so leaving is always one interact away (worlds are never gated).
func _build_home_door() -> void:
	var door := WorldDoor.new()
	door.name = "HomeDoor"
	door.target_world = "pillow_fort"
	door.position = Vector3(SPAWN_PIP.x - 6.0, 0.0, 1.0)
	door.rotation_degrees = Vector3(0.0, 90.0, 0.0) # opening faces the bear (+X)
	door.exit_requested.connect(func() -> void:
		exit_requested_to.emit("pillow_fort")
		exit_requested.emit()
	)
	add_child(door)


# --- Geometry helpers -------------------------------------------------------

## Height of a sphere mound's surface directly above world (x, z); 0 if that
## point is outside the sphere's footprint. Used to anchor props exactly on
## a mound's surface instead of hand-guessing elevations.
func _sphere_surface_y(center: Vector3, radius: float, x: float, z: float) -> float:
	var dx: float = x - center.x
	var dz: float = z - center.z
	var under_sqrt: float = radius * radius - dx * dx - dz * dz
	if under_sqrt < 0.0:
		return center.y
	return center.y + sqrt(under_sqrt)


func _build_meadow() -> void:
	_add_ground_slab("Moat", MOAT_SIZE, MOAT_TOP_Y, MOAT_THICKNESS, COLOR_MOAT)
	# D27 terrain v1 (producer: "even Mario 64 had its polygons"): the
	# meadow is a gently ROLLING heightfield now, not a flat box — same
	# name, same footprint, same layer-1 collision contract, borders eased
	# to exactly y=0 so the moat ring stays flush. Flat discs pin the
	# ground level around authored anchors (spawns, home door, ascent
	# trailhead) so arrivals and doorways never tilt. TerrainPatch IS a
	# MeshInstance3D, so the patchy-shader override below is unchanged.
	var meadow := TerrainPatch.new()
	meadow.name = "Meadow"
	var flat_discs: Array[Vector3] = [
		Vector3(SPAWN_PIP.x, SPAWN_PIP.z, 7.0), # arrival clearing (covers both spawns + HomeDoor)
		Vector3(SPAWN_PIP.x - 6.0, 1.0, 5.0), # HomeDoor's own footing
		Vector3(ASCENT_BASE.x, ASCENT_BASE.z, 6.0), # trailhead — the first ramp's seam stays true
	]
	meadow.setup(MEADOW_SIZE, 0.45, 18.0, 7, flat_discs, 8.0, TerrainPatch.DEFAULT_RESOLUTION, 9.5)
	add_child(meadow)
	# ROUND 2 (director's note 2): the meadow is the world's main walkable
	# ground -- give it the patchy sage/warm-moss shader (the moat stays
	# flat: it's a boundary void ring, not gameplay ground).
	(get_node("Meadow") as MeshInstance3D).set_surface_override_material(0, _ground_patch_material(GROUND_TINT_A, GROUND_TINT_B))


## D22 graphics-v2 ROUND 2, assets/shaders/ground_patches.gdshader (director's
## note 2): builds a ShaderMaterial pre-loaded with a world's near-neighbor
## tint pair.
func _ground_patch_material(tint_a: Color, tint_b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ground_patches.gdshader") as Shader
	mat.set_shader_parameter("tint_a", tint_a)
	mat.set_shader_parameter("tint_b", tint_b)
	return mat


func _add_ground_slab(slab_name: String, size: Vector2, top_y: float, thickness: float, color: Color, xz_center: Vector2 = Vector2.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, thickness, size.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

	var center: Vector3 = Vector3(xz_center.x, top_y - thickness * 0.5, xz_center.y)

	var visual := MeshInstance3D.new()
	visual.name = slab_name
	visual.mesh = mesh
	visual.position = center
	add_child(visual)

	var body := StaticBody3D.new()
	body.name = slab_name + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = mesh.size
	shape.shape = box_shape
	shape.position = center
	body.add_child(shape)
	add_child(body)


func _add_mound(mound_name: String, center: Vector3, radius: float, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = mound_name
	visual.mesh = mesh
	visual.position = center
	add_child(visual)

	var body := StaticBody3D.new()
	body.name = mound_name + "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	shape.shape = sphere_shape
	shape.position = center
	body.add_child(shape)
	add_child(body)


func _build_haunch() -> void:
	_add_mound("Haunch", HAUNCH_CENTER, HAUNCH_RADIUS, COLOR_FUR)


func _build_chest() -> void:
	_chest = BreathingChest.new()
	_chest.name = "Chest"
	_chest.footprint = CHEST_FOOTPRINT
	_chest.thickness = CHEST_THICKNESS
	_chest.amplitude = CHEST_AMPLITUDE
	_chest.period = CHEST_PERIOD
	_chest.surface_color = COLOR_FUR
	_chest.position = CHEST_POSITION
	add_child(_chest)

	# Static pedestal beneath so there is never a hole under the plank, even
	# at the lowest point of its breath.
	var lowest_top: float = (CHEST_POSITION.y + CHEST_THICKNESS * 0.5) - CHEST_AMPLITUDE
	var pedestal_top: float = lowest_top - CHEST_PEDESTAL_CLEARANCE
	var pedestal_footprint: Vector2 = CHEST_FOOTPRINT + Vector2(CHEST_PEDESTAL_MARGIN, CHEST_PEDESTAL_MARGIN) * 2.0
	_add_ground_slab("ChestPedestal", pedestal_footprint, pedestal_top, CHEST_PEDESTAL_THICKNESS,
		COLOR_FUR_DARK, Vector2(CHEST_POSITION.x, CHEST_POSITION.z))


func _build_shoulder() -> void:
	_add_mound("Shoulder", SHOULDER_CENTER, SHOULDER_RADIUS, COLOR_FUR)
	_build_shelf()


func _build_shelf() -> void:
	var anchor_y: float = _sphere_surface_y(SHOULDER_CENTER, SHOULDER_RADIUS, SHELF_ANCHOR_X, SHELF_ANCHOR_Z)
	var shelf_center: Vector3 = Vector3(SHELF_ANCHOR_X, anchor_y + SHELF_HEIGHT_ABOVE_ANCHOR, SHELF_ANCHOR_Z)

	var mesh := BoxMesh.new()
	mesh.size = SHELF_SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_FUR_DARK
	mesh.material = mat

	var visual := MeshInstance3D.new()
	visual.name = "ShoulderShelf"
	visual.mesh = mesh
	visual.position = shelf_center
	add_child(visual)

	var body := StaticBody3D.new()
	body.name = "ShoulderShelfBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = SHELF_SIZE
	shape.shape = box_shape
	shape.position = shelf_center
	body.add_child(shape)
	add_child(body)


## D25: the ear/DreamDoor moved from the old grey-box head mound to the
## summit of the new rigged massif (ASCENT_SUMMIT, the top of the authored
## ascent — see _build_ascent()). The SummitPlatform ledge it built already
## reads as the "ear hollow" landing; no separate bump sphere needed here
## the way the old flat mound-top did. Function name kept (D26 minimal-diff
## convention — same door, same "ear" fiction, new coordinates).
func _build_ear_and_door() -> void:
	var door: DreamDoor = DREAM_DOOR_SCENE.instantiate() as DreamDoor
	door.name = "DreamDoor"
	door.position = ASCENT_SUMMIT
	add_child(door)


func _build_geysers() -> void:
	var geyser_y: float = _sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, GEYSER_ANCHOR_X, GEYSER_ANCHOR_Z)
	_geyser_a = _add_geyser(Vector3(GEYSER_ANCHOR_X, geyser_y, GEYSER_ANCHOR_Z), 1.0)
	_add_geyser(Vector3(GEYSER_ANCHOR_X, geyser_y, -GEYSER_ANCHOR_Z), 3.5)


func _add_geyser(base_position: Vector3, phase_offset: float) -> SnoreGeyser:
	var geyser := SnoreGeyser.new()
	geyser.name = "SnoreGeyser"
	geyser.radius = GEYSER_RADIUS
	geyser.height = GEYSER_HEIGHT
	geyser.active_duration = GEYSER_ACTIVE_DURATION
	geyser.cycle_period = GEYSER_CYCLE_PERIOD
	geyser.phase_offset = phase_offset
	geyser.position = base_position
	add_child(geyser)
	return geyser


func _build_paw_ramps() -> void:
	_add_paw_ramp(PAW_Z_OFFSET)
	_add_paw_ramp(-PAW_Z_OFFSET)


func _add_paw_ramp(z_offset: float) -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(PAW_RUN, PAW_RISE, PAW_WIDTH)
	mesh.left_to_right = 1.0 # ridge at +X: surface rises as local X increases
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_FUR_DARK
	mesh.material = mat

	var ramp_position: Vector3 = Vector3(PAW_START_X + PAW_RUN * 0.5, PAW_RISE * 0.5, z_offset)

	var visual := MeshInstance3D.new()
	visual.name = "PawRamp"
	visual.mesh = mesh
	visual.position = ramp_position
	add_child(visual)

	var body := StaticBody3D.new()
	body.name = "PawRampBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	shape.position = ramp_position
	body.add_child(shape)
	add_child(body)


func _build_fur_patches() -> void:
	var haunch_y: float = _sphere_surface_y(HAUNCH_CENTER, HAUNCH_RADIUS, FUR_PATCH_HAUNCH_X, FUR_PATCH_HAUNCH_Z)
	_add_fur_patch(Vector3(FUR_PATCH_HAUNCH_X, haunch_y, FUR_PATCH_HAUNCH_Z))
	var back_y: float = _sphere_surface_y(HAUNCH_CENTER, HAUNCH_RADIUS, FUR_PATCH_BACK_X, FUR_PATCH_BACK_Z)
	_add_fur_patch(Vector3(FUR_PATCH_BACK_X, back_y, FUR_PATCH_BACK_Z))


func _add_fur_patch(center: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_FUR_DARK
	for i: int in range(FUR_BLADE_COUNT):
		var offset: Vector2 = Vector2(randf_range(-FUR_PATCH_SPREAD, FUR_PATCH_SPREAD), randf_range(-FUR_PATCH_SPREAD, FUR_PATCH_SPREAD))
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, FUR_BLADE_HEIGHT, 0.12)
		mesh.material = mat

		var blade := MeshInstance3D.new()
		blade.name = "FurBlade"
		blade.mesh = mesh
		blade.position = center + Vector3(offset.x, FUR_BLADE_HEIGHT * 0.5 - 0.1, offset.y)
		blade.rotation.y = randf_range(0.0, TAU)
		add_child(blade)


## D25: d04/d06/d10 relocated onto the new ascent path (see ASCENT_* in
## _build_ascent() above) — d04 off the retired -Z paw ramp, d06 off the
## chest (the chest itself stays put as a foothill trampoline; see
## _build_chest()'s own comment), d10 off the old ear bump to the new
## summit, "near the door" exactly as before (same offset-from-door
## convention, new coordinates). d01/d02/d03/d05/d07/d08/d09 are BYTE-FOR-
## BYTE unchanged from pre-D25 — existing harness scripts (finale_home.json,
## mission_*.json) pin to these exact coordinates.
func _build_dreamlings() -> void:
	var positions: Dictionary = {
		"d01": Vector3(-48.0, 0.55, 3.0), # meadow approach, near spawn
		# Clear of the haunch mound's footprint (r16 from x-30,z0): the
		# original (-40, -6) sat INSIDE the hill — buried and unreachable.
		"d02": Vector3(-42.0, 0.55, -14.0), # meadow approach, south side
		"d03": Vector3(3.0, 2.7, PAW_Z_OFFSET), # on the +Z paw ramp
		"d05": Vector3(HAUNCH_CENTER.x, HAUNCH_CENTER.y + HAUNCH_RADIUS + 0.3, 0.0), # haunch peak, first plateau
		"d08": Vector3(SHELF_ANCHOR_X, 0.0, SHELF_ANCHOR_Z), # y filled in below, on the shoulder shelf
		"d09": Vector3(FUR_PATCH_HAUNCH_X, 0.0, FUR_PATCH_HAUNCH_Z), # y filled in below, hidden in fur
	}
	positions["d08"].y = _sphere_surface_y(SHOULDER_CENTER, SHOULDER_RADIUS, SHELF_ANCHOR_X, SHELF_ANCHOR_Z) + SHELF_HEIGHT_ABOVE_ANCHOR + 0.6
	positions["d09"].y = _sphere_surface_y(HAUNCH_CENTER, HAUNCH_RADIUS, FUR_PATCH_HAUNCH_X, FUR_PATCH_HAUNCH_Z) + 0.35

	for id: String in positions.keys():
		_add_dreamling(id, positions[id], self)

	# d07 rides the +Z snore geyser: parented to the column (the marmalade
	# thermal exemption pattern) so the placement property understands it —
	# a dreamling atop an updraft has no ground beneath by design.
	_add_dreamling("d07", Vector3(0.0, GEYSER_HEIGHT - 0.3, 0.0), _geyser_a)

	# --- D25 ascent relocations (on the path, per the brief) -----------------
	# Ledge2, off-center from the AscentLedge2 slab's middle so it doesn't sit
	# exactly on a player's natural walk-through line.
	_add_dreamling("d04", ASCENT_L2 + Vector3(0.0, 0.55, -1.5), self)
	# Ledge4, near the top of the climb.
	_add_dreamling("d06", ASCENT_L4 + Vector3(0.0, 0.55, 1.5), self)
	# Beside the summit door — same "offset from the door" convention the old
	# ear placement used (2.3 m clears the door's own trigger radius).
	_add_dreamling("d10", ASCENT_SUMMIT + Vector3(2.3, 0.55, 0.0), self)


func _add_dreamling(id: String, local_position: Vector3, parent: Node3D) -> void:
	var dreamling: Dreamling = DREAMLING_SCENE.instantiate() as Dreamling
	dreamling.name = "Dreamling_" + id
	dreamling.id = id
	dreamling.position = local_position
	parent.add_child(dreamling)


func _build_camera_hints() -> void:
	# Yaw convention: 0 deg = default -Z forward (Godot's identity facing);
	# -90 deg = +X; +90 deg = -X (see integration notes in worlds-VERIFY.md).
	_add_camera_hint("MeadowApproachHint", Vector3(-35.0, 7.5, 0.0), Vector3(70.0, 15.0, 80.0), -90.0, 0, 1.0)
	_add_camera_hint("ClimbHint", Vector3(10.0, 12.5, 0.0), Vector3(50.0, 25.0, 40.0), -90.0, 1, 0.8)
	_add_camera_hint("HeadEarHint", Vector3(52.5, 15.0, 0.0), Vector3(35.0, 30.0, 40.0), 90.0, 2, 0.8)


func _add_camera_hint(hint_name: String, center: Vector3, size: Vector3, yaw_degrees: float, priority: int, blend_time: float) -> void:
	var hint := CameraHint.new()
	hint.name = hint_name
	hint.priority = priority
	hint.yaw_degrees = yaw_degrees
	hint.blend_time = blend_time

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	hint.add_child(shape)
	add_child(hint)
