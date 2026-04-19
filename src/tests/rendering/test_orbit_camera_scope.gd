extends RefCounted


const OrbitCameraScopeScript = preload("res://src/tools/rendering/orbit_camera_scope.gd")
const UniverseTopologyScript = preload("res://src/sim/topology/universe_topology.gd")


class PositionProvider:
	extends RefCounted

	var positions: Dictionary = {}

	func get_pos(id: StringName) -> Vector2:
		return positions.get(id, Vector2(INF, INF))


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_camera_scope"
	_test_root_scope_includes_root_context(ctx)
	_test_star_scope_excludes_parent_bh(ctx)
	_test_planet_scope_contains_planet_and_moons(ctx)
	_test_moon_scope_contains_parent_planet_and_moon(ctx)


static func _make_registry() -> Node:
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	for def in [
		_root_def(&"obsidian"),
		_child_def(&"beta", &"obsidian", BodyType.Kind.STAR, 100.0),
		_child_def(&"beta_i", &"beta", BodyType.Kind.PLANET, 10.0),
		_child_def(&"beta_ii", &"beta", BodyType.Kind.PLANET, 18.0),
		_child_def(&"beta_i_m", &"beta_i", BodyType.Kind.MOON, 2.0),
	]:
		reg.register_body(def)
	return reg


static func _root_def(id: StringName) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.BLACK_HOLE
	def.mass_kg = 8.0e34
	def.radius_m = 1.0e7
	def.parent_id = &""
	def.orbit_profile = null
	return def


static func _child_def(id: StringName, parent: StringName, kind: int, orbit_radius_ru: float) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = kind
	def.mass_kg = 5.0e24
	def.radius_m = 6.0e6
	def.parent_id = parent
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = orbit_radius_ru * UnitSystem.RENDER_SCALE_M_PER_UNIT
	profile.authored_period_s = 1.0e5
	profile.authored_phase_rad = 0.0
	def.orbit_profile = profile
	return def


static func _scope_frame_for(registry: Node, focus_id: StringName, positions: Dictionary) -> Dictionary:
	var topology = UniverseTopologyScript.new()
	topology.configure(registry)
	var provider := PositionProvider.new()
	provider.positions = positions
	return OrbitCameraScopeScript.get_scope_frame(
		registry,
		topology,
		focus_id,
		Callable(provider, "get_pos")
	)


static func _test_root_scope_includes_root_context(ctx) -> void:
	var reg := _make_registry()
	var frame: Dictionary = _scope_frame_for(
		reg,
		&"obsidian",
		{
			&"obsidian": Vector2.ZERO,
			&"beta": Vector2(100.0, 0.0),
			&"beta_i": Vector2(110.0, 0.0),
			&"beta_ii": Vector2(118.0, 0.0),
			&"beta_i_m": Vector2(112.0, 0.0),
		}
	)
	ctx.assert_true(frame.get("anchor_id", &"") == &"obsidian", "Root-Scope verankert am Fokuskoerper")
	ctx.assert_true(frame.get("scope_kind", &"") == OrbitCameraScopeScript.SCOPE_KIND_ROOT, "Root-Fokus liefert scope_kind root")
	ctx.assert_true(
		_same_ids(frame.get("body_ids", []), [&"obsidian", &"beta", &"beta_i", &"beta_ii", &"beta_i_m"]),
		"Root-Scope enthaelt den ganzen Root-Kontext"
	)
	ctx.assert_true(float(frame.get("radius", 0.0)) > 130.0, "Root-Scope-Radius umfasst den entfernten Sternkontext")
	reg.free()


static func _test_star_scope_excludes_parent_bh(ctx) -> void:
	var reg := _make_registry()
	var frame: Dictionary = _scope_frame_for(
		reg,
		&"beta",
		{
			&"obsidian": Vector2(-100.0, 0.0),
			&"beta": Vector2.ZERO,
			&"beta_i": Vector2(10.0, 0.0),
			&"beta_ii": Vector2(18.0, 0.0),
			&"beta_i_m": Vector2(12.0, 0.0),
		}
	)
	ctx.assert_true(frame.get("scope_kind", &"") == OrbitCameraScopeScript.SCOPE_KIND_STAR, "Stern-Fokus liefert scope_kind star")
	ctx.assert_true(
		_same_ids(frame.get("body_ids", []), [&"beta", &"beta_i", &"beta_ii", &"beta_i_m"]),
		"Stern-Scope enthaelt nur Stern und Nachkommen"
	)
	ctx.assert_true(float(frame.get("radius", 0.0)) < 50.0, "Stern-Scope eskaliert nicht auf den Parent-BH-Kontext")
	reg.free()


static func _test_planet_scope_contains_planet_and_moons(ctx) -> void:
	var reg := _make_registry()
	var frame: Dictionary = _scope_frame_for(
		reg,
		&"beta_i",
		{
			&"obsidian": Vector2(-110.0, 0.0),
			&"beta": Vector2(-10.0, 0.0),
			&"beta_i": Vector2.ZERO,
			&"beta_ii": Vector2(8.0, 0.0),
			&"beta_i_m": Vector2(2.0, 0.0),
		}
	)
	ctx.assert_true(frame.get("scope_kind", &"") == OrbitCameraScopeScript.SCOPE_KIND_PLANET, "Planeten-Fokus liefert scope_kind planet")
	ctx.assert_true(
		_same_ids(frame.get("body_ids", []), [&"beta_i", &"beta_i_m"]),
		"Planeten-Scope enthaelt Planet und Monde"
	)
	ctx.assert_true(float(frame.get("radius", 0.0)) > 4.0 and float(frame.get("radius", 0.0)) < 6.0,
		"Planeten-Scope bleibt lokal statt auf Sternkontext zu wachsen")
	reg.free()


static func _test_moon_scope_contains_parent_planet_and_moon(ctx) -> void:
	var reg := _make_registry()
	var frame: Dictionary = _scope_frame_for(
		reg,
		&"beta_i_m",
		{
			&"obsidian": Vector2(-112.0, 0.0),
			&"beta": Vector2(-12.0, 0.0),
			&"beta_i": Vector2(-2.0, 0.0),
			&"beta_ii": Vector2(6.0, 0.0),
			&"beta_i_m": Vector2.ZERO,
		}
	)
	ctx.assert_true(frame.get("anchor_id", &"") == &"beta_i_m", "Mond-Scope bleibt am Mond verankert")
	ctx.assert_true(frame.get("scope_kind", &"") == OrbitCameraScopeScript.SCOPE_KIND_MOON, "Mond-Fokus liefert scope_kind moon")
	ctx.assert_true(
		_same_ids(frame.get("body_ids", []), [&"beta_i", &"beta_i_m"]),
		"Mond-Scope enthaelt nur Parent-Planet und Mond"
	)
	ctx.assert_true(float(frame.get("radius", 0.0)) > 4.0 and float(frame.get("radius", 0.0)) < 5.0,
		"Mond-Scope bleibt klein und planet-lokal")
	reg.free()


static func _same_ids(actual_variant, expected: Array[StringName]) -> bool:
	var actual: Array[StringName] = []
	for id in actual_variant:
		actual.append(id)
	if actual.size() != expected.size():
		return false
	for i in range(expected.size()):
		if actual[i] != expected[i]:
			return false
	return true
