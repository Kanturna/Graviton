extends RefCounted

const AsteroidSnapshotCacheScript = preload("res://src/runtime/derived/asteroid_snapshot_cache.gd")
const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")


class AsteroidServiceProbe:
	extends RefCounted

	var snapshot: Dictionary = {
		"revision": 7,
		"entries": [
			{
				"id": &"ast_a",
				"root_id": &"root",
				"anchor_id": &"star",
				"x_m": 10.0,
				"y_m": 20.0,
				"z_m": 30.0,
				"radius_m": 100.0,
				"visual_class": &"silicate",
			},
		],
	}

	func get_state_snapshot() -> Dictionary:
		return snapshot


class BubbleProbe:
	extends RefCounted

	func compose_view_position_m(id: StringName, _presentation_offset_s: float = 0.0) -> Vector3:
		if id == &"star":
			return Vector3(100.0, 200.0, 300.0)
		return Vector3.INF


static func run(ctx) -> void:
	ctx.current_suite = "test_asteroid_snapshot_cache"
	_test_cache_projects_read_only_snapshots(ctx)


static func _test_cache_projects_read_only_snapshots(ctx) -> void:
	var cache = AsteroidSnapshotCacheScript.new()
	var service := AsteroidServiceProbe.new()
	var bubble := BubbleProbe.new()
	cache.configure(service, bubble)

	var entries: Array = cache.get_entries()
	ctx.assert_true(entries.size() == 1, "AsteroidSnapshotCache liefert einen separaten Entry-Snapshot")
	var entry: Dictionary = entries[0]
	ctx.assert_true(entry.get("id", StringName("")) == &"ast_a", "AsteroidSnapshotCache uebernimmt die Asteroid-ID")
	ctx.assert_true(entry.get("view_position_m", Vector3.ZERO) == Vector3(110.0, 220.0, 330.0),
		"AsteroidSnapshotCache projiziert Anchor-View plus Anchor-Frame-Offset")
	ctx.assert_true(cache.get_source_revision() == 7, "AsteroidSnapshotCache merkt die Sim-Revision getrennt")
	ctx.assert_true(cache.get_script() == AsteroidSnapshotCacheScript, "AsteroidSnapshotCache ist ein eigener Runtime-Helfer")
	ctx.assert_true(cache.get_script() != DerivedSnapshotCacheScript, "AsteroidSnapshotCache erweitert nicht den planetaren DerivedSnapshotCache")
