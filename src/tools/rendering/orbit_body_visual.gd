class_name OrbitBodyVisual
extends Node2D

var _kind: int = BodyType.Kind.PLANET
var _is_focused: bool = false


func configure(kind: int) -> void:
	_kind = kind
	queue_redraw()


func set_focused(value: bool) -> void:
	if value == _is_focused:
		return
	_is_focused = value
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
	draw_circle(Vector2.ZERO, 8.2, Color(0.05, 0.04, 0.09, 1.0))
	draw_circle(Vector2.ZERO, 3.0, Color(0.72, 0.34, 0.88, 0.18))


func _draw_star() -> void:
	draw_circle(Vector2.ZERO, 22.0, Color(1.0, 0.84, 0.34, 0.06))
	draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.84, 0.34, 0.10))
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.90, 0.56, 0.24))
	draw_circle(Vector2.ZERO, 5.8, Color(1.0, 0.87, 0.45, 1.0))
	draw_circle(Vector2.ZERO, 2.4, Color(1.0, 0.97, 0.86, 0.94))


func _draw_planet() -> void:
	draw_circle(Vector2.ZERO, 10.5, Color(0.30, 0.56, 0.96, 0.15))
	draw_circle(Vector2.ZERO, 5.8, Color(0.42, 0.69, 1.0, 0.95))
	draw_circle(Vector2.ZERO, 2.2, Color(0.74, 0.88, 1.0, 0.42))


func _draw_moon() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(0.83, 0.88, 0.96, 0.07))
	draw_circle(Vector2.ZERO, 3.8, Color(0.82, 0.86, 0.93, 0.92))
	draw_circle(Vector2.ZERO, 1.6, Color(0.96, 0.98, 1.0, 0.35))


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
