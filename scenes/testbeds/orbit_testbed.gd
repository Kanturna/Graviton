extends Node2D

const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")
const TIME_SCALE_PRESETS: Array[float] = [0.25, 1.0, 10.0, 50.0, 100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0]
const VIEWPORT_RADIUS_FACTOR: float = 0.38
const VIEW_SMOOTHNESS: float = 10.0
const ZOOM_FACTOR_STEP: float = 1.20
const MIN_ABSOLUTE_ZOOM_FACTOR: float = 0.05
const MAX_ABSOLUTE_ZOOM_FACTOR: float = 100.0
const GLOBAL_OVERVIEW_RADIUS_FACTOR: float = 1.75
const WORLD_OVERVIEW_SCALE_RATIO: float = 0.4
const MAX_FOCUS_CLOSEUP_BIAS: float = 10.0
const PAN_SPEED_PX_PER_S: float = 960.0

@export_enum("starter_world", "sample_system") var initial_world_id: String = "starter_world"

@onready var _world_loader = $WorldLoader
@onready var _orbit_service: OrbitService = $OrbitService
@onready var _thermal_service = $ThermalService
@onready var _atmosphere_service: Node = $AtmosphereService
@onready var _environment_service: Node = $EnvironmentService
@onready var _bubble: LocalBubbleManager = $LocalBubbleManager
@onready var _activation_set = $BubbleActivationSet
@onready var _renderer: OrbitViewRenderer = $WorldRoot
@onready var _debug_overlay: DebugOverlay = $DebugOverlay

@onready var _focus_value: Label = $HudLayer/TopPanel/Margin/VBox/FocusValue
@onready var _environment_value: Label = $HudLayer/TopPanel/Margin/VBox/EnvironmentValue
@onready var _climate_value: Label = $HudLayer/TopPanel/Margin/VBox/ClimateValue
@onready var _season_value: Label = $HudLayer/TopPanel/Margin/VBox/SeasonValue
@onready var _time_value: Label = $HudLayer/TopPanel/Margin/VBox/TimeValue
@onready var _scale_value: Label = $HudLayer/TopPanel/Margin/VBox/ScaleValue
@onready var _speed_slider: HSlider = $HudLayer/TopPanel/Margin/VBox/SpeedSlider
@onready var _mode_value: Label = $HudLayer/TopPanel/Margin/VBox/ModeValue
@onready var _hint_label: Label = $HudLayer/BottomPanel/Margin/Hints

var _focus_order: Array[StringName] = []
var _focus_index: int = 0
var _time_scale_index: int = 5
var _absolute_zoom_factor: float = 1.0

var _target_view_scale: float = 1.0
var _current_view_scale: float = 1.0
var _target_world_offset: Vector2 = Vector2.ZERO
var _current_world_offset: Vector2 = Vector2.ZERO
var _manual_pan_ru: Vector2 = Vector2.ZERO
var _world_overview_radius_ru: float = 1.0
var _current_focus_frame_radius_ru: float = 1.0


func _ready() -> void:
	TimeService.reset()
	TimeService.set_paused(false)
	UniverseRegistry.clear()
	if not _world_loader.load_named_world(StringName(initial_world_id), UniverseRegistry):
		push_error("OrbitTestbed: failed to load initial world '%s'" % initial_world_id)
		set_process(false)
		set_process_unhandled_input(false)
		return

	_focus_order = UniverseRegistry.get_update_order()
	var root_id: StringName = _root_focus_id()
	_focus_index = maxi(_focus_order.find(root_id), 0)

	_orbit_service.configure(UniverseRegistry, TimeService)
	_orbit_service.recompute_all_at_time(TimeService.sim_time_s)

	_bubble.configure(UniverseRegistry)
	_bubble.set_focus(_focus_order[_focus_index])
	_activation_set.configure(UniverseRegistry, _bubble)
	_activation_set.rebuild()
	_orbit_service.request_numeric_local_candidates(_activation_set.get_active_ids())
	_orbit_service.recompute_all_at_time(TimeService.sim_time_s)
	_thermal_service.configure(UniverseRegistry)
	_atmosphere_service.configure(UniverseRegistry, _thermal_service)
	_environment_service.configure(UniverseRegistry, _atmosphere_service)
	_renderer.configure(UniverseRegistry, _bubble)
	_renderer.set_environment_service(_environment_service)
	_debug_overlay.configure(UniverseRegistry, TimeService, _bubble, _activation_set, _thermal_service)
	_debug_overlay.visible = false
	_cache_world_overview_radius()

	_configure_speed_slider()
	if not TimeService.time_scale_changed.is_connected(_on_time_scale_changed):
		TimeService.time_scale_changed.connect(_on_time_scale_changed)
	_set_time_scale_from_preset_index(_time_scale_index)
	_set_focus(_focus_order[_focus_index], true, true)
	_apply_view_transform(true)
	_update_hud()


func _process(delta: float) -> void:
	# P5: activation_set wird jetzt read-only klassifiziert und direkt als
	# Wish-Set in OrbitService gebridged. Der per-frame-Rebuild bleibt
	# bewusst parallel zum Auto-Rebuild auf focus_changed, damit
	# Callback-Pfade im selben Frame konsistente Klassifikationen sehen.
	_activation_set.rebuild()
	_orbit_service.request_numeric_local_candidates(_activation_set.get_active_ids())
	_update_manual_pan(delta)
	_refresh_target_view()
	_apply_view_transform(false, delta)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				if event.shift_pressed:
					_cycle_focus(-1)
				else:
					_cycle_focus(1)
				get_viewport().set_input_as_handled()
			KEY_HOME:
				var root_id: StringName = _root_focus_id()
				_focus_index = maxi(_focus_order.find(root_id), 0)
				_set_focus(_focus_order[_focus_index])
				get_viewport().set_input_as_handled()
			KEY_Q, KEY_BRACKETLEFT, KEY_PAGEDOWN:
				_set_time_scale_from_preset_index(maxi(_time_scale_index - 1, 0))
				get_viewport().set_input_as_handled()
			KEY_E, KEY_BRACKETRIGHT, KEY_PAGEUP:
				_set_time_scale_from_preset_index(mini(_time_scale_index + 1, TIME_SCALE_PRESETS.size() - 1))
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				TimeService.set_paused(not TimeService.paused)
				get_viewport().set_input_as_handled()
			KEY_F3:
				_debug_overlay.visible = not _debug_overlay.visible
				get_viewport().set_input_as_handled()
			KEY_BACKSPACE:
				_manual_pan_ru = Vector2.ZERO
				_fit_current_focus_zoom()
				_refresh_target_view()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var picked_id: StringName = _renderer.pick_body_at_screen(event.position)
				if picked_id != StringName(""):
					_focus_index = maxi(_focus_order.find(picked_id), 0)
					_set_focus(picked_id)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				_absolute_zoom_factor = minf(_absolute_zoom_factor * ZOOM_FACTOR_STEP, MAX_ABSOLUTE_ZOOM_FACTOR)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_absolute_zoom_factor = maxf(_absolute_zoom_factor / ZOOM_FACTOR_STEP, MIN_ABSOLUTE_ZOOM_FACTOR)
				get_viewport().set_input_as_handled()


func _cycle_focus(direction: int) -> void:
	if _focus_order.is_empty():
		return
	_focus_index = wrapi(_focus_index + direction, 0, _focus_order.size())
	_set_focus(_focus_order[_focus_index])


func _set_focus(body_id: StringName, immediate: bool = false, force_fit: bool = false) -> void:
	if body_id == StringName(""):
		return
	_bubble.set_focus(body_id)
	_renderer.set_focus(body_id)
	_renderer.clear_trails()
	_manual_pan_ru = Vector2.ZERO
	_refresh_focus_frame_radius(body_id)
	if force_fit:
		_fit_current_focus_zoom()
	_refresh_target_view()
	if immediate:
		_apply_view_transform(true)


func _refresh_target_view() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var focus_center: Vector2 = _renderer.get_body_view_position_ru(_bubble.get_focus())
	if not _is_finite_vec2(focus_center):
		focus_center = Vector2.ZERO
	var root_fit_scale: float = _root_fit_scale(viewport_size)
	var focus_fit_scale: float = _current_focus_fit_scale(viewport_size)
	_target_view_scale = OrbitZoomModelScript.target_view_scale(
		root_fit_scale,
		focus_fit_scale,
		_absolute_zoom_factor,
		WORLD_OVERVIEW_SCALE_RATIO,
		MAX_FOCUS_CLOSEUP_BIAS
	)
	_target_world_offset = viewport_size * 0.5 - (focus_center + _manual_pan_ru) * _target_view_scale


func _apply_view_transform(immediate: bool, delta: float = 0.0) -> void:
	if immediate:
		_current_view_scale = _target_view_scale
		_current_world_offset = _target_world_offset
	else:
		var weight: float = 1.0 - exp(-VIEW_SMOOTHNESS * delta)
		_current_view_scale = lerpf(_current_view_scale, _target_view_scale, weight)
		_current_world_offset = _current_world_offset.lerp(_target_world_offset, weight)

	_renderer.scale = Vector2.ONE * _current_view_scale
	_renderer.position = _current_world_offset
	_renderer.set_world_scale(_current_view_scale)
	_renderer.set_focus_closeup_ratio(_current_focus_closeup_ratio(get_viewport_rect().size))


func _update_hud() -> void:
	var focus_id: StringName = _bubble.get_focus()
	var focus_def: BodyDef = UniverseRegistry.get_def(focus_id)
	var focus_name: String = String(focus_id)
	if focus_def != null and focus_def.display_name != "":
		focus_name = focus_def.display_name

	var sim_days: float = TimeService.sim_time_s / UnitSystem.DAY_S
	var fps: int = Engine.get_frames_per_second()
	var speed_step_label: String = _time_scale_step_label(TimeService.time_scale)
	_focus_value.text = "Focus: %s" % focus_name
	_environment_value.text = _environment_hud_text(focus_id)
	_climate_value.text = _climate_hud_text(focus_id)
	_season_value.text = _season_hud_text(focus_id)
	_time_value.text = "T+ %.2f d   steps %d   FPS %d" % [sim_days, TimeService.tick_count, fps]
	_scale_value.text = "Speed x%s   Preset %s   Zoom %.0f%% %s" % [
		_stripped_float(TimeService.time_scale),
		speed_step_label,
		_absolute_zoom_factor * 100.0,
		OrbitZoomModelScript.zoom_mode_label(_absolute_zoom_factor)
	]
	_mode_value.text = "Bodies %d   %s" % [
		UniverseRegistry.body_count(),
		"Paused" if TimeService.paused else "Running"
	]
	_hint_label.text = "LMB focus   Tab / Shift+Tab focus   Q/E or PgUp/PgDn speed   HUD slider speed   WASD pan   Wheel zoom (5%-10000%)   Backspace fit focus   Space pause   F3 debug"


func _environment_hud_text(focus_id: StringName) -> String:
	if _environment_service == null:
		return "Environment: n/a"
	var desc: Dictionary = _environment_service.describe_body(focus_id)
	if not bool(desc.get("is_supported_body_kind", false)):
		return "Environment: n/a"
	# Spielertexte fuer Umwelt-/Welttyp-Labels duerfen nur ueber die
	# zentralen String-Mapper des EnvironmentService laufen.
	return "Environment: %s   Climate: %s" % [
		EnvironmentServiceScript.to_string_class(
			int(desc.get("environment_class", EnvironmentServiceScript.Class.HOSTILE))
		),
		EnvironmentServiceScript.to_string_ecosystem(
			int(desc.get("ecosystem_type", EnvironmentServiceScript.EcosystemType.FROZEN_WORLD))
		),
	]


func _climate_hud_text(focus_id: StringName) -> String:
	if _environment_service == null:
		return "Bands: n/a"
	var desc: Dictionary = _environment_service.describe_body(focus_id)
	if not bool(desc.get("is_supported_body_kind", false)):
		return "Bands: n/a"
	if not bool(desc.get("has_latitudinal_surface_basis", false)):
		return "Bands: n/a"
	return "Bands: -60deg %.0f K   Eq %.0f K   +60deg %.0f K" % [
		float(desc.get("south_midlatitude_surface_temperature_k", 0.0)),
		float(desc.get("equator_surface_temperature_k", 0.0)),
		float(desc.get("north_midlatitude_surface_temperature_k", 0.0)),
	]


func _season_hud_text(focus_id: StringName) -> String:
	if _thermal_service == null:
		return "Season: n/a"
	var desc: Dictionary = _thermal_service.describe_body(focus_id)
	if not bool(desc.get("has_seasonal_basis", false)):
		return "Season: n/a"
	var subsolar_latitude_rad: float = float(desc.get("subsolar_latitude_rad", 0.0))
	return "Season: subsolar %+.0f deg" % rad_to_deg(subsolar_latitude_rad)


func _update_manual_pan(delta: float) -> void:
	var pan_input: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan_input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan_input.y += 1.0

	if pan_input == Vector2.ZERO:
		return

	_manual_pan_ru += pan_input.normalized() * ((PAN_SPEED_PX_PER_S * delta) / maxf(_current_view_scale, 0.001))


func _fit_scale_for_radius(focus_radius: float, viewport_size: Vector2) -> float:
	var safe_radius: float = maxf(focus_radius, 1.0)
	var target_screen_radius: float = minf(viewport_size.x, viewport_size.y) * VIEWPORT_RADIUS_FACTOR
	return target_screen_radius / safe_radius


func _root_fit_scale(viewport_size: Vector2) -> float:
	return maxf(_fit_scale_for_radius(_world_overview_radius_ru, viewport_size), 0.0001)


func _cache_world_overview_radius() -> void:
	var root_id: StringName = _root_focus_id()
	if root_id == StringName(""):
		_world_overview_radius_ru = 1.0
		return
	var frame: Dictionary = _renderer.get_focus_frame(root_id)
	_world_overview_radius_ru = maxf(
		float(frame.get("radius", 1.0)) * GLOBAL_OVERVIEW_RADIUS_FACTOR,
		1.0
	)


func _refresh_focus_frame_radius(body_id: StringName) -> void:
	var frame: Dictionary = _renderer.get_focus_frame(body_id)
	_current_focus_frame_radius_ru = maxf(float(frame.get("radius", 1.0)), 1.0)


func _fit_current_focus_zoom() -> void:
	_refresh_focus_frame_radius(_bubble.get_focus())
	_absolute_zoom_factor = OrbitZoomModelScript.FIT_ZOOM_FACTOR


func _current_focus_fit_scale(viewport_size: Vector2) -> float:
	return _fit_scale_for_radius(_current_focus_frame_radius_ru, viewport_size)


func _current_focus_closeup_ratio(viewport_size: Vector2) -> float:
	return OrbitZoomModelScript.focus_closeup_ratio(
		_current_view_scale,
		_current_focus_fit_scale(viewport_size)
	)


func _root_focus_id() -> StringName:
	for id in UniverseRegistry.get_update_order():
		var def: BodyDef = UniverseRegistry.get_def(id)
		if def != null and def.is_root():
			return id
	return StringName("")


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _configure_speed_slider() -> void:
	if _speed_slider == null:
		return
	_speed_slider.min_value = 0.0
	_speed_slider.max_value = 1.0
	_speed_slider.step = 0.001
	if not _speed_slider.value_changed.is_connected(_on_speed_slider_changed):
		_speed_slider.value_changed.connect(_on_speed_slider_changed)
	_speed_slider.set_value_no_signal(_time_scale_to_slider_value(TIME_SCALE_PRESETS[_time_scale_index]))


func _on_speed_slider_changed(value: float) -> void:
	TimeService.set_time_scale(_slider_value_to_time_scale(value))


func _on_time_scale_changed(new_scale: float) -> void:
	_time_scale_index = _nearest_time_scale_preset_index(new_scale)
	if _speed_slider != null:
		_speed_slider.set_value_no_signal(_time_scale_to_slider_value(new_scale))


func _set_time_scale_from_preset_index(index: int) -> void:
	_time_scale_index = clampi(index, 0, TIME_SCALE_PRESETS.size() - 1)
	TimeService.set_time_scale(TIME_SCALE_PRESETS[_time_scale_index])


func _time_scale_to_slider_value(scale: float) -> float:
	var min_scale: float = _minimum_time_scale()
	var max_scale: float = _maximum_time_scale()
	var clamped: float = clampf(scale, min_scale, max_scale)
	var log_span: float = maxf(log(max_scale) - log(min_scale), 0.0001)
	return clampf((log(clamped) - log(min_scale)) / log_span, 0.0, 1.0)


func _slider_value_to_time_scale(value: float) -> float:
	var min_scale: float = _minimum_time_scale()
	var max_scale: float = _maximum_time_scale()
	var t: float = clampf(value, 0.0, 1.0)
	return exp(lerpf(log(min_scale), log(max_scale), t))


func _nearest_time_scale_preset_index(value: float) -> int:
	var best_index: int = 0
	var best_score: float = INF
	var safe_value: float = maxf(value, _minimum_time_scale())
	for i in range(TIME_SCALE_PRESETS.size()):
		var preset: float = TIME_SCALE_PRESETS[i]
		var score: float = absf(log(maxf(preset, 0.0001)) - log(safe_value))
		if score < best_score:
			best_score = score
			best_index = i
	return best_index


func _time_scale_step_label(value: float) -> String:
	var preset_index: int = _nearest_time_scale_preset_index(value)
	var preset_value: float = TIME_SCALE_PRESETS[preset_index]
	if is_equal_approx(value, preset_value):
		return "%d/%d" % [preset_index + 1, TIME_SCALE_PRESETS.size()]
	return "Custom"


static func _minimum_time_scale() -> float:
	return maxf(TIME_SCALE_PRESETS.front(), 0.001)


static func _maximum_time_scale() -> float:
	return maxf(TIME_SCALE_PRESETS.back(), _minimum_time_scale())


static func _stripped_float(value: float) -> String:
	var rounded: float = roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	return "%.2f" % value
