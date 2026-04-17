extends RefCounted


static func run(ctx) -> void:
	ctx.current_suite = "test_bubble_activation_set"
	_test_rebuild_without_focus_marks_all_no_lca(ctx)
	_test_rebuild_classifies_same_root_and_cross_root(ctx)
	_test_zero_radius_only_keeps_focus_active(ctx)
	_test_active_ids_follow_topological_order(ctx)
	_test_focus_changed_auto_rebuilds_without_manual_rebuild(ctx)
	_test_describe_reports_consistent_counts(ctx)


static func _make_registry() -> Node:
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	var defs: Array[BodyDef] = [
		_root_def(&"root_a"),
		_child_def(&"star_a", &"root_a", BodyType.Kind.STAR),
		_child_def(&"near_a", &"star_a", BodyType.Kind.PLANET),
		_child_def(&"far_a", &"star_a", BodyType.Kind.PLANET),
		_root_def(&"root_b"),
		_child_def(&"star_b", &"root_b", BodyType.Kind.STAR),
		_child_def(&"near_b", &"star_b", BodyType.Kind.PLANET),
	]
	for def in defs:
		reg.register_body(def)

	reg.get_state(&"root_a").position_parent_frame_m = Vector3.ZERO
	reg.get_state(&"star_a").position_parent_frame_m = Vector3(1.0e8, 0.0, 0.0)
	reg.get_state(&"near_a").position_parent_frame_m = Vector3(2.0e8, 0.0, 0.0)
	reg.get_state(&"far_a").position_parent_frame_m = Vector3(8.0e8, 0.0, 0.0)

	reg.get_state(&"root_b").position_parent_frame_m = Vector3.ZERO
	reg.get_state(&"star_b").position_parent_frame_m = Vector3(-1.0e8, 0.0, 0.0)
	reg.get_state(&"near_b").position_parent_frame_m = Vector3(1.0e8, 0.0, 0.0)
	return reg


static func _make_bubble(registry: Node) -> LocalBubbleManager:
	var bubble: LocalBubbleManager = load("res://src/runtime/local_bubble/local_bubble_manager.gd").new()
	bubble.configure(registry)
	return bubble


static func _make_activation_set(registry: Node, bubble: LocalBubbleManager) -> Node:
	var activation_set = load("res://src/runtime/local_bubble/bubble_activation_set.gd").new()
	activation_set.configure(registry, bubble)
	return activation_set


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


static func _test_rebuild_without_focus_marks_all_no_lca(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	var activation_set := _make_activation_set(reg, bubble)

	activation_set.rebuild()

	ctx.assert_true(activation_set.get_active_ids().is_empty(), "ohne Fokus ist das Aktiv-Set leer")
	for id in reg.get_update_order():
		_assert_state(ctx, activation_set, id, "INACTIVE_NO_LCA",
			"ohne Fokus klassifiziert %s als INACTIVE_NO_LCA" % String(id))

	activation_set.free()
	bubble.free()
	reg.free()


static func _test_rebuild_classifies_same_root_and_cross_root(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	bubble.set_focus(&"star_a")
	var activation_set := _make_activation_set(reg, bubble)

	activation_set.activation_radius_m = 5.0e8
	activation_set.rebuild()

	_assert_state(ctx, activation_set, &"root_a", "ACTIVE", "same-root Root innerhalb Radius ist ACTIVE")
	_assert_state(ctx, activation_set, &"star_a", "ACTIVE", "Fokuskoerper ist ACTIVE")
	_assert_state(ctx, activation_set, &"near_a", "ACTIVE", "naher same-root Body ist ACTIVE")
	_assert_state(ctx, activation_set, &"far_a", "INACTIVE_DISTANT", "ferner same-root Body ist INACTIVE_DISTANT")
	_assert_state(ctx, activation_set, &"root_b", "INACTIVE_NO_LCA", "cross-root Root ist INACTIVE_NO_LCA")
	_assert_state(ctx, activation_set, &"star_b", "INACTIVE_NO_LCA", "cross-root Stern ist INACTIVE_NO_LCA")
	_assert_state(ctx, activation_set, &"near_b", "INACTIVE_NO_LCA", "cross-root Planet ist INACTIVE_NO_LCA")

	activation_set.free()
	bubble.free()
	reg.free()


static func _test_zero_radius_only_keeps_focus_active(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	bubble.set_focus(&"star_a")
	var activation_set := _make_activation_set(reg, bubble)

	activation_set.activation_radius_m = 0.0
	activation_set.rebuild()

	var active_ids: Array[StringName] = activation_set.get_active_ids()
	ctx.assert_true(active_ids.size() == 1, "Radius 0.0 haelt genau einen Body aktiv")
	ctx.assert_true(active_ids.size() == 1 and active_ids[0] == &"star_a",
		"Radius 0.0 haelt nur den Fokuskoerper aktiv")
	_assert_state(ctx, activation_set, &"root_a", "INACTIVE_DISTANT",
		"same-root Root ausserhalb Radius 0.0 ist INACTIVE_DISTANT")
	_assert_state(ctx, activation_set, &"near_a", "INACTIVE_DISTANT",
		"same-root Nahkoerper ausserhalb Radius 0.0 ist INACTIVE_DISTANT")
	_assert_state(ctx, activation_set, &"far_a", "INACTIVE_DISTANT",
		"same-root Fernkoerper ausserhalb Radius 0.0 ist INACTIVE_DISTANT")
	_assert_state(ctx, activation_set, &"root_b", "INACTIVE_NO_LCA",
		"cross-root Root bleibt bei Radius 0.0 INACTIVE_NO_LCA")

	activation_set.free()
	bubble.free()
	reg.free()


static func _test_active_ids_follow_topological_order(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	bubble.set_focus(&"star_a")
	var activation_set := _make_activation_set(reg, bubble)

	activation_set.activation_radius_m = 5.0e8
	activation_set.rebuild()

	var active_ids: Array[StringName] = activation_set.get_active_ids()
	ctx.assert_true(active_ids.size() == 3, "bei Radius 5e8 sind drei Bodies aktiv")
	ctx.assert_true(active_ids.size() == 3 and active_ids[0] == &"root_a",
		"active_ids behaelt Parent root_a an erster Stelle")
	ctx.assert_true(active_ids.size() == 3 and active_ids[1] == &"star_a",
		"active_ids behaelt Parent star_a vor Kindern")
	ctx.assert_true(active_ids.size() == 3 and active_ids[2] == &"near_a",
		"active_ids behaelt near_a als letztes aktives Kind")

	activation_set.free()
	bubble.free()
	reg.free()


static func _test_focus_changed_auto_rebuilds_without_manual_rebuild(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	var activation_set := _make_activation_set(reg, bubble)

	activation_set.activation_radius_m = 5.0e8
	bubble.set_focus(&"star_a")
	activation_set.rebuild()
	bubble.set_focus(&"star_b")

	_assert_state(ctx, activation_set, &"root_a", "INACTIVE_NO_LCA",
		"nach Fokuswechsel wird Root A ohne manuellen rebuild INACTIVE_NO_LCA")
	_assert_state(ctx, activation_set, &"star_b", "ACTIVE",
		"nach Fokuswechsel wird star_b ohne manuellen rebuild ACTIVE")
	_assert_state(ctx, activation_set, &"near_b", "ACTIVE",
		"same-root Kind von Root B wird ohne manuellen rebuild ACTIVE")

	activation_set.free()
	bubble.free()
	reg.free()


static func _test_describe_reports_consistent_counts(ctx) -> void:
	var reg := _make_registry()
	var bubble := _make_bubble(reg)
	bubble.set_focus(&"star_a")
	var activation_set := _make_activation_set(reg, bubble)

	activation_set.activation_radius_m = 5.0e8
	activation_set.rebuild()

	var desc: Dictionary = activation_set.describe()
	ctx.assert_true(desc.get("focus_id", &"") == &"star_a", "describe meldet den aktuellen Fokus")
	ctx.assert_almost(float(desc.get("activation_radius_m", 0.0)), 5.0e8, 1.0, "describe meldet den Aktivierungsradius")
	ctx.assert_true(int(desc.get("active_count", -1)) == 3, "describe meldet drei aktive Bodies")
	ctx.assert_true(int(desc.get("inactive_distant_count", -1)) == 1, "describe meldet einen fernen same-root Body")
	ctx.assert_true(int(desc.get("inactive_no_lca_count", -1)) == 3, "describe meldet drei cross-root Bodies")

	activation_set.free()
	bubble.free()
	reg.free()


static func _assert_state(ctx, activation_set: Node, id: StringName, expected: String, label: String) -> void:
	var actual: String = activation_set.to_string_state(activation_set.classify(id))
	ctx.assert_true(actual == expected, "%s (actual=%s expected=%s)" % [label, actual, expected])
