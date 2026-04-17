class_name OrbitBodyVisual
extends Node2D

var _kind: int = BodyType.Kind.PLANET
var _is_focused: bool = false
var _detail_factor: float = 1.0


func configure(kind: int) -> void:
	_kind = kind
	queue_redraw()


func set_focused(value: bool) -> void:
	if value == _is_focused:
		return
	_is_focused = value
	queue_redraw()


func set_detail_factor(value: float) -> void:
	var clamped: float = maxf(value, 1.0)
	if is_equal_approx(clamped, _detail_factor):
		return
	_detail_factor = clamped
	queue_redraw()


func _draw() -> void:
	match _kind:
		BodyType.Kind.BLACK_HOLE:
			_draw_black_hole()
		BodyType.Kind.STAR:
			_draw_star()
		BodyType.Kind.MOON:
			_draw_moon()
		_:
			_draw_planet()

	if _is_focused:
		var _fr: float = _focus_ring_radius()
		draw_arc(Vector2.ZERO, _fr, 0.0, TAU, 72, Color(0.95, 0.98, 1.0, 0.55), 1.2, true)
		draw_arc(Vector2.ZERO, _fr + 3.5, 0.0, TAU, 72, Color(0.80, 0.90, 1.0, 0.16), 1.0, true)


func _draw_black_hole() -> void:
	draw_circle(Vector2.ZERO, 32.0, Color(0.40, 0.12, 0.56, 0.04))
	draw_circle(Vector2.ZERO, 26.0, Color(0.45, 0.18, 0.62, 0.08))
	draw_circle(Vector2.ZERO, 18.0, Color(0.28, 0.10, 0.42, 0.12))
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 72, Color(0.84, 0.48, 1.0, 0.58), 2.4, true)
	if _detail_factor > 1.25:
		draw_arc(Vector2.ZERO, 15.5, -0.55, 1.15, 28, Color(0.98, 0.78, 0.52, 0.20), 1.4, true)
	draw_circle(Vector2.ZERO, 8.2, Color(0.05, 0.04, 0.09, 1.0))
	draw_circle(Vector2.ZERO, 3.0, Color(0.72, 0.34, 0.88, 0.18))


func _draw_star() -> void:
	draw_circle(Vector2.ZERO, 22.0, Color(1.0, 0.84, 0.34, 0.06))
	draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.84, 0.34, 0.10))
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.90, 0.56, 0.24))
	if _detail_factor > 1.35:
		draw_arc(Vector2.ZERO, 6.8, -0.9, 2.2, 32, Color(1.0, 0.97, 0.82, 0.20), 1.1, true)
	draw_circle(Vector2.ZERO, 5.8, Color(1.0, 0.87, 0.45, 1.0))
	draw_circle(Vector2.ZERO, 2.4, Color(1.0, 0.97, 0.86, 0.94))


func _draw_planet() -> void:
	var df_t: float = clampf((_detail_factor - 1.0) / 2.5, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 10.5, Color(0.30, 0.56, 0.96, 0.15))
	if _detail_factor > 1.20:
		draw_arc(Vector2.ZERO, 6.5, -1.55, 1.25, 36, Color(0.78, 0.89, 1.0, 0.28), 1.0, true)
	draw_circle(Vector2.ZERO, 5.8, Color(0.42, 0.69, 1.0, 0.95))
	if _detail_factor > 1.60:
		draw_arc(Vector2.ZERO, 4.3, 0.65, 2.45, 28, Color(0.18, 0.36, 0.72, 0.26), 0.9, true)
	draw_circle(Vector2(-1.8, -1.8), 2.5, Color(0.78, 0.90, 1.0, lerpf(0.18, 0.50, df_t)))
	draw_circle(Vector2.ZERO, 2.2, Color(0.74, 0.88, 1.0, 0.42))
	draw_circle(Vector2(2.2, 2.2), 5.5, Color(0.0, 0.03, 0.10, lerpf(0.10, 0.36, df_t)))


func _draw_moon() -> void:
	var df_t: float = clampf((_detail_factor - 1.0) / 2.5, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 6.0, Color(0.83, 0.88, 0.96, 0.07))
	draw_circle(Vector2.ZERO, 3.8, Color(0.82, 0.86, 0.93, 0.92))
	if _detail_factor > 1.25:
		draw_circle(Vector2(-1.4, -0.5), 0.7, Color(0.70, 0.75, 0.84, 0.42))
		draw_circle(Vector2(0.9, 1.2), 0.55, Color(0.72, 0.77, 0.86, 0.34))
	draw_circle(Vector2(-1.1, -1.0), 1.5, Color(0.96, 0.98, 1.0, lerpf(0.14, 0.46, df_t)))
	draw_circle(Vector2.ZERO, 1.6, Color(0.96, 0.98, 1.0, 0.35))
	draw_circle(Vector2(1.8, 1.8), 3.5, Color(0.0, 0.02, 0.08, lerpf(0.08, 0.32, df_t)))


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
