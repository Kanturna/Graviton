extends Node2D

const OrbitCameraControllerScript = preload("res://src/tools/rendering/orbit_camera_controller.gd")
const OrbitCameraFramingScript = preload("res://src/tools/rendering/orbit_camera_framing.gd")
const OrbitHudFormatterScript = preload("res://src/tools/rendering/orbit_hud_formatter.gd")
const OrbitTimeScaleControllerScript = preload("res://src/tools/rendering/orbit_time_scale_controller.gd")
const PlanetBadgeOverlayScript = preload("res://src/tools/rendering/planet_badge_overlay.gd")
const UniverseTopologyScript = preload("res://src/sim/topology/universe_topology.gd")
const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")
const AsteroidSnapshotCacheScript = preload("res://src/runtime/derived/asteroid_snapshot_cache.gd")
const GalaxyStreamingControllerScript = preload("res://src/runtime/streaming/galaxy_streaming_controller.gd")
const AsteroidSimulationServiceScript = preload("res://src/sim/asteroids/asteroid_simulation_service.gd")
const AsteroidFieldRendererScript = preload("res://src/tools/rendering/asteroid_field_renderer.gd")
const PlanetaryYearSamplerScript = preload("res://src/sim/planetary/planetary_year_sampler.gd")
const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const ProtoBiosphereSimulationServiceScript = preload("res://src/sim/life/proto_biosphere_simulation_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const NativeSpeciesServiceScript = preload("res://src/sim/life/native_species_service.gd")
const GeneticSpeciesServiceScript = preload("res://src/sim/life/genetic_species_service.gd")
const LifeEcologyServiceScript = preload("res://src/sim/life/life_ecology_service.gd")
const LifePopulationEstimateServiceScript = preload("res://src/sim/life/life_population_estimate_service.gd")
const OrbitReadoutServiceScript = preload("res://src/sim/orbit/orbit_readout_service.gd")
const PerfProbeScript = preload("res://src/tools/debug/perf_probe.gd")

const ZOOM_FACTOR_STEP: float = 1.12
const VIEW_BOOKMARK_SLOT_COUNT: int = 5

@export_enum("starter_world", "sample_system", "generated_system", "pilot_galaxy", "scaleup_galaxy_10", "scaleup_galaxy_30", "scaleup_galaxy_100") var initial_world_id: String = "starter_world"

@onready var _world_loader = $WorldLoader
@onready var _orbit_service: OrbitService = $OrbitService
@onready var _thermal_service = $ThermalService
@onready var _atmosphere_service: Node = $AtmosphereService
@onready var _environment_service: Node = $EnvironmentService
@onready var _bubble: LocalBubbleManager = $LocalBubbleManager
@onready var _activation_set = $BubbleActivationSet
@onready var _renderer: OrbitViewRenderer = $WorldRoot
@onready var _galaxy_proxy_renderer = $GalaxyProxyRoot
@onready var _planet_badge_overlay = $PlanetBadgeOverlay
@onready var _debug_overlay: DebugOverlay = $DebugOverlay
@onready var _backdrop: Control = $BackdropLayer/Backdrop

@onready var _focus_value: Label = $HudLayer/TopPanel/Margin/VBox/FocusValue
@onready var _summary_button: Button = $HudLayer/TopPanel/Margin/VBox/HudModeRow/SummaryButton
@onready var _details_button: Button = $HudLayer/TopPanel/Margin/VBox/HudModeRow/DetailsButton
@onready var _planet_summary_value: Label = $HudLayer/TopPanel/Margin/VBox/PlanetSummaryValue
@onready var _planet_life_summary_value: Label = $HudLayer/TopPanel/Margin/VBox/PlanetLifeSummaryValue
@onready var _environment_value: Label = $HudLayer/TopPanel/Margin/VBox/EnvironmentValue
@onready var _climate_value: Label = $HudLayer/TopPanel/Margin/VBox/ClimateValue
@onready var _world_value: Label = $HudLayer/TopPanel/Margin/VBox/WorldValue
@onready var _life_value: Label = $HudLayer/TopPanel/Margin/VBox/LifeValue
@onready var _biomass_value: Label = $HudLayer/TopPanel/Margin/VBox/BiomassValue
@onready var _species_value: Label = $HudLayer/TopPanel/Margin/VBox/SpeciesValue
@onready var _density_value: Label = $HudLayer/TopPanel/Margin/VBox/DensityValue
@onready var _life_potential_value: Label = $HudLayer/TopPanel/Margin/VBox/LifePotentialValue
@onready var _season_value: Label = $HudLayer/TopPanel/Margin/VBox/SeasonValue
@onready var _time_value: Label = $HudLayer/TopPanel/Margin/VBox/TimeValue
@onready var _day_value: Label = $HudLayer/TopPanel/Margin/VBox/DayValue
@onready var _year_value: Label = $HudLayer/TopPanel/Margin/VBox/YearValue
@onready var _cycle_value: Label = $HudLayer/TopPanel/Margin/VBox/CycleValue
@onready var _scale_value: Label = $HudLayer/TopPanel/Margin/VBox/ScaleValue
@onready var _cadence_value: Label = $HudLayer/TopPanel/Margin/VBox/CadenceValue
@onready var _speed_slider: HSlider = $HudLayer/TopPanel/Margin/VBox/SpeedSlider
@onready var _mode_value: Label = $HudLayer/TopPanel/Margin/VBox/ModeValue
@onready var _hint_label: Label = $HudLayer/BottomPanel/Margin/Hints
@onready var _root_inspector = $HudLayer/RootInspector
@onready var _life_detail_panel = $HudLayer/LifeDetailPanel

var _camera_controller = OrbitCameraControllerScript.new()
var _time_scale_controller = OrbitTimeScaleControllerScript.new()
var _derived_snapshot_cache = DerivedSnapshotCacheScript.new()
var _asteroid_snapshot_cache = null
var _asteroid_service = null
var _asteroid_renderer = null
var _streaming_controller = GalaxyStreamingControllerScript.new()
var _planetary_year_sampler = PlanetaryYearSamplerScript.new()
var _planetary_state_service = PlanetaryStateServiceScript.new()
var _life_potential_service = LifePotentialServiceScript.new()
var _proto_biosphere_service = ProtoBiosphereSimulationServiceScript.new()
var _biosphere_scale_service = BiosphereScaleServiceScript.new()
var _native_species_service = NativeSpeciesServiceScript.new()
var _genetic_species_service = GeneticSpeciesServiceScript.new()
var _life_ecology_service = LifeEcologyServiceScript.new()
var _life_population_estimate_service = LifePopulationEstimateServiceScript.new()
var _orbit_readout_service = OrbitReadoutServiceScript.new()
var _focus_order: Array[StringName] = []
var _topology = null
var _focus_index: int = 0
var _view_bookmarks: Dictionary = {}
var _current_galaxy = null
var _is_large_world: bool = false
var _last_frame_label: StringName = StringName("")
var _active_world_scope_id: StringName = StringName("")
var _hud_details_enabled: bool = false
var _last_orbit_perf_counter_snapshot: Dictionary = {}
var _last_asteroid_perf_counter_snapshot: Dictionary = {}
var _last_time_tick_emit_total_us: int = 0
var _last_derived_snapshot_refresh_total_us: int = 0


func _ready() -> void:
	TimeService.reset()
	TimeService.set_paused(false)
	UniverseRegistry.clear()
	_orbit_service.configure(UniverseRegistry, TimeService)
	_asteroid_snapshot_cache = AsteroidSnapshotCacheScript.new()
	_asteroid_service = AsteroidSimulationServiceScript.new()
	_asteroid_service.configure(UniverseRegistry)
	if not _orbit_service.step_completed.is_connected(_on_orbit_service_step_completed):
		_orbit_service.step_completed.connect(_on_orbit_service_step_completed)

	_is_large_world = _is_large_world_id(StringName(initial_world_id))
	_topology = UniverseTopologyScript.new()
	_topology.configure(UniverseRegistry)

	if _is_large_world:
		_current_galaxy = _world_loader.load_named_galaxy(StringName(initial_world_id))
		if _current_galaxy == null:
			push_error("OrbitTestbed: failed to load galaxy '%s'" % initial_world_id)
			set_process(false)
			set_process_unhandled_input(false)
			return
		_streaming_controller.configure(_current_galaxy, _world_loader, UniverseRegistry, TimeService, _orbit_service)
		_active_world_scope_id = _current_galaxy.galaxy_id
		if not _streaming_controller.residency_changed.is_connected(_on_streaming_residency_changed):
			_streaming_controller.residency_changed.connect(_on_streaming_residency_changed)
	else:
		if not _world_loader.load_named_world(StringName(initial_world_id), UniverseRegistry):
			push_error("OrbitTestbed: failed to load initial world '%s'" % initial_world_id)
			set_process(false)
			set_process_unhandled_input(false)
			return
		_orbit_service.recompute_all_at_time(TimeService.sim_time_s)
		_active_world_scope_id = StringName(initial_world_id)

	_refresh_focus_order()
	if _focus_order.is_empty():
		push_error("OrbitTestbed: loaded world '%s' contains no bodies" % initial_world_id)
		set_process(false)
		set_process_unhandled_input(false)
		return

	var root_id: StringName = _root_focus_id()
	_focus_index = maxi(_focus_order.find(root_id), 0)

	_bubble.configure(UniverseRegistry)
	_bubble.set_focus(_focus_order[_focus_index])
	_activation_set.configure(UniverseRegistry, _bubble)
	_activation_set.mark_ids_dirty(UniverseRegistry.get_update_order_ref())
	_activation_set.rebuild()
	if not _orbit_service.bodies_updated.is_connected(_on_orbit_service_bodies_updated):
		_orbit_service.bodies_updated.connect(_on_orbit_service_bodies_updated)
	_orbit_service.request_numeric_local_candidates(_activation_set.get_active_ids())
	_orbit_service.recompute_all_at_time(TimeService.sim_time_s)
	_reset_asteroids_for_current_roots(TimeService.sim_time_s)

	_thermal_service.configure(UniverseRegistry)
	_atmosphere_service.configure(UniverseRegistry, _thermal_service)
	_environment_service.configure(UniverseRegistry, _atmosphere_service)
	_planetary_year_sampler.configure(UniverseRegistry)
	_planetary_state_service.configure(
		UniverseRegistry,
		_thermal_service,
		_atmosphere_service,
		_planetary_year_sampler
	)
	_life_potential_service.configure(
		UniverseRegistry,
		_planetary_state_service,
		_environment_service
	)
	_proto_biosphere_service.configure(
		UniverseRegistry,
		TimeService,
		_world_loader
	)
	if _is_large_world:
		_proto_biosphere_service.initialize_for_galaxy(_current_galaxy)
	else:
		_proto_biosphere_service.initialize_for_named_world(StringName(initial_world_id))
	_biosphere_scale_service.configure(
		UniverseRegistry,
		_planetary_state_service,
		_life_potential_service,
		_proto_biosphere_service
	)
	_native_species_service.configure(
		UniverseRegistry,
		_planetary_state_service,
		_life_potential_service,
		_biosphere_scale_service
	)
	_genetic_species_service.configure(
		UniverseRegistry,
		_planetary_state_service,
		_life_potential_service,
		_biosphere_scale_service,
		_native_species_service
	)
	_life_ecology_service.configure(
		UniverseRegistry,
		_biosphere_scale_service,
		_genetic_species_service
	)
	_life_population_estimate_service.configure(
		UniverseRegistry,
		_biosphere_scale_service,
		_life_ecology_service
	)
	_orbit_readout_service.configure(UniverseRegistry)

	_renderer.configure(UniverseRegistry, _bubble, _topology, TimeService)
	_renderer.set_environment_service(_environment_service)
	_asteroid_snapshot_cache.configure(_asteroid_service, _bubble)
	_configure_asteroid_renderer()
	if not _world_loader.world_loaded.is_connected(_on_world_loader_world_loaded):
		_world_loader.world_loaded.connect(_on_world_loader_world_loaded)
	_derived_snapshot_cache.configure(
		UniverseRegistry,
		TimeService,
		_bubble,
		_world_loader,
		_thermal_service,
		_environment_service,
		_orbit_service,
		_planetary_state_service,
		_life_potential_service,
		_proto_biosphere_service,
		_biosphere_scale_service,
		_orbit_readout_service,
		_native_species_service,
		_genetic_species_service,
		_life_ecology_service,
		_life_population_estimate_service
	)
	_configure_life_detail_panel()
	_configure_root_inspector()
	_refresh_snapshot_interest_ids()
	_renderer.set_derived_snapshot_cache(_derived_snapshot_cache)
	_camera_controller.configure(_renderer, _bubble, UniverseRegistry, _topology)
	if _planet_badge_overlay != null:
		_planet_badge_overlay.configure(
			UniverseRegistry,
			_topology,
			_bubble,
			_derived_snapshot_cache,
			_renderer
		)
		if not _planet_badge_overlay.life_details_requested.is_connected(_on_life_details_requested):
			_planet_badge_overlay.life_details_requested.connect(_on_life_details_requested)
	if _summary_button != null and not _summary_button.pressed.is_connected(_on_summary_button_pressed):
		_summary_button.pressed.connect(_on_summary_button_pressed)
	if _details_button != null and not _details_button.pressed.is_connected(_on_details_button_pressed):
		_details_button.pressed.connect(_on_details_button_pressed)
	_sync_hud_mode_buttons()

	if _is_large_world:
		_galaxy_proxy_renderer.visible = true
		_galaxy_proxy_renderer.configure(
			_current_galaxy,
			UniverseRegistry,
			_bubble,
			_topology,
			TimeService,
			_streaming_controller,
			_renderer
		)
	else:
		_galaxy_proxy_renderer.visible = false

	_debug_overlay.configure(
		UniverseRegistry,
		TimeService,
		_bubble,
		_activation_set,
		_thermal_service,
		_derived_snapshot_cache,
		_backdrop,
		_streaming_controller if _is_large_world else null
	)
	_debug_overlay.visible = false

	_time_scale_controller.configure(_speed_slider)
	_set_focus(_focus_order[_focus_index], false, true)
	_camera_controller.step(0.0, get_viewport_rect().size)
	_sync_view_lod_state(true, false)
	_sync_galaxy_proxy_transform()
	if _planet_badge_overlay != null:
		_planet_badge_overlay.refresh()
	_sync_asteroid_renderer(true)
	_update_hud()


func _exit_tree() -> void:
	_time_scale_controller.dispose()
	_derived_snapshot_cache.dispose()
	if _asteroid_snapshot_cache != null:
		_asteroid_snapshot_cache.dispose()
		_asteroid_snapshot_cache = null
	if _orbit_service != null and _orbit_service.has_signal("step_completed") and _orbit_service.step_completed.is_connected(_on_orbit_service_step_completed):
		_orbit_service.step_completed.disconnect(_on_orbit_service_step_completed)
	if _asteroid_service != null:
		_asteroid_service.free()
		_asteroid_service = null
	if _orbit_readout_service != null:
		_orbit_readout_service.free()
		_orbit_readout_service = null
	if _planetary_state_service != null:
		_planetary_state_service.free()
		_planetary_state_service = null
	if _life_potential_service != null:
		_life_potential_service.free()
		_life_potential_service = null
	if _proto_biosphere_service != null:
		_proto_biosphere_service.free()
		_proto_biosphere_service = null
	if _biosphere_scale_service != null:
		_biosphere_scale_service.free()
		_biosphere_scale_service = null
	if _native_species_service != null:
		_native_species_service.free()
		_native_species_service = null
	if _life_population_estimate_service != null:
		_life_population_estimate_service.free()
		_life_population_estimate_service = null
	if _life_ecology_service != null:
		_life_ecology_service.free()
		_life_ecology_service = null
	if _genetic_species_service != null:
		_genetic_species_service.free()
		_genetic_species_service = null
	if _planetary_year_sampler != null:
		_planetary_year_sampler.free()
		_planetary_year_sampler = null


func _process(delta: float) -> void:
	_activation_set.rebuild()
	_orbit_service.request_numeric_local_candidates(_activation_set.get_active_ids())
	_camera_controller.handle_pan_input(_pan_input_dir(), delta)
	_camera_controller.step(delta, _current_viewport_size())
	# Kamera zuerst anwenden, dann den neuen Frame-/LOD-Kontext an alle
	# View-Consumers spiegeln, bevor der Renderer seine Visuals synct.
	_sync_view_lod_state(false, false)
	if _renderer != null:
		var renderer_sync_start_us: int = Time.get_ticks_usec()
		_renderer.sync_visuals_now()
		PerfProbeScript.sample(&"orbit_renderer_sync_us", Time.get_ticks_usec() - renderer_sync_start_us)
	_sync_asteroid_renderer()
	if _is_large_world:
		_streaming_controller.update(delta, _camera_controller.get_zoom_factor())
	_sync_galaxy_proxy_transform()
	if _planet_badge_overlay != null:
		_planet_badge_overlay.refresh()
	_update_hud()
	_sample_perf_probe()


func _sample_perf_probe() -> void:
	_sample_orbit_service_perf_probe()
	_sample_asteroid_perf_probe()
	PerfProbeScript.sample(&"time_tick_emit_us", TimeService.last_tick_emit_us)
	var current_time_tick_emit_total_us: int = TimeService.tick_emit_total_us
	PerfProbeScript.sample(
		&"time_tick_emit_total_us",
		_delta_from_monotonic_total(current_time_tick_emit_total_us, _last_time_tick_emit_total_us)
	)
	_last_time_tick_emit_total_us = current_time_tick_emit_total_us
	if _derived_snapshot_cache != null and _derived_snapshot_cache.has_method("get_refresh_total_us"):
		var current_derived_refresh_total_us: int = _derived_snapshot_cache.get_refresh_total_us()
		PerfProbeScript.sample(
			&"derived_snapshot_refresh_total_us",
			_delta_from_monotonic_total(current_derived_refresh_total_us, _last_derived_snapshot_refresh_total_us)
		)
		_last_derived_snapshot_refresh_total_us = current_derived_refresh_total_us
	if _activation_set != null:
		PerfProbeScript.sample(&"active_ids", _activation_set.get_active_ids().size())
	if _camera_controller != null:
		PerfProbeScript.sample(&"zoom_factor", _camera_controller.get_zoom_factor())
		PerfProbeScript.sample(&"view_scale", _camera_controller.get_current_view_scale())
		PerfProbeScript.sample(&"frame_label", String(_camera_controller.get_frame_label()))
	if _planet_badge_overlay != null:
		var badge_snapshot: Dictionary = _planet_badge_overlay.get_debug_snapshot()
		PerfProbeScript.sample(&"visible_badges", int(badge_snapshot.get("visible_badge_count", 0)))
	if _root_inspector != null and _root_inspector.has_method("get_debug_snapshot"):
		var inspector_snapshot: Dictionary = _root_inspector.get_debug_snapshot()
		var row_ids: Array = inspector_snapshot.get("row_body_ids", [])
		PerfProbeScript.sample(&"root_inspector_open", int(bool(inspector_snapshot.get("is_open", false))))
		PerfProbeScript.sample(&"root_inspector_row_count", row_ids.size())
		PerfProbeScript.sample(&"root_inspector_full_row_count", int(inspector_snapshot.get("full_row_count", row_ids.size())))
		PerfProbeScript.sample(&"root_inspector_compact_root_overview", int(bool(inspector_snapshot.get("compact_root_overview", false))))
		PerfProbeScript.sample(&"root_inspector_compact_focus_branch", int(bool(inspector_snapshot.get("compact_focus_branch", false))))
		PerfProbeScript.sample(&"root_inspector_model_apply_count", int(inspector_snapshot.get("model_apply_count", 0)))


func _sample_orbit_service_perf_probe() -> void:
	if _orbit_service == null:
		return
	var snapshot: Dictionary = _orbit_service.get_perf_counter_snapshot()
	PerfProbeScript.sample(
		OrbitService.PERF_KEY_NUMERIC_LOCAL_COUNT,
		int(snapshot.get(OrbitService.PERF_KEY_NUMERIC_LOCAL_COUNT, 0))
	)
	PerfProbeScript.sample(
		OrbitService.PERF_KEY_STEP_CORE_US,
		int(snapshot.get(OrbitService.PERF_KEY_STEP_CORE_US, 0))
	)
	_bump_perf_counter_delta(snapshot, OrbitService.PERF_KEY_ORBIT_SIM_TICKS)
	_bump_perf_counter_delta(snapshot, OrbitService.PERF_KEY_REGIME_ENTER_NUMERIC)
	_bump_perf_counter_delta(snapshot, OrbitService.PERF_KEY_NUMERIC_SUBSTEP_TOTAL)
	_bump_perf_counter_delta(snapshot, OrbitService.PERF_KEY_SUBSTEP_CAP_HITS)
	_bump_perf_counter_delta(snapshot, OrbitService.PERF_KEY_REGIME_EXIT_NUMERIC)
	_last_orbit_perf_counter_snapshot = snapshot.duplicate()


func _bump_perf_counter_delta(snapshot: Dictionary, key: StringName) -> void:
	var current: int = int(snapshot.get(key, 0))
	var previous: int = int(_last_orbit_perf_counter_snapshot.get(key, 0))
	var delta: int = current - previous
	if delta > 0:
		PerfProbeScript.bump(key, delta)


func _sample_asteroid_perf_probe() -> void:
	if _asteroid_service == null:
		return
	var snapshot: Dictionary = _asteroid_service.get_perf_counter_snapshot()
	PerfProbeScript.sample(
		AsteroidSimulationServiceScript.PERF_KEY_ACTIVE_ASTEROIDS,
		int(snapshot.get(AsteroidSimulationServiceScript.PERF_KEY_ACTIVE_ASTEROIDS, 0))
	)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_ATTRACTOR_CHECKS)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_SUBSTEPS)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_SUBSTEP_CAP_HITS)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_SPAWNED)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_DESPAWNED)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_FAR_RETIRED_COUNT)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_FREE_DRIFT_COUNT)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_BH_ATTRACTOR_COUNT)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_INFLUENCE_ZONE_CHECKS)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_INFLUENCE_INDEX_REBUILDS)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_TOTAL_ACTIVE_ATTRACTORS_PER_TICK)
	_bump_asteroid_perf_counter_delta(snapshot, AsteroidSimulationServiceScript.PERF_KEY_ATTRACTOR_SET_CHANGES)
	if _asteroid_renderer != null and _asteroid_renderer.has_method("get_debug_snapshot"):
		var renderer_snapshot: Dictionary = _asteroid_renderer.get_debug_snapshot()
		PerfProbeScript.sample(&"asteroid_visible_count", int(renderer_snapshot.get("visible_count", 0)))
		PerfProbeScript.sample(&"asteroid_trail_count", int(renderer_snapshot.get("trail_count", 0)))
		PerfProbeScript.sample(&"asteroid_trail_point_count", int(renderer_snapshot.get("trail_point_count", 0)))
		PerfProbeScript.sample(&"asteroid_screen_visible_count", int(renderer_snapshot.get("screen_visible_count", 0)))
		PerfProbeScript.sample(&"asteroid_screen_culled_count", int(renderer_snapshot.get("screen_culled_count", 0)))
		PerfProbeScript.sample(&"asteroid_view_max_abs_ru", float(renderer_snapshot.get("view_max_abs_ru", 0.0)))
		PerfProbeScript.sample(&"asteroid_screen_max_abs_px", float(renderer_snapshot.get("screen_max_abs_px", 0.0)))
	_last_asteroid_perf_counter_snapshot = snapshot.duplicate()


func _bump_asteroid_perf_counter_delta(snapshot: Dictionary, key: StringName) -> void:
	var current: int = int(snapshot.get(key, 0))
	var previous: int = int(_last_asteroid_perf_counter_snapshot.get(key, 0))
	var delta: int = current - previous
	if delta > 0:
		PerfProbeScript.bump(key, delta)


func _dump_perf_probe_snapshot_json(path: String, csv_path: String, csv_rows: int) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("OrbitTestbed: cannot open perf snapshot '%s' for write" % path)
		return false
	var snapshot: Dictionary = _build_perf_probe_snapshot(csv_path, csv_rows)
	file.store_string(JSON.stringify(_json_safe(snapshot), "\t"))
	file.store_string("\n")
	file.close()
	return true


func _build_perf_probe_snapshot(csv_path: String, csv_rows: int) -> Dictionary:
	var focus_id: StringName = StringName("") if _bubble == null else _bubble.get_focus()
	return {
		"schema": "graviton_perf_probe_snapshot_v1",
		"created_unix_time": Time.get_unix_time_from_system(),
		"created_ticks_msec": Time.get_ticks_msec(),
		"csv_path": csv_path,
		"csv_rows": csv_rows,
		"scene": _scene_debug_snapshot(),
		"time": _time_debug_snapshot(),
		"focus": _focus_debug_snapshot(focus_id),
		"registry": _registry_debug_snapshot(focus_id),
		"camera": _camera_debug_snapshot(),
		"activation_set": _activation_debug_snapshot(),
		"derived_snapshot_cache": _derived_cache_debug_snapshot(),
		"renderer": _debug_snapshot_from(_renderer),
		"asteroid_renderer": _debug_snapshot_from(_asteroid_renderer),
		"asteroid_snapshot_cache": _debug_snapshot_from(_asteroid_snapshot_cache),
		"galaxy_proxy": _debug_snapshot_from(_galaxy_proxy_renderer),
		"streaming": _debug_snapshot_from(_streaming_controller),
		"ui": {
			"root_inspector": _debug_snapshot_from(_root_inspector),
			"planet_badge_overlay": _debug_snapshot_from(_planet_badge_overlay),
			"life_detail_panel": _debug_snapshot_from(_life_detail_panel),
			"debug_overlay": _debug_snapshot_from(_debug_overlay),
		},
		"backdrop": _debug_snapshot_from(_backdrop, "debug_snapshot"),
		"services": {
			"orbit_perf_counters": _orbit_service.get_perf_counter_snapshot() if _orbit_service != null else {},
			"asteroid_perf_counters": _asteroid_service.get_perf_counter_snapshot() if _asteroid_service != null else {},
			"asteroids": _debug_snapshot_from(_asteroid_service),
			"proto_biosphere": _debug_snapshot_from(_proto_biosphere_service),
		},
		"perf_probe": {
			"ring_rows": PerfProbeScript.rows_captured(),
			"last_dump": PerfProbeScript.last_dump_summary(),
		},
	}


func _scene_debug_snapshot() -> Dictionary:
	var viewport_size: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2.ZERO
	return {
		"initial_world_id": initial_world_id,
		"active_world_scope_id": _active_world_scope_id,
		"is_large_world": _is_large_world,
		"last_frame_label": _last_frame_label,
		"hud_details_enabled": _hud_details_enabled,
		"focus_index": _focus_index,
		"focus_order_count": _focus_order.size(),
		"focus_order": _focus_order.duplicate(),
		"viewport_size": viewport_size,
		"process_frame": Engine.get_process_frames(),
		"galaxy": _galaxy_debug_snapshot(),
	}


func _galaxy_debug_snapshot() -> Dictionary:
	if _current_galaxy == null:
		return {}
	var out: Dictionary = {
		"galaxy_id": _current_galaxy.galaxy_id,
		"focus_root_id": _current_galaxy.focus_root_id,
		"default_resident_root_ids": _current_galaxy.default_resident_root_ids,
	}
	if _current_galaxy.has_method("root_ids"):
		var root_ids: Array[StringName] = _current_galaxy.root_ids()
		out["root_count"] = root_ids.size()
		out["root_ids"] = root_ids
	return out


func _time_debug_snapshot() -> Dictionary:
	return {
		"sim_time_s": TimeService.sim_time_s,
		"tick_count": TimeService.tick_count,
		"time_scale": TimeService.time_scale,
		"paused": TimeService.paused,
		"last_sim_dt_s": TimeService.last_sim_dt_s,
		"last_tick_emit_us": TimeService.last_tick_emit_us,
		"tick_emit_total_us": TimeService.tick_emit_total_us,
	}


func _focus_debug_snapshot(focus_id: StringName) -> Dictionary:
	var def: BodyDef = UniverseRegistry.get_def(focus_id) if focus_id != StringName("") else null
	if def == null:
		return {
			"id": focus_id,
			"present": false,
		}
	return {
		"id": focus_id,
		"present": true,
		"display_name": def.display_name,
		"kind": BodyType.to_string_kind(def.kind),
		"kind_id": def.kind,
		"parent_id": def.parent_id,
		"root_id": _topology.root_id_of(focus_id) if _topology != null else StringName(""),
		"is_root": def.is_root(),
		"mass_kg": def.mass_kg,
		"radius_m": def.radius_m,
	}


func _registry_debug_snapshot(focus_id: StringName) -> Dictionary:
	var order: Array[StringName] = UniverseRegistry.get_update_order_ref()
	var focus_root_id: StringName = _topology.root_id_of(focus_id) if _topology != null and focus_id != StringName("") else StringName("")
	var root_ids: Array[StringName] = []
	var body_rows: Array[Dictionary] = []
	var kind_counts: Dictionary = {}
	var focus_root_kind_counts: Dictionary = {}
	var focus_root_body_count: int = 0
	for id in order:
		var def: BodyDef = UniverseRegistry.get_def(id)
		if def == null:
			continue
		var kind_text: String = BodyType.to_string_kind(def.kind)
		kind_counts[kind_text] = int(kind_counts.get(kind_text, 0)) + 1
		var root_id: StringName = _topology.root_id_of(id) if _topology != null else StringName("")
		if def.is_root():
			root_ids.append(id)
		if focus_root_id != StringName("") and root_id == focus_root_id:
			focus_root_body_count += 1
			focus_root_kind_counts[kind_text] = int(focus_root_kind_counts.get(kind_text, 0)) + 1
		var state: BodyState = UniverseRegistry.get_state(id)
		body_rows.append({
			"id": id,
			"display_name": def.display_name,
			"kind": kind_text,
			"kind_id": def.kind,
			"parent_id": def.parent_id,
			"root_id": root_id,
			"current_mode": OrbitMode.to_string_kind(state.current_mode) if state != null else "n/a",
			"parent_frame_position_m": Vector3.ZERO if state == null else state.position_parent_frame_m,
			"parent_frame_position_m_length": 0.0 if state == null else state.position_parent_frame_m.length(),
		})
	return {
		"body_count": UniverseRegistry.body_count(),
		"update_order_count": order.size(),
		"root_count": root_ids.size(),
		"root_ids": root_ids,
		"kind_counts": kind_counts,
		"focus_root_id": focus_root_id,
		"focus_root_body_count": focus_root_body_count,
		"focus_root_kind_counts": focus_root_kind_counts,
		"bodies": body_rows,
	}


func _camera_debug_snapshot() -> Dictionary:
	if _camera_controller == null:
		return {}
	var out: Dictionary = {}
	if _camera_controller.has_method("get_zoom_factor"):
		out["zoom_factor"] = _camera_controller.get_zoom_factor()
	if _camera_controller.has_method("get_current_view_scale"):
		out["view_scale"] = _camera_controller.get_current_view_scale()
	if _camera_controller.has_method("get_zoom_mode"):
		out["zoom_mode"] = _camera_controller.get_zoom_mode()
	if _camera_controller.has_method("get_frame_label"):
		out["frame_label"] = _camera_controller.get_frame_label()
	if _camera_controller.has_method("capture_view_state"):
		out["view_state"] = _camera_controller.capture_view_state()
	return out


func _activation_debug_snapshot() -> Dictionary:
	if _activation_set == null:
		return {}
	var out: Dictionary = _activation_set.describe() if _activation_set.has_method("describe") else {}
	if _activation_set.has_method("get_active_ids"):
		var active_ids: Array[StringName] = _activation_set.get_active_ids()
		out["active_ids"] = active_ids
		out["active_id_count"] = active_ids.size()
	return out


func _derived_cache_debug_snapshot() -> Dictionary:
	if _derived_snapshot_cache == null:
		return {}
	return {
		"revision": _derived_snapshot_cache.get_revision(),
		"last_refresh_reason": _derived_snapshot_cache.get_last_refresh_reason(),
		"last_refreshed_body_count": _derived_snapshot_cache.get_last_refreshed_body_count(),
		"refresh_call_count_total": _derived_snapshot_cache.get_refresh_call_count_total(),
		"refresh_throttled_count": _derived_snapshot_cache.get_refresh_throttled_count(),
		"last_refresh_us": _derived_snapshot_cache.get_last_refresh_us(),
		"refresh_total_us": _derived_snapshot_cache.get_refresh_total_us(),
		"focus_id": _derived_snapshot_cache.get_focus_id(),
		"focus_descs": {
			"thermal": _derived_snapshot_cache.get_focus_thermal_desc(),
			"environment": _derived_snapshot_cache.get_focus_environment_desc(),
			"planetary_state": _derived_snapshot_cache.get_focus_planetary_state_desc(),
			"life_potential": _derived_snapshot_cache.get_focus_life_potential_desc(),
			"biosphere": _derived_snapshot_cache.get_focus_biosphere_desc(),
			"biosphere_scale": _derived_snapshot_cache.get_focus_biosphere_scale_desc(),
			"orbit_readout": _derived_snapshot_cache.get_focus_orbit_readout_desc(),
			"native_species": _derived_snapshot_cache.get_focus_native_species_desc(),
			"genetic_species": _derived_snapshot_cache.get_focus_genetic_species_desc(),
			"life_ecology": _derived_snapshot_cache.get_focus_life_ecology_desc(),
			"population_estimate": _derived_snapshot_cache.get_focus_population_estimate_desc(),
		},
	}


func _debug_snapshot_from(provider, method_name: String = "get_debug_snapshot") -> Dictionary:
	if provider == null or not provider.has_method(method_name):
		return {}
	var snapshot = provider.call(method_name)
	if typeof(snapshot) == TYPE_DICTIONARY:
		return snapshot
	return {"value": snapshot}


static func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return value
		TYPE_FLOAT:
			var float_value: float = float(value)
			return float_value if is_finite(float_value) else str(float_value)
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value)
		TYPE_VECTOR2:
			var vector2: Vector2 = value
			return {"x": vector2.x, "y": vector2.y}
		TYPE_VECTOR3:
			var vector3: Vector3 = value
			return {"x": vector3.x, "y": vector3.y, "z": vector3.z}
		TYPE_COLOR:
			var color: Color = value
			return {"r": color.r, "g": color.g, "b": color.b, "a": color.a}
		TYPE_DICTIONARY:
			var safe_dict: Dictionary = {}
			var source_dict: Dictionary = value
			for key in source_dict.keys():
				safe_dict[str(key)] = _json_safe(source_dict[key])
			return safe_dict
		TYPE_ARRAY:
			var safe_array: Array = []
			for item in value:
				safe_array.append(_json_safe(item))
			return safe_array
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			var packed_array: Array = []
			for item in value:
				packed_array.append(_json_safe(item))
			return packed_array
		_:
			return str(value)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_view_bookmark_key_event(event):
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_TAB:
				_cycle_focus(-1 if event.shift_pressed else 1)
				get_viewport().set_input_as_handled()
			KEY_HOME:
				var root_id: StringName = _root_focus_id()
				_focus_index = maxi(_focus_order.find(root_id), 0)
				_set_focus(_focus_order[_focus_index])
				get_viewport().set_input_as_handled()
			KEY_Q, KEY_BRACKETLEFT, KEY_PAGEDOWN:
				_time_scale_controller.apply_previous_preset()
				get_viewport().set_input_as_handled()
			KEY_E, KEY_BRACKETRIGHT, KEY_PAGEUP:
				_time_scale_controller.apply_next_preset()
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				TimeService.set_paused(not TimeService.paused)
				get_viewport().set_input_as_handled()
			KEY_F3:
				_debug_overlay.visible = not _debug_overlay.visible
				_debug_overlay.mark_dirty(_debug_overlay.visible)
				get_viewport().set_input_as_handled()
			KEY_P:
				if event.shift_pressed:
					PerfProbeScript.clear()
					print("[PerfProbe] ring cleared")
				else:
					var dump_stamp: int = int(Time.get_unix_time_from_system())
					var dump_path: String = "user://perf_probe_%d.csv" % dump_stamp
					var rows_written: int = PerfProbeScript.dump_csv(dump_path)
					var snapshot_path: String = "user://perf_probe_%d.json" % dump_stamp
					var snapshot_written: bool = _dump_perf_probe_snapshot_json(snapshot_path, dump_path, rows_written)
					if snapshot_written:
						print("[PerfProbe] dumped %d rows to %s and snapshot to %s" % [rows_written, dump_path, snapshot_path])
					else:
						print("[PerfProbe] dumped %d rows to %s; snapshot write failed for %s" % [rows_written, dump_path, snapshot_path])
				get_viewport().set_input_as_handled()
			KEY_I:
				_toggle_root_inspector_for_current_root()
				get_viewport().set_input_as_handled()
			KEY_BACKSPACE:
				_camera_controller.fit_current_focus()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var picked_id: StringName = _renderer.pick_body_at_screen(event.position)
				if picked_id != StringName(""):
					_focus_index = maxi(_focus_order.find(picked_id), 0)
					_set_focus(picked_id)
					get_viewport().set_input_as_handled()
				elif _is_large_world:
					var picked_root_id: StringName = _galaxy_proxy_renderer.pick_root_at_screen(event.position)
					if picked_root_id != StringName(""):
						_streaming_controller.set_focus_root(picked_root_id)
						_refresh_focus_order()
						_focus_index = maxi(_focus_order.find(picked_root_id), 0)
						_set_focus(picked_root_id, true, true)
						get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				_camera_controller.handle_zoom_multiplier(ZOOM_FACTOR_STEP)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera_controller.handle_zoom_multiplier(1.0 / ZOOM_FACTOR_STEP)
				get_viewport().set_input_as_handled()


func _cycle_focus(direction: int) -> void:
	if _focus_order.is_empty():
		return
	_focus_index = wrapi(_focus_index + direction, 0, _focus_order.size())
	_set_focus(_focus_order[_focus_index])


func _set_focus(body_id: StringName, immediate: bool = false, force_fit: bool = false) -> void:
	if body_id == StringName(""):
		return
	var previous_focus_id: StringName = _bubble.get_focus() if _bubble != null else StringName("")
	_camera_controller.set_focus(body_id, immediate, force_fit)
	if body_id != previous_focus_id and not _focuses_share_root(previous_focus_id, body_id):
		_clear_asteroid_renderer_state()
	_sync_root_inspector_context(false)
	_refresh_snapshot_interest_ids()
	_debug_overlay.mark_dirty(_debug_overlay.visible)
	if immediate and _can_sync_immediate_view_state():
		_sync_immediate_view_state(true)


func _update_hud() -> void:
	var focus_id: StringName = _bubble.get_focus()
	var focus_def: BodyDef = UniverseRegistry.get_def(focus_id)
	var focus_name: String = String(focus_id)
	if focus_def != null and focus_def.display_name != "":
		focus_name = focus_def.display_name

	var environment_desc: Dictionary = _derived_snapshot_cache.get_focus_environment_desc()
	var thermal_desc: Dictionary = _derived_snapshot_cache.get_focus_thermal_desc()
	var planetary_state_desc: Dictionary = _derived_snapshot_cache.get_focus_planetary_state_desc()
	var biosphere_scale_desc: Dictionary = _derived_snapshot_cache.get_focus_biosphere_scale_desc()
	var native_species_desc: Dictionary = _derived_snapshot_cache.get_focus_native_species_desc()
	var life_potential_desc: Dictionary = _derived_snapshot_cache.get_focus_life_potential_desc()
	var orbit_readout_desc: Dictionary = _derived_snapshot_cache.get_focus_orbit_readout_desc()
	var is_planetary_focus: bool = focus_def != null and (
		focus_def.kind == BodyType.Kind.PLANET or focus_def.kind == BodyType.Kind.MOON
	)
	var has_species_basis: bool = bool(native_species_desc.get(
		NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS,
		false
	))
	var has_cycle_basis: bool = bool(orbit_readout_desc.get(
		OrbitReadoutServiceScript.KEY_HAS_ROTATION_BASIS,
		false
	)) or bool(orbit_readout_desc.get(
		OrbitReadoutServiceScript.KEY_HAS_ORBITAL_PERIOD_BASIS,
		false
	))

	var fps: int = Engine.get_frames_per_second()
	var speed_step_label: String = _time_scale_controller.get_step_label()
	_focus_value.text = OrbitHudFormatterScript.format_focus(focus_name)
	_environment_value.text = OrbitHudFormatterScript.format_environment(environment_desc)
	_time_value.text = OrbitHudFormatterScript.format_time(TimeService.sim_time_s, TimeService.tick_count, fps)
	_scale_value.text = OrbitHudFormatterScript.format_scale(
		TimeService.time_scale,
		speed_step_label,
		_camera_controller.get_zoom_factor(),
		String(_camera_controller.get_zoom_mode()),
		String(_camera_controller.get_frame_label())
	)
	_cadence_value.text = OrbitHudFormatterScript.format_cadence(TimeService.time_scale)
	_mode_value.text = OrbitHudFormatterScript.format_mode(UniverseRegistry.body_count(), TimeService.paused)

	if _hud_details_enabled:
		_planet_summary_value.visible = false
		_planet_life_summary_value.visible = false
		_environment_value.visible = true
		_climate_value.visible = true
		_climate_value.text = OrbitHudFormatterScript.format_bands(environment_desc)
		_world_value.visible = is_planetary_focus
		if _world_value.visible:
			_world_value.text = OrbitHudFormatterScript.format_world(planetary_state_desc)
		_life_value.visible = is_planetary_focus
		if _life_value.visible:
			_life_value.text = OrbitHudFormatterScript.format_life(biosphere_scale_desc)
		_biomass_value.visible = is_planetary_focus
		if _biomass_value.visible:
			_biomass_value.text = OrbitHudFormatterScript.format_biomass(biosphere_scale_desc)
		_species_value.visible = is_planetary_focus and has_species_basis
		if _species_value.visible:
			_species_value.text = OrbitHudFormatterScript.format_species(native_species_desc)
		_density_value.visible = false
		_life_potential_value.visible = is_planetary_focus
		if _life_potential_value.visible:
			_life_potential_value.text = OrbitHudFormatterScript.format_life_potential(life_potential_desc)
		_season_value.visible = true
		_season_value.text = "%s   %s" % [
			OrbitHudFormatterScript.format_season(thermal_desc),
			OrbitHudFormatterScript.format_primary_source(thermal_desc)
		]
		_day_value.visible = bool(orbit_readout_desc.get(OrbitReadoutServiceScript.KEY_HAS_ROTATION_BASIS, false))
		if _day_value.visible:
			_day_value.text = OrbitHudFormatterScript.format_rotation(orbit_readout_desc)
		_year_value.visible = bool(orbit_readout_desc.get(OrbitReadoutServiceScript.KEY_HAS_ORBITAL_PERIOD_BASIS, false))
		if _year_value.visible:
			_year_value.text = OrbitHudFormatterScript.format_orbit(orbit_readout_desc)
		_cycle_value.visible = false
	else:
		_planet_summary_value.visible = is_planetary_focus
		if _planet_summary_value.visible:
			_planet_summary_value.text = OrbitHudFormatterScript.format_planet_summary(environment_desc)
		_planet_life_summary_value.visible = is_planetary_focus
		if _planet_life_summary_value.visible:
			_planet_life_summary_value.text = OrbitHudFormatterScript.format_planet_life_summary(
				biosphere_scale_desc,
				native_species_desc
			)
		_environment_value.visible = false
		_climate_value.visible = false
		_world_value.visible = false
		_life_value.visible = false
		_biomass_value.visible = false
		_species_value.visible = false
		_density_value.visible = false
		_life_potential_value.visible = false
		_season_value.visible = false
		_day_value.visible = false
		_year_value.visible = false
		_cycle_value.visible = is_planetary_focus and has_cycle_basis
		if _cycle_value.visible:
			_cycle_value.text = OrbitHudFormatterScript.format_cycle(orbit_readout_desc)

	_hint_label.text = "LMB focus   I root inspector   Tab / Shift+Tab focus   Home root overview   Ctrl+1-5 save view   1-5 recall view   Q/E or PgUp/PgDn speed   WASD pan   Wheel zoom   Backspace fit focus   Space pause   F3 debug   P perf dump   Shift+P perf clear"


func _pan_input_dir() -> Vector2:
	var pan_input: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan_input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan_input.y += 1.0
	return pan_input


func _handle_view_bookmark_key_event(event: InputEventKey) -> bool:
	var slot: int = _bookmark_slot_for_key_event(event)
	if slot < 1:
		return false
	if event.alt_pressed or event.meta_pressed:
		return false
	if event.ctrl_pressed:
		_store_view_bookmark_slot(slot)
		return true
	if event.shift_pressed:
		return false
	_restore_view_bookmark_slot(slot)
	return true


func _bookmark_slot_for_key_event(event: InputEventKey) -> int:
	var key_slot: int = _bookmark_slot_for_keycode(event.keycode)
	if key_slot > 0:
		return key_slot
	return _bookmark_slot_for_keycode(event.physical_keycode)


func _bookmark_slot_for_keycode(keycode: int) -> int:
	match keycode:
		KEY_1, KEY_KP_1:
			return 1
		KEY_2, KEY_KP_2:
			return 2
		KEY_3, KEY_KP_3:
			return 3
		KEY_4, KEY_KP_4:
			return 4
		KEY_5, KEY_KP_5:
			return 5
		_:
			return -1


func _store_view_bookmark_slot(slot: int) -> void:
	if slot < 1 or slot > VIEW_BOOKMARK_SLOT_COUNT:
		return
	if _camera_controller == null or _bubble == null:
		return
	if not _camera_controller.has_method("capture_view_state"):
		return
	var focus_id: StringName = _bubble.get_focus()
	if focus_id == StringName("") or not UniverseRegistry.has_body(focus_id):
		return
	var state: Dictionary = _camera_controller.capture_view_state()
	if state.is_empty():
		return
	state["slot"] = slot
	state["world_scope_id"] = _active_world_scope_id
	_view_bookmarks[slot] = state


func _restore_view_bookmark_slot(slot: int) -> void:
	if slot < 1 or slot > VIEW_BOOKMARK_SLOT_COUNT:
		return
	if not _view_bookmarks.has(slot):
		return
	if _camera_controller == null or not _camera_controller.has_method("restore_view_state"):
		return
	var state: Dictionary = _view_bookmarks.get(slot, {})
	var focus_id: StringName = StringName(state.get("focus_id", StringName("")))
	if focus_id == StringName("") or not UniverseRegistry.has_body(focus_id):
		return
	var bookmark_world_scope_id: StringName = StringName(state.get("world_scope_id", _active_world_scope_id))
	if bookmark_world_scope_id != _active_world_scope_id:
		return
	_focus_index = maxi(_focus_order.find(focus_id), 0)
	_camera_controller.restore_view_state(state, true)
	_sync_root_inspector_context(false)
	_refresh_snapshot_interest_ids()
	_debug_overlay.mark_dirty(_debug_overlay.visible)
	if _can_sync_immediate_view_state():
		_sync_immediate_view_state(true)


func _root_focus_id() -> StringName:
	if _is_large_world and _streaming_controller.get_focus_root_id() != StringName(""):
		return _streaming_controller.get_focus_root_id()
	if _topology != null and not _focus_order.is_empty():
		return _topology.root_id_of(_focus_order[0])
	return StringName("")


func _refresh_focus_order() -> void:
	_focus_order = UniverseRegistry.get_update_order()


func _refresh_snapshot_interest_ids() -> void:
	if _derived_snapshot_cache == null or _topology == null or _bubble == null:
		return
	var focus_id: StringName = _bubble.get_focus()
	var focus_root_id: StringName = _topology.root_id_of(focus_id)
	if _is_root_inspector_interest_override_active(focus_root_id):
		_derived_snapshot_cache.set_interest_ids(_planetary_interest_ids_for_root(focus_root_id))
		return
	if _camera_controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW:
		_derived_snapshot_cache.set_interest_ids([])
		return
	_derived_snapshot_cache.set_interest_ids(_planetary_interest_ids_for_root(focus_root_id))


func _sync_galaxy_proxy_transform() -> void:
	if not _is_large_world or _galaxy_proxy_renderer == null:
		return
	if not _galaxy_proxy_renderer.visible:
		return
	_galaxy_proxy_renderer.scale = _renderer.scale
	_galaxy_proxy_renderer.position = _renderer.position


func _current_viewport_size() -> Vector2:
	return get_viewport_rect().size


func _can_sync_immediate_view_state() -> bool:
	return is_inside_tree()


func _sync_immediate_view_state(force_interest_refresh: bool) -> void:
	_camera_controller.step(0.0, _current_viewport_size())
	_sync_view_lod_state(force_interest_refresh, _debug_overlay.visible)
	if _renderer != null:
		_renderer.sync_visuals_now(true)
	_sync_asteroid_renderer(true)
	_sync_galaxy_proxy_transform()


func _on_streaming_residency_changed(_resident_root_ids: Array[StringName], focus_root_id: StringName) -> void:
	_refresh_focus_order()
	_renderer.rebuild_from_registry()
	if _asteroid_service != null:
		_asteroid_service.sync_resident_roots(_active_world_scope_id, _asteroid_root_ids_for_focus(focus_root_id), TimeService.sim_time_s)
	if not UniverseRegistry.has_body(_bubble.get_focus()) and UniverseRegistry.has_body(focus_root_id):
		_focus_index = maxi(_focus_order.find(focus_root_id), 0)
		_set_focus(focus_root_id, true, true)
	else:
		_sync_root_inspector_context(false)
	_sync_view_lod_state(true, _debug_overlay.visible)
	_debug_overlay.mark_dirty(_debug_overlay.visible)
	_sync_galaxy_proxy_transform()
	_sync_asteroid_renderer(true)


func _on_orbit_service_bodies_updated(ids: Array[StringName], _reason: StringName) -> void:
	_activation_set.mark_ids_dirty(ids)


func _on_orbit_service_step_completed(dt_s: float, t_s: float) -> void:
	if _orbit_service != null:
		PerfProbeScript.bump(&"orbit_step_core_total_us", _orbit_service.get_last_step_core_us())
	if _asteroid_service != null:
		var advance_start_us: int = Time.get_ticks_usec()
		_asteroid_service.advance_to_time(t_s, dt_s)
		var advance_elapsed_us: int = Time.get_ticks_usec() - advance_start_us
		PerfProbeScript.sample(&"asteroid_advance_us", advance_elapsed_us)
		PerfProbeScript.bump(&"asteroid_advance_total_us", advance_elapsed_us)


static func _delta_from_monotonic_total(current: int, previous: int) -> int:
	if current < previous:
		return current
	return current - previous


static func _is_large_world_id(world_id: StringName) -> bool:
	return world_id == WorldLoader.PILOT_GALAXY_ID \
		or world_id == WorldLoader.SCALEUP_GALAXY_10_ID \
		or world_id == WorldLoader.SCALEUP_GALAXY_30_ID \
		or world_id == WorldLoader.SCALEUP_GALAXY_100_ID


func _sync_view_lod_state(force_interest_refresh: bool, immediate_debug_refresh: bool) -> void:
	var frame_label: StringName = _camera_controller.get_frame_label()
	_renderer.set_frame_label(frame_label)
	if _is_large_world and _galaxy_proxy_renderer != null:
		_galaxy_proxy_renderer.visible = frame_label == OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW
	if _planet_badge_overlay != null:
		_planet_badge_overlay.set_frame_label(frame_label)
	_sync_root_inspector_display_mode(frame_label)
	_debug_overlay.set_view_context(_is_large_world, frame_label)
	var frame_changed: bool = frame_label != _last_frame_label
	if force_interest_refresh or frame_changed:
		_refresh_snapshot_interest_ids()
	if frame_changed:
		_debug_overlay.mark_dirty(immediate_debug_refresh)
	_last_frame_label = frame_label


func _configure_asteroid_renderer() -> void:
	if _renderer == null:
		return
	if _asteroid_renderer == null:
		_asteroid_renderer = AsteroidFieldRendererScript.new()
		_asteroid_renderer.name = "AsteroidFieldRenderer"
		_renderer.add_child(_asteroid_renderer)
	_asteroid_renderer.configure(_asteroid_snapshot_cache)


func _sync_asteroid_renderer(force: bool = false) -> void:
	if _asteroid_renderer == null:
		return
	if _asteroid_snapshot_cache != null and _asteroid_snapshot_cache.has_method("refresh"):
		var snapshot_start_us: int = Time.get_ticks_usec()
		_asteroid_snapshot_cache.refresh(&"manual")
		PerfProbeScript.sample(&"asteroid_snapshot_refresh_us", Time.get_ticks_usec() - snapshot_start_us)
	var renderer_start_us: int = Time.get_ticks_usec()
	_asteroid_renderer.sync_visuals_now(force, false)
	PerfProbeScript.sample(&"asteroid_renderer_sync_us", Time.get_ticks_usec() - renderer_start_us)


func _clear_asteroid_renderer_state() -> void:
	if _asteroid_renderer != null and _asteroid_renderer.has_method("clear_state"):
		_asteroid_renderer.clear_state()


func _focuses_share_root(a: StringName, b: StringName) -> bool:
	if a == StringName("") or b == StringName("") or _topology == null:
		return false
	if not UniverseRegistry.has_body(a) or not UniverseRegistry.has_body(b):
		return false
	var root_a: StringName = _topology.root_id_of(a)
	var root_b: StringName = _topology.root_id_of(b)
	return root_a != StringName("") and root_a == root_b


func _reset_asteroids_for_current_roots(t_s: float) -> void:
	if _asteroid_service == null:
		return
	_asteroid_service.reset_for_world(_active_world_scope_id, _current_asteroid_root_ids(), t_s)


func _current_asteroid_root_ids() -> Array[StringName]:
	if _is_large_world and _streaming_controller != null and _streaming_controller.has_method("get_focus_root_id"):
		return _asteroid_root_ids_for_focus(_streaming_controller.get_focus_root_id())
	var root_ids: Array[StringName] = []
	for id in UniverseRegistry.get_update_order_ref():
		var def: BodyDef = UniverseRegistry.get_def(id)
		if def != null and def.is_root():
			root_ids.append(id)
	return root_ids


func _asteroid_root_ids_for_focus(focus_root_id: StringName) -> Array[StringName]:
	if focus_root_id == StringName("") or not UniverseRegistry.has_body(focus_root_id):
		return []
	return [focus_root_id]


func _configure_root_inspector() -> void:
	if _root_inspector == null:
		return
	_root_inspector.clear_state()
	_root_inspector.visible = false
	if not _is_large_world:
		return
	_root_inspector.configure(UniverseRegistry, _topology, _derived_snapshot_cache)
	if not _root_inspector.focus_requested.is_connected(_on_root_inspector_focus_requested):
		_root_inspector.focus_requested.connect(_on_root_inspector_focus_requested)
	if _root_inspector.has_signal("life_details_requested") and not _root_inspector.life_details_requested.is_connected(_on_life_details_requested):
		_root_inspector.life_details_requested.connect(_on_life_details_requested)
	if not _root_inspector.closed.is_connected(_on_root_inspector_closed):
		_root_inspector.closed.connect(_on_root_inspector_closed)


func _configure_life_detail_panel() -> void:
	if _life_detail_panel == null:
		return
	_life_detail_panel.configure(UniverseRegistry, _derived_snapshot_cache)
	_life_detail_panel.close_panel()


func _sync_root_inspector_context(auto_open: bool = false) -> void:
	if not _is_large_world or _root_inspector == null:
		return
	_sync_root_inspector_display_mode(_camera_controller.get_frame_label())
	var focus_id: StringName = _bubble.get_focus()
	var focus_root_id: StringName = _topology.root_id_of(focus_id)
	_root_inspector.set_root_context(focus_root_id, focus_id, auto_open)


func _open_root_inspector_for_current_root() -> void:
	if not _is_large_world or _root_inspector == null:
		return
	_sync_root_inspector_context(true)
	_refresh_snapshot_interest_ids()
	_debug_overlay.mark_dirty(_debug_overlay.visible)


func _toggle_root_inspector_for_current_root() -> void:
	if not _is_large_world or _root_inspector == null:
		return
	if _root_inspector.is_open():
		_root_inspector.close_panel(false)
		_refresh_snapshot_interest_ids()
		_debug_overlay.mark_dirty(_debug_overlay.visible)
		return
	_open_root_inspector_for_current_root()


func _sync_root_inspector_display_mode(frame_label: StringName) -> void:
	if _root_inspector == null:
		return
	var compact_root_overview: bool = _should_compact_root_inspector(frame_label)
	var compact_focus_branch: bool = _should_compact_root_inspector_focus_branch(compact_root_overview)
	if _root_inspector.has_method("set_compact_display_modes"):
		_root_inspector.set_compact_display_modes(compact_root_overview, compact_focus_branch)
		return
	if _root_inspector.has_method("set_compact_root_overview"):
		_root_inspector.set_compact_root_overview(compact_root_overview)
	if _root_inspector.has_method("set_compact_focus_branch"):
		_root_inspector.set_compact_focus_branch(compact_focus_branch)


func _should_compact_root_inspector(frame_label: StringName) -> bool:
	if not _is_large_world:
		return false
	if frame_label == OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW:
		return true
	if _bubble == null or _topology == null:
		return false
	var focus_id: StringName = _bubble.get_focus()
	if focus_id == StringName(""):
		return false
	return _topology.root_id_of(focus_id) == focus_id


func _should_compact_root_inspector_focus_branch(compact_root_overview: bool) -> bool:
	if not _is_large_world or compact_root_overview:
		return false
	if _bubble == null or _topology == null:
		return false
	var focus_id: StringName = _bubble.get_focus()
	if focus_id == StringName(""):
		return false
	var focus_root_id: StringName = _topology.root_id_of(focus_id)
	return focus_root_id != StringName("") and focus_root_id != focus_id


func _planetary_interest_ids_for_root(root_id: StringName) -> Array[StringName]:
	var interest_ids: Array[StringName] = []
	if root_id == StringName(""):
		return interest_ids
	for id in UniverseRegistry.get_update_order_ref():
		var def: BodyDef = UniverseRegistry.get_def(id)
		if def == null:
			continue
		if _topology.root_id_of(id) != root_id:
			continue
		if def.kind == BodyType.Kind.PLANET or def.kind == BodyType.Kind.MOON:
			interest_ids.append(id)
	return interest_ids


func _is_root_inspector_interest_override_active(focus_root_id: StringName) -> bool:
	if not _is_large_world or _root_inspector == null or not _root_inspector.is_open():
		return false
	return _camera_controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW \
		and _root_inspector.get_root_id() == focus_root_id


func _on_root_inspector_focus_requested(body_id: StringName) -> void:
	_focus_index = maxi(_focus_order.find(body_id), 0)
	_set_focus(body_id, true, true)


func _on_life_details_requested(body_id: StringName) -> void:
	if _life_detail_panel == null:
		return
	_life_detail_panel.open_for_body(body_id)


func _on_root_inspector_closed() -> void:
	_refresh_snapshot_interest_ids()
	_debug_overlay.mark_dirty(_debug_overlay.visible)


func _on_world_loader_world_loaded(world_id: StringName) -> void:
	if world_id == StringName("") or world_id == _active_world_scope_id:
		return
	_active_world_scope_id = world_id
	_view_bookmarks.clear()
	if _proto_biosphere_service != null and _proto_biosphere_service.is_configured():
		if _is_large_world and _current_galaxy != null and world_id == _current_galaxy.galaxy_id:
			_proto_biosphere_service.initialize_for_galaxy(_current_galaxy)
		else:
			_proto_biosphere_service.initialize_for_named_world(world_id)
	if _root_inspector != null:
		_root_inspector.clear_state()
	if _life_detail_panel != null:
		_life_detail_panel.close_panel()
	_reset_asteroids_for_current_roots(TimeService.sim_time_s)
	if _asteroid_snapshot_cache != null:
		_asteroid_snapshot_cache.clear()
	_sync_asteroid_renderer(true)
	_refresh_snapshot_interest_ids()
	_debug_overlay.mark_dirty(_debug_overlay.visible)


func _on_summary_button_pressed() -> void:
	_set_hud_details_enabled(false)


func _on_details_button_pressed() -> void:
	_set_hud_details_enabled(true)


func _set_hud_details_enabled(value: bool) -> void:
	if _hud_details_enabled == value:
		return
	_hud_details_enabled = value
	_sync_hud_mode_buttons()
	_update_hud()


func _sync_hud_mode_buttons() -> void:
	if _summary_button == null or _details_button == null:
		return
	_summary_button.disabled = not _hud_details_enabled
	_details_button.disabled = _hud_details_enabled
