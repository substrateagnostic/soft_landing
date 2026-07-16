class_name CameraHint
extends Area3D
## CameraHint — designer-placed yaw hint volume (D4). Data only: the camera
## rig (owned by the core-feel/camera agent) reads these on overlap and
## blends yaw by priority. Worlds place these; nothing here drives behavior.

@export var priority: int = 0
@export var yaw_degrees: float = 0.0
@export var blend_time: float = 1.0
