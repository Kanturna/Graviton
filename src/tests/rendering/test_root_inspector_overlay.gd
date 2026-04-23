extends RefCounted

const RootInspectorModelBuilderScript = preload("res://src/tools/ui/root_inspector_model_builder.gd")
const RootInspectorOverlayScript = preload("res://src/tools/ui/root_inspector_overlay.gd")
const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")
const UniverseTopologyScript = preload("res://src/sim/topology/universe_topology.gd")
const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")
const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")


class BubbleProbe:
	extends Node

	signal focus_changed(new_id: StringName)

	var focus_id: StringName = &"obsidian"

	func get_focus() -> StringName:
		return focus_id

	func set_focus(body_id: StringName) -> void:
		focus_id = body_id
		focus_changed.emit(body_id)


class FocusRequestProbe:
	extends RefCounted

	var requested_id: StringName = &""

	func on_focus_requested(body_id: StringName) -> void:
		requested_id = body_id


static func run(ctx) -> void:
	ctx.current_suite = "test_root_inspector_overlay"
	_test_model_builder_builds_hierarchy_and_summary_for_starter_root(ctx)
	_test_overlay_starts_closed_and_emits_focus_requests(ctx)


static func _test_model_builder_builds_hierarchy_and_summary_for_starter_root(ctx) -> void:
	var context: Dictionary = _build_starter_root_context()
	var builder = RootInspectorModelBuilderScript.new()
	builder.configure(
		context.get("registry"),
		context.get("topology"),
		context.get("snapshot_cache")
	)

	var model: Dictionary = builder.build(&"obsidian", &"alpha_i")
	var rows: Array = model.get("rows", [])
	ctx.assert_true(String(model.get("root_name", "")) == "Obsidian", "ModelBuilder uebernimmt den sichtbaren Root-Namen")
	ctx.assert_true(int(model.get("summary", {}).get("stars", 0)) == 4, "ModelBuilder zaehlt die vier Sterne von obsidian korrekt")
	ctx.assert_true(int(model.get("summary", {}).get("planets", 0)) == 10, "ModelBuilder zaehlt die zehn Planeten des Starter-Roots korrekt")
	ctx.assert_true(int(model.get("summary", {}).get("moons", 0)) == 3, "ModelBuilder zaehlt die drei Monde des Starter-Roots korrekt")
	ctx.assert_true(rows.size() == 18, "ModelBuilder baut fuer den Starter-Root die vollstaendige 18er-Hierarchie")
	ctx.assert_true(
		_row_body_ids(rows) == [
			&"obsidian",
			&"alpha",
			&"alpha_i",
			&"alpha_i_m",
			&"alpha_ii",
			&"alpha_iii",
			&"beta",
			&"beta_i",
			&"beta_i_m",
			&"beta_ii",
			&"gamma",
			&"gamma_i",
			&"gamma_ii",
			&"gamma_ii_m",
			&"gamma_iii",
			&"gamma_iv",
			&"delta",
			&"delta_i",
		],
		"ModelBuilder baut die BH->Star->Planet->Moon-Hierarchie in stabiler Registry-Reihenfolge auf"
	)
	var gamma_iv_row: Dictionary = _row_by_body_id(rows, &"gamma_iv")
	ctx.assert_true(
		String(gamma_iv_row.get("world_text", "")) == "World: LIMITED / MODERATE / WINDOWED / TEMPERATE / SEASONAL",
		"ModelBuilder haengt fuer planetare Bodies die neue kompakte World-Zeile an"
	)
	ctx.assert_true(
		String(gamma_iv_row.get("potential_text", "")) == "Potential: WATER_CARBON / MEDIUM",
		"ModelBuilder haengt fuer planetare Bodies zusaetzlich die kompakte Potenzialzeile an"
	)

	var summary: Dictionary = model.get("summary", {})
	var expected_environment_counts: Dictionary = _environment_class_counts(context.get("snapshot_cache"), _planetary_interest_ids_for_root(context.get("registry"), context.get("topology"), &"obsidian"))
	ctx.assert_true(
		int(summary.get("habitable", 0)) == int(expected_environment_counts.get("habitable", 0)),
		"ModelBuilder zaehlt HABITABLE-Klassen exakt aus den Derived-Snapshots"
	)
	ctx.assert_true(
		int(summary.get("harsh", 0)) == int(expected_environment_counts.get("harsh", 0)),
		"ModelBuilder zaehlt HARSH-Klassen exakt aus den Derived-Snapshots"
	)
	ctx.assert_true(
		int(summary.get("hostile", 0)) == int(expected_environment_counts.get("hostile", 0)),
		"ModelBuilder zaehlt HOSTILE-Klassen exakt aus den Derived-Snapshots"
	)

	_teardown_starter_root_context(context)


static func _test_overlay_starts_closed_and_emits_focus_requests(ctx) -> void:
	var context: Dictionary = _build_starter_root_context()
	var overlay = RootInspectorOverlayScript.new()
	var focus_probe := FocusRequestProbe.new()
	overlay.focus_requested.connect(focus_probe.on_focus_requested)
	overlay.configure(
		context.get("registry"),
		context.get("topology"),
		context.get("snapshot_cache")
	)

	ctx.assert_true(not overlay.is_open(), "RootInspectorOverlay startet geschlossen")
	overlay.set_root_context(&"obsidian", &"alpha_i")
	ctx.assert_true(not overlay.is_open(), "set_root_context ohne auto_open oeffnet das Panel nicht implizit")

	overlay.set_root_context(&"obsidian", &"alpha_i", true)
	var snapshot: Dictionary = overlay.get_debug_snapshot()
	ctx.assert_true(bool(snapshot.get("is_open", false)), "auto_open macht den Inspector sichtbar")
	ctx.assert_true(snapshot.get("root_id", StringName("")) == &"obsidian", "Inspector haelt den aktuell inspizierten Root explizit im State")
	ctx.assert_true(snapshot.get("focused_body_id", StringName("")) == &"alpha_i", "Inspector tracked die aktuell fokussierte Body-Zeile")
	var row_body_ids: Array = snapshot.get("row_body_ids", [])
	ctx.assert_true(row_body_ids.size() == 18, "Inspector rendert die vollstaendige Root-Hierarchie als eingerueckte Liste")

	overlay._on_row_pressed(&"gamma_iv")
	ctx.assert_true(focus_probe.requested_id == &"gamma_iv", "Inspector-Zeilen routen Fokuswunsch ueber ein einziges focus_requested-Signal")

	overlay.close_panel()
	ctx.assert_true(not overlay.is_open(), "close_panel verbirgt das Panel wieder")
	overlay.clear_state()
	ctx.assert_true(overlay.get_debug_snapshot().get("root_id", &"sentinel") == StringName(""), "clear_state loescht den Root-Kontext fuer Welt-Wechsel hart")

	overlay.free()
	_teardown_starter_root_context(context)


static func _build_starter_root_context() -> Dictionary:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"starter_world")
	var topology = UniverseTopologyScript.new()
	topology.configure(setup.get(SimTestHarnessScript.HARNESS_KEY_REGISTRY))
	var bubble := BubbleProbe.new()
	var snapshot_cache = DerivedSnapshotCacheScript.new()
	snapshot_cache.configure(
		setup.get(SimTestHarnessScript.HARNESS_KEY_REGISTRY),
		setup.get(SimTestHarnessScript.HARNESS_KEY_TIME_SERVICE),
		bubble,
		setup.get(SimTestHarnessScript.HARNESS_KEY_LOADER),
		setup.get(SimTestHarnessScript.HARNESS_KEY_THERMAL_SERVICE),
		setup.get(SimTestHarnessScript.HARNESS_KEY_ENVIRONMENT_SERVICE),
		setup.get(SimTestHarnessScript.HARNESS_KEY_ORBIT_SERVICE),
		setup.get(SimTestHarnessScript.HARNESS_KEY_PLANETARY_STATE_SERVICE),
		setup.get(SimTestHarnessScript.HARNESS_KEY_LIFE_POTENTIAL_SERVICE)
	)
	snapshot_cache.set_interest_ids(
		_planetary_interest_ids_for_root(
			setup.get(SimTestHarnessScript.HARNESS_KEY_REGISTRY),
			topology,
			&"obsidian"
		)
	)
	return {
		"setup": setup,
		"registry": setup.get(SimTestHarnessScript.HARNESS_KEY_REGISTRY),
		"topology": topology,
		"bubble": bubble,
		"snapshot_cache": snapshot_cache,
	}


static func _teardown_starter_root_context(context: Dictionary) -> void:
	var snapshot_cache = context.get("snapshot_cache", null)
	if snapshot_cache != null:
		snapshot_cache.dispose()
	var bubble = context.get("bubble", null)
	if bubble != null:
		bubble.free()
	var setup: Dictionary = context.get("setup", {})
	SimTestHarnessScript.teardown_context(setup)
	context.clear()


static func _planetary_interest_ids_for_root(registry: Node, topology, root_id: StringName) -> Array[StringName]:
	var interest_ids: Array[StringName] = []
	for id in registry.get_update_order():
		var def: BodyDef = registry.get_def(id)
		if def == null:
			continue
		if topology.root_id_of(id) != root_id:
			continue
		if def.kind == BodyType.Kind.PLANET or def.kind == BodyType.Kind.MOON:
			interest_ids.append(id)
	return interest_ids


static func _environment_class_counts(snapshot_cache, ids: Array[StringName]) -> Dictionary:
	var counts := {
		"habitable": 0,
		"harsh": 0,
		"hostile": 0,
	}
	for id in ids:
		var desc: Dictionary = snapshot_cache.get_environment_desc(id)
		if not bool(desc.get(EnvironmentServiceScript.KEY_IS_SUPPORTED_BODY_KIND, false)):
			continue
		match int(desc.get(EnvironmentServiceScript.KEY_ENVIRONMENT_CLASS, EnvironmentServiceScript.Class.HOSTILE)):
			EnvironmentServiceScript.Class.HABITABLE:
				counts["habitable"] += 1
			EnvironmentServiceScript.Class.MARGINAL:
				counts["harsh"] += 1
			EnvironmentServiceScript.Class.HOSTILE:
				counts["hostile"] += 1
	return counts


static func _row_body_ids(rows: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for row_variant in rows:
		var row: Dictionary = row_variant
		out.append(row.get("body_id", StringName("")))
	return out


static func _row_by_body_id(rows: Array, body_id: StringName) -> Dictionary:
	for row_variant in rows:
		var row: Dictionary = row_variant
		if row.get("body_id", StringName("")) == body_id:
			return row
	return {}
