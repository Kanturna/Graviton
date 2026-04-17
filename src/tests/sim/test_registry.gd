extends RefCounted

# Unit-Tests fuer UniverseRegistry. Testet Topologie-Reihenfolge,
# body_count/clear/unregister-Grundverhalten und null-Rueckgaben.
# Keine Autoloads — Registry wird per Skript-Pfad direkt instanziiert.


static func run(ctx) -> void:
	ctx.current_suite = "test_registry"
	_test_topological_order(ctx)
	_test_orphan_no_crash(ctx)
	_test_body_count(ctx)
	_test_unregister(ctx)
	_test_clear(ctx)
	_test_unknown_id_returns_null(ctx)


# --- helpers ---

static func _make_registry() -> Node:
	return load("res://src/sim/universe/universe_registry.gd").new()


static func _root_def(id: StringName) -> BodyDef:
	var d := BodyDef.new()
	d.id = id
	d.display_name = String(id)
	d.kind = BodyType.Kind.STAR
	d.mass_kg = 1.989e30
	d.radius_m = 6.96e8
	d.parent_id = &""
	d.orbit_profile = null
	return d


static func _child_def(id: StringName, parent: StringName) -> BodyDef:
	var d := BodyDef.new()
	d.id = id
	d.display_name = String(id)
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = 5.972e24
	d.radius_m = 6.371e6
	d.parent_id = parent
	var p := OrbitProfile.new()
	p.mode = OrbitMode.Kind.AUTHORED_ORBIT
	p.authored_radius_m = 1.496e11
	p.authored_period_s = 3.156e7
	p.authored_phase_rad = 0.0
	d.orbit_profile = p
	return d


# --- tests ---

static func _test_topological_order(ctx) -> void:
	var reg := _make_registry()
	reg.register_body(_root_def(&"sol"))
	reg.register_body(_child_def(&"planet_a", &"sol"))
	reg.register_body(_child_def(&"moon_a", &"planet_a"))
	var order: Array[StringName] = reg.get_update_order()
	var i_sol: int = order.find(&"sol")
	var i_planet: int = order.find(&"planet_a")
	var i_moon: int = order.find(&"moon_a")
	ctx.assert_true(i_sol < i_planet, "sol vor planet_a in update_order")
	ctx.assert_true(i_planet < i_moon, "planet_a vor moon_a in update_order")
	reg.free()


static func _test_orphan_no_crash(ctx) -> void:
	# Body mit unbekanntem parent_id: soll push_warning ausloesen, aber nicht crashen.
	var reg := _make_registry()
	var orphan := _child_def(&"orphan", &"nobody")
	reg.register_body(orphan)
	var order: Array[StringName] = reg.get_update_order()
	ctx.assert_true(order.has(&"orphan"), "orphan erscheint in update_order (kein stiller Drop)")
	ctx.assert_true(reg.body_count() == 1, "body_count == 1 nach orphan-Registrierung")
	reg.free()


static func _test_body_count(ctx) -> void:
	var reg := _make_registry()
	ctx.assert_true(reg.body_count() == 0, "body_count 0 bei leerem Registry")
	reg.register_body(_root_def(&"sol"))
	ctx.assert_true(reg.body_count() == 1, "body_count 1 nach erstem register")
	reg.register_body(_child_def(&"planet_a", &"sol"))
	ctx.assert_true(reg.body_count() == 2, "body_count 2 nach zweitem register")
	reg.free()


static func _test_unregister(ctx) -> void:
	var reg := _make_registry()
	reg.register_body(_root_def(&"sol"))
	reg.register_body(_child_def(&"planet_a", &"sol"))
	reg.unregister_body(&"planet_a")
	ctx.assert_true(reg.body_count() == 1, "body_count 1 nach unregister von planet_a")
	ctx.assert_true(not reg.has_body(&"planet_a"), "planet_a nicht mehr in registry")
	ctx.assert_true(reg.has_body(&"sol"), "sol noch in registry")
	reg.free()


static func _test_clear(ctx) -> void:
	var reg := _make_registry()
	reg.register_body(_root_def(&"sol"))
	reg.register_body(_child_def(&"planet_a", &"sol"))
	reg.clear()
	ctx.assert_true(reg.body_count() == 0, "body_count 0 nach clear")
	ctx.assert_true(reg.get_update_order().is_empty(), "update_order leer nach clear")
	reg.free()


static func _test_unknown_id_returns_null(ctx) -> void:
	var reg := _make_registry()
	ctx.assert_true(reg.get_def(&"nonexistent") == null, "get_def null fuer unbekannte id")
	ctx.assert_true(reg.get_state(&"nonexistent") == null, "get_state null fuer unbekannte id")
	ctx.assert_true(not reg.has_body(&"nonexistent"), "has_body false fuer unbekannte id")
	reg.free()
