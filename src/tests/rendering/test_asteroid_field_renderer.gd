extends RefCounted

const AsteroidSnapshotCacheScript = preload("res://src/runtime/derived/asteroid_snapshot_cache.gd")


class SnapshotCacheProbe:
	extends RefCounted

	var revision: int = 1
	var entries: Array = []
	var refresh_calls: int = 0

	func refresh(_reason: StringName = &"manual") -> void:
		refresh_calls += 1

	func get_source_revision() -> int:
		return revision

	func get_entries() -> Array:
		return entries.duplicate(true)


class AsteroidServiceProbe:
	extends RefCounted

	var snapshot: Dictionary = {
		"revision": 1,
		"entries": [
			{
				"id": &"ast_a",
				"root_id": &"root",
				"anchor_id": &"root",
				"spawn_origin_id": &"star",
				"x_m": 10.0,
				"y_m": 0.0,
				"z_m": 0.0,
				"radius_m": 100.0,
				"visual_class": &"silicate",
			},
			{
				"id": &"ast_b",
				"root_id": &"root",
				"anchor_id": &"root",
				"spawn_origin_id": &"star",
				"x_m": 20.0,
				"y_m": 0.0,
				"z_m": 0.0,
				"radius_m": 120.0,
				"visual_class": &"metal",
			},
		],
	}

	func get_state_snapshot() -> Dictionary:
		return snapshot


class BubbleProbe:
	extends RefCounted

	var compose_calls: int = 0

	func compose_view_position_m(id: StringName, _presentation_offset_s: float = 0.0) -> Vector3:
		compose_calls += 1
		if id == &"root":
			return Vector3(100.0, 0.0, 0.0)
		return Vector3.INF


static func run(ctx) -> void:
	ctx.current_suite = "test_asteroid_field_renderer"
	_test_renderer_keeps_trails_as_local_history(ctx)
	_test_renderer_path_composes_once_per_anchor_per_sync(ctx)
	_test_renderer_debug_snapshot_exposes_view_and_screen_bounds(ctx)
	_test_renderer_screen_bounds_cull_logic(ctx)


static func _test_renderer_keeps_trails_as_local_history(ctx) -> void:
	var renderer = load("res://src/tools/rendering/asteroid_field_renderer.gd").new()
	var cache := SnapshotCacheProbe.new()
	cache.entries = [_entry(&"ast_a", Vector3(UnitSystem.RENDER_SCALE_M_PER_UNIT * 10.0, 0.0, 0.0))]
	renderer.configure(cache)
	ctx.assert_true(renderer._trail_histories_by_id.has(&"ast_a"),
		"AsteroidFieldRenderer baut Trail-History lokal aus Snapshots")
	var first_sample: Dictionary = renderer._trail_histories_by_id[&"ast_a"][0]
	ctx.assert_true(not first_sample.has("view_position_m"),
		"Trail-History speichert keine View-Koordinaten als Wahrheit")

	cache.revision = 2
	cache.entries = [_entry(&"ast_a", Vector3(UnitSystem.RENDER_SCALE_M_PER_UNIT * 30.0, 0.0, 0.0))]
	renderer.sync_visuals_now()
	ctx.assert_true(renderer._trail_histories_by_id[&"ast_a"].size() >= 2,
		"Trail-History waechst nur im Renderer bei neuer Snapshot-Revision")

	cache.revision = 3
	cache.entries = [_entry(&"ast_b", Vector3(UnitSystem.RENDER_SCALE_M_PER_UNIT * 50.0, 0.0, 0.0))]
	renderer.sync_visuals_now()
	ctx.assert_true(not renderer._trail_histories_by_id.has(&"ast_a"),
		"Renderer entfernt Trail-History fuer verschwundene Asteroiden")
	ctx.assert_true(renderer.get_debug_snapshot().get("visible_count", 0) == 1,
		"Renderer konsumiert nur die aktuellen Snapshot-Eintraege")
	renderer.free()


static func _test_renderer_path_composes_once_per_anchor_per_sync(ctx) -> void:
	var renderer = load("res://src/tools/rendering/asteroid_field_renderer.gd").new()
	var service := AsteroidServiceProbe.new()
	var bubble := BubbleProbe.new()
	var cache = AsteroidSnapshotCacheScript.new()
	cache.configure(service, bubble)
	renderer.configure(cache)

	bubble.compose_calls = 0
	service.snapshot["revision"] = 2
	for entry in service.snapshot.get("entries", []):
		if typeof(entry) == TYPE_DICTIONARY:
			entry["x_m"] = float(entry.get("x_m", 0.0)) + UnitSystem.RENDER_SCALE_M_PER_UNIT * 2.0
	renderer.sync_visuals_now()

	ctx.assert_true(bubble.compose_calls == 1,
		"Renderer/Snapshot-Pfad komponiert pro sync genau einmal pro unique Asteroid-Anchor")
	ctx.assert_true(renderer.get_debug_snapshot().get("anchor_view_count", 0) == 1,
		"Renderer nutzt einen per-frame Anchor-View-Cache fuer Trail-Reprojektion")
	renderer.free()


static func _test_renderer_debug_snapshot_exposes_view_and_screen_bounds(ctx) -> void:
	var renderer = load("res://src/tools/rendering/asteroid_field_renderer.gd").new()
	var cache := SnapshotCacheProbe.new()
	cache.entries = [
		_entry(&"ast_a", Vector3(UnitSystem.RENDER_SCALE_M_PER_UNIT * -4.0, 0.0, 0.0)),
		_entry(&"ast_b", Vector3(UnitSystem.RENDER_SCALE_M_PER_UNIT * 8.0, UnitSystem.RENDER_SCALE_M_PER_UNIT * 2.0, 0.0)),
	]
	renderer.configure(cache)

	var debug: Dictionary = renderer.get_debug_snapshot()
	ctx.assert_true(bool(debug.get("screen_bounds_valid", false)),
		"AsteroidFieldRenderer meldet gueltige Debug-Bounds fuer finite Asteroiden")
	ctx.assert_true(int(debug.get("screen_visible_count", 0)) == 2,
		"AsteroidFieldRenderer zaehlt ohne Viewport alle finiten Asteroiden als screen-visible Diagnosepunkte")
	ctx.assert_true(float(debug.get("view_min_x_ru", 0.0)) == -4.0,
		"AsteroidFieldRenderer exponiert min View-X in Render-Units")
	ctx.assert_true(float(debug.get("view_max_x_ru", 0.0)) == 8.0,
		"AsteroidFieldRenderer exponiert max View-X in Render-Units")
	ctx.assert_true(float(debug.get("view_max_abs_ru", 0.0)) == 8.0,
		"AsteroidFieldRenderer exponiert maximale View-Distanz fuer Kamera-Diagnose")
	renderer.free()


static func _test_renderer_screen_bounds_cull_logic(ctx) -> void:
	var renderer_script = load("res://src/tools/rendering/asteroid_field_renderer.gd")
	var viewport := Vector2(100.0, 80.0)
	ctx.assert_true(renderer_script._screen_bounds_visible(Vector2(10.0, 10.0), Vector2(20.0, 20.0), viewport, 0.0),
		"AsteroidFieldRenderer-Culling behaelt sichtbare Trail-Bounds")
	ctx.assert_true(renderer_script._screen_bounds_visible(Vector2(-10.0, 20.0), Vector2(10.0, 40.0), viewport, 0.0),
		"AsteroidFieldRenderer-Culling behaelt Bounds, die den Screen schneiden")
	ctx.assert_true(not renderer_script._screen_bounds_visible(Vector2(120.0, 10.0), Vector2(140.0, 20.0), viewport, 0.0),
		"AsteroidFieldRenderer-Culling verwirft Bounds rechts ausserhalb des Screens")
	ctx.assert_true(not renderer_script._screen_bounds_visible(Vector2(-INF, 0.0), Vector2(10.0, 10.0), viewport, 0.0),
		"AsteroidFieldRenderer-Culling verwirft nicht-finite Bounds")


static func _entry(id: StringName, position_m: Vector3) -> Dictionary:
	return {
		"id": id,
		"root_id": &"root",
		"anchor_id": &"root",
		"spawn_origin_id": &"star",
		"x_m": position_m.x,
		"y_m": position_m.y,
		"z_m": position_m.z,
		"anchor_view_m": Vector3.ZERO,
		"view_position_m": position_m,
		"visual_class": &"silicate",
		"is_finite": true,
	}
