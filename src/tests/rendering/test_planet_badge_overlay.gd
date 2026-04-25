extends RefCounted

const PlanetBadgeOverlayScript = preload("res://src/tools/rendering/planet_badge_overlay.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const NativeSpeciesServiceScript = preload("res://src/sim/life/native_species_service.gd")


class LifeDetailsRequestProbe:
	extends RefCounted

	var requested_id: StringName = &""

	func on_life_details_requested(body_id: StringName) -> void:
		requested_id = body_id


class FakeRegistry:
	extends Node

	var _defs: Dictionary = {}
	var _order: Array[StringName] = []

	func add_body(id: StringName, kind: int) -> void:
		var def := BodyDef.new()
		def.id = id
		def.kind = kind
		_defs[id] = def
		_order.append(id)

	func get_def(id: StringName) -> BodyDef:
		return _defs.get(id, null)

	func get_update_order_ref() -> Array[StringName]:
		return _order

	func get_update_order() -> Array[StringName]:
		var out: Array[StringName] = []
		out.append_array(_order)
		return out


class FakeTopology:
	extends RefCounted

	func root_id_of(id: StringName) -> StringName:
		return &"root" if id != StringName("") else StringName("")


class FakeBubble:
	extends RefCounted

	func get_focus() -> StringName:
		return &"root"


class FakeSnapshotCache:
	extends RefCounted

	signal snapshot_refreshed(reason: StringName)

	var biosphere_call_count: int = 0
	var native_call_count: int = 0

	func get_biosphere_scale_desc(_id: StringName) -> Dictionary:
		biosphere_call_count += 1
		return {
			BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
			BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: BiosphereScaleServiceScript.Stage.MICROBIAL,
			BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.SULFUR_REACTIVE,
		}

	func get_native_species_desc(_id: StringName) -> Dictionary:
		native_call_count += 1
		return {}


class FakeRenderer:
	extends RefCounted

	var metrics_call_count: int = 0
	var metrics_by_id: Dictionary = {}

	func set_metric(body_id: StringName, center_px: Vector2, projected_radius_px: float) -> void:
		metrics_by_id[body_id] = {
			"visible": true,
			"center_px": center_px,
			"projected_radius_px": projected_radius_px,
		}

	func get_body_screen_metrics(body_id: StringName) -> Dictionary:
		metrics_call_count += 1
		if not metrics_by_id.has(body_id):
			return {"visible": false}
		return metrics_by_id[body_id].duplicate(true)


static func run(ctx) -> void:
	ctx.current_suite = "test_planet_badge_overlay"
	_test_badge_lines_hide_second_row_for_prebiotic_worlds(ctx)
	_test_badge_lines_show_density_without_species_for_microbial_worlds(ctx)
	_test_badge_lines_show_density_and_species_for_complex_worlds(ctx)
	_test_badge_click_contract_and_debug_snapshot(ctx)
	_test_badge_text_layout_is_cached_for_stable_lines(ctx)
	_test_refresh_throttles_candidate_scans_but_moves_cached_badges(ctx)


static func _test_badge_lines_hide_second_row_for_prebiotic_worlds(ctx) -> void:
	var lines: PackedStringArray = PlanetBadgeOverlayScript.build_badge_text_lines({
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: BiosphereScaleServiceScript.Stage.PREBIOTIC,
	}, {})
	ctx.assert_true(lines.size() == 1, "PREBIOTIC-Badges bleiben einzeilig")
	ctx.assert_true(lines[0] == "LIFE PREBIOTIC", "PREBIOTIC-Badges tragen nur die Life-Stage")


static func _test_badge_lines_show_density_without_species_for_microbial_worlds(ctx) -> void:
	var lines: PackedStringArray = PlanetBadgeOverlayScript.build_badge_text_lines({
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: BiosphereScaleServiceScript.Stage.MICROBIAL,
		BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.SULFUR_REACTIVE,
	}, {})
	ctx.assert_true(lines.size() == 2, "MICROBIAL-Badges bekommen eine zweite Zeile fuer Density")
	ctx.assert_true(lines[0] == "LIFE MICROBIAL", "Erste Badge-Zeile zeigt die kompakte Life-Stage")
	ctx.assert_true(lines[1] == "SPARSE", "MICROBIAL-Badges zeigen ohne Species-Basis nur die Density")


static func _test_badge_lines_show_density_and_species_for_complex_worlds(ctx) -> void:
	var lines: PackedStringArray = PlanetBadgeOverlayScript.build_badge_text_lines({
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
		BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.SULFUR_REACTIVE,
	}, {
		NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS: true,
		NativeSpeciesServiceScript.KEY_METABOLISM_CLASS: NativeSpeciesServiceScript.MetabolismClass.SULFUR_CHEMOSYNTHETIC,
	})
	ctx.assert_true(lines.size() == 2, "Species-Badges behalten die zweizeilige Survey-Darstellung")
	ctx.assert_true(lines[0] == "LIFE COMPLEX", "Erste Badge-Zeile kuerzt COMPLEX_MULTICELLULAR auf COMPLEX")
	ctx.assert_true(lines[1] == "THRIVING SULFUR", "Zweite Badge-Zeile kombiniert Density und Species-Kurzform")


static func _test_badge_click_contract_and_debug_snapshot(ctx) -> void:
	var overlay = PlanetBadgeOverlayScript.new()
	var probe := LifeDetailsRequestProbe.new()
	overlay.life_details_requested.connect(probe.on_life_details_requested)
	overlay._ensure_ui()
	overlay._ensure_badge_pool()

	ctx.assert_true(overlay._root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "BadgeRoot bleibt MOUSE_FILTER_IGNORE, damit Klicks neben Badges zur Welt durchfallen")

	var badge: Dictionary = overlay._badge_pool[0]
	overlay._apply_badge(badge, {
		"body_id": &"alpha_ii",
		"center_px": Vector2(100.0, 100.0),
		"projected_radius_px": 16.0,
		"lines": PackedStringArray(["LIFE MICROBIAL", "SPARSE"]),
	}, Vector2(800.0, 600.0))

	var panel: PanelContainer = badge.get("panel", null) as PanelContainer
	var line_one: Button = badge.get("line_one", null) as Button
	var line_two: Button = badge.get("line_two", null) as Button
	ctx.assert_true(panel != null and panel.visible, "Badge-Panel wird als sichtbarer Klickbereich gerendert")
	ctx.assert_true(panel.size.x > 0.0 and panel.size.y > 0.0, "Sichtbare Badge-Panels bekommen eine echte klickbare Control-Groesse")
	ctx.assert_true(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "Sichtbare Badge-Buttons stoppen Klicks auf dem Badge")
	ctx.assert_true(line_one != null and line_one.text == "LIFE MICROBIAL", "Die sichtbare erste Badge-Zeile ist selbst ein Button")
	ctx.assert_true(line_one.size.x >= 0.0 and line_one.get_combined_minimum_size().x > 0.0, "Die Textzeile hat eine eigene Button-Hitbox")
	ctx.assert_true(line_one.mouse_filter == Control.MOUSE_FILTER_STOP, "Badge-Textbuttons stoppen Klicks direkt auf dem Text")
	ctx.assert_true(line_one.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS, "Badge-Textbuttons feuern auf Mouse-Down")
	ctx.assert_true(line_two != null and line_two.visible and line_two.text == "SPARSE", "Auch die zweite sichtbare Badge-Zeile ist klickbarer Text")
	ctx.assert_true(line_two.get_combined_minimum_size().x > 0.0, "Die zweite Textzeile hat eine eigene Button-Hitbox")
	var uses_deferred_click_routing: bool = false
	for connection_variant in line_one.get_signal_connection_list("pressed"):
		var connection: Dictionary = connection_variant
		if int(connection.get("flags", 0)) & CONNECT_DEFERRED:
			uses_deferred_click_routing = true
			break
	ctx.assert_true(uses_deferred_click_routing, "Badge-Textbuttons routen Detailsignale deferred")

	var snapshot: Dictionary = overlay.get_debug_snapshot()
	var visible_badges: Array = snapshot.get("visible_badges", [])
	ctx.assert_true(visible_badges.size() == 1, "get_debug_snapshot listet sichtbare Badge-Eintraege zielgerichtet auf")
	ctx.assert_true(visible_badges[0].get("body_id", StringName("")) == &"alpha_ii", "Debug-Badge-Eintrag traegt die Body-ID")
	ctx.assert_true(bool(visible_badges[0].get("visible", false)), "Debug-Badge-Eintrag pinnt sichtbar=true")

	overlay._on_badge_pressed(0)
	ctx.assert_true(probe.requested_id == &"alpha_ii", "Badge-Klick emittiert life_details_requested fuer den sichtbaren Body")
	PlanetBadgeOverlayScript._set_badge_visible(badge, false)
	ctx.assert_true(badge.get("body_id", &"sentinel") == StringName(""), "Versteckte Badges verlieren ihre alte Body-ID")
	overlay.free()


static func _test_badge_text_layout_is_cached_for_stable_lines(ctx) -> void:
	var overlay = PlanetBadgeOverlayScript.new()
	overlay._ensure_ui()
	overlay._ensure_badge_pool()
	var badge: Dictionary = overlay._badge_pool[0]
	var first_candidate: Dictionary = {
		"body_id": &"alpha_ii",
		"center_px": Vector2(100.0, 100.0),
		"projected_radius_px": 16.0,
		"lines": PackedStringArray(["LIFE MICROBIAL", "SPARSE"]),
	}
	overlay._apply_badge(badge, first_candidate, Vector2(800.0, 600.0))
	var first_apply_count: int = int(overlay.get_debug_snapshot().get("badge_text_apply_count", -1))
	var panel: PanelContainer = badge.get("panel", null) as PanelContainer
	var first_position: Vector2 = panel.position

	var moved_candidate: Dictionary = first_candidate.duplicate(true)
	moved_candidate["center_px"] = Vector2(180.0, 140.0)
	overlay._apply_badge(badge, moved_candidate, Vector2(800.0, 600.0))
	ctx.assert_true(
		int(overlay.get_debug_snapshot().get("badge_text_apply_count", -1)) == first_apply_count,
		"Stabile Badge-Zeilen recyceln Text/Layout statt jedes Render-Refresh neu zu messen"
	)
	ctx.assert_true(
		not panel.position.is_equal_approx(first_position),
		"Stabile Badge-Zeilen duerfen trotzdem weiter ihrer Body-Position folgen"
	)

	var changed_candidate: Dictionary = moved_candidate.duplicate(true)
	changed_candidate["lines"] = PackedStringArray(["LIFE COMPLEX", "THRIVING PHOTO"])
	overlay._apply_badge(badge, changed_candidate, Vector2(800.0, 600.0))
	ctx.assert_true(
		int(overlay.get_debug_snapshot().get("badge_text_apply_count", -1)) == first_apply_count + 1,
		"Geaenderte Badge-Zeilen erneuern Text/Layout weiterhin"
	)
	overlay.free()


static func _test_refresh_throttles_candidate_scans_but_moves_cached_badges(ctx) -> void:
	var registry := FakeRegistry.new()
	registry.add_body(&"alpha_i", BodyType.Kind.STAR)
	registry.add_body(&"alpha_ii", BodyType.Kind.PLANET)
	registry.add_body(&"alpha_iii", BodyType.Kind.MOON)
	var topology := FakeTopology.new()
	var bubble := FakeBubble.new()
	var snapshot_cache := FakeSnapshotCache.new()
	var renderer := FakeRenderer.new()
	renderer.set_metric(&"alpha_ii", Vector2.ZERO, 24.0)
	renderer.set_metric(&"alpha_iii", Vector2.ZERO, 18.0)

	var overlay = PlanetBadgeOverlayScript.new()
	overlay.configure(registry, topology, bubble, snapshot_cache, renderer)
	overlay.refresh()
	var first_snapshot: Dictionary = overlay.get_debug_snapshot()
	var first_rebuild_count: int = int(first_snapshot.get("badge_candidate_rebuild_count", -1))
	var first_biosphere_calls: int = snapshot_cache.biosphere_call_count
	var first_renderer_calls: int = renderer.metrics_call_count
	ctx.assert_true(first_rebuild_count == 1, "Erster Badge-Refresh baut Candidate-Cache genau einmal auf")
	ctx.assert_true(int(first_snapshot.get("visible_badge_count", -1)) == 2, "Erster Badge-Refresh zeigt die sichtbaren planetaren Kandidaten")
	ctx.assert_true(first_biosphere_calls == 2, "Candidate-Rebuild liest Derived-Badge-Text nur fuer planetare Kandidaten")

	overlay._last_candidate_rebuild_usec = Time.get_ticks_usec()
	renderer.set_metric(&"alpha_ii", Vector2(32.0, 16.0), 24.0)
	snapshot_cache.snapshot_refreshed.emit(&"sim_tick")
	overlay.refresh()
	var second_snapshot: Dictionary = overlay.get_debug_snapshot()
	ctx.assert_true(
		int(second_snapshot.get("badge_candidate_rebuild_count", -1)) == first_rebuild_count,
		"Sim-Tick-Dirty loest innerhalb des Badge-Cooldowns keinen neuen Full-Scan aus"
	)
	ctx.assert_true(
		snapshot_cache.biosphere_call_count == first_biosphere_calls,
		"Throttled Badge-Refresh liest Snapshot-Texte nicht erneut"
	)
	ctx.assert_true(
		renderer.metrics_call_count == first_renderer_calls + 2,
		"Throttled Badge-Refresh aktualisiert nur die zwei gecachten Badge-Positionen"
	)

	snapshot_cache.snapshot_refreshed.emit(&"focus_changed")
	overlay.refresh()
	ctx.assert_true(
		int(overlay.get_debug_snapshot().get("badge_candidate_rebuild_count", -1)) == first_rebuild_count + 1,
		"Fokus-/Kontext-Dirty erzwingt den naechsten Badge-Full-Scan sofort"
	)
	overlay.free()
	registry.free()
