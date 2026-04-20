extends Node2D

const OrbitCameraControllerScript = preload("res://src/tools/rendering/orbit_camera_controller.gd")
const OrbitHudFormatterScript = preload("res://src/tools/rendering/orbit_hud_formatter.gd")
const OrbitTimeScaleControllerScript = preload("res://src/tools/rendering/orbit_time_scale_controller.gd")
const UniverseTopologyScript = preload("res://src/sim/topology/universe_topology.gd")
const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")
const GalaxyStreamingControllerScript = preload("res://src/runtime/streaming/galaxy_streaming_controller.gd")

const ZOOM_FACTOR_STEP: float = 1.12

@export_enum("starter_world", "sample_system", "generated_system", "pilot_galaxy", "scaleup_galaxy_10", "scaleup_galaxy_30") var initial_world_id: String = "starter_world"

@onready var _world_loader = $WorldLoader
@onready var _orbit_service: OrbitService = $OrbitService
@onready var _thermal_service = $ThermalService
@onready var _atmosphere_service: Node = $AtmosphereService
@onready var _environment_service: Node = $EnvironmentService
@onready var _bubble: LocalBubbleManager = $LocalBubbleManager
@onready var _activation_set = $BubbleActivationSet
@onready var _renderer: OrbitViewRenderer = $WorldRoot
@onready var _galaxy_proxy_renderer = $GalaxyProxyRoot
@onready var _debug_overlay: DebugOverlay = $DebugOverlay
@onready var _backdrop: Control = $BackdropLayer/Backdrop

@onready var _focus_value: Label = $HudLayer/TopPanel/Margin/VBox/FocusValue
@onready var _environment_value: Label = $HudLayer/TopPanel/Margin/VBox/EnvironmentValue
@onready var _climate_value: Label = $HudLayer/TopPanel/Margin/VBox/ClimateValue
@onready var _season_value: Label = $HudLayer/TopPanel/Margin/VBox/SeasonValue
@onready var _time_value: Label = $HudLayer/TopPanel/Margin/VBox/TimeValue
@onready var _scale_value: Label = $HudLayer/TopPanel/Margin/VBox/ScaleValue
@onready var _speed_slider: HSlider = $HudLayer/TopPanel/Margin/VBox/SpeedSlider
@onready var _mode_value: Label = $HudLayer/TopPanel/Margin/VBox/ModeValue
@onready var _hint_label: Label = $HudLayer/BottomPanel/Margin/Hints

var _camera_controller = OrbitCameraControllerScript.new()
var _time_scale_controller = OrbitTimeScaleControllerScript.new()
var _derived_snapshot_cache = DerivedSnapshotCacheScript.new()
var _streaming_controller = GalaxyStreamingControllerScript.new()
var _focus_order: Array[StringName] = []
var _topology = null
var _focus_index: int = 0
var _current_galaxy = null
var _is_large_world: bool = false


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
		if not _streaming_controller.residency_changed.is_connected(_on_streaming_residency_changed):
			_streaming_controller.residency_changed.connect(_on_streaming_residency_changed)
	else:
		if not _world_loader.load_named_world(StringName(initial_world_id), UniverseRegistry):
			push_error("OrbitTestbed: failed to load initial world '%s'" % initial_world_id)
			set_process(false)
			set_process_unhandled_input(false)
			return
		_orbit_service.recompute_all_at_time(TimeService.sim_time_s)

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
	_activation_set.mark_ids_dirty(UniverseRegistry.get_update_order())
	_activation_set.rebuild()
	if not _orbit_service.bodies_updated.is_connected(_on_orbit_service_bodies_updated):
		_orbit_service.bodies_updated.connect(_on_orbit_service_bodies_updated)
	_orbit_service.request_numeric_local_candidates(_activation_set.get_active_ids())
	_orbit_service.recompute_all_at_time(TimeService.sim_time_s)

	_thermal_service.configure(UniverseRegistry)
	_atmosphere_service.configure(UniverseRegistry, _thermal_service)
	_environment_service.configure(UniverseRegistry, _atmosphere_service)

	_renderer.configure(UniverseRegistry, _bubble, _topology)
	_renderer.set_environment_service(_environment_service)
	_derived_snapshot_cache.configure(
		UniverseRegistry,
		TimeService,
		_bubble,
		_world_loader,
		_thermal_service,
		_environment_service,
		_orbit_service
	)
	_refresh_snapshot_interest_ids()
	_renderer.set_derived_snapshot_cache(_derived_snapshot_cache)
	_camera_controller.configure(_renderer, _bubble, UniverseRegistry, _topology)

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
	_sync_galaxy_proxy_transform()
	_update_hud()


func _exit_tree() -> void:
	_time_scale_controller.dispose()
	_derived_snapshot_cache.dispose()


func _process(delta: float) -> void:
	_activation_set.rebuild()
	_orbit_service.request_numeric_local_candidates(_activation_set.get_active_ids())
	_camera_controller.handle_pan_input(_pan_input_dir(), delta)
	_camera_controller.step(delta, get_viewport_rect().size)
	if _is_large_world:
		_streaming_controller.update(delta, _camera_controller.get_zoom_factor())
	_sync_galaxy_proxy_transform()
	_refresh_snapshot_interest_ids()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
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
	_camera_controller.set_focus(body_id, false, force_fit)
	_refresh_snapshot_interest_ids()
	if immediate:
		_camera_controller.step(0.0, get_viewport_rect().size)
		_sync_galaxy_proxy_transform()


func _update_hud() -> void:
	var focus_id: StringName = _bubble.get_focus()
	var focus_def: BodyDef = UniverseRegistry.get_def(focus_id)
	var focus_name: String = String(focus_id)
	if focus_def != null and focus_def.display_name != "":
		focus_name = focus_def.display_name

	var environment_desc: Dictionary = _derived_snapshot_cache.get_focus_environment_desc()
	var thermal_desc: Dictionary = _derived_snapshot_cache.get_focus_thermal_desc()

	var fps: int = Engine.get_frames_per_second()
	var speed_step_label: String = _time_scale_controller.get_step_label()
	_focus_value.text = OrbitHudFormatterScript.format_focus(focus_name)
	_environment_value.text = OrbitHudFormatterScript.format_environment(environment_desc)
	_climate_value.text = OrbitHudFormatterScript.format_bands(environment_desc)
	_season_value.text = "%s   %s" % [
		OrbitHudFormatterScript.format_season(thermal_desc),
		OrbitHudFormatterScript.format_primary_source(thermal_desc)
	]
	_time_value.text = OrbitHudFormatterScript.format_time(TimeService.sim_time_s, TimeService.tick_count, fps)
	_scale_value.text = OrbitHudFormatterScript.format_scale(
		TimeService.time_scale,
		speed_step_label,
		_camera_controller.get_zoom_factor(),
		String(_camera_controller.get_zoom_mode()),
		String(_camera_controller.get_frame_label())
	)
	_mode_value.text = OrbitHudFormatterScript.format_mode(UniverseRegistry.body_count(), TimeService.paused)
	_hint_label.text = "LMB focus   Tab / Shift+Tab focus   Home root overview   Q/E or PgUp/PgDn speed   HUD slider speed   WASD pan   Wheel zoom (0.5%-10000%)   Backspace fit focus   Space pause   F3 debug"


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
	var interest_ids: Array[StringName] = []
	for id in UniverseRegistry.get_update_order():
		var def: BodyDef = UniverseRegistry.get_def(id)
		if def == null:
			continue
		if _topology.root_id_of(id) != focus_root_id:
			continue
		if def.kind == BodyType.Kind.PLANET or def.kind == BodyType.Kind.MOON:
			interest_ids.append(id)
	_derived_snapshot_cache.set_interest_ids(interest_ids)


func _sync_galaxy_proxy_transform() -> void:
	if not _is_large_world or _galaxy_proxy_renderer == null:
		return
	_galaxy_proxy_renderer.scale = _renderer.scale
	_galaxy_proxy_renderer.position = _renderer.position


func _on_streaming_residency_changed(_resident_root_ids: Array[StringName], focus_root_id: StringName) -> void:
	_refresh_focus_order()
	_renderer.rebuild_from_registry()
	if not UniverseRegistry.has_body(_bubble.get_focus()) and UniverseRegistry.has_body(focus_root_id):
		_focus_index = maxi(_focus_order.find(focus_root_id), 0)
		_set_focus(focus_root_id, true, true)
	_refresh_snapshot_interest_ids()
	_sync_galaxy_proxy_transform()


func _on_orbit_service_bodies_updated(ids: Array[StringName], _reason: StringName) -> void:
	_activation_set.mark_ids_dirty(ids)


static func _is_large_world_id(world_id: StringName) -> bool:
	return world_id == WorldLoader.PILOT_GALAXY_ID \
		or world_id == WorldLoader.SCALEUP_GALAXY_10_ID \
		or world_id == WorldLoader.SCALEUP_GALAXY_30_ID
