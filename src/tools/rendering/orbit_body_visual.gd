class_name OrbitBodyVisual
extends Node2D

const _SHADER_SPHERE := preload("res://src/tools/rendering/shaders/body_sphere.gdshader")
const _SHADER_STAR := preload("res://src/tools/rendering/shaders/body_star.gdshader")
const PlanetVisualThemeScript := preload("res://src/tools/rendering/planet_visual_theme.gd")

var _kind: int = BodyType.Kind.PLANET
var _is_focused: bool = false
var _detail_factor: float = 1.0

var _sphere: Sprite2D = null
var _overlay: Node2D = null
var _theme = null
var _glow_color: Color = Color(0.30, 0.56, 0.96, 0.15)
var _overlay_primary_color: Color = Color(0.78, 0.89, 1.0)
var _overlay_accent_color: Color = Color(0.18, 0.36, 0.72)
var _overlay_cloud_strength: float = 0.0
var _overlay_crater_strength: float = 0.0


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

	if _theme != null:
		_apply_theme_to_material(_theme)


func apply_planet_theme(theme) -> void:
	if _kind != BodyType.Kind.PLANET and _kind != BodyType.Kind.MOON:
		return
	_theme = theme
	_apply_theme_to_material(theme)
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()


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
	# BLACK_HOLE has no _overlay - draw focus rings in parent
	if _is_focused and _overlay == null:
		var fr: float = _focus_ring_radius()
		var ring_fade: float = clampf(1.0 - (_detail_factor - 2.0) / 5.0, 0.0, 1.0)
		draw_arc(Vector2.ZERO, fr, 0.0, TAU, 72,
			Color(0.95, 0.98, 1.0, 0.55 * ring_fade), 1.2, true)
		draw_arc(Vector2.ZERO, fr + 3.5, 0.0, TAU, 72,
			Color(0.80, 0.90, 1.0, 0.16 * ring_fade), 1.0, true)


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
		var ring_fade: float = clampf(1.0 - (_detail_factor - 2.0) / 5.0, 0.0, 1.0)
		_overlay.draw_arc(Vector2.ZERO, fr, 0.0, TAU, 72,
			Color(0.95, 0.98, 1.0, 0.55 * ring_fade), 1.2, true)
		_overlay.draw_arc(Vector2.ZERO, fr + 3.5, 0.0, TAU, 72,
			Color(0.80, 0.90, 1.0, 0.16 * ring_fade), 1.0, true)


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
	draw_circle(Vector2.ZERO, 10.5, _glow_color)


func _draw_moon_glow() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(_glow_color.r, _glow_color.g, _glow_color.b, _glow_color.a * 0.62))


func _draw_star_glow() -> void:
	draw_circle(Vector2.ZERO, 22.0, Color(1.0, 0.84, 0.34, 0.06))
	draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.84, 0.34, 0.10))
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.90, 0.56, 0.24))


func _draw_planet_overlay() -> void:
	if _detail_factor > 1.20:
		var atmo_alpha: float = (0.10 + 0.18 * maxf(_overlay_cloud_strength, 0.22)) * minf(_detail_factor / 2.0, 1.0)
		_overlay.draw_arc(
			Vector2.ZERO,
			6.5,
			-1.55,
			1.25,
			36,
			Color(_overlay_primary_color.r, _overlay_primary_color.g, _overlay_primary_color.b, atmo_alpha),
			1.0,
			true
		)
	if _detail_factor > 1.60:
		var accent_alpha: float = (0.08 + 0.16 * maxf(_overlay_cloud_strength, 0.18)) * minf(_detail_factor / 2.6, 1.0)
		_overlay.draw_arc(
			Vector2.ZERO,
			4.3,
			0.65,
			2.45,
			28,
			Color(_overlay_accent_color.r, _overlay_accent_color.g, _overlay_accent_color.b, accent_alpha),
			0.9,
			true
		)


func _draw_moon_overlay() -> void:
	var crater_alpha_scale: float = clampf(_overlay_crater_strength, 0.18, 1.0)
	if _detail_factor > 1.25:
		_overlay.draw_circle(
			Vector2(-1.4, -0.5),
			0.70,
			Color(_overlay_primary_color.r, _overlay_primary_color.g, _overlay_primary_color.b, 0.18 * crater_alpha_scale)
		)
		_overlay.draw_circle(
			Vector2(0.9, 1.2),
			0.55,
			Color(_overlay_primary_color.r, _overlay_primary_color.g, _overlay_primary_color.b, 0.14 * crater_alpha_scale)
		)
	if _detail_factor > 1.80:
		_overlay.draw_circle(
			Vector2(1.6, -0.9),
			0.45,
			Color(_overlay_accent_color.r, _overlay_accent_color.g, _overlay_accent_color.b, 0.14 * crater_alpha_scale)
		)
		_overlay.draw_circle(
			Vector2(-0.5, 1.6),
			0.35,
			Color(_overlay_primary_color.r, _overlay_primary_color.g, _overlay_primary_color.b, 0.12 * crater_alpha_scale)
		)
	if _detail_factor > 2.80:
		_overlay.draw_circle(
			Vector2(-1.8, 1.1),
			0.28,
			Color(_overlay_accent_color.r, _overlay_accent_color.g, _overlay_accent_color.b, 0.11 * crater_alpha_scale)
		)
		_overlay.draw_circle(
			Vector2(0.3, -1.5),
			0.22,
			Color(_overlay_primary_color.r, _overlay_primary_color.g, _overlay_primary_color.b, 0.10 * crater_alpha_scale)
		)


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


func _apply_theme_to_material(theme) -> void:
	if theme == null:
		return

	_glow_color = _glow_color_for_theme(theme)
	_overlay_primary_color = theme.atmo_color
	_overlay_accent_color = theme.accent_color
	_overlay_cloud_strength = theme.cloud_strength
	_overlay_crater_strength = theme.crater_strength

	if _sphere == null or _sphere.material == null:
		return

	var mat: ShaderMaterial = _sphere.material as ShaderMaterial
	mat.set_shader_parameter("base_color", theme.base_color)
	mat.set_shader_parameter("secondary_color", theme.secondary_color)
	mat.set_shader_parameter("accent_color", theme.accent_color)
	mat.set_shader_parameter("atmo_color", theme.atmo_color)
	mat.set_shader_parameter("land_ocean_strength", theme.land_ocean_strength)
	mat.set_shader_parameter("cloud_strength", theme.cloud_strength)
	mat.set_shader_parameter("ice_strength", theme.ice_strength)
	mat.set_shader_parameter("lava_strength", theme.lava_strength)
	mat.set_shader_parameter("dryness_strength", theme.dryness_strength)
	mat.set_shader_parameter("crater_strength", theme.crater_strength)

	var is_moon: bool = _kind == BodyType.Kind.MOON
	match theme.archetype:
		PlanetVisualThemeScript.Archetype.TEMPERATE_OCEAN:
			mat.set_shader_parameter("surface_freq", 11.0 if is_moon else 8.2)
			mat.set_shader_parameter("surface_var_strength", 0.08 if is_moon else 0.07)
			mat.set_shader_parameter("polar_tint_strength", 0.10 if is_moon else 0.24)
			mat.set_shader_parameter("band_strength", 0.05 if is_moon else 0.14)
			mat.set_shader_parameter("patch_strength", 0.18 if is_moon else 0.06)
		PlanetVisualThemeScript.Archetype.FROZEN:
			mat.set_shader_parameter("surface_freq", 13.0 if is_moon else 9.5)
			mat.set_shader_parameter("surface_var_strength", 0.05 if is_moon else 0.06)
			mat.set_shader_parameter("polar_tint_strength", 0.14 if is_moon else 0.34)
			mat.set_shader_parameter("band_strength", 0.02 if is_moon else 0.08)
			mat.set_shader_parameter("patch_strength", 0.22 if is_moon else 0.10)
		PlanetVisualThemeScript.Archetype.HOT_SCORCHED:
			mat.set_shader_parameter("surface_freq", 12.5 if is_moon else 10.5)
			mat.set_shader_parameter("surface_var_strength", 0.07 if is_moon else 0.08)
			mat.set_shader_parameter("polar_tint_strength", 0.00)
			mat.set_shader_parameter("band_strength", 0.0 if is_moon else 0.04)
			mat.set_shader_parameter("patch_strength", 0.20 if is_moon else 0.08)
		_:
			mat.set_shader_parameter("surface_freq", 12.0 if is_moon else 9.0)
			mat.set_shader_parameter("surface_var_strength", 0.06 if is_moon else 0.07)
			mat.set_shader_parameter("polar_tint_strength", 0.02 if is_moon else 0.08)
			mat.set_shader_parameter("band_strength", 0.0 if is_moon else 0.03)
			mat.set_shader_parameter("patch_strength", 0.24 if is_moon else 0.12)


func _glow_color_for_theme(theme) -> Color:
	if theme == null:
		return Color(0.30, 0.56, 0.96, 0.15)

	var alpha: float = 0.11 if _kind == BodyType.Kind.MOON else 0.15
	match theme.archetype:
		PlanetVisualThemeScript.Archetype.TEMPERATE_OCEAN:
			return Color(theme.atmo_color.r * 0.90, theme.atmo_color.g * 0.94, theme.atmo_color.b, alpha)
		PlanetVisualThemeScript.Archetype.FROZEN:
			return Color(theme.atmo_color.r * 0.92, theme.atmo_color.g * 0.97, theme.atmo_color.b, alpha * 0.92)
		PlanetVisualThemeScript.Archetype.HOT_SCORCHED:
			return Color(theme.accent_color.r, theme.accent_color.g * 0.82, theme.accent_color.b * 0.72, alpha * 0.92)
		_:
			return Color(theme.atmo_color.r * 0.78, theme.atmo_color.g * 0.80, theme.atmo_color.b * 0.86, alpha * 0.72)


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
		mat.set_shader_parameter("secondary_color",
			Color(0.72, 0.76, 0.82) if is_moon else Color(0.32, 0.55, 0.82))
		mat.set_shader_parameter("accent_color",
			Color(0.85, 0.88, 0.94) if is_moon else Color(0.78, 0.88, 0.98))
		mat.set_shader_parameter("atmo_color",
			Color(0.85, 0.90, 1.0) if is_moon else Color(0.54, 0.78, 1.0))
		mat.set_shader_parameter("rotation_speed", 0.14 if is_moon else 0.22)
		mat.set_shader_parameter("surface_freq", 13.0 if is_moon else 8.0)
		mat.set_shader_parameter("surface_var_strength", 0.05 if is_moon else 0.06)
		mat.set_shader_parameter("polar_tint_strength", 0.0 if is_moon else 0.18)
		mat.set_shader_parameter("band_strength", 0.0 if is_moon else 0.42)
		mat.set_shader_parameter("patch_strength", 0.28 if is_moon else 0.0)
		mat.set_shader_parameter("land_ocean_strength", 0.0)
		mat.set_shader_parameter("cloud_strength", 0.0)
		mat.set_shader_parameter("ice_strength", 0.0)
		mat.set_shader_parameter("lava_strength", 0.0)
		mat.set_shader_parameter("dryness_strength", 0.0)
		mat.set_shader_parameter("crater_strength", 0.30 if is_moon else 0.0)
		mat.set_shader_parameter("spherical_mix", 0.0 if is_moon else 1.0)
	return mat
