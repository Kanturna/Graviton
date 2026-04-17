extends Control

const STAR_COUNT: int = 180
const DUST_COUNT: int = 5

var _stars: Array = []
var _dust_clouds: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_regenerate()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.014, 0.020, 0.055, 1.0), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.028, 0.080, 0.28), true)

	for cloud in _dust_clouds:
		draw_circle(cloud["position"], cloud["radius"], cloud["color"])

	for star in _stars:
		draw_circle(star["position"], star["radius"], star["color"])


func _on_resized() -> void:
	_regenerate()


func _regenerate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242

	_stars.clear()
	_dust_clouds.clear()

	var safe_size: Vector2 = size
	if safe_size.x <= 0.0 or safe_size.y <= 0.0:
		return

	for _i in range(DUST_COUNT):
		var radius: float = rng.randf_range(140.0, 320.0)
		var color := Color(
			rng.randf_range(0.08, 0.18),
			rng.randf_range(0.14, 0.24),
			rng.randf_range(0.28, 0.42),
			rng.randf_range(0.06, 0.12)
		)
		_dust_clouds.append({
			"position": Vector2(
				rng.randf_range(0.0, safe_size.x),
				rng.randf_range(0.0, safe_size.y)
			),
			"radius": radius,
			"color": color,
		})

	for _i in range(STAR_COUNT):
		var brightness: float = rng.randf()
		var radius: float = 0.6 if brightness < 0.72 else rng.randf_range(0.9, 1.8)
		var alpha: float = rng.randf_range(0.30, 0.90)
		_stars.append({
			"position": Vector2(
				rng.randf_range(0.0, safe_size.x),
				rng.randf_range(0.0, safe_size.y)
			),
			"radius": radius,
			"color": Color(
				rng.randf_range(0.78, 1.0),
				rng.randf_range(0.82, 1.0),
				1.0,
				alpha
			),
		})

	queue_redraw()
