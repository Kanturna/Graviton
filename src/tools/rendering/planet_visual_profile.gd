class_name PlanetVisualProfile
extends RefCounted

const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const PlanetVisualThemeScript = preload("res://src/tools/rendering/planet_visual_theme.gd")


static func resolve(def: BodyDef, environment_desc: Dictionary):
	if def == null:
		return _make_barren_theme(false)

	if not _is_supported_visual_kind(def.kind):
		return _make_barren_theme(false)

	var has_valid_environment_basis: bool = bool(environment_desc.get("is_supported_body_kind", false)) \
		and bool(environment_desc.get("has_luminous_ancestor", false)) \
		and bool(environment_desc.get("has_latitudinal_surface_basis", false))
	if not has_valid_environment_basis:
		return _finalize_for_body_kind(_make_barren_theme(false), def.kind)

	var ecosystem_type: int = int(
		environment_desc.get(
			"ecosystem_type",
			EnvironmentServiceScript.EcosystemType.FROZEN_WORLD
		)
	)
	var has_habitable_band: bool = bool(environment_desc.get("has_habitable_band", false))

	match ecosystem_type:
		EnvironmentServiceScript.EcosystemType.HOT_WORLD:
			return _finalize_for_body_kind(_make_hot_scorched_theme(), def.kind)
		EnvironmentServiceScript.EcosystemType.FROZEN_WORLD:
			return _finalize_for_body_kind(_make_frozen_theme(), def.kind)
		EnvironmentServiceScript.EcosystemType.TEMPERATE_WORLD:
			return _finalize_for_body_kind(_make_temperate_ocean_theme(), def.kind)
		EnvironmentServiceScript.EcosystemType.SEASONAL_WORLD:
			if has_habitable_band:
				return _finalize_for_body_kind(_make_temperate_ocean_theme(), def.kind)
	return _finalize_for_body_kind(_make_barren_theme(false), def.kind)


static func _is_supported_visual_kind(kind: int) -> bool:
	return kind == BodyType.Kind.PLANET or kind == BodyType.Kind.MOON


static func _make_temperate_ocean_theme():
	var theme := PlanetVisualThemeScript.new()
	theme.archetype = PlanetVisualThemeScript.Archetype.TEMPERATE_OCEAN
	# Stilistische Interpretation: Die Sim liefert Habitability-/Climate-Zustaende,
	# aber weder Wasserinventar noch Land/Ozean-Verhaeltnis oder Wolkenphysik.
	# Der earth-like Look projiziert diese Daten bewusst als lesbaren Archetyp.
	theme.is_stylized_interpretation = true
	theme.base_color = Color(0.16, 0.37, 0.74)
	theme.secondary_color = Color(0.34, 0.54, 0.24)
	theme.accent_color = Color(0.78, 0.66, 0.46)
	theme.atmo_color = Color(0.60, 0.80, 1.0)
	theme.land_ocean_strength = 0.84
	theme.cloud_strength = 0.88
	theme.ice_strength = 0.32
	theme.lava_strength = 0.0
	theme.dryness_strength = 0.08
	theme.crater_strength = 0.06
	return theme


static func _make_frozen_theme():
	var theme := PlanetVisualThemeScript.new()
	theme.archetype = PlanetVisualThemeScript.Archetype.FROZEN
	theme.is_stylized_interpretation = false
	theme.base_color = Color(0.77, 0.87, 0.96)
	theme.secondary_color = Color(0.92, 0.96, 1.0)
	theme.accent_color = Color(0.60, 0.72, 0.86)
	theme.atmo_color = Color(0.70, 0.86, 1.0)
	theme.land_ocean_strength = 0.14
	theme.cloud_strength = 0.10
	theme.ice_strength = 0.96
	theme.lava_strength = 0.0
	theme.dryness_strength = 0.0
	theme.crater_strength = 0.18
	return theme


static func _make_hot_scorched_theme():
	var theme := PlanetVisualThemeScript.new()
	theme.archetype = PlanetVisualThemeScript.Archetype.HOT_SCORCHED
	theme.is_stylized_interpretation = false
	theme.base_color = Color(0.18, 0.16, 0.16)
	theme.secondary_color = Color(0.42, 0.24, 0.14)
	theme.accent_color = Color(0.94, 0.42, 0.16)
	theme.atmo_color = Color(0.96, 0.54, 0.24)
	theme.land_ocean_strength = 0.08
	theme.cloud_strength = 0.0
	theme.ice_strength = 0.0
	theme.lava_strength = 0.54
	theme.dryness_strength = 0.82
	theme.crater_strength = 0.22
	return theme


static func _make_barren_theme(is_stylized_interpretation: bool):
	var theme := PlanetVisualThemeScript.new()
	theme.archetype = PlanetVisualThemeScript.Archetype.BARREN
	theme.is_stylized_interpretation = is_stylized_interpretation
	theme.base_color = Color(0.46, 0.44, 0.46)
	theme.secondary_color = Color(0.62, 0.58, 0.55)
	theme.accent_color = Color(0.76, 0.72, 0.68)
	theme.atmo_color = Color(0.54, 0.60, 0.68)
	theme.land_ocean_strength = 0.0
	theme.cloud_strength = 0.0
	theme.ice_strength = 0.0
	theme.lava_strength = 0.0
	theme.dryness_strength = 0.18
	theme.crater_strength = 0.72
	return theme


static func _finalize_for_body_kind(theme, kind: int):
	if kind != BodyType.Kind.MOON:
		return theme

	var moon_theme := PlanetVisualThemeScript.new()
	moon_theme.archetype = theme.archetype
	moon_theme.is_stylized_interpretation = theme.is_stylized_interpretation
	moon_theme.base_color = theme.base_color.lerp(Color(0.72, 0.74, 0.78), 0.30)
	moon_theme.secondary_color = theme.secondary_color.lerp(Color(0.76, 0.77, 0.80), 0.34)
	moon_theme.accent_color = theme.accent_color.lerp(Color(0.86, 0.86, 0.88), 0.22)
	moon_theme.atmo_color = theme.atmo_color.lerp(Color(0.82, 0.86, 0.92), 0.38)
	moon_theme.land_ocean_strength = theme.land_ocean_strength * 0.58
	moon_theme.cloud_strength = theme.cloud_strength * 0.22
	moon_theme.ice_strength = theme.ice_strength * 0.74
	moon_theme.lava_strength = theme.lava_strength * 0.52
	moon_theme.dryness_strength = theme.dryness_strength * 0.76
	moon_theme.crater_strength = maxf(theme.crater_strength, 0.34)
	return moon_theme
