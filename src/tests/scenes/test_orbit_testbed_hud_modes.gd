extends RefCounted

const OrbitTestbedScript = preload("res://scenes/testbeds/orbit_testbed.gd")
const OrbitCameraFramingScript = preload("res://src/tools/rendering/orbit_camera_framing.gd")
const LocalBubbleManagerScript = preload("res://src/runtime/local_bubble/local_bubble_manager.gd")
const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const ThermalServiceScript = preload("res://src/sim/thermal/thermal_service.gd")
const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const NativeSpeciesServiceScript = preload("res://src/sim/life/native_species_service.gd")
const OrbitReadoutServiceScript = preload("res://src/sim/orbit/orbit_readout_service.gd")


class BubbleProbe:
	extends LocalBubbleManagerScript

	var focus_id: StringName = &"gamma_iii"

	func get_focus() -> StringName:
		return focus_id


class SnapshotCacheProbe:
	extends RefCounted

	var environment_desc: Dictionary = {}
	var thermal_desc: Dictionary = {}
	var planetary_state_desc: Dictionary = {}
	var biosphere_desc: Dictionary = {}
	var native_species_desc: Dictionary = {}
	var life_potential_desc: Dictionary = {}
	var orbit_readout_desc: Dictionary = {}

	func get_focus_environment_desc() -> Dictionary:
		return environment_desc

	func get_focus_thermal_desc() -> Dictionary:
		return thermal_desc

	func get_focus_planetary_state_desc() -> Dictionary:
		return planetary_state_desc

	func get_focus_biosphere_scale_desc() -> Dictionary:
		return biosphere_desc

	func get_focus_native_species_desc() -> Dictionary:
		return native_species_desc

	func get_focus_life_potential_desc() -> Dictionary:
		return life_potential_desc

	func get_focus_orbit_readout_desc() -> Dictionary:
		return orbit_readout_desc


class CameraControllerProbe:
	extends RefCounted

	func get_zoom_factor() -> float:
		return 1.0

	func get_zoom_mode() -> StringName:
		return &"focus-lock"

	func get_frame_label() -> StringName:
		return OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK


class TimeScaleControllerProbe:
	extends RefCounted

	func get_step_label() -> String:
		return "5/8"


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_testbed_hud_modes"
	_test_summary_mode_is_default_and_compact(ctx)
	_test_details_mode_restores_expert_readouts(ctx)


static func _test_summary_mode_is_default_and_compact(ctx) -> void:
	var testbed = _build_testbed_probe()
	testbed._sync_hud_mode_buttons()
	testbed._update_hud()

	ctx.assert_true(not testbed._hud_details_enabled, "HUD startet im Summary-Modus")
	ctx.assert_true(testbed._summary_button.disabled, "Summary-Button spiegelt den aktiven Default-Modus")
	ctx.assert_true(not testbed._details_button.disabled, "Details-Button bleibt im Summary-Modus waehbar")
	ctx.assert_true(testbed._life_value.visible, "Summary zeigt die Life-Zeile")
	ctx.assert_true(testbed._species_value.visible, "Summary zeigt Species bei vorhandener Species-Basis")
	ctx.assert_true(testbed._density_value.visible, "Summary zeigt Density bei post-prebiotic Life-Stages")
	ctx.assert_true(testbed._cycle_value.visible, "Summary ersetzt Rotation/Orbit durch die kompakte Cycle-Zeile")
	ctx.assert_true(not testbed._climate_value.visible, "Summary blendet Bands aus")
	ctx.assert_true(not testbed._world_value.visible, "Summary blendet World aus")
	ctx.assert_true(not testbed._biomass_value.visible, "Summary blendet Biomass aus")
	ctx.assert_true(not testbed._life_potential_value.visible, "Summary blendet Life Potential aus")
	ctx.assert_true(not testbed._season_value.visible, "Summary blendet Season/Primary Source aus")
	ctx.assert_true(not testbed._day_value.visible, "Summary blendet Rotation aus")
	ctx.assert_true(not testbed._year_value.visible, "Summary blendet Orbit aus")
	ctx.assert_true(
		testbed._life_value.text == "Life: ECOSYSTEM / CRYOGENIC_SOLVENT",
		"Summary nutzt die kompakte Life-Lesart"
	)
	ctx.assert_true(
		testbed._species_value.text == "Species: CRYO / MOTILE",
		"Summary nutzt die kompakte Species-Lesart"
	)
	ctx.assert_true(
		testbed._density_value.text == "Density: ABUNDANT",
		"Summary mappt die Dichte direkt aus der Life-Stage"
	)
	ctx.assert_true(
		testbed._cycle_value.text == "Cycle: rot 43.2 h / orb 8.6 d",
		"Summary benennt Rotation und Orbit explizit in der Cycle-Zeile"
	)

	_destroy_testbed_probe(testbed)


static func _test_details_mode_restores_expert_readouts(ctx) -> void:
	var testbed = _build_testbed_probe()
	testbed._set_hud_details_enabled(true)

	ctx.assert_true(testbed._hud_details_enabled, "Details-Toggle aktiviert den Expertenmodus")
	ctx.assert_true(not testbed._summary_button.disabled, "Summary bleibt im Expertenmodus wieder waehlbar")
	ctx.assert_true(testbed._details_button.disabled, "Details-Button spiegelt den aktiven Expertenmodus")
	ctx.assert_true(testbed._climate_value.visible, "Details zeigt Bands wieder an")
	ctx.assert_true(testbed._world_value.visible, "Details zeigt World wieder an")
	ctx.assert_true(testbed._biomass_value.visible, "Details zeigt Biomass wieder an")
	ctx.assert_true(testbed._life_potential_value.visible, "Details zeigt Life Potential wieder an")
	ctx.assert_true(testbed._season_value.visible, "Details zeigt die kombinierte Season/Primary Source-Zeile")
	ctx.assert_true(testbed._day_value.visible, "Details zeigt Rotation separat wieder an")
	ctx.assert_true(testbed._year_value.visible, "Details zeigt Orbit separat wieder an")
	ctx.assert_true(not testbed._density_value.visible, "Details blendet die Summary-Density-Zeile aus")
	ctx.assert_true(not testbed._cycle_value.visible, "Details ersetzt Cycle wieder durch Rotation/Orbit")
	ctx.assert_true(
		testbed._species_value.text == "Species: DIVERSE_MACRO / CRYOCHEMICAL / CRYO_SURFACE / MOTILE",
		"Details zeigt die volle Species-Zeile"
	)
	ctx.assert_true(
		testbed._season_value.text == "Season: subsolar -2 deg   Primary source: gamma",
		"Details behaelt die bestehende Season/Primary source-Zeile unveraendert"
	)
	ctx.assert_true(
		testbed._day_value.text == "Rotation: 43.2 h",
		"Details zeigt Rotation wieder separat"
	)
	ctx.assert_true(
		testbed._year_value.text == "Orbit: 8.6 d",
		"Details zeigt Orbit wieder separat"
	)

	_destroy_testbed_probe(testbed)


static func _build_testbed_probe():
	var testbed = OrbitTestbedScript.new()
	var snapshot_cache := SnapshotCacheProbe.new()
	snapshot_cache.environment_desc = {
		EnvironmentServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		EnvironmentServiceScript.KEY_ENVIRONMENT_CLASS: EnvironmentServiceScript.Class.HABITABLE,
		EnvironmentServiceScript.KEY_ECOSYSTEM_TYPE: EnvironmentServiceScript.EcosystemType.FROZEN_WORLD,
		EnvironmentServiceScript.KEY_HAS_LATITUDINAL_SURFACE_BASIS: true,
		EnvironmentServiceScript.KEY_SOUTH_MIDLATITUDE_SURFACE_TEMPERATURE_K: 239.0,
		EnvironmentServiceScript.KEY_EQUATOR_SURFACE_TEMPERATURE_K: 277.0,
		EnvironmentServiceScript.KEY_NORTH_MIDLATITUDE_SURFACE_TEMPERATURE_K: 227.0,
	}
	snapshot_cache.thermal_desc = {
		ThermalServiceScript.KEY_HAS_SEASONAL_BASIS: true,
		ThermalServiceScript.KEY_SUBSOLAR_LATITUDE_RAD: deg_to_rad(-2.0),
		ThermalServiceScript.KEY_HAS_LUMINOUS_ANCESTOR: true,
		ThermalServiceScript.KEY_SOURCE_ID: &"gamma",
	}
	snapshot_cache.planetary_state_desc = {
		PlanetaryStateServiceScript.KEY_HAS_SAMPLED_YEAR_BASIS: true,
		PlanetaryStateServiceScript.KEY_VOLATILE_INVENTORY_CLASS: 2,
		PlanetaryStateServiceScript.KEY_CLIMATE_BUFFER_CLASS: 2,
		PlanetaryStateServiceScript.KEY_SEASONALITY_CLASS: 0,
		PlanetaryStateServiceScript.KEY_STABILITY_CLASS: 2,
		PlanetaryStateServiceScript.KEY_THERMAL_EXTREMITY_CLASS: 1,
	}
	snapshot_cache.biosphere_desc = {
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM,
		BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
		BiosphereScaleServiceScript.KEY_DOMINANT_POTENTIAL_CLASS: LifePotentialServiceScript.PotentialClass.HIGH,
		BiosphereScaleServiceScript.KEY_DOMINANT_BIOMASS_INDEX: 0.82,
	}
	snapshot_cache.native_species_desc = {
		NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS: true,
		NativeSpeciesServiceScript.KEY_SPECIES_COMPLEXITY_CLASS: NativeSpeciesServiceScript.ComplexityClass.DIVERSE_MACRO,
		NativeSpeciesServiceScript.KEY_METABOLISM_CLASS: NativeSpeciesServiceScript.MetabolismClass.CRYOCHEMICAL,
		NativeSpeciesServiceScript.KEY_HABITAT_CLASS: NativeSpeciesServiceScript.HabitatClass.CRYO_SURFACE,
		NativeSpeciesServiceScript.KEY_MOBILITY_CLASS: NativeSpeciesServiceScript.MobilityClass.MOTILE,
	}
	snapshot_cache.life_potential_desc = {
		LifePotentialServiceScript.KEY_HAS_LIFE_POTENTIAL_BASIS: true,
		LifePotentialServiceScript.KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
		LifePotentialServiceScript.KEY_DOMINANT_POTENTIAL_CLASS: LifePotentialServiceScript.PotentialClass.HIGH,
	}
	snapshot_cache.orbit_readout_desc = {
		OrbitReadoutServiceScript.KEY_HAS_ROTATION_BASIS: true,
		OrbitReadoutServiceScript.KEY_ROTATION_PERIOD_S: 43.2 * 3600.0,
		OrbitReadoutServiceScript.KEY_HAS_ORBITAL_PERIOD_BASIS: true,
		OrbitReadoutServiceScript.KEY_ORBITAL_PERIOD_S: 8.6 * UnitSystem.DAY_S,
	}

	testbed._bubble = BubbleProbe.new()
	testbed._camera_controller = CameraControllerProbe.new()
	testbed._time_scale_controller = TimeScaleControllerProbe.new()
	testbed._derived_snapshot_cache = snapshot_cache
	testbed._summary_button = Button.new()
	testbed._details_button = Button.new()
	testbed._focus_value = Label.new()
	testbed._environment_value = Label.new()
	testbed._climate_value = Label.new()
	testbed._world_value = Label.new()
	testbed._life_value = Label.new()
	testbed._biomass_value = Label.new()
	testbed._species_value = Label.new()
	testbed._density_value = Label.new()
	testbed._life_potential_value = Label.new()
	testbed._season_value = Label.new()
	testbed._time_value = Label.new()
	testbed._day_value = Label.new()
	testbed._year_value = Label.new()
	testbed._cycle_value = Label.new()
	testbed._scale_value = Label.new()
	testbed._cadence_value = Label.new()
	testbed._mode_value = Label.new()
	testbed._hint_label = Label.new()
	testbed.add_child(testbed._bubble)
	for node in [
		testbed._summary_button,
		testbed._details_button,
		testbed._focus_value,
		testbed._environment_value,
		testbed._climate_value,
		testbed._world_value,
		testbed._life_value,
		testbed._biomass_value,
		testbed._species_value,
		testbed._density_value,
		testbed._life_potential_value,
		testbed._season_value,
		testbed._time_value,
		testbed._day_value,
		testbed._year_value,
		testbed._cycle_value,
		testbed._scale_value,
		testbed._cadence_value,
		testbed._mode_value,
		testbed._hint_label,
	]:
		testbed.add_child(node)

	UniverseRegistry.clear()
	_register_probe_planet(&"gamma_iii", "Gamma III")
	TimeService.reset()
	TimeService.sim_time_s = 236.5 * UnitSystem.DAY_S
	TimeService.tick_count = 33093
	TimeService.set_time_scale(13.0 * 60.0)
	TimeService.set_paused(false)
	return testbed


static func _destroy_testbed_probe(testbed) -> void:
	if testbed != null:
		testbed.free()
	UniverseRegistry.clear()
	TimeService.reset()
	TimeService.set_time_scale(1.0)
	TimeService.set_paused(false)


static func _register_probe_planet(id: StringName, display_name: String) -> void:
	if UniverseRegistry.has_body(id):
		return
	var def := BodyDef.new()
	def.id = id
	def.display_name = display_name
	def.kind = BodyType.Kind.PLANET
	def.mass_kg = 1.0
	def.radius_m = 1.0
	UniverseRegistry.register_body(def)
