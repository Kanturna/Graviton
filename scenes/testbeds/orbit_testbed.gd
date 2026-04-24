extends Node2D

const OrbitCameraControllerScript = preload("res://src/tools/rendering/orbit_camera_controller.gd")
const OrbitCameraFramingScript = preload("res://src/tools/rendering/orbit_camera_framing.gd")
const OrbitHudFormatterScript = preload("res://src/tools/rendering/orbit_hud_formatter.gd")
const OrbitTimeScaleControllerScript = preload("res://src/tools/rendering/orbit_time_scale_controller.gd")
const PlanetBadgeOverlayScript = preload("res://src/tools/rendering/planet_badge_overlay.gd")
const UniverseTopologyScript = preload("res://src/sim/topology/universe_topology.gd")
const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")
const GalaxyStreamingControllerScript = preload("res://src/runtime/streaming/galaxy_streaming_controller.gd")
const PlanetaryYearSamplerScript = preload("res://src/sim/planetary/planetary_year_sampler.gd")
const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const ProtoBiosphereSimulationServiceScript = preload("res://src/sim/life/proto_biosphere_simulation_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const NativeSpeciesServiceScript = preload("res://src/sim/life/native_species_service.gd")
const GeneticSpeciesServiceScript = preload("res://src/sim/life/genetic_species_service.gd")
const OrbitReadoutServiceScript = preload("res://src/sim/orbit/orbit_readout_service.gd")

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
var _streaming_controller = GalaxyStreamingControllerScript.new()
var _planetary_year_sampler = PlanetaryYearSamplerScript.new()
var _planetary_state_service = PlanetaryStateServiceScript.new()
var _life_potential_service = LifePotentialServiceScript.new()
var _proto_biosphere_service = ProtoBiosphereSimulationServiceScript.new()
var _biosphere_scale_service = BiosphereScaleServiceScript.new()
var _native_species_service = NativeSpeciesServiceScript.new()
var _genetic_species_service = GeneticSpeciesServiceScript.new()
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


func _ready() -> void:
	TimeService.reset()
	TimeService.set_paused(false)
	UniverseRegistry.clear()
	_orbit_service.configure(UniverseRegistry, TimeService)

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
	_orbit_readout_service.configure(UniverseRegistry)

	_renderer.configure(UniverseRegistry, _bubble, _topology, TimeService)
	_renderer.set_environment_service(_environment_service)
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
		_genetic_species_service
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
	_update_hud()


func _exit_tree() -> void:
	_time_scale_controller.dispose()
	_derived_snapshot_cache.dispose()
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
	_camera_controller.step(delta, get_viewport_rect().size)
	if _is_large_world:
		_streaming_controller.update(delta, _camera_controller.get_zoom_factor())
	_sync_view_lod_state(false, false)
	_sync_galaxy_proxy_transform()
	if _planet_badge_overlay != null:
		_planet_badge_overlay.refresh()
	_update_hud()


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
					var picked_def: BodyDef = UniverseRegistry.get_def(picked_id)
					if picked_def != null and picked_def.is_root():
						_open_root_inspector_for_current_root()
					get_viewport().set_input_as_handled()
				elif _is_large_world:
					var picked_root_id: StringName = _galaxy_proxy_renderer.pick_root_at_screen(event.position)
					if picked_root_id != StringName(""):
						_streaming_controller.set_focus_root(picked_root_id)
						_refresh_focus_order()
						_focus_index = maxi(_focus_order.find(picked_root_id), 0)
						_set_focus(picked_root_id, true, true)
						_open_root_inspector_for_current_root()
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
	_camera_controller.set_focus(body_id, immediate, force_fit)
	_sync_root_inspector_context(false)
	_refresh_snapshot_interest_ids()
	_debug_overlay.mark_dirty(_debug_overlay.visible)
	if immediate and is_inside_tree():
		_camera_controller.step(0.0, get_viewport_rect().size)
		_sync_view_lod_state(true, _debug_overlay.visible)
		_sync_galaxy_proxy_transform()


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

	_hint_label.text = "LMB focus   Tab / Shift+Tab focus   Home root overview   Ctrl+1-5 save view   1-5 recall view   Q/E or PgUp/PgDn speed   WASD pan   Wheel zoom   Backspace fit focus   Space pause   F3 debug"


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
	if is_inside_tree():
		_camera_controller.step(0.0, get_viewport_rect().size)


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


func _on_streaming_residency_changed(_resident_root_ids: Array[StringName], focus_root_id: StringName) -> void:
	_refresh_focus_order()
	_renderer.rebuild_from_registry()
	if not UniverseRegistry.has_body(_bubble.get_focus()) and UniverseRegistry.has_body(focus_root_id):
		_focus_index = maxi(_focus_order.find(focus_root_id), 0)
		_set_focus(focus_root_id, true, true)
	else:
		_sync_root_inspector_context(false)
	_sync_view_lod_state(true, _debug_overlay.visible)
	_debug_overlay.mark_dirty(_debug_overlay.visible)
	_sync_galaxy_proxy_transform()


func _on_orbit_service_bodies_updated(ids: Array[StringName], _reason: StringName) -> void:
	_activation_set.mark_ids_dirty(ids)


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
	_debug_overlay.set_view_context(_is_large_world, frame_label)
	var frame_changed: bool = frame_label != _last_frame_label
	if force_interest_refresh or frame_changed:
		_refresh_snapshot_interest_ids()
	if frame_changed:
		_debug_overlay.mark_dirty(immediate_debug_refresh)
	_last_frame_label = frame_label


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
	var focus_id: StringName = _bubble.get_focus()
	var focus_root_id: StringName = _topology.root_id_of(focus_id)
	_root_inspector.set_root_context(focus_root_id, focus_id, auto_open)


func _open_root_inspector_for_current_root() -> void:
	if not _is_large_world or _root_inspector == null:
		return
	_sync_root_inspector_context(true)
	_refresh_snapshot_interest_ids()
	_debug_overlay.mark_dirty(_debug_overlay.visible)


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
