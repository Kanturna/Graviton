extends RefCounted

const WorldGeneratorScript = preload("res://src/sim/world/deterministic_world_generator.gd")


class LoadProbe:
	extends RefCounted

	var loaded_world_ids: Array[StringName] = []

	func record(world_id: StringName) -> void:
		loaded_world_ids.append(world_id)


static func run(ctx) -> void:
	ctx.current_suite = "test_world_loader"
	_test_available_world_ids(ctx)
	_test_load_named_starter_world(ctx)
	_test_load_named_sample_system(ctx)
	_test_load_named_generated_system(ctx)
	_test_load_named_pilot_galaxy(ctx)
	_test_load_named_scaleup_galaxy(ctx)
	_test_load_named_scaleup_galaxy_30(ctx)
	_test_load_named_galaxy_returns_catalog(ctx)
	_test_load_named_scaleup_galaxy_returns_catalog(ctx)
	_test_load_named_scaleup_galaxy_30_returns_catalog(ctx)
	_test_materialize_galaxy_roots_preserves_unchanged_resident_states(ctx)
	_test_prepared_root_slice_cache_is_scoped_to_active_galaxy(ctx)
	_test_world_loaded_signal_emits_named_world_id(ctx)
	_test_unknown_world_id_keeps_registry_unchanged(ctx)
	_test_load_defs_accepts_two_root_world(ctx)
	_test_load_defs_rejects_dangling_parent(ctx)
	_test_load_defs_rejects_child_before_parent(ctx)
	_test_load_defs_rejects_duplicate_ids(ctx)


static func _make_loader() -> Node:
	return load("res://src/sim/world/world_loader.gd").new()


static func _make_registry() -> Node:
	return load("res://src/sim/universe/universe_registry.gd").new()


static func _root_def(id: StringName) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.STAR
	def.mass_kg = UnitSystem.SOLAR_MASS_KG
	def.radius_m = 6.957e8
	def.parent_id = &""
	def.orbit_profile = null
	return def


static func _child_def(id: StringName, parent: StringName) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.PLANET
	def.mass_kg = UnitSystem.EARTH_MASS_KG
	def.radius_m = 6.371e6
	def.parent_id = parent
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = 1.0e8
	profile.authored_period_s = 1.0e5
	profile.authored_phase_rad = 0.0
	def.orbit_profile = profile
	return def


static func _test_available_world_ids(ctx) -> void:
	var loader := _make_loader()
	var ids: Array[StringName] = loader.available_world_ids()
	ctx.assert_true(ids.size() == 6, "available_world_ids liefert genau sechs Eintraege")
	ctx.assert_true(ids[0] == &"starter_world", "starter_world steht an erster Stelle")
	ctx.assert_true(ids[1] == &"sample_system", "sample_system steht an zweiter Stelle")
	ctx.assert_true(ids[2] == &"generated_system", "generated_system steht an dritter Stelle")
	ctx.assert_true(ids[3] == &"pilot_galaxy", "pilot_galaxy steht an vierter Stelle")
	ctx.assert_true(ids[4] == &"scaleup_galaxy_10", "scaleup_galaxy_10 steht an fuenfter Stelle")
	ctx.assert_true(ids[5] == &"scaleup_galaxy_30", "scaleup_galaxy_30 steht an sechster Stelle")
	loader.free()


static func _test_load_named_starter_world(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	ctx.assert_true(loader.load_named_world(&"starter_world", reg), "starter_world laedt erfolgreich")
	ctx.assert_true(reg.body_count() == 18, "starter_world registriert 18 Bodies")
	ctx.assert_true(reg.has_body(&"obsidian"), "starter_world enthaelt Root obsidian")
	ctx.assert_true(reg.has_body(&"gamma"), "starter_world enthaelt Gamma-Def")
	ctx.assert_true(reg.has_body(&"delta"), "starter_world enthaelt Delta-Def")
	var alpha: BodyDef = reg.get_def(&"alpha")
	var alpha_i: BodyDef = reg.get_def(&"alpha_i")
	var gamma: BodyDef = reg.get_def(&"gamma")
	var gamma_ii: BodyDef = reg.get_def(&"gamma_ii")
	var gamma_iv: BodyDef = reg.get_def(&"gamma_iv")
	ctx.assert_true(alpha != null, "starter_world enthaelt Alpha-Def")
	ctx.assert_true(alpha_i != null, "starter_world enthaelt Alpha-I-Def")
	ctx.assert_true(gamma != null, "starter_world enthaelt Gamma-Def")
	ctx.assert_true(gamma_ii != null, "starter_world enthaelt Gamma-II-Def")
	ctx.assert_true(gamma_iv != null, "starter_world enthaelt Gamma-IV-Def")
	ctx.assert_almost(alpha.luminosity_w, 3.0 * UnitSystem.SOLAR_LUMINOSITY_W, 1.0e12, "starter_world setzt Alpha-Luminositaet")
	ctx.assert_almost(alpha_i.albedo, 0.28, 1.0e-9, "starter_world setzt Planeten-Albedo")
	ctx.assert_almost(gamma.mass_kg, 0.20 * UnitSystem.SOLAR_MASS_KG, 1.0e18, "starter_world setzt Gamma-Masse auf Red-Dwarf-Wert")
	ctx.assert_almost(gamma.luminosity_w, 0.0036 * UnitSystem.SOLAR_LUMINOSITY_W, 1.0e12, "starter_world setzt Gamma-Luminositaet auf Red-Dwarf-Wert")
	ctx.assert_almost(gamma_ii.north_pole_orbit_frame_azimuth_rad, PI / 3.0, 1.0e-9, "starter_world setzt Gamma-II-Saisonazimut")
	ctx.assert_almost(gamma_iv.greenhouse_delta_k, 35.0, 1.0e-9, "starter_world setzt Gamma-IV-Greenhouse fuer lokale Habitability")
	ctx.assert_almost(gamma_iv.orbit_profile.semi_major_axis_m, 9.0e9, 1.0e-3, "starter_world setzt Gamma-IV auf kompakten Orbit")
	loader.free()
	reg.free()


static func _test_load_named_sample_system(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	ctx.assert_true(loader.load_named_world(&"sample_system", reg), "sample_system laedt erfolgreich")
	ctx.assert_true(reg.body_count() == 3, "sample_system registriert 3 Bodies")
	ctx.assert_true(reg.has_body(&"sol"), "sample_system enthaelt Root sol")
	var sol: BodyDef = reg.get_def(&"sol")
	var planet_a: BodyDef = reg.get_def(&"planet_a")
	ctx.assert_true(sol != null, "sample_system enthaelt Sol-Def")
	ctx.assert_true(planet_a != null, "sample_system enthaelt Planet-A-Def")
	ctx.assert_almost(sol.luminosity_w, UnitSystem.SOLAR_LUMINOSITY_W, 1.0e12, "sample_system setzt Sol-Luminositaet")
	ctx.assert_almost(planet_a.axial_tilt_rad, 0.4091, 1.0e-9, "sample_system setzt Planet-A-Tilt")
	ctx.assert_almost(planet_a.albedo, 0.30, 1.0e-9, "sample_system setzt Planet-A-Albedo")
	loader.free()
	reg.free()


static func _test_load_named_generated_system(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	var expected_defs: Array[BodyDef] = WorldGeneratorScript.build(WorldGeneratorScript.DEFAULT_SEED)
	ctx.assert_true(loader.load_named_world(&"generated_system", reg), "generated_system laedt erfolgreich")
	ctx.assert_true(reg.body_count() == expected_defs.size(), "generated_system registriert genau die deterministische Def-Anzahl")
	ctx.assert_true(reg.has_body(&"genesis"), "generated_system enthaelt den Root genesis")
	var root: BodyDef = reg.get_def(&"genesis")
	ctx.assert_true(root != null and root.is_root(), "generated_system Root bleibt topologisch gueltig")
	loader.free()
	reg.free()


static func _test_load_named_pilot_galaxy(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	ctx.assert_true(loader.load_named_world(&"pilot_galaxy", reg), "pilot_galaxy laedt erfolgreich")
	ctx.assert_true(reg.body_count() == 18, "pilot_galaxy materialisiert im Loader-Default genau den Hero-Root")
	ctx.assert_true(reg.has_body(&"obsidian"), "pilot_galaxy enthaelt den Hero-Root")
	ctx.assert_true(not reg.has_body(&"onyx"), "pilot_galaxy laedt standardmaessig keinen zweiten Detail-Root")
	ctx.assert_true(not reg.has_body(&"umbra"), "pilot_galaxy laedt standardmaessig keinen dritten Root")
	loader.free()
	reg.free()


static func _test_load_named_scaleup_galaxy(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	ctx.assert_true(loader.load_named_world(&"scaleup_galaxy_10", reg), "scaleup_galaxy_10 laedt erfolgreich")
	ctx.assert_true(reg.body_count() == 18, "scaleup_galaxy_10 startet weiterhin mit genau einem residenten Detail-Root")
	ctx.assert_true(reg.has_body(&"obsidian"), "scaleup_galaxy_10 enthaelt den Fokus-Root obsidian")
	ctx.assert_true(not reg.has_body(&"onyx"), "scaleup_galaxy_10 laedt standardmaessig keinen zweiten Pilot-Root")
	ctx.assert_true(not reg.has_body(&"shade_01"), "scaleup_galaxy_10 laedt standardmaessig keinen Zusatz-Root")
	loader.free()
	reg.free()


static func _test_load_named_scaleup_galaxy_30(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	ctx.assert_true(loader.load_named_world(&"scaleup_galaxy_30", reg), "scaleup_galaxy_30 laedt erfolgreich")
	ctx.assert_true(reg.body_count() == 18, "scaleup_galaxy_30 startet weiterhin mit genau einem residenten Detail-Root")
	ctx.assert_true(reg.has_body(&"obsidian"), "scaleup_galaxy_30 enthaelt den Fokus-Root obsidian")
	ctx.assert_true(not reg.has_body(&"onyx"), "scaleup_galaxy_30 laedt standardmaessig keinen zweiten Pilot-Root")
	ctx.assert_true(not reg.has_body(&"shade_27"), "scaleup_galaxy_30 laedt standardmaessig keinen entfernten Zusatz-Root")
	loader.free()
	reg.free()


static func _test_load_named_galaxy_returns_catalog(ctx) -> void:
	var loader := _make_loader()
	var galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	ctx.assert_true(galaxy != null, "pilot_galaxy Catalog laedt erfolgreich")
	ctx.assert_true(galaxy.galaxy_id == &"pilot_galaxy", "Catalog meldet die korrekte Galaxy-ID")
	ctx.assert_true(galaxy.focus_root_id == &"obsidian", "Catalog setzt obsidian als Fokus-Root")
	ctx.assert_true(galaxy.root_ids().size() == 3, "Catalog enthaelt genau drei Roots")
	ctx.assert_true(galaxy.get_manifest(&"obsidian") != null, "Catalog enthaelt den Hero-Root")
	ctx.assert_true(galaxy.get_manifest(&"onyx") != null, "Catalog enthaelt den ersten generierten Root")
	ctx.assert_true(galaxy.get_manifest(&"umbra") != null, "Catalog enthaelt den zweiten generierten Root")
	ctx.assert_true(galaxy.default_resident_root_ids.size() == 1 and galaxy.default_resident_root_ids[0] == &"obsidian",
		"Catalog startet bewusst mit genau einem Detail-Root")
	loader.free()


static func _test_load_named_scaleup_galaxy_returns_catalog(ctx) -> void:
	var loader := _make_loader()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_10")
	ctx.assert_true(galaxy != null, "scaleup_galaxy_10 Catalog laedt erfolgreich")
	ctx.assert_true(galaxy.galaxy_id == &"scaleup_galaxy_10", "scaleup-Catalog meldet die korrekte Galaxy-ID")
	ctx.assert_true(galaxy.focus_root_id == &"obsidian", "scaleup-Catalog setzt obsidian als Fokus-Root")
	ctx.assert_true(galaxy.root_ids().size() == 10, "scaleup-Catalog enthaelt genau zehn Roots")
	ctx.assert_true(galaxy.get_manifest(&"obsidian") != null, "scaleup-Catalog enthaelt den Hero-Root")
	ctx.assert_true(galaxy.get_manifest(&"onyx") != null, "scaleup-Catalog behaelt den ersten Pilot-Nachbarn")
	ctx.assert_true(galaxy.get_manifest(&"umbra") != null, "scaleup-Catalog behaelt den zweiten Pilot-Nachbarn")
	ctx.assert_true(galaxy.get_manifest(&"shade_01") != null, "scaleup-Catalog enthaelt den ersten Zusatz-Root")
	ctx.assert_true(galaxy.get_manifest(&"shade_07") != null, "scaleup-Catalog enthaelt den siebten Zusatz-Root")
	ctx.assert_true(galaxy.default_resident_root_ids.size() == 1 and galaxy.default_resident_root_ids[0] == &"obsidian",
		"scaleup-Catalog startet bewusst mit genau einem Detail-Root")
	loader.free()


static func _test_load_named_scaleup_galaxy_30_returns_catalog(ctx) -> void:
	var loader := _make_loader()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_30")
	ctx.assert_true(galaxy != null, "scaleup_galaxy_30 Catalog laedt erfolgreich")
	ctx.assert_true(galaxy.galaxy_id == &"scaleup_galaxy_30", "30er-Catalog meldet die korrekte Galaxy-ID")
	ctx.assert_true(galaxy.focus_root_id == &"obsidian", "30er-Catalog setzt obsidian als Fokus-Root")
	ctx.assert_true(galaxy.root_ids().size() == 30, "30er-Catalog enthaelt genau dreissig Roots")
	ctx.assert_true(galaxy.get_manifest(&"obsidian") != null, "30er-Catalog enthaelt den Hero-Root")
	ctx.assert_true(galaxy.get_manifest(&"onyx") != null, "30er-Catalog behaelt den ersten Pilot-Nachbarn")
	ctx.assert_true(galaxy.get_manifest(&"umbra") != null, "30er-Catalog behaelt den zweiten Pilot-Nachbarn")
	ctx.assert_true(galaxy.get_manifest(&"shade_01") != null, "30er-Catalog enthaelt den ersten Zusatz-Root")
	ctx.assert_true(galaxy.get_manifest(&"shade_27") != null, "30er-Catalog enthaelt den siebenundzwanzigsten Zusatz-Root")
	ctx.assert_true(galaxy.default_resident_root_ids.size() == 1 and galaxy.default_resident_root_ids[0] == &"obsidian",
		"30er-Catalog startet bewusst mit genau einem Detail-Root")
	loader.free()


static func _test_materialize_galaxy_roots_preserves_unchanged_resident_states(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	var time_service: Node = load("res://src/core/time/time_service.gd").new()
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	orbit_service.configure(reg, time_service)
	var galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	ctx.assert_true(loader.load_named_world(&"pilot_galaxy", reg), "pilot_galaxy laedt als Delta-Materialisierungsbasis")
	orbit_service.recompute_all_at_time(1234.0)

	var preserved_focus_state: BodyState = reg.get_state(&"gamma_iv")
	ctx.assert_true(preserved_focus_state != null, "Hero-Root liefert einen persistenten Planet-BodyState")
	preserved_focus_state.current_mode = OrbitMode.Kind.NUMERIC_LOCAL

	var resident_root_ids: Array[StringName] = [&"obsidian", &"onyx"]
	ctx.assert_true(loader.materialize_galaxy_roots(galaxy, resident_root_ids, reg), "onyx laesst sich additiv zum Hero-Root materialisieren")
	ctx.assert_true(reg.has_body(&"obsidian"), "materialize_galaxy_roots behaelt den unveraenderten Fokus-Root")
	ctx.assert_true(reg.has_body(&"onyx"), "materialize_galaxy_roots registriert den neuen Nachbar-Root")
	ctx.assert_true(reg.get_state(&"gamma_iv") == preserved_focus_state, "unveraenderter Fokus-Root behaelt dieselbe BodyState-Instanz")
	ctx.assert_true(reg.get_state(&"gamma_iv").current_mode == OrbitMode.Kind.NUMERIC_LOCAL, "NUMERIC_LOCAL-Zustand ueberlebt Neighbor-Load")

	var preserved_neighbor_state: BodyState = reg.get_state(&"onyx")
	ctx.assert_true(preserved_neighbor_state != null, "materialisierter Neighbor liefert einen BodyState")

	resident_root_ids = [&"onyx"]
	ctx.assert_true(loader.materialize_galaxy_roots(galaxy, resident_root_ids, reg), "Hero-Root laesst sich gezielt wieder entladen")
	ctx.assert_true(not reg.has_body(&"obsidian"), "entfallener Hero-Root wird gezielt deregistriert")
	ctx.assert_true(reg.has_body(&"onyx"), "verbleibender Neighbor-Root bleibt resident")
	ctx.assert_true(reg.get_state(&"onyx") == preserved_neighbor_state, "unveraenderter Neighbor behaelt seine BodyState-Instanz ueber Delta-Unload")
	var seen_ids: Dictionary = {}
	for id in reg.get_update_order():
		var def: BodyDef = reg.get_def(id)
		if def.parent_id != StringName(""):
			ctx.assert_true(seen_ids.has(def.parent_id), "materialisierter Root behaelt Parent-vor-Child-Order fuer %s" % String(id))
		seen_ids[id] = true
	orbit_service.free()
	time_service.free()
	loader.free()
	reg.free()


static func _test_prepared_root_slice_cache_is_scoped_to_active_galaxy(ctx) -> void:
	var loader := _make_loader()
	var pilot_galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	loader.build_defs_for_root_manifest(pilot_galaxy.get_manifest(&"onyx"), pilot_galaxy.galaxy_id)
	loader.build_defs_for_root_manifest(pilot_galaxy.get_manifest(&"umbra"), pilot_galaxy.galaxy_id)
	ctx.assert_true(loader.get_prepared_root_slice_cache_scope_id() == &"pilot_galaxy", "Loader bindet vorbereitete Root-Slices an die aktive Pilot-Galaxy")
	ctx.assert_true(loader.get_prepared_root_slice_cache_size() == 2, "Loader cached zwei vorbereitete Pilot-Roots innerhalb desselben Galaxy-Scopes")

	var scaleup_galaxy = loader.load_named_galaxy(&"scaleup_galaxy_30")
	loader.build_defs_for_root_manifest(scaleup_galaxy.get_manifest(&"shade_01"), scaleup_galaxy.galaxy_id)
	ctx.assert_true(loader.get_prepared_root_slice_cache_scope_id() == &"scaleup_galaxy_30", "Galaxy-Wechsel setzt den Loader-Cache auf den neuen Scope um")
	ctx.assert_true(loader.get_prepared_root_slice_cache_size() == 1, "Galaxy-Wechsel verwirft alte vorbereitete Root-Slices statt galaxy-uebergreifend zu wachsen")

	loader.clear_prepared_root_slice_cache()
	ctx.assert_true(loader.get_prepared_root_slice_cache_size() == 0, "Loader kann vorbereitete Root-Slices explizit wieder leeren")
	loader.free()


static func _test_world_loaded_signal_emits_named_world_id(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	var probe := LoadProbe.new()
	loader.world_loaded.connect(probe.record)
	ctx.assert_true(loader.load_named_world(&"sample_system", reg), "sample_system laedt fuer Signaltest erfolgreich")
	ctx.assert_true(probe.loaded_world_ids.size() == 1, "world_loaded signal emittiert genau einmal")
	ctx.assert_true(probe.loaded_world_ids[0] == &"sample_system", "world_loaded signal meldet die geladene Welt-ID")
	ctx.assert_true(loader.load_named_world(&"pilot_galaxy", reg), "pilot_galaxy laedt fuer Signaltest erfolgreich")
	ctx.assert_true(probe.loaded_world_ids.size() == 2, "world_loaded signal emittiert auch fuer pilot_galaxy")
	ctx.assert_true(probe.loaded_world_ids[1] == &"pilot_galaxy", "world_loaded signal meldet auch die Galaxy-Welt-ID")
	loader.free()
	reg.free()


static func _test_unknown_world_id_keeps_registry_unchanged(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	reg.register_body(_root_def(&"existing_root"))
	reg.register_body(_child_def(&"existing_child", &"existing_root"))

	ctx.assert_true(not loader.load_named_world(&"missing_world", reg), "unbekannte Welt-ID liefert false")
	ctx.assert_true(reg.body_count() == 2, "Registry bleibt bei unbekannter Welt-ID unveraendert")
	ctx.assert_true(reg.has_body(&"existing_root"), "bestehender Root bleibt erhalten")
	ctx.assert_true(reg.has_body(&"existing_child"), "bestehendes Kind bleibt erhalten")
	loader.free()
	reg.free()


static func _test_load_defs_accepts_two_root_world(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	var defs: Array[BodyDef] = [
		_root_def(&"root_a"),
		_child_def(&"planet_a", &"root_a"),
		_root_def(&"root_b"),
		_child_def(&"planet_b", &"root_b"),
	]
	ctx.assert_true(loader.load_defs_into_registry(defs, reg), "Two-Root-Testwelt laedt erfolgreich")
	ctx.assert_true(reg.has_body(&"root_a"), "root_a vorhanden")
	ctx.assert_true(reg.has_body(&"root_b"), "root_b vorhanden")
	var order: Array[StringName] = reg.get_update_order()
	ctx.assert_true(order.find(&"root_a") < order.find(&"planet_a"), "root_a vor planet_a in update_order")
	ctx.assert_true(order.find(&"root_b") < order.find(&"planet_b"), "root_b vor planet_b in update_order")
	loader.free()
	reg.free()


static func _test_load_defs_rejects_dangling_parent(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	reg.register_body(_root_def(&"existing_root"))
	var defs: Array[BodyDef] = [
		_root_def(&"root_a"),
		_child_def(&"planet_a", &"missing_parent"),
	]
	ctx.assert_true(not loader.load_defs_into_registry(defs, reg), "dangling parent wird abgelehnt")
	ctx.assert_true(reg.body_count() == 1, "Registry bleibt bei dangling parent unveraendert")
	ctx.assert_true(reg.has_body(&"existing_root"), "bestehender Root bleibt nach dangling parent erhalten")
	loader.free()
	reg.free()


static func _test_load_defs_rejects_child_before_parent(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	reg.register_body(_root_def(&"existing_root"))
	var defs: Array[BodyDef] = [
		_child_def(&"planet_a", &"root_a"),
		_root_def(&"root_a"),
	]
	ctx.assert_true(not loader.load_defs_into_registry(defs, reg), "Kind vor Parent wird abgelehnt")
	ctx.assert_true(reg.body_count() == 1, "Registry bleibt bei Kind-vor-Parent unveraendert")
	ctx.assert_true(reg.has_body(&"existing_root"), "bestehender Root bleibt nach Reihenfolgefehler erhalten")
	loader.free()
	reg.free()


static func _test_load_defs_rejects_duplicate_ids(ctx) -> void:
	var loader := _make_loader()
	var reg := _make_registry()
	reg.register_body(_root_def(&"existing_root"))
	var defs: Array[BodyDef] = [
		_root_def(&"root_a"),
		_root_def(&"root_a"),
	]
	ctx.assert_true(not loader.load_defs_into_registry(defs, reg), "doppelte IDs werden abgelehnt")
	ctx.assert_true(reg.body_count() == 1, "Registry bleibt bei doppelter ID unveraendert")
	ctx.assert_true(reg.has_body(&"existing_root"), "bestehender Root bleibt nach Duplicate-ID erhalten")
	loader.free()
	reg.free()
