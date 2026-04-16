extends RefCounted

# Unit-Tests fuer BubbleActivationSet.
# Kein Szenen-Laden, keine Autoloads — synthetisches Mini-System.
# MockRegistry und MockBubble emulieren die Minimal-API.


class MockRegistry:
	var _states: Dictionary = {}
	var _order: Array[StringName] = []

	func add(id: StringName, parent_id: StringName) -> void:
		var s := BodyState.new(id, parent_id)
		_states[id] = s
		_order.append(id)

	func get_state(id: StringName):
		return _states.get(id, null)

	func get_update_order() -> Array[StringName]:
		return _order.duplicate()


class MockBubble:
	extends Node

	signal focus_changed(new_id: StringName)

	var _focus_id: StringName = &""
	# id -> Vector3: feste View-Distanzen fuer Tests
	var _view_positions: Dictionary = {}

	func set_focus(id: StringName) -> void:
		_focus_id = id
		focus_changed.emit(id)

	func get_focus() -> StringName:
		return _focus_id

	func compose_view_position_m(id: StringName) -> Vector3:
		return _view_positions.get(id, Vector3.ZERO)

	func set_view_pos(id: StringName, pos: Vector3) -> void:
		_view_positions[id] = pos


static func _make_activation(registry: MockRegistry, bubble: MockBubble) -> BubbleActivationSet:
	var a := BubbleActivationSet.new()
	a.configure(registry, bubble)
	return a


static func run(ctx) -> void:
	_test_focus_always_active(ctx)
	_test_body_outside_radius_inactive(ctx)
	_test_body_on_radius_active(ctx)
	_test_radius_zero_only_focus(ctx)
	_test_radius_inf_all_active(ctx)
	_test_no_focus_empty_set(ctx)
	_test_no_lca_classified_separately(ctx)
	_test_no_mutation(ctx)
	_test_describe_not_empty(ctx)
	_test_auto_rebuild_on_focus_change(ctx)
	_test_distant_vs_no_lca_distinct(ctx)


# Fokus-Body ist immer aktiv (Distanz = 0)
static func _test_focus_always_active(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"planet_a", &"sol")
	var bub := MockBubble.new()
	bub.set_view_pos(&"planet_a", Vector3.ZERO)
	bub._focus_id = &"planet_a"
	var a := _make_activation(reg, bub)
	a.rebuild()
	ctx.assert_true(a.is_active(&"planet_a"),
		"focus_always_active: Fokus-Body ist immer aktiv")
	a.free()
	bub.free()


# Body ausserhalb Radius → INACTIVE_DISTANT
static func _test_body_outside_radius_inactive(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"planet_a", &"sol")
	reg.add(&"sol", &"")
	var bub := MockBubble.new()
	bub._focus_id = &"planet_a"
	bub.set_view_pos(&"planet_a", Vector3.ZERO)
	bub.set_view_pos(&"sol", Vector3(1.0e12, 0.0, 0.0))
	var a := _make_activation(reg, bub)
	a.set_activation_radius_m(5.0e8)
	ctx.assert_true(not a.is_active(&"sol"),
		"outside_radius: Sol ausserhalb Radius ist inaktiv")
	ctx.assert_true(
		a.get_status(&"sol") == BubbleActivationSet.ActivationStatus.INACTIVE_DISTANT,
		"outside_radius: Grund ist INACTIVE_DISTANT")
	a.free()
	bub.free()


# Body genau auf Radius → aktiv (<=)
static func _test_body_on_radius_active(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"focus", &"")
	reg.add(&"edge", &"focus")
	var bub := MockBubble.new()
	bub._focus_id = &"focus"
	bub.set_view_pos(&"focus", Vector3.ZERO)
	bub.set_view_pos(&"edge", Vector3(5.0e8, 0.0, 0.0))
	var a := _make_activation(reg, bub)
	a.set_activation_radius_m(5.0e8)
	ctx.assert_true(a.is_active(&"edge"),
		"on_radius: Body genau auf Radius ist aktiv (<=)")
	a.free()
	bub.free()


# Radius = 0 → nur Fokus aktiv
static func _test_radius_zero_only_focus(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"focus", &"")
	reg.add(&"other", &"focus")
	var bub := MockBubble.new()
	bub._focus_id = &"focus"
	bub.set_view_pos(&"focus", Vector3.ZERO)
	bub.set_view_pos(&"other", Vector3(1.0, 0.0, 0.0))
	var a := _make_activation(reg, bub)
	a.set_activation_radius_m(0.0)
	ctx.assert_true(a.is_active(&"focus"),
		"radius_zero: Fokus ist aktiv bei Radius 0")
	ctx.assert_true(not a.is_active(&"other"),
		"radius_zero: anderer Body inaktiv bei Radius 0")
	ctx.assert_true(a.get_active_ids().size() == 1,
		"radius_zero: genau 1 aktiver Body")
	a.free()
	bub.free()


# Radius = INF → alle Bodies aktiv
static func _test_radius_inf_all_active(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"a", &"")
	reg.add(&"b", &"a")
	reg.add(&"c", &"a")
	var bub := MockBubble.new()
	bub._focus_id = &"a"
	for id: StringName in [&"a", &"b", &"c"]:
		bub.set_view_pos(id, Vector3(randf() * 1.0e15, 0.0, 0.0))
	bub.set_view_pos(&"a", Vector3.ZERO)
	var a := _make_activation(reg, bub)
	a.set_activation_radius_m(INF)
	ctx.assert_true(a.get_active_ids().size() == 3,
		"radius_inf: alle Bodies aktiv bei Radius INF")
	a.free()
	bub.free()


# Kein Fokus → leeres Aktiv-Set
static func _test_no_focus_empty_set(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"body_a", &"")
	var bub := MockBubble.new()
	# focus bleibt &""
	var a := _make_activation(reg, bub)
	a.rebuild()
	ctx.assert_true(a.get_active_ids().is_empty(),
		"no_focus: leeres Aktiv-Set wenn kein Fokus gesetzt")
	ctx.assert_true(not a.is_active(&"body_a"),
		"no_focus: is_active gibt false fuer alle Bodies")
	a.free()
	bub.free()


# Vector3.INF → INACTIVE_NO_LCA
static func _test_no_lca_classified_separately(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"focus", &"")
	reg.add(&"other", &"")
	var bub := MockBubble.new()
	bub._focus_id = &"focus"
	bub.set_view_pos(&"focus", Vector3.ZERO)
	bub.set_view_pos(&"other", Vector3.INF)
	var a := _make_activation(reg, bub)
	a.set_activation_radius_m(5.0e8)
	ctx.assert_true(not a.is_active(&"other"),
		"no_lca: Body mit INF-View ist inaktiv")
	ctx.assert_true(
		a.get_status(&"other") == BubbleActivationSet.ActivationStatus.INACTIVE_NO_LCA,
		"no_lca: Grund ist INACTIVE_NO_LCA")
	a.free()
	bub.free()


# Keine BodyState-Mutation nach rebuild()
static func _test_no_mutation(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"focus", &"")
	reg.add(&"moon", &"focus")
	var bub := MockBubble.new()
	bub._focus_id = &"focus"
	bub.set_view_pos(&"focus", Vector3.ZERO)
	bub.set_view_pos(&"moon", Vector3(3.844e8, 0.0, 0.0))
	var pos_before: Vector3 = reg.get_state(&"moon").position_parent_frame_m
	var a := _make_activation(reg, bub)
	a.rebuild()
	a.rebuild()
	var pos_after: Vector3 = reg.get_state(&"moon").position_parent_frame_m
	ctx.assert_vec_almost(pos_after, pos_before, 0.0,
		"no_mutation: BodyState nach rebuild() unveraendert")
	a.free()
	bub.free()


# describe() nicht leer und informativ
static func _test_describe_not_empty(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"focus", &"")
	reg.add(&"near", &"focus")
	var bub := MockBubble.new()
	bub._focus_id = &"focus"
	bub.set_view_pos(&"focus", Vector3.ZERO)
	bub.set_view_pos(&"near", Vector3(1.0e7, 0.0, 0.0))
	var a := _make_activation(reg, bub)
	a.rebuild()
	var desc: String = a.describe()
	ctx.assert_true(desc.length() > 0, "describe: nicht leer")
	ctx.assert_true(desc.contains("radius"), "describe: enthaelt 'radius'")
	ctx.assert_true(desc.contains("active"), "describe: enthaelt 'active'")
	a.free()
	bub.free()


# Auto-Rebuild bei focus_changed Signal
static func _test_auto_rebuild_on_focus_change(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"a", &"")
	reg.add(&"b", &"a")
	var bub := MockBubble.new()
	bub._focus_id = &"a"
	bub.set_view_pos(&"a", Vector3.ZERO)
	bub.set_view_pos(&"b", Vector3(1.0e12, 0.0, 0.0))
	var a := _make_activation(reg, bub)
	a.set_activation_radius_m(5.0e8)
	ctx.assert_true(not a.is_active(&"b"),
		"auto_rebuild: b inaktiv bei Fokus a (weit weg)")
	# Fokus wechseln: b ist jetzt Fokus, View-Distanz = 0
	bub.set_view_pos(&"b", Vector3.ZERO)
	bub.set_focus(&"b")  # loest focus_changed aus → auto-rebuild
	ctx.assert_true(a.is_active(&"b"),
		"auto_rebuild: b aktiv nach Fokuswechsel auf b")
	a.free()
	bub.free()


# INACTIVE_DISTANT und INACTIVE_NO_LCA sind semantisch unterschiedlich
static func _test_distant_vs_no_lca_distinct(ctx) -> void:
	var reg := MockRegistry.new()
	reg.add(&"focus", &"")
	reg.add(&"far", &"focus")
	reg.add(&"orphan", &"")
	var bub := MockBubble.new()
	bub._focus_id = &"focus"
	bub.set_view_pos(&"focus", Vector3.ZERO)
	bub.set_view_pos(&"far", Vector3(1.0e15, 0.0, 0.0))
	bub.set_view_pos(&"orphan", Vector3.INF)
	var a := _make_activation(reg, bub)
	a.set_activation_radius_m(5.0e8)
	var status_far: BubbleActivationSet.ActivationStatus = a.get_status(&"far")
	var status_orphan: BubbleActivationSet.ActivationStatus = a.get_status(&"orphan")
	ctx.assert_true(status_far == BubbleActivationSet.ActivationStatus.INACTIVE_DISTANT,
		"distinct: 'far' ist INACTIVE_DISTANT")
	ctx.assert_true(status_orphan == BubbleActivationSet.ActivationStatus.INACTIVE_NO_LCA,
		"distinct: 'orphan' ist INACTIVE_NO_LCA")
	ctx.assert_true(status_far != status_orphan,
		"distinct: INACTIVE_DISTANT != INACTIVE_NO_LCA (keine semantische Vermischung)")
	a.free()
	bub.free()
