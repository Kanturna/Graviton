extends RefCounted


const OrbitTimeScaleControllerScript = preload("res://src/tools/rendering/orbit_time_scale_controller.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_time_scale_controller"
	_test_configure_sets_default_preset_and_slider(ctx)
	_test_adjacent_preset_controls_step_through_presets(ctx)
	_test_slider_input_sets_custom_time_scale(ctx)
	_test_external_time_scale_change_resyncs_slider(ctx)


static func _make_setup() -> Dictionary:
	TimeService.reset()
	TimeService.set_paused(false)
	TimeService.set_time_scale(1.0)
	var controller = OrbitTimeScaleControllerScript.new()
	var slider := HSlider.new()
	controller.configure(slider)
	return {
		"controller": controller,
		"slider": slider,
	}


static func _teardown_setup(setup: Dictionary) -> void:
	var controller = setup.get("controller", null)
	if controller != null:
		controller.dispose()
	var slider: HSlider = setup.get("slider", null)
	if slider != null:
		slider.free()
	TimeService.set_time_scale(1.0)
	TimeService.reset()


static func _test_configure_sets_default_preset_and_slider(ctx) -> void:
	var setup := _make_setup()
	var slider: HSlider = setup["slider"]
	var expected_scale: float = OrbitTimeScaleControllerScript.TIME_SCALE_PRESETS[
		OrbitTimeScaleControllerScript.DEFAULT_PRESET_INDEX
	]
	ctx.assert_almost(TimeService.time_scale, expected_scale, 1.0e-9, "configure setzt das Default-Speed-Preset")
	ctx.assert_almost(
		slider.value,
		OrbitTimeScaleControllerScript.time_scale_to_slider_value(expected_scale),
		1.0e-3,
		"configure synchronisiert den Slider auf das Default-Preset"
	)
	_teardown_setup(setup)


static func _test_adjacent_preset_controls_step_through_presets(ctx) -> void:
	var setup := _make_setup()
	var controller = setup["controller"]
	controller.apply_previous_preset()
	ctx.assert_almost(TimeService.time_scale, 250.0, 1.0e-9, "previous springt auf das naechste kleinere Preset")
	ctx.assert_true(controller.get_step_label() == "6/10", "Preset-Label folgt dem kleineren Schritt")
	controller.apply_next_preset()
	ctx.assert_almost(TimeService.time_scale, 500.0, 1.0e-9, "next springt auf das naechste groessere Preset")
	ctx.assert_true(controller.get_step_label() == "7/10", "Preset-Label folgt dem groesseren Schritt")
	_teardown_setup(setup)


static func _test_slider_input_sets_custom_time_scale(ctx) -> void:
	var setup := _make_setup()
	var controller = setup["controller"]
	var slider: HSlider = setup["slider"]
	var custom_slider_value: float = 0.5
	var expected_scale: float = OrbitTimeScaleControllerScript.slider_value_to_time_scale(custom_slider_value)
	slider.value = custom_slider_value
	slider.value_changed.emit(custom_slider_value)
	ctx.assert_almost(TimeService.time_scale, expected_scale, 1.0e-9, "Slider-Input mappt logarithmisch auf time_scale")
	ctx.assert_true(controller.get_step_label() == "Custom", "nicht-Preset-Werte bleiben als Custom markiert")
	_teardown_setup(setup)


static func _test_external_time_scale_change_resyncs_slider(ctx) -> void:
	var setup := _make_setup()
	var controller = setup["controller"]
	var slider: HSlider = setup["slider"]
	TimeService.set_time_scale(1000.0)
	ctx.assert_almost(
		slider.value,
		OrbitTimeScaleControllerScript.time_scale_to_slider_value(1000.0),
		1.0e-3,
		"extern gesetzte time_scale synchronisiert den Slider nach"
	)
	ctx.assert_true(controller.get_step_label() == "8/10", "Preset-Label bleibt bei externen Preset-Werten stabil")
	_teardown_setup(setup)
