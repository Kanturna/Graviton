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


static func run(ctx) -> void:
	ctx.current_suite = "test_planet_badge_overlay"
	_test_badge_lines_hide_second_row_for_prebiotic_worlds(ctx)
	_test_badge_lines_show_density_without_species_for_microbial_worlds(ctx)
	_test_badge_lines_show_density_and_species_for_complex_worlds(ctx)
	_test_badge_click_contract_and_debug_snapshot(ctx)


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
		"lines": PackedStringArray(["LIFE PREBIOTIC"]),
	}, Vector2(800.0, 600.0))

	var panel: Button = badge.get("panel", null) as Button
	ctx.assert_true(panel != null and panel.visible, "Badge-Panel wird als klickbarer Button sichtbar")
	ctx.assert_true(panel.size.x > 0.0 and panel.size.y > 0.0, "Sichtbare Badge-Buttons bekommen eine echte klickbare Control-Groesse")
	ctx.assert_true(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "Sichtbare Badge-Buttons stoppen Klicks auf dem Badge")
	ctx.assert_true(panel.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS, "Badge-Buttons feuern auf Mouse-Down")
	var uses_deferred_click_routing: bool = false
	for connection_variant in panel.get_signal_connection_list("pressed"):
		var connection: Dictionary = connection_variant
		if int(connection.get("flags", 0)) & CONNECT_DEFERRED:
			uses_deferred_click_routing = true
			break
	ctx.assert_true(uses_deferred_click_routing, "Badge-Buttons routen Detailsignale deferred")

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
