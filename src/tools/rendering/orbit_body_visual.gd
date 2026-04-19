class_name OrbitBodyVisual
extends Node2D

const _SHADER_SPHERE := preload("res://src/tools/rendering/shaders/body_sphere.gdshader")
const _SHADER_STAR := preload("res://src/tools/rendering/shaders/body_star.gdshader")
const _STAR_DETAIL_TEXTURE_PATH := "res://src/tools/rendering/assets/star_detailmap.png"
const _MOON_REFERENCE_TEXTURE_PATH := "res://src/tools/rendering/assets/moon_reference.png"
const _TEMPERATE_REFERENCE_TEXTURE_PATH := "res://src/tools/rendering/assets/temperate_reference.png"
const _FROZEN_REFERENCE_TEXTURE_PATH := "res://src/tools/rendering/assets/frozen_reference.png"
const _HOT_SCORCHED_REFERENCE_TEXTURE_PATH := "res://src/tools/rendering/assets/hot_scorched_reference.png"
const PlanetVisualThemeScript := preload("res://src/tools/rendering/planet_visual_theme.gd")

# Star halo: 5 concentric discs, outermost first in draw order so inner rings
# layer on top. Outer radius stays within the previous 22 px footprint plus a
# minimal gradient margin — the halo gets softer, not bigger.
const _STAR_HALO_INNER_RINGS: Array = [
	[8.8, Color(1.0, 0.92, 0.56, 0.18)],
	[11.8, Color(1.0, 0.78, 0.30, 0.10)],
	[15.0, Color(0.98, 0.60, 0.20, 0.055)],
	[18.8, Color(0.92, 0.38, 0.14, 0.028)],
]
const _STAR_HALO_OUTER_RADIUS: float = 23.2
const _STAR_HALO_OUTER_COLOR: Color = Color(1.0, 0.42, 0.16, 0.018)
const _STAR_HALO_BREATH_FREQ_RAD_PER_S: float = 0.28
const _STAR_HALO_BREATH_AMPLITUDE: float = 0.10
static var _TEXTURE_CACHE: Dictionary = {}

var _kind: int = BodyType.Kind.PLANET
var _is_focused: bool = false
var _detail_factor: float = 1.0
var _star_closeup_phase: float = 0.0

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


func set_star_closeup_phase(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, _star_closeup_phase):
		return
	_star_closeup_phase = clamped
	if _sphere != null and _sphere.material != null and _kind == BodyType.Kind.STAR:
		(_sphere.material as ShaderMaterial).set_shader_parameter("star_closeup_phase", _star_closeup_phase)
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


func _process(_delta: float) -> void:
	# Stars drive a subtle outer-ring breath in `_draw_star_glow`; all other
	# kinds only redraw on state change, so _process is a no-op for them.
	if _kind == BodyType.Kind.STAR:
		queue_redraw()


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
	var breath: float = 1.0 - _STAR_HALO_BREATH_AMPLITUDE + _STAR_HALO_BREATH_AMPLITUDE \
		* sin(Time.get_ticks_msec() * 0.001 * _STAR_HALO_BREATH_FREQ_RAD_PER_S)
	var outer_color: Color = _STAR_HALO_OUTER_COLOR
	outer_color.a *= breath
	draw_circle(Vector2.ZERO, _STAR_HALO_OUTER_RADIUS, outer_color)
	for i in range(_STAR_HALO_INNER_RINGS.size() - 1, -1, -1):
		var ring: Array = _STAR_HALO_INNER_RINGS[i]
		draw_circle(Vector2.ZERO, ring[0], ring[1])
	if _star_closeup_phase <= 0.35:
		return

	var time_s: float = Time.get_ticks_msec() * 0.001
	var spike_phase: float = smoothstep(0.35, 1.0, _star_closeup_phase)
	var spike_base_radius: float = _STAR_HALO_OUTER_RADIUS - 0.8
	var spike_lengths: Array[float] = [1.8, 2.6, 1.4, 3.0, 2.1, 1.7, 2.8, 1.5, 2.2, 1.9, 2.7, 1.6]
	var spike_angles: Array[float] = [-2.92, -2.35, -1.82, -1.28, -0.71, -0.18, 0.42, 0.97, 1.54, 2.08, 2.63, 3.03]
	for i in range(spike_angles.size()):
		var angle: float = float(spike_angles[i]) + sin(time_s * 0.11 + float(i) * 0.73) * 0.04
		var length: float = float(spike_lengths[i]) * spike_phase
		var start: Vector2 = Vector2(cos(angle), sin(angle)) * spike_base_radius
		var finish: Vector2 = Vector2(cos(angle), sin(angle)) * (spike_base_radius + length)
		draw_line(start, finish, Color(1.0, 0.86, 0.34, 0.18 * spike_phase), 0.9, true)

	var prominence_radius: float = _STAR_HALO_OUTER_RADIUS + 0.6
	var prominence_boost: float = 0.28 * spike_phase
	draw_arc(
		Vector2.ZERO,
		prominence_radius + 1.2 * spike_phase,
		-2.74 + sin(time_s * 0.09) * 0.03,
		-2.22 + sin(time_s * 0.12) * 0.03,
		16,
		Color(1.0, 0.74, 0.28, prominence_boost),
		1.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		prominence_radius + 1.8 * spike_phase,
		-0.18 + sin(time_s * 0.08 + 0.8) * 0.02,
		0.29 + sin(time_s * 0.10 + 0.4) * 0.02,
		18,
		Color(1.0, 0.70, 0.24, prominence_boost * 0.92),
		1.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		prominence_radius + 1.4 * spike_phase,
		1.88 + sin(time_s * 0.07 + 1.3) * 0.02,
		2.27 + sin(time_s * 0.09 + 0.6) * 0.02,
		15,
		Color(1.0, 0.72, 0.26, prominence_boost * 0.84),
		0.9,
		true
	)


func _draw_planet_overlay() -> void:
	var reference_overlay_damp: float = 0.42 if _surface_reference_is_active() else 1.0
	if _detail_factor > 1.20:
		var atmo_alpha: float = (0.10 + 0.18 * maxf(_overlay_cloud_strength, 0.22)) \
			* minf(_detail_factor / 2.0, 1.0) * reference_overlay_damp
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
		var accent_alpha: float = (0.08 + 0.16 * maxf(_overlay_cloud_strength, 0.18)) \
			* minf(_detail_factor / 2.6, 1.0) * reference_overlay_damp
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
	if _moon_reference_is_active():
		return
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
	# P14.4 moves star activity into the shader and inner rim. Keep the
	# overlay clear so it does not read as a decorative UI arc.
	return


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
			mat.set_shader_parameter("surface_var_strength", 0.08 if is_moon else 0.04)
			mat.set_shader_parameter("polar_tint_strength", 0.10 if is_moon else 0.11)
			mat.set_shader_parameter("band_strength", 0.05 if is_moon else 0.05)
			mat.set_shader_parameter("patch_strength", 0.18 if is_moon else 0.02)
		PlanetVisualThemeScript.Archetype.FROZEN:
			mat.set_shader_parameter("surface_freq", 13.0 if is_moon else 8.9)
			mat.set_shader_parameter("surface_var_strength", 0.05 if is_moon else 0.04)
			mat.set_shader_parameter("polar_tint_strength", 0.14 if is_moon else 0.20)
			mat.set_shader_parameter("band_strength", 0.02 if is_moon else 0.04)
			mat.set_shader_parameter("patch_strength", 0.22 if is_moon else 0.04)
		PlanetVisualThemeScript.Archetype.HOT_SCORCHED:
			mat.set_shader_parameter("surface_freq", 12.5 if is_moon else 9.8)
			mat.set_shader_parameter("surface_var_strength", 0.07 if is_moon else 0.05)
			mat.set_shader_parameter("polar_tint_strength", 0.00)
			mat.set_shader_parameter("band_strength", 0.0 if is_moon else 0.02)
			mat.set_shader_parameter("patch_strength", 0.20 if is_moon else 0.04)
		_:
			mat.set_shader_parameter("surface_freq", 12.0 if is_moon else 9.0)
			mat.set_shader_parameter("surface_var_strength", 0.06 if is_moon else 0.07)
			mat.set_shader_parameter("polar_tint_strength", 0.02 if is_moon else 0.08)
			mat.set_shader_parameter("band_strength", 0.0 if is_moon else 0.03)
			mat.set_shader_parameter("patch_strength", 0.24 if is_moon else 0.12)

	var reference_setup: Dictionary = _surface_reference_setup_for(
		_kind,
		int(theme.archetype)
	)
	if is_moon and not reference_setup.is_empty():
		reference_setup["strength"] = 0.72 + theme.crater_strength * 0.22
		reference_setup["detail_strength"] = 0.20 + theme.crater_strength * 0.18
	_apply_surface_reference_to_material(mat, reference_setup)


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


func _surface_reference_is_active() -> bool:
	if (_kind != BodyType.Kind.PLANET and _kind != BodyType.Kind.MOON) \
			or _sphere == null or _sphere.material == null:
		return false
	var mat: ShaderMaterial = _sphere.material as ShaderMaterial
	if mat == null:
		return false
	return float(mat.get_shader_parameter("surface_reference_strength")) > 0.05


func _moon_reference_is_active() -> bool:
	return _kind == BodyType.Kind.MOON and _surface_reference_is_active()


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


static func _load_png_texture(path: String) -> Texture2D:
	var png_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if png_bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(png_bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)


static func _load_png_texture_cached(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _TEXTURE_CACHE.has(path):
		return _TEXTURE_CACHE[path]
	var texture: Texture2D = _load_png_texture(path)
	if texture != null:
		_TEXTURE_CACHE[path] = texture
	return texture


static func _surface_reference_setup_for(kind: int, archetype: int) -> Dictionary:
	if kind == BodyType.Kind.MOON:
		return {
			"path": _MOON_REFERENCE_TEXTURE_PATH,
			"strength": 0.78,
			"detail_strength": 0.26,
			"radius": 0.46,
			"center_preserve": 0.82,
			"side_shade_strength": 0.92,
			"procedural_damp": 0.84,
			"rim_boost": 0.22,
		}
	if kind != BodyType.Kind.PLANET:
		return {}

	match archetype:
		PlanetVisualThemeScript.Archetype.TEMPERATE_OCEAN:
			return {
				"path": _TEMPERATE_REFERENCE_TEXTURE_PATH,
				"strength": 0.84,
				"detail_strength": 0.24,
				"radius": 0.408,
				"center_preserve": 0.90,
				"side_shade_strength": 0.68,
				"procedural_damp": 0.74,
				"rim_boost": 0.10,
			}
		PlanetVisualThemeScript.Archetype.FROZEN:
			return {
				"path": _FROZEN_REFERENCE_TEXTURE_PATH,
				"strength": 0.82,
				"detail_strength": 0.20,
				"radius": 0.408,
				"center_preserve": 0.88,
				"side_shade_strength": 0.74,
				"procedural_damp": 0.72,
				"rim_boost": 0.16,
			}
		PlanetVisualThemeScript.Archetype.HOT_SCORCHED:
			return {
				"path": _HOT_SCORCHED_REFERENCE_TEXTURE_PATH,
				"strength": 0.86,
				"detail_strength": 0.28,
				"radius": 0.404,
				"center_preserve": 0.84,
				"side_shade_strength": 0.80,
				"procedural_damp": 0.80,
				"rim_boost": 0.24,
			}
		_:
			return {}


static func _reset_surface_reference_material(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("surface_reference_tex", _make_white_1px())
	mat.set_shader_parameter("surface_reference_strength", 0.0)
	mat.set_shader_parameter("surface_reference_detail_strength", 0.0)
	mat.set_shader_parameter("surface_reference_radius", 0.46)
	mat.set_shader_parameter("surface_reference_center_preserve", 0.0)
	mat.set_shader_parameter("surface_reference_side_shade_strength", 0.0)
	mat.set_shader_parameter("surface_reference_procedural_damp", 0.0)
	mat.set_shader_parameter("surface_reference_rim_boost", 0.0)


static func _apply_surface_reference_to_material(mat: ShaderMaterial, setup: Dictionary) -> void:
	_reset_surface_reference_material(mat)
	if setup.is_empty():
		return

	var reference_texture: Texture2D = _load_png_texture_cached(String(setup.get("path", "")))
	if reference_texture == null:
		return

	mat.set_shader_parameter("surface_reference_tex", reference_texture)
	mat.set_shader_parameter("surface_reference_strength", float(setup.get("strength", 0.0)))
	mat.set_shader_parameter("surface_reference_detail_strength", float(setup.get("detail_strength", 0.0)))
	mat.set_shader_parameter("surface_reference_radius", float(setup.get("radius", 0.46)))
	mat.set_shader_parameter("surface_reference_center_preserve", float(setup.get("center_preserve", 0.0)))
	mat.set_shader_parameter("surface_reference_side_shade_strength", float(setup.get("side_shade_strength", 0.0)))
	mat.set_shader_parameter("surface_reference_procedural_damp", float(setup.get("procedural_damp", 0.0)))
	mat.set_shader_parameter("surface_reference_rim_boost", float(setup.get("rim_boost", 0.0)))


static func _make_sphere_material(kind: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	if kind == BodyType.Kind.STAR:
		mat.shader = _SHADER_STAR
		var star_detail_texture: Texture2D = _load_png_texture_cached(_STAR_DETAIL_TEXTURE_PATH)
		if star_detail_texture != null:
			mat.set_shader_parameter("star_detail_tex", star_detail_texture)
		mat.set_shader_parameter("star_closeup_phase", 0.0)
		mat.set_shader_parameter("star_core_color", Color(1.0, 0.95, 0.80))
		mat.set_shader_parameter("star_mid_color", Color(1.0, 0.62, 0.18))
		mat.set_shader_parameter("star_channel_color", Color(0.62, 0.18, 0.08))
		mat.set_shader_parameter("activity_strength", 0.34)
		mat.set_shader_parameter("activity_scale", 4.2)
		mat.set_shader_parameter("filament_strength", 0.30)
		mat.set_shader_parameter("filament_scale", 3.1)
		mat.set_shader_parameter("rim_hotness", 0.78)
		mat.set_shader_parameter("edge_activity_strength", 0.22)
		mat.set_shader_parameter("edge_activity_scale", 5.0)
		mat.set_shader_parameter("macro_surface_strength", 0.26)
		mat.set_shader_parameter("macro_surface_scale", 1.35)
		mat.set_shader_parameter("meso_breakup_strength", 0.22)
		mat.set_shader_parameter("meso_breakup_scale", 2.40)
		mat.set_shader_parameter("granulation_contrast", 1.12)
		mat.set_shader_parameter("channel_contrast", 1.18)
		mat.set_shader_parameter("hotspot_contrast", 1.16)
		mat.set_shader_parameter("detailmap_strength", 0.62)
		mat.set_shader_parameter("detailmap_scale", 1.10)
		mat.set_shader_parameter("prominence_strength", 0.32)
		mat.set_shader_parameter("sunspot_strength", 0.24)
	else:
		mat.shader = _SHADER_SPHERE
		var is_moon: bool = kind == BodyType.Kind.MOON
		_reset_surface_reference_material(mat)
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
		if is_moon:
			_apply_surface_reference_to_material(
				mat,
				_surface_reference_setup_for(kind, PlanetVisualThemeScript.Archetype.BARREN)
			)
	return mat
