extends RefCounted


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


static func run(ctx) -> void:
	ctx.current_suite = "test_asteroid_field_renderer"
	_test_renderer_keeps_trails_as_local_history(ctx)


static func _test_renderer_keeps_trails_as_local_history(ctx) -> void:
	var renderer = load("res://src/tools/rendering/asteroid_field_renderer.gd").new()
	var cache := SnapshotCacheProbe.new()
	cache.entries = [_entry(&"ast_a", Vector3(UnitSystem.RENDER_SCALE_M_PER_UNIT * 10.0, 0.0, 0.0))]
	renderer.configure(cache)
	ctx.assert_true(renderer._trail_histories_by_id.has(&"ast_a"),
		"AsteroidFieldRenderer baut Trail-History lokal aus Snapshots")

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


static func _entry(id: StringName, position_m: Vector3) -> Dictionary:
	return {
		"id": id,
		"view_position_m": position_m,
		"visual_class": &"silicate",
		"is_finite": true,
	}
