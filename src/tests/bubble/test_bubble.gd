extends RefCounted

# Unit-Tests fuer LocalBubbleManager.
# Kein Szenen-Laden, keine Autoloads — synthetisches Mini-System.
# MockRegistry emuliert UniverseRegistry mit nur get_state().


class MockRegistry:
	var _states: Dictionary = {}

	func add(id: StringName, parent_id: StringName, pos: Vector3) -> void:
		var s := BodyState.new(id, parent_id)
		s.position_parent_frame_m = pos
		_states[id] = s

	func get_state(id: StringName):
		return _states.get(id, null)


static func _make_bubble(registry: MockRegistry) -> LocalBubbleManager:
	var b := LocalBubbleManager.new()
	b.configure(registry)
	return b


static func run(ctx) -> void:
	_test_self_focus_zero(ctx)
	_test_symmetry(ctx)
	_test_precision_at_au(ctx)
	_test_no_mutation(ctx)
	_test_to_render_units_linear(ctx)
	_test_no_lca_returns_inf(ctx)
	_test_describe_chain_not_empty(ctx)


# Fokus auf sich selbst → View = ZERO
static func _test_self_focus_zero(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"sol", &"", Vector3.ZERO)
	reg.add(&"planet_a", &"sol", Vector3(1.5e11, 0.0, 0.0))
	var b := _make_bubble(reg)
	b.set_focus(&"planet_a")
	var v: Vector3 = b.compose_view_position_m(&"planet_a")
	ctx.assert_vec_almost(v, Vector3.ZERO, 0.001,
		"self-focus: compose_view_position_m(focus) == ZERO")
	b.free()


# Fokuswechsel-Symmetrie: view(b von a) == -view(a von b)
static func _test_symmetry(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"sol", &"", Vector3.ZERO)
	reg.add(&"planet_a", &"sol", Vector3(1.5e11, 0.0, 0.0))
	reg.add(&"moon_a", &"planet_a", Vector3(3.844e8, 0.0, 0.0))
	var b := _make_bubble(reg)
	b.set_focus(&"planet_a")
	var from_planet: Vector3 = b.compose_view_position_m(&"moon_a")
	b.set_focus(&"moon_a")
	var from_moon: Vector3 = b.compose_view_position_m(&"planet_a")
	ctx.assert_vec_almost(from_planet, -from_moon, 0.001,
		"symmetry: view(moon von planet) == -view(planet von moon)")
	b.free()


# Praezisionstest bei 1 AU: LCA-Ansatz verliert keine float32-Praezision
# durch Kancellation grosser Zahlen. Naive Vector3-Weltsubtraktion haette
# ~18 km Fehler; unser Ansatz hat 0 Fehler (kein grosser Wert summiert).
static func _test_precision_at_au(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"sol", &"", Vector3.ZERO)
	reg.add(&"planet_a", &"sol", Vector3(UnitSystem.AU_M, 0.0, 0.0))
	var moon_pos := Vector3(3.844e8, 0.0, 0.0)
	reg.add(&"moon_a", &"planet_a", moon_pos)
	var b := _make_bubble(reg)
	b.set_focus(&"planet_a")
	var view: Vector3 = b.compose_view_position_m(&"moon_a")
	# LCA = planet_a → t_sum = moon.pos, f_sum = 0 → view = moon.pos exakt
	ctx.assert_vec_almost(view, moon_pos, 1.0,
		"precision at 1 AU: view(moon) == moon.position_parent_frame_m innerhalb 1 m")
	b.free()


# Bubble-Aufrufe veraendern keinen BodyState
static func _test_no_mutation(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"sol", &"", Vector3.ZERO)
	reg.add(&"planet_a", &"sol", Vector3(1.5e11, 0.0, 0.0))
	reg.add(&"moon_a", &"planet_a", Vector3(3.844e8, 0.0, 0.0))
	var b := _make_bubble(reg)
	b.set_focus(&"planet_a")
	var planet_before: Vector3 = reg.get_state(&"planet_a").position_parent_frame_m
	var moon_before: Vector3 = reg.get_state(&"moon_a").position_parent_frame_m
	b.compose_view_position_m(&"moon_a")
	b.compose_render_units(&"sol")
	b.describe_chain(&"moon_a")
	b.debug_compose_world_m(&"planet_a")
	ctx.assert_vec_almost(reg.get_state(&"planet_a").position_parent_frame_m, planet_before, 0.0,
		"no mutation: planet_a.position nach Bubble-Aufrufen unveraendert")
	ctx.assert_vec_almost(reg.get_state(&"moon_a").position_parent_frame_m, moon_before, 0.0,
		"no mutation: moon_a.position nach Bubble-Aufrufen unveraendert")
	b.free()


# to_render_units ist linear: RENDER_SCALE_M / RENDER_SCALE_M == 1
static func _test_to_render_units_linear(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"sol", &"", Vector3.ZERO)
	var b := _make_bubble(reg)
	b.set_focus(&"sol")
	var v := Vector3(UnitSystem.RENDER_SCALE_M_PER_UNIT, 0.0, 0.0)
	var r: Vector3 = b.to_render_units(v)
	ctx.assert_vec_almost(r, Vector3(1.0, 0.0, 0.0), 1.0e-6,
		"to_render_units: RENDER_SCALE_M / RENDER_SCALE_M == 1.0")
	b.free()


# Kein gemeinsamer Vorfahre → Vector3.INF (kein stilles ZERO)
static func _test_no_lca_returns_inf(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"root_x", &"", Vector3.ZERO)
	reg.add(&"body_x", &"root_x", Vector3(1.0e10, 0.0, 0.0))
	reg.add(&"root_y", &"", Vector3.ZERO)
	reg.add(&"body_y", &"root_y", Vector3(2.0e10, 0.0, 0.0))
	var b := _make_bubble(reg)
	b.set_focus(&"body_x")
	var result: Vector3 = b.compose_view_position_m(&"body_y")
	ctx.assert_true(result == Vector3.INF,
		"no LCA: compose_view_position_m gibt Vector3.INF zurueck")
	b.free()


# describe_chain liefert nicht-leere Ausgabe mit Fokus-ID
static func _test_describe_chain_not_empty(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"sol", &"", Vector3.ZERO)
	reg.add(&"planet_a", &"sol", Vector3(1.5e11, 0.0, 0.0))
	reg.add(&"moon_a", &"planet_a", Vector3(3.844e8, 0.0, 0.0))
	var b := _make_bubble(reg)
	b.set_focus(&"planet_a")
	for id: StringName in [&"sol", &"planet_a", &"moon_a"]:
		var desc: String = b.describe_chain(id)
		ctx.assert_true(desc.length() > 0,
			"describe_chain('%s') nicht leer" % str(id))
		ctx.assert_true(desc.contains("planet_a"),
			"describe_chain('%s') enthaelt Fokus-ID 'planet_a'" % str(id))
	b.free()
