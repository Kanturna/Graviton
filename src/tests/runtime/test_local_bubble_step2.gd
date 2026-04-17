extends RefCounted


static func run(ctx) -> void:
	ctx.current_suite = "test_local_bubble_step2"
	_test_no_focus_returns_inf(ctx)
	_test_focus_body_is_zero(ctx)
	_test_same_root_relative_positions(ctx)
	_test_cross_root_returns_inf(ctx)
	_test_focus_switch_flips_root_visibility(ctx)
	_test_root_local_position_is_focus_independent(ctx)
	_test_large_parent_offsets_keep_local_delta_precise(ctx)


static func _make_registry() -> Node:
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	var defs: Array[BodyDef] = [
		_root_def(&"root_a"),
		_child_def(&"star_a", &"root_a", BodyType.Kind.STAR),
		_child_def(&"planet_a1", &"star_a", BodyType.Kind.PLANET),
		_child_def(&"planet_a2", &"star_a", BodyType.Kind.PLANET),
		_root_def(&"root_b"),
		_child_def(&"star_b", &"root_b", BodyType.Kind.STAR),
		_child_def(&"planet_b1", &"star_b", BodyType.Kind.PLANET),
	]
	for def in defs:
		reg.register_body(def)

	reg.get_state(&"root_a").position_parent_frame_m = Vector3.ZERO
	reg.get_state(&"star_a").position_parent_frame_m = Vector3(1.0e12, 0.0, 0.0)
	reg.get_state(&"planet_a1").position_parent_frame_m = Vector3(100.0, 20.0, 0.0)
	reg.get_state(&"planet_a2").position_parent_frame_m = Vector3(220.0, -30.0, 0.0)

	reg.get_state(&"root_b").position_parent_frame_m = Vector3.ZERO
	reg.get_state(&"star_b").position_parent_frame_m = Vector3(-4.0e11, 0.0, 0.0)
	reg.get_state(&"planet_b1").position_parent_frame_m = Vector3(80.0, 10.0, 0.0)
	return reg


static func _make_bubble(registry: Node) -> LocalBubbleManager:
	var bubble: LocalBubbleManager = load("res://src/runtime/local_bubble/local_bubble_manager.gd").new()
	bubble.configure(registry)
	return bubble


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


static func _test_no_focus_returns_inf(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	var pos: Vector3 = bubble.compose_view_position_m(&"planet_a1")
	ctx.assert_true(_is_inf_vec3(pos), "kein Fokus liefert Vector3.INF")
	bubble.free()
	reg.free()


static func _test_focus_body_is_zero(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	bubble.set_focus(&"planet_a1")
	ctx.assert_vec_almost(
		bubble.compose_view_position_m(&"planet_a1"),
		Vector3.ZERO,
		1.0e-9,
		"Fokuskoerper liegt bei Vector3.ZERO"
	)
	bubble.free()
	reg.free()


static func _test_same_root_relative_positions(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	bubble.set_focus(&"planet_a1")

	ctx.assert_vec_almost(
		bubble.compose_view_position_m(&"planet_a2"),
		Vector3(120.0, -50.0, 0.0),
		1.0e-6,
		"Geschwister unter gleichem LCA werden korrekt relativ komponiert"
	)
	ctx.assert_vec_almost(
		bubble.compose_view_position_m(&"star_a"),
		Vector3(-100.0, -20.0, 0.0),
		1.0e-6,
		"Ancestor relativ zum Fokus korrekt"
	)

	bubble.free()
	reg.free()


static func _test_cross_root_returns_inf(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	bubble.set_focus(&"planet_a1")
	var pos: Vector3 = bubble.compose_view_position_m(&"planet_b1")
	ctx.assert_true(_is_inf_vec3(pos), "fremder Root liefert Vector3.INF")
	bubble.free()
	reg.free()


static func _test_focus_switch_flips_root_visibility(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	bubble.set_focus(&"planet_a1")
	ctx.assert_true(_is_inf_vec3(bubble.compose_view_position_m(&"planet_b1")),
		"planet_b1 ist bei Fokus auf Root A nicht lokalisierbar")
	bubble.set_focus(&"planet_b1")
	ctx.assert_true(_is_inf_vec3(bubble.compose_view_position_m(&"planet_a1")),
		"planet_a1 ist bei Fokus auf Root B nicht lokalisierbar")
	ctx.assert_vec_almost(
		bubble.compose_view_position_m(&"star_b"),
		Vector3(-80.0, -10.0, 0.0),
		1.0e-6,
		"same-root View wird nach Fokuswechsel wieder finite"
	)
	bubble.free()
	reg.free()


static func _test_root_local_position_is_focus_independent(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	var expected: Vector3 = Vector3(1.0e12 + 220.0, -30.0, 0.0)
	ctx.assert_vec_almost(
		bubble.compose_root_local_position_m(&"planet_a2"),
		expected,
		1.0e-3,
		"root-lokale Position ohne Fokus korrekt"
	)
	bubble.set_focus(&"planet_a1")
	ctx.assert_vec_almost(
		bubble.compose_root_local_position_m(&"planet_a2"),
		expected,
		1.0e-3,
		"root-lokale Position bleibt fokusunabhaengig"
	)
	bubble.free()
	reg.free()


static func _test_large_parent_offsets_keep_local_delta_precise(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	bubble.set_focus(&"planet_a1")
	var pos: Vector3 = bubble.compose_view_position_m(&"planet_a2")
	ctx.assert_vec_almost(
		pos,
		Vector3(120.0, -50.0, 0.0),
		1.0e-6,
		"LCA-Komposition behaelt 100m-Lokaldeltas trotz 1e12m-Root-Offset"
	)
	bubble.free()
	reg.free()


static func _is_inf_vec3(value: Vector3) -> bool:
	return not is_finite(value.x) and not is_finite(value.y) and not is_finite(value.z)
