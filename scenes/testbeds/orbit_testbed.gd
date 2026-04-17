extends Node2D

const TIME_SCALE_PRESETS: Array[float] = [0.25, 1.0, 10.0, 50.0, 100.0, 250.0, 500.0, 1000.0]
const VIEWPORT_RADIUS_FACTOR: float = 0.38
const VIEW_SMOOTHNESS: float = 10.0
const ZOOM_BIAS_STEP: float = 1.12
const MIN_ZOOM_BIAS: float = 0.55
const MAX_ZOOM_BIAS: float = 2.4

@onready var _orbit_service: OrbitService = $OrbitService
@onready var _bubble: LocalBubbleManager = $LocalBubbleManager
@onready var _renderer: Node2D = $WorldRoot
@onready var _debug_overlay: DebugOverlay = $DebugOverlay

@onready var _focus_value: Label = $HudLayer/TopPanel/Margin/VBox/FocusValue
@onready var _time_value: Label = $HudLayer/TopPanel/Margin/VBox/TimeValue
@onready var _scale_value: Label = $HudLayer/TopPanel/Margin/VBox/ScaleValue
@onready var _mode_value: Label = $HudLayer/TopPanel/Margin/VBox/ModeValue
@onready var _hint_label: Label = $HudLayer/BottomPanel/Margin/Hints

var _focus_order: Array[StringName] = []
var _focus_index: int = 0
var _time_scale_index: int = 5
var _zoom_bias: float = 1.0

var _target_view_scale: float = 1.0
var _current_view_scale: float = 1.0
var _target_world_offset: Vector2 = Vector2.ZERO
var _current_world_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	TimeService.reset()
	TimeService.set_paused(false)
	UniverseRegistry.clear()
	UniverseRegistry.load_from_starter_world()

	_focus_order = UniverseRegistry.get_update_order()
	_focus_index = maxi(_focus_order.find(&"obsidian"), 0)

	_orbit_service.configure(UniverseRegistry, TimeService)
	_orbit_service.recompute_all_at_time(TimeService.sim_time_s)

	_bubble.configure(UniverseRegistry)
	_renderer.configure(UniverseRegistry, _bubble)
	_debug_overlay.configure(UniverseRegistry, TimeService, _bubble)
	_debug_overlay.visible = false

	TimeService.set_time_scale(TIME_SCALE_PRESETS[_time_scale_index])
	_set_focus(_focus_order[_focus_index], true)
	_apply_view_transform(true)
	_update_hud()


func _process(delta: float) -> void:
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
				_focus_index = 0
				_set_focus(_focus_order[_focus_index])
				get_viewport().set_input_as_handled()
			KEY_BRACKETLEFT:
				_time_scale_index = maxi(_time_scale_index - 1, 0)
				TimeService.set_time_scale(TIME_SCALE_PRESETS[_time_scale_index])
				get_viewport().set_input_as_handled()
			KEY_BRACKETRIGHT:
				_time_scale_index = mini(_time_scale_index + 1, TIME_SCALE_PRESETS.size() - 1)
				TimeService.set_time_scale(TIME_SCALE_PRESETS[_time_scale_index])
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				TimeService.set_paused(not TimeService.paused)
				get_viewport().set_input_as_handled()
			KEY_F3:
				_debug_overlay.visible = not _debug_overlay.visible
				get_viewport().set_input_as_handled()
			KEY_BACKSPACE:
				_zoom_bias = 1.0
				get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_bias = minf(_zoom_bias * ZOOM_BIAS_STEP, MAX_ZOOM_BIAS)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_bias = maxf(_zoom_bias / ZOOM_BIAS_STEP, MIN_ZOOM_BIAS)
				get_viewport().set_input_as_handled()


func _cycle_focus(direction: int) -> void:
	if _focus_order.is_empty():
		return
	_focus_index = wrapi(_focus_index + direction, 0, _focus_order.size())
	_set_focus(_focus_order[_focus_index])


func _set_focus(body_id: StringName, immediate: bool = false) -> void:
	if body_id == StringName(""):
		return
	_bubble.set_focus(body_id)
	_renderer.set_focus(body_id)
	_refresh_target_view()
	if immediate:
		_apply_view_transform(true)


func _refresh_target_view() -> void:
	var frame: Dictionary = _renderer.get_focus_frame(_bubble.get_focus())
	var viewport_size: Vector2 = get_viewport_rect().size
	var focus_center: Vector2 = frame.get("center", Vector2.ZERO)
	var focus_radius: float = maxf(float(frame.get("radius", 1.0)), 1.0)
	var target_screen_radius: float = minf(viewport_size.x, viewport_size.y) * VIEWPORT_RADIUS_FACTOR

	_target_view_scale = clampf(
		(target_screen_radius / focus_radius) * _zoom_bias,
		0.22,
		16.0
	)
	_target_world_offset = viewport_size * 0.5 - focus_center * _target_view_scale


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


func _update_hud() -> void:
	var focus_id: StringName = _bubble.get_focus()
	var focus_def: BodyDef = UniverseRegistry.get_def(focus_id)
	var focus_name: String = String(focus_id)
	if focus_def != null and focus_def.display_name != "":
		focus_name = focus_def.display_name

	var sim_days: float = TimeService.sim_time_s / UnitSystem.DAY_S
	_focus_value.text = "Focus: %s" % focus_name
	_time_value.text = "T+ %.2f d   ticks %d" % [sim_days, TimeService.tick_count]
	_scale_value.text = "Speed x%s   Zoom %.0f%%" % [
		_stripped_float(TimeService.time_scale),
		_zoom_bias * 100.0
	]
	_mode_value.text = "Bodies %d   %s" % [
		UniverseRegistry.body_count(),
		"Paused" if TimeService.paused else "Running"
	]
	_hint_label.text = "Tab / Shift+Tab focus   [ ] speed   Wheel zoom   Backspace reset zoom   Space pause   F3 debug"


static func _stripped_float(value: float) -> String:
	var rounded: float = roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	return "%.2f" % value
