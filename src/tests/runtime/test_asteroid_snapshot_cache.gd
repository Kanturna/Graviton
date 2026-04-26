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
				"anchor_id": &"root",
				"spawn_origin_id": &"star",
				"x_m": 10.0,
				"y_m": 20.0,
				"z_m": 30.0,
				"radius_m": 100.0,
				"visual_class": &"silicate",
			},
			{
				"id": &"ast_b",
				"root_id": &"root",
				"anchor_id": &"root",
				"spawn_origin_id": &"star",
				"x_m": 40.0,
				"y_m": 50.0,
				"z_m": 60.0,
				"radius_m": 120.0,
				"visual_class": &"metal",
			},
			{
				"id": &"ast_foreign",
				"root_id": &"other_root",
				"anchor_id": &"other_root",
				"spawn_origin_id": &"other_star",
				"x_m": 1.0,
				"y_m": 2.0,
				"z_m": 3.0,
				"radius_m": 80.0,
				"visual_class": &"carbon",
			},
		],
	}

	func get_state_snapshot() -> Dictionary:
		return snapshot


class BubbleProbe:
	extends RefCounted

	var compose_calls: int = 0
	var focus_id: StringName = &"root"

	func get_focus() -> StringName:
		return focus_id

	func compose_view_position_m(id: StringName, _presentation_offset_s: float = 0.0) -> Vector3:
		compose_calls += 1
		if id == &"root":
			return Vector3(100.0, 200.0, 300.0)
		return Vector3.INF


static func run(ctx) -> void:
	ctx.current_suite = "test_asteroid_snapshot_cache"
	_test_cache_projects_read_only_snapshots(ctx)


static func _test_cache_projects_read_only_snapshots(ctx) -> void:
	var cache = AsteroidSnapshotCacheScript.new()
	var service := AsteroidServiceProbe.new()
	var bubble := BubbleProbe.new()
	UniverseRegistry.clear()
	_register_root(&"root")
	_register_root(&"other_root")
	var topology := UniverseTopology.new()
	topology.configure(UniverseRegistry)
	cache.configure(service, bubble, UniverseRegistry, topology)

	var entries: Array = cache.get_entries()
	ctx.assert_true(entries.size() == 3, "AsteroidSnapshotCache liefert separate Entry-Snapshots")
	var entry: Dictionary = entries[0]
	ctx.assert_true(entry.get("id", StringName("")) == &"ast_a", "AsteroidSnapshotCache uebernimmt die Asteroid-ID")
	ctx.assert_true(entry.get("view_position_m", Vector3.ZERO) == Vector3(110.0, 220.0, 330.0),
		"AsteroidSnapshotCache projiziert Anchor-View plus Root-Frame-Offset")
	ctx.assert_true(entry.get("anchor_id", StringName("")) == &"root", "AsteroidSnapshotCache exponiert den Root-Frame-Anchor")
	ctx.assert_true(entry.get("spawn_origin_id", StringName("")) == &"star", "AsteroidSnapshotCache exponiert das Spawn-Origin read-only")
	ctx.assert_true(float(entry.get("x_m", 0.0)) == 10.0 and float(entry.get("z_m", 0.0)) == 30.0,
		"AsteroidSnapshotCache reicht Root-Frame-Komponenten read-only durch")
	ctx.assert_true(entry.get("anchor_view_m", Vector3.ZERO) == Vector3(100.0, 200.0, 300.0),
		"AsteroidSnapshotCache stellt die Anchor-View-Projektion getrennt bereit")
	ctx.assert_true(bubble.compose_calls == 1,
		"AsteroidSnapshotCache komponiert pro unique anchor_id nur einmal pro Refresh")
	var foreign_entry: Dictionary = entries[2]
	ctx.assert_true(not bool(foreign_entry.get("is_finite", true)),
		"AsteroidSnapshotCache markiert fremde Root-Asteroiden als nicht finit")
	ctx.assert_true(foreign_entry.get("anchor_view_m", Vector3.ZERO) == Vector3.INF,
		"fremde Root-Asteroiden bekommen keinen Bubble-Compose-Pfad")
	ctx.assert_true(bubble.compose_calls == 1,
		"fremde Root-Asteroiden erzeugen keine zusaetzlichen Bubble-Compose-Calls")
	ctx.assert_true(cache.get_source_revision() == 7, "AsteroidSnapshotCache merkt die Sim-Revision getrennt")
	ctx.assert_true(cache.get_script() == AsteroidSnapshotCacheScript, "AsteroidSnapshotCache ist ein eigener Runtime-Helfer")
	ctx.assert_true(cache.get_script() != DerivedSnapshotCacheScript, "AsteroidSnapshotCache erweitert nicht den planetaren DerivedSnapshotCache")
	UniverseRegistry.clear()


static func _register_root(id: StringName) -> void:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.BLACK_HOLE
	def.mass_kg = 1.0
	def.radius_m = 1.0
	def.parent_id = StringName("")
	def.orbit_profile = null
	UniverseRegistry.register_body(def)
