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


class OrbitServiceStub:
	extends Node

	signal bodies_updated(ids: Array[StringName], reason: StringName)

	func emit_bodies_updated(ids: Array[StringName], reason: StringName) -> void:
		bodies_updated.emit(ids, reason)


class ThermalStub:
	extends Node

	var describe_calls: int = 0
	var describe_calls_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		describe_calls += 1
		describe_calls_by_id[id] = int(describe_calls_by_id.get(id, 0)) + 1
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
	var describe_calls_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		describe_calls += 1
		describe_calls_by_id[id] = int(describe_calls_by_id.get(id, 0)) + 1
		var is_supported_body_kind: bool = id != &"genesis"
		return {
			"body_id": id,
			"is_supported_body_kind": is_supported_body_kind,
			"has_luminous_ancestor": is_supported_body_kind,
			"has_latitudinal_surface_basis": is_supported_body_kind,
			"environment_class": 0,
			"ecosystem_type": 1,
		}


class PlanetaryStateStub:
	extends Node

	var describe_calls: int = 0
	var describe_calls_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		describe_calls += 1
		describe_calls_by_id[id] = int(describe_calls_by_id.get(id, 0)) + 1
		return {
			"body_id": id,
			"has_sampled_year_basis": id != &"genesis",
			"volatile_inventory_class": 1,
		}


class LifePotentialStub:
	extends Node

	var describe_calls: int = 0
	var describe_calls_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		describe_calls += 1
		describe_calls_by_id[id] = int(describe_calls_by_id.get(id, 0)) + 1
		return {
			"body_id": id,
			"has_life_potential_basis": id != &"genesis",
			"dominant_track_id": 0,
			"dominant_potential_class": 2,
		}


static func run(ctx) -> void:
	ctx.current_suite = "test_derived_snapshot_cache"
	_test_cache_tracks_interest_and_dirty_updates(ctx)
	_test_cache_falls_back_to_sim_tick_without_orbit_signal(ctx)


static func _test_cache_tracks_interest_and_dirty_updates(ctx) -> void:
	var registry: Node = _make_registry()
	var time_service: Node = load("res://src/core/time/time_service.gd").new()
	var bubble := BubbleStub.new()
	var world_loader := WorldLoaderStub.new()
	var orbit_service := OrbitServiceStub.new()
	var thermal_service := ThermalStub.new()
	var environment_service := EnvironmentStub.new()
	var planetary_state_service := PlanetaryStateStub.new()
	var life_potential_service := LifePotentialStub.new()
	var cache = DerivedSnapshotCacheScript.new()

	bubble.set_focus(&"planet_a")
	cache.configure(
		registry,
		time_service,
		bubble,
		world_loader,
		thermal_service,
		environment_service,
		orbit_service,
		planetary_state_service,
		life_potential_service
	)

	ctx.assert_true(cache.get_revision() == 1, "configure baut den ersten Snapshot sofort")
	ctx.assert_true(cache.get_last_refresh_reason() == DerivedSnapshotCacheScript.REASON_CONFIGURE, "configure markiert den Refresh-Grund")
	ctx.assert_true(cache.get_last_refreshed_body_count() == 1, "configure refreshes nur den Fokuskoerper")
	ctx.assert_true(thermal_service.describe_calls == 1, "configure liest Thermalwerte nur fuer den Fokus")
	ctx.assert_true(environment_service.describe_calls == 1, "configure liest Environment-Werte nur fuer den Fokus")
	ctx.assert_true(cache.get_focus_id() == &"planet_a", "configure uebernimmt den aktuellen Fokus")
	ctx.assert_true(cache.get_focus_thermal_desc().get("body_id", &"") == &"planet_a", "Focus-Thermalsnapshot zeigt auf den Fokuskoerper")
	ctx.assert_true(cache.get_focus_planetary_state_desc().get("body_id", &"") == &"planet_a", "configure baut auch den planetaren Focus-Snapshot")
	ctx.assert_true(cache.get_focus_life_potential_desc().get("body_id", &"") == &"planet_a", "configure baut auch den Life-Potential-Focus-Snapshot")
	ctx.assert_true(cache.get_environment_desc(&"moon_a").is_empty(), "nicht interessierte Bodies bleiben ungecacht")

	cache.set_interest_ids([&"planet_a", &"moon_a"])
	ctx.assert_true(cache.get_revision() == 2, "interest change triggert sofortigen Refresh")
	ctx.assert_true(cache.get_last_refresh_reason() == DerivedSnapshotCacheScript.REASON_INTEREST_CHANGED, "interest change setzt den passenden Grund")
	ctx.assert_true(cache.get_last_refreshed_body_count() == 2, "interest change refresht nur Fokus plus explizites Interesse")
	ctx.assert_true(cache.get_thermal_desc(&"moon_a").get("body_id", &"") == &"moon_a", "interessierter Mond wird gecacht")
	ctx.assert_true(cache.get_planetary_state_desc(&"moon_a").get("body_id", &"") == &"moon_a", "interessierter Mond bekommt auch einen planetaren Snapshot")
	ctx.assert_true(cache.get_life_potential_desc(&"moon_a").get("body_id", &"") == &"moon_a", "interessierter Mond bekommt auch einen Life-Potential-Snapshot")

	var revision_before_irrelevant_update: int = cache.get_revision()
	var thermal_calls_before_irrelevant_update: int = thermal_service.describe_calls
	orbit_service.emit_bodies_updated([&"planet_b"], DerivedSnapshotCacheScript.REASON_SIM_TICK)
	ctx.assert_true(cache.get_revision() == revision_before_irrelevant_update, "unrelevante Dirty-IDs triggern keinen Refresh")
	ctx.assert_true(thermal_service.describe_calls == thermal_calls_before_irrelevant_update, "unrelevante Dirty-IDs lesen keine neuen Thermalwerte")

	orbit_service.emit_bodies_updated([&"genesis"], DerivedSnapshotCacheScript.REASON_SIM_TICK)
	ctx.assert_true(cache.get_revision() == revision_before_irrelevant_update + 1, "Dirty-Update fuer Ancestor refresht interessierte Nachfahren")
	ctx.assert_true(cache.get_last_refresh_reason() == DerivedSnapshotCacheScript.REASON_SIM_TICK, "Orbit-Dirty-Update nutzt sim_tick als Refresh-Grund")
	ctx.assert_true(cache.get_last_refreshed_body_count() == 2, "Ancestor-Dirty refresht nur abhaengige interessierte Bodies")
	ctx.assert_true(int(thermal_service.describe_calls_by_id.get(&"planet_a", 0)) == 3, "planet_a wurde nur bei relevanten Refreshes neu gelesen")
	ctx.assert_true(int(thermal_service.describe_calls_by_id.get(&"moon_a", 0)) == 2, "moon_a wurde erst nach Interest-Set und Ancestor-Dirty gelesen")
	ctx.assert_true(int(thermal_service.describe_calls_by_id.get(&"planet_b", 0)) == 0, "planet_b bleibt ohne Interesse unberuehrt")

	bubble.set_focus(&"genesis")
	ctx.assert_true(cache.get_revision() == revision_before_irrelevant_update + 2, "focus_changed invalidiert und rebuilt den Snapshot")
	ctx.assert_true(cache.get_last_refresh_reason() == DerivedSnapshotCacheScript.REASON_FOCUS_CHANGED, "focus_changed setzt den passenden Refresh-Grund")
	ctx.assert_true(cache.get_last_refreshed_body_count() == 1, "focus change refresht nur den neuen Fokuskoerper")
	ctx.assert_true(cache.get_focus_id() == &"genesis", "Focus-Refresh uebernimmt den neuen Fokus")
	ctx.assert_true(cache.get_focus_thermal_desc().get("body_id", &"") == &"genesis", "Focus-Thermalsnapshot springt auf den neuen Fokus")

	world_loader.emit_loaded(&"pilot_galaxy")
	ctx.assert_true(cache.get_revision() == revision_before_irrelevant_update + 3, "world_loaded invalidiert und rebuilt den Snapshot")
	ctx.assert_true(cache.get_last_refresh_reason() == DerivedSnapshotCacheScript.REASON_WORLD_RELOAD, "world_loaded setzt den passenden Refresh-Grund")
	ctx.assert_true(cache.get_last_refreshed_body_count() == 3, "world reload refresht den Fokus plus explizite Interessen")

	cache.dispose()
	orbit_service.free()
	bubble.free()
	thermal_service.free()
	environment_service.free()
	planetary_state_service.free()
	life_potential_service.free()
	world_loader.free()
	time_service.free()
	registry.free()


static func _test_cache_falls_back_to_sim_tick_without_orbit_signal(ctx) -> void:
	var registry: Node = _make_registry()
	var time_service: Node = load("res://src/core/time/time_service.gd").new()
	var bubble := BubbleStub.new()
	var world_loader := WorldLoaderStub.new()
	var thermal_service := ThermalStub.new()
	var environment_service := EnvironmentStub.new()
	var cache = DerivedSnapshotCacheScript.new()

	bubble.set_focus(&"planet_a")
	cache.configure(registry, time_service, bubble, world_loader, thermal_service, environment_service)
	ctx.assert_true(cache.get_last_refreshed_body_count() == 1, "fallback configure refresht nur den Fokus")

	time_service._emit_tick(1.0)
	ctx.assert_true(cache.get_revision() == 2, "sim_tick fallback invalidiert und rebuilt den Snapshot")
	ctx.assert_true(cache.get_last_refresh_reason() == DerivedSnapshotCacheScript.REASON_SIM_TICK, "fallback sim_tick setzt den passenden Refresh-Grund")
	ctx.assert_true(cache.get_last_refreshed_body_count() == 1, "fallback sim_tick refresht weiter nur den Fokus")

	cache.dispose()
	bubble.free()
	thermal_service.free()
	environment_service.free()
	world_loader.free()
	time_service.free()
	registry.free()


static func _make_registry() -> Node:
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	registry.register_body(_root_def())
	registry.register_body(_planet_def(&"planet_a", &"genesis"))
	registry.register_body(_moon_def(&"moon_a", &"planet_a"))
	registry.register_body(_planet_def(&"planet_b", &"genesis"))
	return registry


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


static func _planet_def(id: StringName, parent_id: StringName) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.PLANET
	def.mass_kg = UnitSystem.EARTH_MASS_KG
	def.radius_m = 6.371e6
	def.parent_id = parent_id
	def.orbit_profile = _authored_profile(1.0e9, 1.0e5, 0.0)
	return def


static func _moon_def(id: StringName, parent_id: StringName) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.MOON
	def.mass_kg = UnitSystem.LUNAR_MASS_KG
	def.radius_m = UnitSystem.LUNAR_RADIUS_M
	def.parent_id = parent_id
	def.orbit_profile = _authored_profile(2.0e8, 4.0e4, 0.4)
	return def


static func _authored_profile(radius_m: float, period_s: float, phase_rad: float) -> OrbitProfile:
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = radius_m
	profile.authored_period_s = period_s
	profile.authored_phase_rad = phase_rad
	return profile
