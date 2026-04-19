extends RefCounted

const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")


class BubbleStub:
	extends Node

	signal focus_changed(new_id: StringName)

	var _focus_id: StringName = &""

	func set_focus(body_id: StringName) -> void:
		if body_id == _focus_id:
			return
		_focus_id = body_id
		focus_changed.emit(body_id)

	func get_focus() -> StringName:
		return _focus_id


class WorldLoaderStub:
	extends Node

	signal world_loaded(world_id: StringName)

	func emit_loaded(world_id: StringName) -> void:
		world_loaded.emit(world_id)


class ThermalStub:
	extends Node

	var describe_calls: int = 0

	func describe_body(id: StringName) -> Dictionary:
		describe_calls += 1
		var has_source: bool = id != &"genesis"
		return {
			"body_id": id,
			"source_id": &"genesis" if has_source else StringName(""),
			"has_luminous_ancestor": has_source,
			"has_seasonal_basis": id == &"planet_a",
		}


class EnvironmentStub:
	extends Node

	var describe_calls: int = 0

	func describe_body(id: StringName) -> Dictionary:
		describe_calls += 1
		var is_supported_body_kind: bool = id != &"genesis"
		return {
			"body_id": id,
			"is_supported_body_kind": is_supported_body_kind,
			"has_luminous_ancestor": is_supported_body_kind,
			"has_latitudinal_surface_basis": is_supported_body_kind,
			"environment_class": 0,
			"ecosystem_type": 1,
		}


static func run(ctx) -> void:
	ctx.current_suite = "test_derived_snapshot_cache"
	_test_cache_rebuilds_only_on_configured_invalidators(ctx)


static func _test_cache_rebuilds_only_on_configured_invalidators(ctx) -> void:
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	registry.register_body(_root_def())
	registry.register_body(_planet_def())
	var time_service: Node = load("res://src/core/time/time_service.gd").new()
	var bubble := BubbleStub.new()
	var world_loader := WorldLoaderStub.new()
	var thermal_service := ThermalStub.new()
	var environment_service := EnvironmentStub.new()
	var cache = DerivedSnapshotCacheScript.new()

	bubble.set_focus(&"planet_a")
	cache.configure(registry, time_service, bubble, world_loader, thermal_service, environment_service)

	var body_count: int = registry.body_count()
	ctx.assert_true(cache.get_revision() == 1, "configure baut den ersten Snapshot sofort")
	ctx.assert_true(cache.get_last_refresh_reason() == DerivedSnapshotCacheScript.REASON_CONFIGURE, "configure markiert den Refresh-Grund")
	ctx.assert_true(thermal_service.describe_calls == body_count, "configure liest Thermalwerte genau einmal pro Body")
	ctx.assert_true(environment_service.describe_calls == body_count, "configure liest Environment-Werte genau einmal pro Body")
	ctx.assert_true(cache.get_focus_id() == &"planet_a", "configure uebernimmt den aktuellen Fokus")
	ctx.assert_true(cache.get_focus_thermal_desc().get("body_id", &"") == &"planet_a", "Focus-Thermalsnapshot zeigt auf den Fokuskoerper")

	var thermal_calls_before_reads: int = thermal_service.describe_calls
	var environment_calls_before_reads: int = environment_service.describe_calls
	cache.get_focus_environment_desc()
	cache.get_environment_desc(&"planet_a")
	cache.get_thermal_desc(&"planet_a")
	ctx.assert_true(thermal_service.describe_calls == thermal_calls_before_reads, "Snapshot-Reads selbst triggern keinen neuen Thermal-Rebuild")
	ctx.assert_true(environment_service.describe_calls == environment_calls_before_reads, "Snapshot-Reads selbst triggern keinen neuen Environment-Rebuild")

	time_service._emit_tick(1.0)
	ctx.assert_true(cache.get_revision() == 2, "sim_tick invalidiert und rebuilt den Snapshot")
	ctx.assert_true(cache.get_last_refresh_reason() == DerivedSnapshotCacheScript.REASON_SIM_TICK, "sim_tick setzt den passenden Refresh-Grund")
	ctx.assert_true(thermal_service.describe_calls == body_count * 2, "sim_tick rebuilt wieder genau einmal pro Body")
	ctx.assert_true(environment_service.describe_calls == body_count * 2, "sim_tick rebuilt Environment wieder genau einmal pro Body")

	bubble.set_focus(&"genesis")
	ctx.assert_true(cache.get_revision() == 3, "focus_changed invalidiert und rebuilt den Snapshot")
	ctx.assert_true(cache.get_last_refresh_reason() == DerivedSnapshotCacheScript.REASON_FOCUS_CHANGED, "focus_changed setzt den passenden Refresh-Grund")
	ctx.assert_true(cache.get_focus_id() == &"genesis", "Focus-Refresh uebernimmt den neuen Fokus")
	ctx.assert_true(cache.get_focus_thermal_desc().get("body_id", &"") == &"genesis", "Focus-Thermalsnapshot springt auf den neuen Fokus")

	world_loader.emit_loaded(&"generated_system")
	ctx.assert_true(cache.get_revision() == 4, "world_loaded invalidiert und rebuilt den Snapshot")
	ctx.assert_true(cache.get_last_refresh_reason() == DerivedSnapshotCacheScript.REASON_WORLD_RELOAD, "world_loaded setzt den passenden Refresh-Grund")

	cache.dispose()
	bubble.free()
	thermal_service.free()
	environment_service.free()
	world_loader.free()
	time_service.free()
	registry.free()


static func _root_def() -> BodyDef:
	var def := BodyDef.new()
	def.id = &"genesis"
	def.display_name = "Genesis"
	def.kind = BodyType.Kind.STAR
	def.mass_kg = UnitSystem.SOLAR_MASS_KG
	def.radius_m = 6.957e8
	def.parent_id = &""
	def.orbit_profile = null
	return def


static func _planet_def() -> BodyDef:
	var def := BodyDef.new()
	def.id = &"planet_a"
	def.display_name = "Planet A"
	def.kind = BodyType.Kind.PLANET
	def.mass_kg = UnitSystem.EARTH_MASS_KG
	def.radius_m = 6.371e6
	def.parent_id = &"genesis"
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = 1.0e9
	profile.authored_period_s = 1.0e5
	profile.authored_phase_rad = 0.0
	def.orbit_profile = profile
	return def
