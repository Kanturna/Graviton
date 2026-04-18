extends RefCounted


static func run(ctx) -> void:
	ctx.current_suite = "test_world_loader"
	_test_available_world_ids(ctx)
	_test_load_named_starter_world(ctx)
	_test_load_named_sample_system(ctx)
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
	ctx.assert_true(ids.size() == 2, "available_world_ids liefert genau zwei Eintraege")
	ctx.assert_true(ids[0] == &"starter_world", "starter_world steht an erster Stelle")
	ctx.assert_true(ids[1] == &"sample_system", "sample_system steht an zweiter Stelle")
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
	var gamma_ii: BodyDef = reg.get_def(&"gamma_ii")
	ctx.assert_true(alpha != null, "starter_world enthaelt Alpha-Def")
	ctx.assert_true(alpha_i != null, "starter_world enthaelt Alpha-I-Def")
	ctx.assert_true(gamma_ii != null, "starter_world enthaelt Gamma-II-Def")
	ctx.assert_almost(alpha.luminosity_w, 3.0 * UnitSystem.SOLAR_LUMINOSITY_W, 1.0e12, "starter_world setzt Alpha-Luminositaet")
	ctx.assert_almost(alpha_i.albedo, 0.28, 1.0e-9, "starter_world setzt Planeten-Albedo")
	ctx.assert_almost(gamma_ii.north_pole_orbit_frame_azimuth_rad, PI / 3.0, 1.0e-9, "starter_world setzt Gamma-II-Saisonazimut")
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
