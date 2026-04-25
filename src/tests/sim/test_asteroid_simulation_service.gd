extends RefCounted

const AsteroidSimulationServiceScript = preload("res://src/sim/asteroids/asteroid_simulation_service.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_asteroid_simulation_service"
	_test_spawn_is_deterministic(ctx)
	_test_trajectory_is_deterministic(ctx)
	_test_major_body_states_stay_read_only(ctx)
	_test_anchor_id_stays_stable(ctx)
	_test_attractor_cap_and_hysteresis(ctx)
	_test_sync_resident_roots_lifecycle_is_idempotent(ctx)
	_test_single_world_spawns_without_streaming_controller(ctx)
	_test_sim_asteroids_imports_no_runtime_tools_or_scenes(ctx)


static func _make_registry() -> Node:
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	for def in [
		_root_def(&"root_a"),
		_star_def(&"star_a", &"root_a", 1.0e10, 0.0),
		_star_def(&"star_b", &"root_a", -1.0e10, 0.8),
		_planet_def(&"planet_a", &"star_a", 0.8e11, 0.0, UnitSystem.EARTH_MASS_KG),
		_planet_def(&"planet_b", &"star_a", 1.0e11, 0.7, UnitSystem.EARTH_MASS_KG * 0.8),
		_planet_def(&"planet_c", &"star_a", 1.2e11, 1.4, UnitSystem.EARTH_MASS_KG * 0.7),
		_planet_def(&"planet_d", &"star_a", 1.4e11, 2.1, UnitSystem.EARTH_MASS_KG * 0.6),
		_planet_def(&"planet_e", &"star_a", 1.6e11, 2.8, UnitSystem.EARTH_MASS_KG * 0.5),
		_moon_def(&"moon_a", &"planet_a"),
	]:
		reg.register_body(def)
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	var time_service = load("res://src/core/time/time_service.gd").new()
	orbit_service.configure(reg, time_service)
	orbit_service.recompute_all_at_time(0.0)
	orbit_service.free()
	time_service.free()
	return reg


static func _make_two_root_registry() -> Node:
	var reg := _make_registry()
	for def in [
		_root_def(&"root_b"),
		_star_def(&"star_c", &"root_b", 1.0e10, 0.1),
		_planet_def(&"planet_f", &"star_c", 0.9e11, 0.3, UnitSystem.EARTH_MASS_KG),
	]:
		reg.register_body(def)
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	var time_service = load("res://src/core/time/time_service.gd").new()
	orbit_service.configure(reg, time_service)
	orbit_service.recompute_all_at_time(0.0)
	orbit_service.free()
	time_service.free()
	return reg


static func _make_service(registry: Node):
	var service = AsteroidSimulationServiceScript.new()
	service.configure(registry)
	return service


static func _root_def(id: StringName) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.BLACK_HOLE
	def.mass_kg = UnitSystem.SOLAR_MASS_KG * 4.0
	def.radius_m = 2.0e9
	def.parent_id = &""
	def.orbit_profile = null
	return def


static func _star_def(id: StringName, parent_id: StringName, radius_m: float, phase_rad: float) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.STAR
	def.mass_kg = UnitSystem.SOLAR_MASS_KG
	def.radius_m = 6.957e8
	def.parent_id = parent_id
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = radius_m
	profile.authored_period_s = 9.0e6
	profile.authored_phase_rad = phase_rad
	def.orbit_profile = profile
	return def


static func _planet_def(id: StringName, parent_id: StringName, axis_m: float, phase_rad: float, mass_kg: float) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.PLANET
	def.mass_kg = mass_kg
	def.radius_m = 6.371e6
	def.parent_id = parent_id
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = axis_m
	profile.authored_period_s = 3.0e7
	profile.authored_phase_rad = phase_rad
	def.orbit_profile = profile
	return def


static func _moon_def(id: StringName, parent_id: StringName) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.MOON
	def.mass_kg = UnitSystem.LUNAR_MASS_KG
	def.radius_m = 1.737e6
	def.parent_id = parent_id
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = 4.0e8
	profile.authored_period_s = 2.4e6
	profile.authored_phase_rad = 0.2
	def.orbit_profile = profile
	return def


static func _test_spawn_is_deterministic(ctx) -> void:
	var reg := _make_registry()
	var service_a = _make_service(reg)
	var service_b = _make_service(reg)
	service_a.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	service_b.reset_for_world(&"scope_a", [&"root_a"], 0.0)

	var entries_a: Array = service_a.get_state_snapshot().get("entries", [])
	var entries_b: Array = service_b.get_state_snapshot().get("entries", [])
	ctx.assert_true(entries_a.size() == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT,
		"ein Root spawnt exakt das V1-Budget an Asteroiden")
	ctx.assert_true(entries_a.size() == entries_b.size(), "deterministischer Spawn hat dieselbe Anzahl")
	for idx in range(entries_a.size()):
		var a: Dictionary = entries_a[idx]
		var b: Dictionary = entries_b[idx]
		ctx.assert_true(a.get("id", StringName("")) == b.get("id", StringName("")),
			"deterministischer Spawn haelt IDs stabil")
		ctx.assert_almost(float(a.get("x_m", 0.0)), float(b.get("x_m", 0.0)), 1.0e-6,
			"deterministischer Spawn haelt Positionen stabil")
		ctx.assert_true(StringName(a.get("anchor_id", StringName(""))) != StringName(""),
			"Asteroid hat einen festen Anchor")

	service_a.free()
	service_b.free()
	reg.free()


static func _test_trajectory_is_deterministic(ctx) -> void:
	var reg := _make_registry()
	var service_a = _make_service(reg)
	var service_b = _make_service(reg)
	service_a.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	service_b.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	for dt_s in [600.0, 1200.0, 1800.0]:
		service_a.advance_to_time(dt_s, dt_s)
		service_b.advance_to_time(dt_s, dt_s)

	var entries_a: Array = service_a.get_state_snapshot().get("entries", [])
	var entries_b: Array = service_b.get_state_snapshot().get("entries", [])
	for idx in range(entries_a.size()):
		var a: Dictionary = entries_a[idx]
		var b: Dictionary = entries_b[idx]
		ctx.assert_almost(float(a.get("x_m", 0.0)), float(b.get("x_m", 0.0)), 1.0e-3,
			"gleiche dt-Sequenz erzeugt gleiche x-Position")
		ctx.assert_almost(float(a.get("vy_mps", 0.0)), float(b.get("vy_mps", 0.0)), 1.0e-6,
			"gleiche dt-Sequenz erzeugt gleiche Velocity")

	service_a.free()
	service_b.free()
	reg.free()


static func _test_major_body_states_stay_read_only(ctx) -> void:
	var reg := _make_registry()
	var before: Dictionary = _capture_body_states(reg)
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	service.advance_to_time(3600.0, 3600.0)
	var after: Dictionary = _capture_body_states(reg)

	for id in before.keys():
		var b: Dictionary = before[id]
		var a: Dictionary = after[id]
		ctx.assert_true(b.get("position") == a.get("position"), "Asteroiden mutieren keine Major-Body-Positionen")
		ctx.assert_true(b.get("velocity") == a.get("velocity"), "Asteroiden mutieren keine Major-Body-Velocities")
		ctx.assert_true(int(b.get("mode", -1)) == int(a.get("mode", -2)), "Asteroiden mutieren keinen Major-Body-Orbitmodus")

	service.free()
	reg.free()


static func _test_anchor_id_stays_stable(ctx) -> void:
	var reg := _make_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	var before: Dictionary = _anchors_by_id(service.get_state_snapshot().get("entries", []))
	for step in range(8):
		service.advance_to_time(float(step + 1) * 900.0, 900.0)
	var after: Dictionary = _anchors_by_id(service.get_state_snapshot().get("entries", []))

	ctx.assert_true(before.size() == after.size(), "Anchor-Stabilitaet behaelt alle aktiven Test-Asteroiden")
	for id in before.keys():
		ctx.assert_true(before[id] == after[id], "V1 fuehrt keinen Anchor-Switch durch")

	service.free()
	reg.free()


static func _test_attractor_cap_and_hysteresis(ctx) -> void:
	var reg := _make_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	var state = service._states_by_id[service._state_order[0]]
	state.anchor_id = &"star_a"
	state.root_id = &"root_a"
	state.x_m = 1.05e11
	state.y_m = 0.0
	state.z_m = 0.0
	reg.get_def(&"star_b").mass_kg = 1.0
	reg.get_def(&"moon_a").mass_kg = 1.0
	for idx in range(5):
		var planet_id: StringName = [&"planet_a", &"planet_b", &"planet_c", &"planet_d", &"planet_e"][idx]
		reg.get_def(planet_id).mass_kg = UnitSystem.EARTH_MASS_KG
		var planet_state: BodyState = reg.get_state(planet_id)
		planet_state.position_parent_frame_m = Vector3(1.06e11 + float(idx) * 2.0e9, 0.0, 0.0)
		planet_state.velocity_parent_frame_mps = Vector3.ZERO
	var current_attractor_ids: Array[StringName] = [&"root_a", &"star_a", &"planet_a", &"planet_b", &"planet_c", &"planet_d"]
	state.current_attractor_ids = current_attractor_ids

	var selected: Array[StringName] = service.call("_select_attractors_for", state)
	ctx.assert_true(selected.size() <= AsteroidSimulationServiceScript.MAX_ATTRACTORS,
		"Attractor-Auswahl bleibt auf MAX_ATTRACTORS gecappt")
	ctx.assert_true(selected.has(&"planet_d"),
		"Hysterese behaelt einen aktuellen optionalen Attraktor bei knapper Konkurrenz")

	reg.get_def(&"planet_e").mass_kg = UnitSystem.EARTH_MASS_KG * 20.0
	var replaced: Array[StringName] = service.call("_select_attractors_for", state)
	ctx.assert_true(replaced.has(&"planet_e"),
		"Hysterese ersetzt erst bei deutlichem Score-Vorsprung")

	service.free()
	reg.free()


static func _test_sync_resident_roots_lifecycle_is_idempotent(ctx) -> void:
	var reg := _make_two_root_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	var initial_revision: int = int(service.get_state_snapshot().get("revision", -1))
	service.sync_resident_roots(&"scope_a", [&"root_a"], 10.0)
	var same_revision: int = int(service.get_state_snapshot().get("revision", -1))
	ctx.assert_true(same_revision == initial_revision,
		"wiederholtes sync_resident_roots mit gleicher Root-Liste ist ein No-op")

	service.sync_resident_roots(&"scope_a", [&"root_a", &"root_b"], 20.0)
	ctx.assert_true(int(service.get_state_snapshot().get("count", 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT * 2,
		"neue residente Roots spawnen eigene Asteroiden")
	service.sync_resident_roots(&"scope_a", [&"root_b"], 30.0)
	ctx.assert_true(int(service.get_state_snapshot().get("count", 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT,
		"nichtresidente Roots werden entfernt")
	ctx.assert_true(int(service.get_perf_counter_snapshot().get(AsteroidSimulationServiceScript.PERF_KEY_DESPAWNED, 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT,
		"Despawn-Counter zaehlt entfernte Root-Asteroiden")

	service.free()
	reg.free()


static func _test_single_world_spawns_without_streaming_controller(ctx) -> void:
	var loader = load("res://src/sim/world/world_loader.gd").new()
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	var loaded: bool = loader.load_named_world(WorldLoader.SAMPLE_SYSTEM_ID, reg)
	ctx.assert_true(loaded, "sample_system laedt fuer den Single-World-Spawn-Test")
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	var time_service = load("res://src/core/time/time_service.gd").new()
	orbit_service.configure(reg, time_service)
	orbit_service.recompute_all_at_time(0.0)
	var service = _make_service(reg)
	service.reset_for_world(WorldLoader.SAMPLE_SYSTEM_ID, _root_ids(reg), 0.0)

	ctx.assert_true(int(service.get_state_snapshot().get("count", 0)) > 0,
		"Single-World-Pfad spawnt Asteroiden ohne GalaxyStreamingController")

	service.free()
	orbit_service.free()
	time_service.free()
	reg.free()
	loader.free()


static func _test_sim_asteroids_imports_no_runtime_tools_or_scenes(ctx) -> void:
	var dir_path: String = "res://src/sim/asteroids"
	for file_name in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".gd"):
			continue
		var file := FileAccess.open("%s/%s" % [dir_path, file_name], FileAccess.READ)
		ctx.assert_true(file != null, "Asteroid-Sim-Datei ist lesbar")
		var text: String = file.get_as_text()
		file.close()
		ctx.assert_true(text.find("res://src/runtime/") < 0, "sim/asteroids importiert kein runtime")
		ctx.assert_true(text.find("res://src/tools/") < 0, "sim/asteroids importiert keine tools")
		ctx.assert_true(text.find("res://scenes/") < 0, "sim/asteroids importiert keine scenes")
		ctx.assert_true(text.find("RigidBody") < 0 and text.find("Area2D") < 0 and text.find("Area3D") < 0,
			"sim/asteroids nutzt keine Physik-Engine")


static func _capture_body_states(registry: Node) -> Dictionary:
	var out: Dictionary = {}
	for id in registry.get_update_order_ref():
		var state: BodyState = registry.get_state(id)
		out[id] = {
			"position": state.position_parent_frame_m,
			"velocity": state.velocity_parent_frame_mps,
			"mode": state.current_mode,
		}
	return out


static func _anchors_by_id(entries: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY:
			out[entry.get("id", StringName(""))] = entry.get("anchor_id", StringName(""))
	return out


static func _root_ids(registry: Node) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in registry.get_update_order_ref():
		var def: BodyDef = registry.get_def(id)
		if def != null and def.is_root():
			out.append(id)
	return out
