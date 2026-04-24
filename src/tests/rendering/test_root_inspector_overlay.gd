extends RefCounted

const RootInspectorModelBuilderScript = preload("res://src/tools/ui/root_inspector_model_builder.gd")
const RootInspectorOverlayScript = preload("res://src/tools/ui/root_inspector_overlay.gd")
const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")
const UniverseTopologyScript = preload("res://src/sim/topology/universe_topology.gd")
const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")
const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const SurveyVisualThemeScript = preload("res://src/tools/ui/survey_visual_theme.gd")


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


class LifeDetailsRequestProbe:
	extends RefCounted

	var requested_id: StringName = &""

	func on_life_details_requested(body_id: StringName) -> void:
		requested_id = body_id


static func run(ctx) -> void:
	ctx.current_suite = "test_root_inspector_overlay"
	_test_model_builder_builds_hierarchy_and_summary_for_starter_root(ctx)
	_test_overlay_formats_navigation_first_rows(ctx)
	_test_overlay_starts_closed_and_emits_focus_requests(ctx)
	_test_overlay_life_chip_emits_details_without_focus_request(ctx)
	_test_overlay_throttles_sim_tick_rebuilds_but_not_user_events(ctx)
	_test_overlay_skips_identical_model_apply(ctx)


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
		String(gamma_iv_row.get("life_badge_text", "")) == "PREBIOTIC",
		"ModelBuilder legt fuer planetare Bodies nur noch das kompakte Life-Badge in der Navigator-Row ab"
	)
	ctx.assert_true(
		String(gamma_iv_row.get("detail_text", "")) == "",
		"Ohne Species-Basis gibt der ModelBuilder fuer fokussierte PLANET-Rows keine Fallback-Detailzeile aus"
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


static func _test_overlay_formats_navigation_first_rows(ctx) -> void:
	var context: Dictionary = _build_starter_root_context()
	var overlay = RootInspectorOverlayScript.new()
	overlay.configure(
		context.get("registry"),
		context.get("topology"),
		context.get("snapshot_cache")
	)
	overlay.set_root_context(&"obsidian", &"alpha", true)

	var alpha_row: PanelContainer = _find_row_panel_by_body_id(overlay, &"alpha")
	ctx.assert_true(alpha_row != null, "Overlay rendert STAR-Rows als strukturierte Row-Panels")
	ctx.assert_true(_label_text(alpha_row, "NameLabel") == "Alpha", "STAR-Row haelt den Namen in einem eigenen Label")
	ctx.assert_true(_label_text(alpha_row, "KindLabel") == "STAR", "STAR-Row haelt den Body-Kind in einem eigenen Label")
	ctx.assert_true(_find_named_descendant(alpha_row, "LifeChip") == null, "STAR-Rows tragen keinen Life-Chip")
	ctx.assert_true(_find_named_descendant(alpha_row, "EnvironmentChip") == null, "STAR-Rows tragen keinen Environment-Chip")
	ctx.assert_true(_find_named_descendant(alpha_row, "DetailLabel") == null, "STAR-Rows tragen keine World-/Species-Detailzeile")
	ctx.assert_true(_colors_close(
		_label_color(alpha_row, "NameLabel"),
		SurveyVisualThemeScript.color_for_body_kind(BodyType.Kind.STAR)
	), "STAR-Namen nutzen den warmen Survey-Farbton")

	var gamma_iv_row: PanelContainer = _find_row_panel_by_body_id(overlay, &"gamma_iv")
	ctx.assert_true(gamma_iv_row != null, "Overlay rendert PLANET-Rows als strukturierte Row-Panels")
	ctx.assert_true(
		_label_text(gamma_iv_row, "NameLabel") == "Gamma IV" and _label_text(gamma_iv_row, "KindLabel") == "PLANET",
		"Nicht fokussierte PLANET-Rows behalten Name und Kind an erster Stelle"
	)
	ctx.assert_true(
		_chip_label_text(gamma_iv_row, "EnvironmentChip") != "" and _chip_label_text(gamma_iv_row, "ClimateChip") != "",
		"PLANET-Rows trennen Environment und Climate in zwei eigene Chips"
	)
	ctx.assert_true(
		_chip_label_text(gamma_iv_row, "LifeChip") == "PREBIOTIC" and _label_text(gamma_iv_row, "NoteLabel") == "0 moons",
		"Nicht fokussierte PLANET-Rows tragen nur noch Life-Chip und Moon-Note als kompakte Zusatzinfos"
	)
	ctx.assert_true(
		_find_named_descendant(gamma_iv_row, "DetailLabel") == null,
		"Nicht fokussierte PLANET-Rows blenden die Detailzeile im Navigator aus"
	)
	ctx.assert_true(_theme_color_matches_chip(gamma_iv_row, "EnvironmentChip"), "Environment-Chip nutzt seine enum-basierte Theme-Farbe")
	ctx.assert_true(_theme_color_matches_chip(gamma_iv_row, "ClimateChip"), "Climate-Chip nutzt seine eigene enum-basierte Theme-Farbe")

	overlay.set_root_context(&"obsidian", &"gamma_iv", true)
	var focused_gamma_iv_row: PanelContainer = _find_row_panel_by_body_id(overlay, &"gamma_iv")
	ctx.assert_true(
		_label_text(focused_gamma_iv_row, "NameLabel") == "Gamma IV" and _chip_label_text(focused_gamma_iv_row, "LifeChip") == "PREBIOTIC",
		"Fokussierte PLANET-Rows ohne Species-Basis bleiben ebenfalls navigator-first"
	)
	ctx.assert_true(
		_find_named_descendant(focused_gamma_iv_row, "DetailLabel") == null,
		"Ohne Species-Basis gibt es fuer fokussierte PLANET-Rows keine Fallback-Zeile"
	)
	ctx.assert_true(
		RootInspectorOverlayScript._format_row_text({
			"name_text": "Gamma III",
			"kind_text": "PLANET",
			"badge_text": "HABITABLE / COLD",
			"life_badge_text": "ECOSYSTEM",
			"note_text": "0 moons",
			"detail_text": "Species: CRYO / ABUNDANT",
		}) == "Gamma III   PLANET   HABITABLE / COLD   ECOSYSTEM   0 moons\nSpecies: CRYO / ABUNDANT",
		"Fokussierte Species-Rows bekommen nur die definierte kompakte Zusatzzeile"
	)

	overlay.free()
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
	var alpha_row_panel: PanelContainer = _find_row_panel_by_body_id(overlay, &"alpha")
	ctx.assert_true(alpha_row_panel != null, "Overlay rendert fuer STAR-Rows klickbare Row-Panels")
	ctx.assert_true(
		alpha_row_panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		"Row-Panels stoppen gezielt Inspector-Klicks, damit Fokusnavigation nicht zur Welt durchfaellt"
	)
	var gui_connections: Array[Dictionary] = alpha_row_panel.get_signal_connection_list("gui_input")
	var uses_deferred_click_routing: bool = false
	for connection_variant in gui_connections:
		var connection: Dictionary = connection_variant
		if int(connection.get("flags", 0)) & CONNECT_DEFERRED:
			uses_deferred_click_routing = true
			break
	ctx.assert_true(
		uses_deferred_click_routing,
		"Row-Panels routen Fokuswechsel deferred, damit Rebuilds die aktive Row nicht mitten im gui_input-Signal freigeben"
	)
	var first_row_container: Control = overlay.find_children("Rows", "VBoxContainer", true, false)[0].get_child(0)

	overlay._on_row_gui_input(_left_mouse_press_event(), &"gamma_iv")
	ctx.assert_true(focus_probe.requested_id == &"gamma_iv", "Inspector-Zeilen routen Fokuswunsch ueber ein einziges focus_requested-Signal")

	overlay.close_panel()
	ctx.assert_true(not overlay.is_open(), "close_panel verbirgt das Panel wieder")
	overlay.clear_state()
	ctx.assert_true(overlay.get_debug_snapshot().get("root_id", &"sentinel") == StringName(""), "clear_state loescht den Root-Kontext fuer Welt-Wechsel hart")
	ctx.assert_true(first_row_container.is_queued_for_deletion(), "Beim Rebuild werden alte Row-Nodes nur noch per queue_free() entsorgt")

	overlay.free()
	_teardown_starter_root_context(context)


static func _test_overlay_life_chip_emits_details_without_focus_request(ctx) -> void:
	var context: Dictionary = _build_starter_root_context()
	var overlay = RootInspectorOverlayScript.new()
	var focus_probe := FocusRequestProbe.new()
	var life_probe := LifeDetailsRequestProbe.new()
	overlay.focus_requested.connect(focus_probe.on_focus_requested)
	overlay.life_details_requested.connect(life_probe.on_life_details_requested)
	overlay.configure(
		context.get("registry"),
		context.get("topology"),
		context.get("snapshot_cache")
	)
	overlay.set_root_context(&"obsidian", &"alpha", true)

	var gamma_iv_row: PanelContainer = _find_row_panel_by_body_id(overlay, &"gamma_iv")
	var life_chip: Button = _find_named_descendant(gamma_iv_row, "LifeChip") as Button
	ctx.assert_true(life_chip != null, "Planetare Life-Chips sind echte Buttons")
	ctx.assert_true(
		life_chip.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS,
		"Life-Chips feuern auf Mouse-Down wie die bisherige Inspector-Klickdisziplin"
	)
	ctx.assert_true(
		life_chip.mouse_filter == Control.MOUSE_FILTER_STOP,
		"Life-Chips stoppen das Event, damit kein Row-Fokuswechsel mit ausgeloest wird"
	)
	var uses_deferred_click_routing: bool = false
	for connection_variant in life_chip.get_signal_connection_list("pressed"):
		var connection: Dictionary = connection_variant
		if int(connection.get("flags", 0)) & CONNECT_DEFERRED:
			uses_deferred_click_routing = true
			break
	ctx.assert_true(
		uses_deferred_click_routing,
		"Life-Chips routen Detailsignale deferred, damit Rebuilds keine Button-Lifetime-Regressions ausloesen"
	)

	overlay._on_life_chip_pressed(&"gamma_iv")
	ctx.assert_true(life_probe.requested_id == &"gamma_iv", "Life-Chip emittiert life_details_requested fuer den Body")
	ctx.assert_true(focus_probe.requested_id == StringName(""), "Life-Chip emittiert keinen focus_requested-Fokuswechsel")

	overlay.free()
	_teardown_starter_root_context(context)


static func _test_overlay_throttles_sim_tick_rebuilds_but_not_user_events(ctx) -> void:
	var context: Dictionary = _build_starter_root_context()
	var overlay = RootInspectorOverlayScript.new()
	overlay.configure(context.get("registry"), context.get("topology"), context.get("snapshot_cache"))
	overlay._ready()
	overlay.set_root_context(&"obsidian", &"alpha", true)
	ctx.assert_true(overlay.is_open(), "Overlay ist fuer den Throttle-Test sichtbar geoeffnet")

	var baseline: int = int(overlay.get_debug_snapshot().get("rebuild_count", -1))
	overlay._on_snapshot_refreshed(DerivedSnapshotCacheScript.REASON_SIM_TICK)
	var after_first_tick: int = int(overlay.get_debug_snapshot().get("rebuild_count", -1))
	ctx.assert_true(
		after_first_tick == baseline + 1,
		"Erster sim_tick nach set_root_context darf sofort rebuilden"
	)
	overlay._on_snapshot_refreshed(DerivedSnapshotCacheScript.REASON_SIM_TICK)
	overlay._on_snapshot_refreshed(DerivedSnapshotCacheScript.REASON_SIM_TICK)
	var after_burst: int = int(overlay.get_debug_snapshot().get("rebuild_count", -1))
	ctx.assert_true(
		after_burst == after_first_tick,
		"Weitere sim_tick-Signale innerhalb des Cooldowns werden geschluckt"
	)
	overlay._on_snapshot_refreshed(DerivedSnapshotCacheScript.REASON_FOCUS_CHANGED)
	var after_user_event: int = int(overlay.get_debug_snapshot().get("rebuild_count", -1))
	ctx.assert_true(
		after_user_event == after_burst + 1,
		"User-Events umgehen den sim_tick-Cooldown und rebuilden sofort"
	)
	overlay._on_snapshot_refreshed(DerivedSnapshotCacheScript.REASON_WORLD_RELOAD)
	var after_world_reload: int = int(overlay.get_debug_snapshot().get("rebuild_count", -1))
	ctx.assert_true(
		after_world_reload == after_user_event + 1,
		"Welt-Reload umgeht den sim_tick-Cooldown"
	)

	overlay.set_root_context(&"obsidian", &"alpha_i", false)
	var after_set_root: int = int(overlay.get_debug_snapshot().get("rebuild_count", -1))
	overlay._on_snapshot_refreshed(DerivedSnapshotCacheScript.REASON_SIM_TICK)
	var after_post_set_root_tick: int = int(overlay.get_debug_snapshot().get("rebuild_count", -1))
	ctx.assert_true(
		after_post_set_root_tick == after_set_root + 1,
		"set_root_context setzt den Cooldown zurueck, naechster sim_tick rebuildet wieder sofort"
	)

	overlay.close_panel(false)
	var after_close: int = int(overlay.get_debug_snapshot().get("rebuild_count", -1))
	overlay._on_snapshot_refreshed(DerivedSnapshotCacheScript.REASON_SIM_TICK)
	ctx.assert_true(
		int(overlay.get_debug_snapshot().get("rebuild_count", -1)) == after_close,
		"Geschlossenes Overlay rebuildet auch bei sim_tick gar nicht"
	)

	overlay.free()
	_teardown_starter_root_context(context)


static func _test_overlay_skips_identical_model_apply(ctx) -> void:
	var context: Dictionary = _build_starter_root_context()
	var overlay = RootInspectorOverlayScript.new()
	overlay.configure(context.get("registry"), context.get("topology"), context.get("snapshot_cache"))
	overlay._ready()
	overlay.set_root_context(&"obsidian", &"alpha", true)

	var baseline_snapshot: Dictionary = overlay.get_debug_snapshot()
	var baseline_rebuild_count: int = int(baseline_snapshot.get("rebuild_count", -1))
	var baseline_apply_count: int = int(baseline_snapshot.get("model_apply_count", -1))
	overlay._on_snapshot_refreshed(DerivedSnapshotCacheScript.REASON_FOCUS_CHANGED)
	var unchanged_snapshot: Dictionary = overlay.get_debug_snapshot()
	ctx.assert_true(
		int(unchanged_snapshot.get("rebuild_count", -1)) == baseline_rebuild_count + 1,
		"Identische User-Refreshes laufen weiter durch den Rebuild-Pfad"
	)
	ctx.assert_true(
		int(unchanged_snapshot.get("model_apply_count", -1)) == baseline_apply_count,
		"Identische Inspector-Modelle werden nicht erneut auf Rows angewendet"
	)

	overlay.set_root_context(&"obsidian", &"gamma_iv", false)
	ctx.assert_true(
		int(overlay.get_debug_snapshot().get("model_apply_count", -1)) == baseline_apply_count + 1,
		"Fokuswechsel aendert die Model-Signatur und aktualisiert die Row-Fokusmarkierung weiterhin"
	)

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
		setup.get(SimTestHarnessScript.HARNESS_KEY_LIFE_POTENTIAL_SERVICE),
		setup.get(SimTestHarnessScript.HARNESS_KEY_PROTO_BIOSPHERE_SERVICE),
		setup.get(SimTestHarnessScript.HARNESS_KEY_BIOSPHERE_SCALE_SERVICE),
		setup.get(SimTestHarnessScript.HARNESS_KEY_ORBIT_READOUT_SERVICE),
		setup.get(SimTestHarnessScript.HARNESS_KEY_NATIVE_SPECIES_SERVICE),
		setup.get(SimTestHarnessScript.HARNESS_KEY_GENETIC_SPECIES_SERVICE)
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


static func _find_row_panel_by_body_id(overlay: Control, body_id: StringName) -> PanelContainer:
	for panel_variant in overlay.find_children("Row_%s" % RootInspectorOverlayScript._node_name_fragment(body_id), "PanelContainer", true, false):
		return panel_variant as PanelContainer
	return null


static func _find_named_descendant(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	for child_variant in root.find_children(node_name, "", true, false):
		return child_variant
	return null


static func _label_text(root: Node, node_name: String) -> String:
	var label: Label = _find_named_descendant(root, node_name) as Label
	return "" if label == null else label.text


static func _label_color(root: Node, node_name: String) -> Color:
	var label: Label = _find_named_descendant(root, node_name) as Label
	return Color.TRANSPARENT if label == null else label.get_theme_color("font_color")


static func _chip_label_text(root: Node, chip_name: String) -> String:
	var chip := _find_named_descendant(root, chip_name)
	if chip == null:
		return ""
	if chip is Button:
		return (chip as Button).text
	var label: Label = _find_named_descendant(chip, "Label") as Label
	return "" if label == null else label.text


static func _theme_color_matches_chip(root: Node, chip_name: String) -> bool:
	var chip := _find_named_descendant(root, chip_name)
	if chip == null:
		return false
	var label: Label = _find_named_descendant(chip, "Label") as Label
	if label == null:
		return false
	var expected: Color = Color.TRANSPARENT
	match chip_name:
		"EnvironmentChip":
			var text := label.text
			if text == "HABITABLE":
				expected = SurveyVisualThemeScript.color_for_environment_class(EnvironmentServiceScript.Class.HABITABLE)
			elif text == "HARSH":
				expected = SurveyVisualThemeScript.color_for_environment_class(EnvironmentServiceScript.Class.MARGINAL)
			elif text == "HOSTILE":
				expected = SurveyVisualThemeScript.color_for_environment_class(EnvironmentServiceScript.Class.HOSTILE)
		"ClimateChip":
			var text := label.text
			if text == "FROZEN":
				expected = SurveyVisualThemeScript.color_for_ecosystem_type(EnvironmentServiceScript.EcosystemType.FROZEN_WORLD)
			elif text == "TEMPERATE":
				expected = SurveyVisualThemeScript.color_for_ecosystem_type(EnvironmentServiceScript.EcosystemType.TEMPERATE_WORLD)
			elif text == "SEASONAL":
				expected = SurveyVisualThemeScript.color_for_ecosystem_type(EnvironmentServiceScript.EcosystemType.SEASONAL_WORLD)
			elif text == "HOT":
				expected = SurveyVisualThemeScript.color_for_ecosystem_type(EnvironmentServiceScript.EcosystemType.HOT_WORLD)
	return _colors_close(label.get_theme_color("font_color"), expected)


static func _colors_close(a: Color, b: Color) -> bool:
	return is_equal_approx(a.r, b.r) \
		and is_equal_approx(a.g, b.g) \
		and is_equal_approx(a.b, b.b) \
		and is_equal_approx(a.a, b.a)


static func _left_mouse_press_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event
