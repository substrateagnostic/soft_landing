class_name CameraHint
extends Area3D
## CameraHint — designer-placed yaw hint volume (D4). Data only: the camera
## rig (owned by the core-feel/camera agent) reads these on overlap and
## blends yaw by priority. Worlds place these; nothing here drives behavior.
## Forces a dedicated collision layer in _ready() so camera_rig.gd's physics
## point query reliably finds every hint volume regardless of how a world
## scene configures its own geometry/player layers.
##
## NOTE: `priority` is intentionally NOT declared here — Area3D already
## exposes a native `priority: int` property (editor-visible out of the
## box), and re-declaring it with @export throws a hard compile error in
## Godot 4.6.2 ("Member 'priority' redefined (original in native class
## 'Area3D')"). The SPEC.md contract ("priority int") is satisfied by the
## inherited property as-is — no shadow field needed.

const HINT_COLLISION_LAYER: int = 512 # layer 10 (1 << 9), dedicated to hints

@export var yaw_degrees: float = 0.0
@export var blend_time: float = 1.0


func _ready() -> void:
	collision_layer = HINT_COLLISION_LAYER
	collision_mask = 0
