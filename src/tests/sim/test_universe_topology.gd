extends RefCounted


static func run(ctx) -> void:
	ctx.current_suite = "test_universe_topology"
	_test_root_id_of(ctx)
	_test_ancestor_path_root_to_leaf(ctx)
	_test_lowest_common_ancestor(ctx)
	_test_is_descendant_of(ctx)
	_test_descendants_follow_update_order(ctx)
	_test_cross_root_lca_returns_empty(ctx)


static func _make_registry() -> Node:
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	var defs: Array[BodyDef] = [
		_root_def(&"root_a"),
		_child_def(&"star_a", &"root_a", BodyType.Kind.STAR),
		_child_def(&"planet_a1", &"star_a", BodyType.Kind.PLANET),
		_child_def(&"planet_a2", &"star_a", BodyType.Kind.PLANET),
		_child_def(&"moon_a2", &"planet_a2", BodyType.Kind.MOON),
		_root_def(&"root_b"),
		_child_def(&"star_b", &"root_b", BodyType.Kind.STAR),
		_child_def(&"planet_b1", &"star_b", BodyType.Kind.PLANET),
	]
	for def in defs:
		reg.register_body(def)
	return reg


static func _make_topology(registry: Node):
	var topology = load("res://src/sim/topology/universe_topology.gd").new()
	topology.configure(registry)
	return topology


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


static func _child_def(id: StringName, parent: StringName, kind: int) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = kind
	def.mass_kg = 5.0e24
	def.radius_m = 6.0e6
	def.parent_id = parent
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = 1.0e8
	profile.authored_period_s = 1.0e5
	profile.authored_phase_rad = 0.0
	def.orbit_profile = profile
	return def


static func _test_root_id_of(ctx) -> void:
	var reg := _make_registry()
	var topology = _make_topology(reg)
	ctx.assert_true(topology.root_id_of(&"moon_a2") == &"root_a", "root_id_of findet den Root ueber mehrere Ebenen")
	ctx.assert_true(topology.root_id_of(&"root_b") == &"root_b", "root_id_of liefert den Root fuer Root selbst")
	ctx.assert_true(topology.root_id_of(&"missing") == StringName(""), "root_id_of liefert leer fuer fehlende Bodies")
	reg.free()


static func _test_ancestor_path_root_to_leaf(ctx) -> void:
	var reg := _make_registry()
	var topology = _make_topology(reg)
	var path: Array[StringName] = topology.ancestor_path_root_to_leaf(&"moon_a2")
	ctx.assert_true(path == [&"root_a", &"star_a", &"planet_a2", &"moon_a2"],
		"ancestor_path_root_to_leaf liefert den kompletten Root-zu-Leaf-Pfad")
	reg.free()


static func _test_lowest_common_ancestor(ctx) -> void:
	var reg := _make_registry()
	var topology = _make_topology(reg)
	ctx.assert_true(
		topology.lowest_common_ancestor(&"planet_a1", &"moon_a2") == &"star_a",
		"LCA von Geschwistern/Nachfahren unter root_a ist star_a"
	)
	reg.free()


static func _test_is_descendant_of(ctx) -> void:
	var reg := _make_registry()
	var topology = _make_topology(reg)
	ctx.assert_true(topology.is_descendant_of(&"moon_a2", &"root_a"), "moon_a2 ist Nachfahr von root_a")
	ctx.assert_true(not topology.is_descendant_of(&"star_a", &"star_a"), "ein Body ist nicht Nachfahr von sich selbst")
	ctx.assert_true(not topology.is_descendant_of(&"planet_b1", &"root_a"), "cross-root Bodies sind keine Nachfahren")
	reg.free()


static func _test_descendants_follow_update_order(ctx) -> void:
	var reg := _make_registry()
	var topology = _make_topology(reg)
	var descendants: Array[StringName] = topology.descendants_of(&"star_a")
	ctx.assert_true(
		descendants == [&"planet_a1", &"planet_a2", &"moon_a2"],
		"descendants_of folgt der Registry-Update-Reihenfolge und schliesst den Root selbst aus"
	)
	reg.free()


static func _test_cross_root_lca_returns_empty(ctx) -> void:
	var reg := _make_registry()
	var topology = _make_topology(reg)
	ctx.assert_true(
		topology.lowest_common_ancestor(&"planet_a1", &"planet_b1") == StringName(""),
		"cross-root LCA bleibt leer"
	)
	reg.free()
