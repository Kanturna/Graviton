class_name OrbitBodyVisual
extends Node2D

const _SHADER_SPHERE := preload("res://src/tools/rendering/shaders/body_sphere.gdshader")
const _SHADER_STAR := preload("res://src/tools/rendering/shaders/body_star.gdshader")

var _kind: int = BodyType.Kind.PLANET
var _is_focused: bool = false
var _detail_factor: float = 1.0

var _sphere: Sprite2D = null
var _overlay: Node2D = null


func configure(kind: int) -> void:
	_kind = kind
	queue_redraw()


func set_focused(value: bool) -> void:
	if value == _is_focused:
		return
	_is_focused = value
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()


func set_detail_factor(value: float) -> void:
	var clamped: float = maxf(value, 1.0)
	if is_equal_approx(clamped, _detail_factor):
		return
	_detail_factor = clamped
	var df_t: float = clampf((_detail_factor - 1.0) / 2.5, 0.0, 1.0)
	if _sphere != null and _sphere.material != null:
		(_sphere.material as ShaderMaterial).set_shader_parameter("df_t", df_t)
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()


func _ready() -> void:
	if _kind == BodyType.Kind.BLACK_HOLE:
		return

	_sphere = Sprite2D.new()
	_sphere.centered = true
	_sphere.z_index = 0
	_sphere.texture = _make_white_1px()
	_sphere.scale = _sphere_local_scale(_kind)
	_sphere.material = _make_sphere_material(_kind)
	add_child(_sphere)

	_overlay = Node2D.new()
	_overlay.z_index = 1
	_overlay.draw.connect(_on_overlay_draw)
	add_child(_overlay)


func _draw() -> void:
	match _kind:
		BodyType.Kind.BLACK_HOLE:
			_draw_black_hole()
		BodyType.Kind.STAR:
			_draw_star_glow()
		BodyType.Kind.MOON:
			_draw_moon_glow()
		_:
			_draw_planet_glow()
	# BLACK_HOLE has no _overlay — draw focus rings in parent
	if _is_focused and _overlay == null:
		var fr: float = _focus_ring_radius()
		draw_arc(Vector2.ZERO, fr, 0.0, TAU, 72, Color(0.95, 0.98, 1.0, 0.55), 1.2, true)
		draw_arc(Vector2.ZERO, fr + 3.5, 0.0, TAU, 72, Color(0.80, 0.90, 1.0, 0.16), 1.0, true)


func _on_overlay_draw() -> void:
	match _kind:
		BodyType.Kind.PLANET:
			_draw_planet_overlay()
		BodyType.Kind.MOON:
			_draw_moon_overlay()
		BodyType.Kind.STAR:
			_draw_star_overlay()
	if _is_focused:
		var fr: float = _focus_ring_radius()
		_overlay.draw_arc(Vector2.ZERO, fr, 0.0, TAU, 72, Color(0.95, 0.98, 1.0, 0.55), 1.2, true)
		_overlay.draw_arc(Vector2.ZERO, fr + 3.5, 0.0, TAU, 72, Color(0.80, 0.90, 1.0, 0.16), 1.0, true)


func _draw_black_hole() -> void:
	draw_circle(Vector2.ZERO, 32.0, Color(0.40, 0.12, 0.56, 0.04))
	draw_circle(Vector2.ZERO, 26.0, Color(0.45, 0.18, 0.62, 0.08))
	draw_circle(Vector2.ZERO, 18.0, Color(0.28, 0.10, 0.42, 0.12))
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 72, Color(0.84, 0.48, 1.0, 0.58), 2.4, true)
	if _detail_factor > 1.25:
		draw_arc(Vector2.ZERO, 15.5, -0.55, 1.15, 28, Color(0.98, 0.78, 0.52, 0.20), 1.4, true)
	draw_circle(Vector2.ZERO, 8.2, Color(0.05, 0.04, 0.09, 1.0))
	draw_circle(Vector2.ZERO, 3.0, Color(0.72, 0.34, 0.88, 0.18))


func _draw_planet_glow() -> void:
	draw_circle(Vector2.ZERO, 10.5, Color(0.30, 0.56, 0.96, 0.15))


func _draw_moon_glow() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(0.83, 0.88, 0.96, 0.07))


func _draw_star_glow() -> void:
	draw_circle(Vector2.ZERO, 22.0, Color(1.0, 0.84, 0.34, 0.06))
	draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.84, 0.34, 0.10))
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.90, 0.56, 0.24))


func _draw_planet_overlay() -> void:
	if _detail_factor > 1.20:
		_overlay.draw_arc(Vector2.ZERO, 6.5, -1.55, 1.25, 36, Color(0.78, 0.89, 1.0, 0.28), 1.0, true)
	if _detail_factor > 1.60:
		_overlay.draw_arc(Vector2.ZERO, 4.3, 0.65, 2.45, 28, Color(0.18, 0.36, 0.72, 0.26), 0.9, true)


func _draw_moon_overlay() -> void:
	if _detail_factor > 1.25:
		_overlay.draw_circle(Vector2(-1.4, -0.5), 0.7, Color(0.70, 0.75, 0.84, 0.42))
		_overlay.draw_circle(Vector2(0.9, 1.2), 0.55, Color(0.72, 0.77, 0.86, 0.34))


func _draw_star_overlay() -> void:
	if _detail_factor > 1.35:
		_overlay.draw_arc(Vector2.ZERO, 6.8, -0.9, 2.2, 32, Color(1.0, 0.97, 0.82, 0.20), 1.1, true)


func _focus_ring_radius() -> float:
	match _kind:
		BodyType.Kind.BLACK_HOLE:
			return 20.0
		BodyType.Kind.STAR:
			return 13.0
		BodyType.Kind.MOON:
			return 8.0
		_:
			return 10.0


static func _make_white_1px() -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _sphere_local_scale(kind: int) -> Vector2:
	match kind:
		BodyType.Kind.MOON:
			return Vector2(10.0, 10.0)
		_:
			return Vector2(14.0, 14.0)


static func _make_sphere_material(kind: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	if kind == BodyType.Kind.STAR:
		mat.shader = _SHADER_STAR
	else:
		mat.shader = _SHADER_SPHERE
		var is_moon: bool = kind == BodyType.Kind.MOON
		mat.set_shader_parameter("terminator_softness", 0.12 if is_moon else 0.28)
		mat.set_shader_parameter("rim_strength", 0.06 if is_moon else 0.32)
		mat.set_shader_parameter("base_color",
			Color(0.82, 0.86, 0.93) if is_moon else Color(0.42, 0.69, 1.0))
		mat.set_shader_parameter("atmo_color",
			Color(0.85, 0.90, 1.0) if is_moon else Color(0.54, 0.78, 1.0))
	return mat
