extends RefCounted

const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const PlanetVisualProfileScript = preload("res://src/tools/rendering/planet_visual_profile.gd")
const PlanetVisualThemeScript = preload("res://src/tools/rendering/planet_visual_theme.gd")
const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")
const HK_REGISTRY: StringName = SimTestHarnessScript.HARNESS_KEY_REGISTRY
const HK_ENVIRONMENT_SERVICE: StringName = SimTestHarnessScript.HARNESS_KEY_ENVIRONMENT_SERVICE


static func run(ctx) -> void:
	ctx.current_suite = "test_planet_visual_profile"
	_test_synthetic_resolver_rules_for_planets_and_moons(ctx)
	_test_invalid_or_missing_environment_basis_falls_back_to_barren(ctx)
	_test_sample_system_planet_a_maps_to_temperate_ocean(ctx)
	_test_starter_world_gamma_iv_maps_to_temperate_ocean_at_t0(ctx)


static func _body_def_for_visual_kind(kind: int) -> BodyDef:
	var def := BodyDef.new()
	def.id = &"visual_body"
	def.display_name = "visual_body"
	def.kind = kind
	def.mass_kg = UnitSystem.EARTH_MASS_KG
	def.radius_m = 6.371e6
	def.parent_id = &"sol"
	return def


static func _environment_desc(
	ecosystem_type: int,
	has_habitable_band: bool,
	is_supported_body_kind: bool = true,
	has_luminous_ancestor: bool = true,
	has_latitudinal_surface_basis: bool = true
) -> Dictionary:
	return {
		"is_supported_body_kind": is_supported_body_kind,
		"has_luminous_ancestor": has_luminous_ancestor,
		"has_latitudinal_surface_basis": has_latitudinal_surface_basis,
		"ecosystem_type": ecosystem_type,
		"has_habitable_band": has_habitable_band,
	}


static func _setup_named_world(world_id: StringName) -> Dictionary:
	return SimTestHarnessScript.build_named_world_context(world_id)


static func _cleanup_setup(setup: Dictionary) -> void:
	SimTestHarnessScript.teardown_context(setup)


static func _test_synthetic_resolver_rules_for_planets_and_moons(ctx) -> void:
	var visual_kinds: Array[int] = [BodyType.Kind.PLANET, BodyType.Kind.MOON]
	for kind in visual_kinds:
		var def: BodyDef = _body_def_for_visual_kind(kind)
		var label_prefix: String = "planet" if kind == BodyType.Kind.PLANET else "moon"

		var hot_theme = PlanetVisualProfileScript.resolve(
			def,
			_environment_desc(EnvironmentServiceScript.EcosystemType.HOT_WORLD, false)
		)
		_assert_archetype_eq(
			ctx,
			hot_theme.archetype,
			PlanetVisualThemeScript.Archetype.HOT_SCORCHED,
			"%s HOT_WORLD -> HOT_SCORCHED" % label_prefix
		)
		ctx.assert_true(
			not hot_theme.is_stylized_interpretation,
			"%s HOT_SCORCHED bleibt sim-gestuetzte Visualfamilie" % label_prefix
		)

		var frozen_theme = PlanetVisualProfileScript.resolve(
			def,
			_environment_desc(EnvironmentServiceScript.EcosystemType.FROZEN_WORLD, false)
		)
		_assert_archetype_eq(
			ctx,
			frozen_theme.archetype,
			PlanetVisualThemeScript.Archetype.FROZEN,
			"%s FROZEN_WORLD -> FROZEN" % label_prefix
		)
		ctx.assert_true(
			not frozen_theme.is_stylized_interpretation,
			"%s FROZEN bleibt sim-gestuetzte Visualfamilie" % label_prefix
		)

		var temperate_theme = PlanetVisualProfileScript.resolve(
			def,
			_environment_desc(EnvironmentServiceScript.EcosystemType.TEMPERATE_WORLD, true)
		)
		_assert_archetype_eq(
			ctx,
			temperate_theme.archetype,
			PlanetVisualThemeScript.Archetype.TEMPERATE_OCEAN,
			"%s TEMPERATE_WORLD -> TEMPERATE_OCEAN" % label_prefix
		)
		ctx.assert_true(
			temperate_theme.is_stylized_interpretation,
			"%s TEMPERATE_OCEAN bleibt bewusst stilistische Interpretation" % label_prefix
		)

		var seasonal_habitable_theme = PlanetVisualProfileScript.resolve(
			def,
			_environment_desc(EnvironmentServiceScript.EcosystemType.SEASONAL_WORLD, true)
		)
		_assert_archetype_eq(
			ctx,
			seasonal_habitable_theme.archetype,
			PlanetVisualThemeScript.Archetype.TEMPERATE_OCEAN,
			"%s SEASONAL_WORLD + habitable band -> TEMPERATE_OCEAN" % label_prefix
		)
		ctx.assert_true(
			seasonal_habitable_theme.is_stylized_interpretation,
			"%s SEASONAL_WORLD + habitable band bleibt stilisierte TEMPERATE_OCEAN-Lesart" % label_prefix
		)


static func _test_invalid_or_missing_environment_basis_falls_back_to_barren(ctx) -> void:
	for kind in [BodyType.Kind.PLANET, BodyType.Kind.MOON]:
		var def: BodyDef = _body_def_for_visual_kind(kind)
		var label_prefix: String = "planet" if kind == BodyType.Kind.PLANET else "moon"
		var theme = PlanetVisualProfileScript.resolve(
			def,
			_environment_desc(
				EnvironmentServiceScript.EcosystemType.SEASONAL_WORLD,
				true,
				false,
				false,
				false
			)
		)
		_assert_archetype_eq(
			ctx,
			theme.archetype,
			PlanetVisualThemeScript.Archetype.BARREN,
			"%s ohne gueltige Umweltbasis faellt auf BARREN zurueck" % label_prefix
		)
		ctx.assert_true(
			not theme.is_stylized_interpretation,
			"%s BARREN-Fallback bleibt nicht-stilisierte Sim-Familie" % label_prefix
		)


static func _test_sample_system_planet_a_maps_to_temperate_ocean(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var registry = setup[HK_REGISTRY]
	var environment_service = setup[HK_ENVIRONMENT_SERVICE]
	var def: BodyDef = registry.get_def(&"planet_a")
	var desc: Dictionary = environment_service.describe_body(&"planet_a")
	var theme = PlanetVisualProfileScript.resolve(def, desc)
	_assert_archetype_eq(
		ctx,
		theme.archetype,
		PlanetVisualThemeScript.Archetype.TEMPERATE_OCEAN,
		"sample_system.planet_a bleibt renderer-seitig TEMPERATE_OCEAN"
	)
	ctx.assert_true(
		theme.is_stylized_interpretation,
		"sample_system.planet_a bleibt als earth-like Visual bewusst stilisierte Interpretation"
	)
	_cleanup_setup(setup)


static func _test_starter_world_gamma_iv_maps_to_temperate_ocean_at_t0(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"starter_world")
	var registry = setup[HK_REGISTRY]
	var environment_service = setup[HK_ENVIRONMENT_SERVICE]
	var def: BodyDef = registry.get_def(&"gamma_iv")
	var desc: Dictionary = environment_service.describe_body(&"gamma_iv")
	var theme = PlanetVisualProfileScript.resolve(def, desc)
	_assert_archetype_eq(
		ctx,
		theme.archetype,
		PlanetVisualThemeScript.Archetype.TEMPERATE_OCEAN,
		"starter_world.gamma_iv mappt bei t = 0.0 renderer-seitig auf TEMPERATE_OCEAN"
	)
	ctx.assert_true(
		theme.is_stylized_interpretation,
		"starter_world.gamma_iv bleibt als temperate archetype bewusst stilisierte Interpretation"
	)
	_cleanup_setup(setup)


static func _assert_archetype_eq(ctx, actual: int, expected: int, label: String) -> void:
	ctx.assert_true(actual == expected, "%s (actual=%s expected=%s)" % [
		label,
		PlanetVisualThemeScript.archetype_to_string(actual),
		PlanetVisualThemeScript.archetype_to_string(expected),
	])
