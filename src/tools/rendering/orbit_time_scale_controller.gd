class_name OrbitTimeScaleController
extends RefCounted


const DEFAULT_PRESET_INDEX: int = 6
const TIME_SCALE_PRESETS: Array[float] = [0.25, 1.0, 10.0, 50.0, 100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0]

var _slider: HSlider = null
var _time_scale_index: int = DEFAULT_PRESET_INDEX


func configure(slider: HSlider, initial_index: int = DEFAULT_PRESET_INDEX) -> void:
	dispose()
	_slider = slider
	_configure_slider()
	if not TimeService.time_scale_changed.is_connected(_on_time_scale_changed):
		TimeService.time_scale_changed.connect(_on_time_scale_changed)
	set_preset_index(initial_index)


func dispose() -> void:
	if _slider != null and _slider.value_changed.is_connected(_on_slider_value_changed):
		_slider.value_changed.disconnect(_on_slider_value_changed)
	_slider = null
	if TimeService.time_scale_changed.is_connected(_on_time_scale_changed):
		TimeService.time_scale_changed.disconnect(_on_time_scale_changed)


func apply_previous_preset() -> void:
	set_preset_index(maxi(_time_scale_index - 1, 0))


func apply_next_preset() -> void:
	set_preset_index(mini(_time_scale_index + 1, TIME_SCALE_PRESETS.size() - 1))


func set_preset_index(index: int) -> void:
	_time_scale_index = clampi(index, 0, TIME_SCALE_PRESETS.size() - 1)
	TimeService.set_time_scale(TIME_SCALE_PRESETS[_time_scale_index])
	_sync_slider(TimeService.time_scale)


func get_step_label() -> String:
	return step_label(TimeService.time_scale)


static func time_scale_to_slider_value(scale: float) -> float:
	var min_scale: float = _minimum_time_scale()
	var max_scale: float = _maximum_time_scale()
	var clamped: float = clampf(scale, min_scale, max_scale)
	var log_span: float = maxf(log(max_scale) - log(min_scale), 0.0001)
	return clampf((log(clamped) - log(min_scale)) / log_span, 0.0, 1.0)


static func slider_value_to_time_scale(value: float) -> float:
	var min_scale: float = _minimum_time_scale()
	var max_scale: float = _maximum_time_scale()
	var t: float = clampf(value, 0.0, 1.0)
	return exp(lerpf(log(min_scale), log(max_scale), t))


static func nearest_preset_index(value: float) -> int:
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


static func step_label(value: float) -> String:
	var preset_index: int = nearest_preset_index(value)
	var preset_value: float = TIME_SCALE_PRESETS[preset_index]
	if is_equal_approx(value, preset_value):
		return "%d/%d" % [preset_index + 1, TIME_SCALE_PRESETS.size()]
	return "Custom"


func _configure_slider() -> void:
	if _slider == null:
		return
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.001
	if not _slider.value_changed.is_connected(_on_slider_value_changed):
		_slider.value_changed.connect(_on_slider_value_changed)


func _on_slider_value_changed(value: float) -> void:
	TimeService.set_time_scale(slider_value_to_time_scale(value))


func _on_time_scale_changed(new_scale: float) -> void:
	_time_scale_index = nearest_preset_index(new_scale)
	_sync_slider(new_scale)


func _sync_slider(scale: float) -> void:
	if _slider != null:
		_slider.set_value_no_signal(time_scale_to_slider_value(scale))


static func _minimum_time_scale() -> float:
	return maxf(TIME_SCALE_PRESETS[0], 0.001)


static func _maximum_time_scale() -> float:
	return maxf(TIME_SCALE_PRESETS[TIME_SCALE_PRESETS.size() - 1], _minimum_time_scale())
