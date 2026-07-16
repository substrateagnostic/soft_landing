class_name BlobShadow
extends Decal
## BlobShadow — always-on landing shadow (D9). Instanced under each
## character's ReadabilityAnchor (itself offset to foot level), so normal
## scene-tree parenting keeps it pinned to the exact ground column below
## the character with zero per-frame code. The character root never
## rotates (only its Visual mesh does — see player_body.gd), so the
## decal's local -Y projection always points straight down.
## Full strength, never fades: the "unrealistic but essential landing
## shadow" reads landing position better than a realistic shadow ever
## could (camera_readability.md C.1). Exempt from mood/lighting rules.

const TEXTURE_RESOLUTION: int = 64

@export var max_distance: float = 20.0
@export var footprint: Vector2 = Vector2(0.6, 0.6)
@export var shadow_alpha: float = 0.55


func _ready() -> void:
	size = Vector3(footprint.x, max_distance, footprint.y)
	texture_albedo = _make_circle_texture()
	modulate = Color(0.0, 0.0, 0.0, shadow_alpha)
	cull_mask = 1
	upper_fade = 0.0
	lower_fade = 0.3


func _make_circle_texture() -> ImageTexture:
	var image: Image = Image.create(TEXTURE_RESOLUTION, TEXTURE_RESOLUTION, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(TEXTURE_RESOLUTION / 2.0, TEXTURE_RESOLUTION / 2.0)
	var radius: float = TEXTURE_RESOLUTION / 2.0
	for y: int in range(TEXTURE_RESOLUTION):
		for x: int in range(TEXTURE_RESOLUTION):
			var dist: float = Vector2(x, y).distance_to(center) / radius
			var alpha: float = clampf(1.0 - dist, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha * alpha))
	return ImageTexture.create_from_image(image)
