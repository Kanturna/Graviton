extends RefCounted

const LifeDetailPanelScript = preload("res://src/tools/ui/life_detail_panel.gd")
const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const NativeSpeciesServiceScript = preload("res://src/sim/life/native_species_service.gd")


class RegistryProbe:
	extends Node

	var defs_by_id: Dictionary = {}

	func add_body(id: StringName, display_name: String, kind: int) -> void:
		var body_def := BodyDef.new()
		body_def.id = id
		body_def.display_name = display_name
		body_def.kind = kind
		body_def.mass_kg = 1.0
		body_def.radius_m = 1.0
		defs_by_id[id] = body_def

	func has_body(id: StringName) -> bool:
		return defs_by_id.has(id)

	func get_def(id: StringName) -> BodyDef:
		return defs_by_id.get(id, null)


class SnapshotCacheProbe:
	extends RefCounted

	var environment_by_id: Dictionary = {}
	var planetary_state_by_id: Dictionary = {}
	var biosphere_scale_by_id: Dictionary = {}
	var native_species_by_id: Dictionary = {}
	var life_potential_by_id: Dictionary = {}

	func get_environment_desc(id: StringName) -> Dictionary:
		return environment_by_id.get(id, {})

	func get_planetary_state_desc(id: StringName) -> Dictionary:
		return planetary_state_by_id.get(id, {})

	func get_biosphere_scale_desc(id: StringName) -> Dictionary:
		return biosphere_scale_by_id.get(id, {})

	func get_native_species_desc(id: StringName) -> Dictionary:
		return native_species_by_id.get(id, {})

	func get_life_potential_desc(id: StringName) -> Dictionary:
		return life_potential_by_id.get(id, {})


static func run(ctx) -> void:
	ctx.current_suite = "test_life_detail_panel"
	_test_panel_reuses_formatter_lines_and_placeholders(ctx)
	_test_panel_missing_basis_stays_na(ctx)
	_test_panel_open_rules_toggle_switch_close_and_escape(ctx)


static func _test_panel_reuses_formatter_lines_and_placeholders(ctx) -> void:
	var registry := RegistryProbe.new()
	registry.add_body(&"planet_a", "Planet A", BodyType.Kind.PLANET)
	var cache := SnapshotCacheProbe.new()
	_seed_full_descriptions(cache, &"planet_a")

	var panel = LifeDetailPanelScript.new()
	panel.configure(registry, cache)
	panel.open_for_body(&"planet_a")

	var snapshot: Dictionary = panel.get_debug_snapshot()
	var lines: PackedStringArray = snapshot.get("line_texts", PackedStringArray())
	ctx.assert_true(bool(snapshot.get("is_open", false)), "LifeDetailPanel oeffnet fuer einen Body")
	ctx.assert_true(snapshot.get("body_id", StringName("")) == &"planet_a", "LifeDetailPanel tracked den geoeffneten Body")
	ctx.assert_true(String(snapshot.get("title_text", "")) == "Life Details: Planet A", "LifeDetailPanel zeigt den sichtbaren Body-Namen")
	ctx.assert_true(lines.has("Environment: HABITABLE   Climate: TEMPERATE"), "Panel reusst format_environment")
	ctx.assert_true(lines.has("World: RICH / BUFFERED / LOW / STABLE / TEMPERATE"), "Panel reusst format_world")
	ctx.assert_true(lines.has("Life: COMPLEX_MULTICELLULAR / WATER_CARBON"), "Panel reusst format_life")
	ctx.assert_true(lines.has("Density: THRIVING"), "Panel reusst format_density")
	ctx.assert_true(lines.has("Species: DIVERSE_MACRO / PHOTOTROPHIC / TEMPERATE_SURFACE / MOTILE"), "Panel reusst format_species")
	ctx.assert_true(lines.has("Life Potential: WATER_CARBON / HIGH"), "Panel reusst format_life_potential")
	ctx.assert_true(lines.has("Biomass: 0.42"), "Panel reusst format_biomass")
	ctx.assert_true(
		snapshot.get("placeholder_texts", PackedStringArray()) == PackedStringArray([
			"Population: not established",
			"Native forms: pending",
			"Visual profile: pending",
		]),
		"Panel zeigt nur explizite Platzhalter fuer noch nicht etablierte Population/Visuals"
	)
	panel.free()
	registry.free()


static func _test_panel_missing_basis_stays_na(ctx) -> void:
	var registry := RegistryProbe.new()
	registry.add_body(&"moon_a", "Moon A", BodyType.Kind.MOON)
	var cache := SnapshotCacheProbe.new()
	var panel = LifeDetailPanelScript.new()
	panel.configure(registry, cache)
	panel.open_for_body(&"moon_a")

	var lines: PackedStringArray = panel.get_debug_snapshot().get("line_texts", PackedStringArray())
	ctx.assert_true(lines.has("Environment: n/a"), "Fehlende Environment-Basis bleibt n/a")
	ctx.assert_true(lines.has("World: n/a"), "Fehlende World-Basis bleibt n/a")
	ctx.assert_true(lines.has("Life: n/a"), "Fehlende Life-Basis bleibt n/a")
	ctx.assert_true(lines.has("Density: n/a"), "Fehlende Density-Basis bleibt n/a")
	ctx.assert_true(lines.has("Species: n/a"), "Fehlende Species-Basis bleibt n/a")
	ctx.assert_true(lines.has("Life Potential: n/a"), "Fehlende Life-Potential-Basis bleibt n/a")
	ctx.assert_true(lines.has("Biomass: n/a"), "Fehlende Biomass-Basis bleibt n/a")
	panel.free()
	registry.free()


static func _test_panel_open_rules_toggle_switch_close_and_escape(ctx) -> void:
	var registry := RegistryProbe.new()
	registry.add_body(&"planet_a", "Planet A", BodyType.Kind.PLANET)
	registry.add_body(&"moon_a", "Moon A", BodyType.Kind.MOON)
	var cache := SnapshotCacheProbe.new()
	var panel = LifeDetailPanelScript.new()
	panel.configure(registry, cache)

	panel.open_for_body(&"planet_a")
	panel.open_for_body(&"moon_a")
	ctx.assert_true(panel.get_debug_snapshot().get("body_id", StringName("")) == &"moon_a", "open_for_body(new) wechselt den Inhalt bei offenem Panel")

	panel.open_for_body(&"moon_a")
	ctx.assert_true(not bool(panel.get_debug_snapshot().get("is_open", true)), "Same-Body-Klick toggelt das Panel zu")

	panel.open_for_body(&"planet_a")
	panel.close_panel()
	ctx.assert_true(not bool(panel.get_debug_snapshot().get("is_open", true)), "Close schliesst das Panel")

	panel.open_for_body(&"planet_a")
	panel._unhandled_input(_escape_press_event())
	ctx.assert_true(not bool(panel.get_debug_snapshot().get("is_open", true)), "ESC schliesst das Panel")

	panel.free()
	registry.free()


static func _seed_full_descriptions(cache: SnapshotCacheProbe, id: StringName) -> void:
	cache.environment_by_id[id] = {
		EnvironmentServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		EnvironmentServiceScript.KEY_ENVIRONMENT_CLASS: EnvironmentServiceScript.Class.HABITABLE,
		EnvironmentServiceScript.KEY_ECOSYSTEM_TYPE: EnvironmentServiceScript.EcosystemType.TEMPERATE_WORLD,
	}
	cache.planetary_state_by_id[id] = {
		PlanetaryStateServiceScript.KEY_HAS_SAMPLED_YEAR_BASIS: true,
		PlanetaryStateServiceScript.KEY_VOLATILE_INVENTORY_CLASS: PlanetaryStateServiceScript.VolatileInventoryClass.RICH,
		PlanetaryStateServiceScript.KEY_CLIMATE_BUFFER_CLASS: PlanetaryStateServiceScript.ClimateBufferClass.BUFFERED,
		PlanetaryStateServiceScript.KEY_SEASONALITY_CLASS: PlanetaryStateServiceScript.SeasonalityClass.LOW,
		PlanetaryStateServiceScript.KEY_STABILITY_CLASS: PlanetaryStateServiceScript.StabilityClass.STABLE,
		PlanetaryStateServiceScript.KEY_THERMAL_EXTREMITY_CLASS: PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE,
	}
	cache.biosphere_scale_by_id[id] = {
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
		BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.WATER_CARBON,
		BiosphereScaleServiceScript.KEY_DOMINANT_POTENTIAL_CLASS: LifePotentialServiceScript.PotentialClass.HIGH,
		BiosphereScaleServiceScript.KEY_DOMINANT_BIOMASS_INDEX: 0.42,
	}
	cache.native_species_by_id[id] = {
		NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS: true,
		NativeSpeciesServiceScript.KEY_SPECIES_COMPLEXITY_CLASS: NativeSpeciesServiceScript.ComplexityClass.DIVERSE_MACRO,
		NativeSpeciesServiceScript.KEY_HABITAT_CLASS: NativeSpeciesServiceScript.HabitatClass.TEMPERATE_SURFACE,
		NativeSpeciesServiceScript.KEY_METABOLISM_CLASS: NativeSpeciesServiceScript.MetabolismClass.PHOTOTROPHIC,
		NativeSpeciesServiceScript.KEY_MOBILITY_CLASS: NativeSpeciesServiceScript.MobilityClass.MOTILE,
	}
	cache.life_potential_by_id[id] = {
		LifePotentialServiceScript.KEY_HAS_LIFE_POTENTIAL_BASIS: true,
		LifePotentialServiceScript.KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.WATER_CARBON,
		LifePotentialServiceScript.KEY_DOMINANT_POTENTIAL_CLASS: LifePotentialServiceScript.PotentialClass.HIGH,
	}


static func _escape_press_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	return event
