class_name RootInspectorModelBuilder
extends RefCounted


const OrbitHudFormatterScript = preload("res://src/tools/rendering/orbit_hud_formatter.gd")
const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")

var _registry: Node = null
var _topology = null
var _snapshot_cache = null


func configure(registry: Node, topology, snapshot_cache) -> void:
	assert(registry != null, "RootInspectorModelBuilder.configure: registry is null")
	assert(topology != null, "RootInspectorModelBuilder.configure: topology is null")
	assert(snapshot_cache != null, "RootInspectorModelBuilder.configure: snapshot_cache is null")
	_registry = registry
	_topology = topology
	_snapshot_cache = snapshot_cache


func build(root_id: StringName, focused_body_id: StringName) -> Dictionary:
	if _registry == null or _topology == null or _snapshot_cache == null:
		return {}
	if root_id == StringName(""):
		return {}
	var root_def: BodyDef = _registry.get_def(root_id)
	if root_def == null:
		return {}

	var rows: Array[Dictionary] = []
	var summary := {
		"stars": 0,
		"planets": 0,
		"moons": 0,
		"habitable": 0,
		"harsh": 0,
		"hostile": 0,
	}
	var children_by_parent: Dictionary = {}

	for id in _registry.get_update_order():
		if _topology.root_id_of(id) != root_id:
			continue
		var def: BodyDef = _registry.get_def(id)
		if def == null:
			continue
		if not children_by_parent.has(def.parent_id):
			children_by_parent[def.parent_id] = []
		var children: Array = children_by_parent[def.parent_id]
		children.append(id)
		children_by_parent[def.parent_id] = children

		match def.kind:
			BodyType.Kind.STAR:
				summary["stars"] += 1
			BodyType.Kind.PLANET:
				summary["planets"] += 1
			BodyType.Kind.MOON:
				summary["moons"] += 1

		var environment_desc: Dictionary = _snapshot_cache.get_environment_desc(id)
		if not bool(environment_desc.get(EnvironmentServiceScript.KEY_IS_SUPPORTED_BODY_KIND, false)):
			continue
		match int(environment_desc.get(EnvironmentServiceScript.KEY_ENVIRONMENT_CLASS, EnvironmentServiceScript.Class.HOSTILE)):
			EnvironmentServiceScript.Class.HABITABLE:
				summary["habitable"] += 1
			EnvironmentServiceScript.Class.MARGINAL:
				summary["harsh"] += 1
			EnvironmentServiceScript.Class.HOSTILE:
				summary["hostile"] += 1

	_append_rows(rows, root_id, focused_body_id, 0, children_by_parent)
	return {
		"root_id": root_id,
		"root_name": _display_name(root_def),
		"root_kind_text": BodyType.to_string_kind(root_def.kind),
		"summary": summary,
		"rows": rows,
	}


func _append_rows(
		rows: Array[Dictionary],
		body_id: StringName,
		focused_body_id: StringName,
		depth: int,
		children_by_parent: Dictionary
	) -> void:
	var def: BodyDef = _registry.get_def(body_id)
	if def == null:
		return
	var environment_desc: Dictionary = _snapshot_cache.get_environment_desc(body_id)
	var planetary_state_desc: Dictionary = _snapshot_cache.get_planetary_state_desc(body_id)
	rows.append({
		"body_id": body_id,
		"depth": depth,
		"name_text": _display_name(def),
		"kind_text": BodyType.to_string_kind(def.kind),
		"badge_text": _badge_text_for_body(def, environment_desc),
		"note_text": _note_text_for_body(body_id, def, children_by_parent),
		"world_text": _world_text_for_body(def, planetary_state_desc),
		"potential_text": _potential_text_for_body(def, _snapshot_cache.get_life_potential_desc(body_id)),
		"is_focused": body_id == focused_body_id,
	})

	var children: Array = children_by_parent.get(body_id, [])
	for child_variant in children:
		_append_rows(rows, StringName(child_variant), focused_body_id, depth + 1, children_by_parent)


func _note_text_for_body(body_id: StringName, def: BodyDef, children_by_parent: Dictionary) -> String:
	match def.kind:
		BodyType.Kind.BLACK_HOLE:
			return _count_label(_child_count_of_kind(body_id, BodyType.Kind.STAR, children_by_parent), "star", "stars")
		BodyType.Kind.STAR:
			return _count_label(_child_count_of_kind(body_id, BodyType.Kind.PLANET, children_by_parent), "planet", "planets")
		BodyType.Kind.PLANET:
			return _count_label(_child_count_of_kind(body_id, BodyType.Kind.MOON, children_by_parent), "moon", "moons")
		BodyType.Kind.MOON:
			return "moon"
	return ""


func _child_count_of_kind(parent_id: StringName, target_kind: int, children_by_parent: Dictionary) -> int:
	var count: int = 0
	var children: Array = children_by_parent.get(parent_id, [])
	for child_variant in children:
		var child_id: StringName = child_variant
		var child_def: BodyDef = _registry.get_def(child_id)
		if child_def != null and child_def.kind == target_kind:
			count += 1
	return count


static func _count_label(count: int, singular: String, plural: String) -> String:
	return "%d %s" % [count, singular if count == 1 else plural]


static func _badge_text_for_body(def: BodyDef, environment_desc: Dictionary) -> String:
	if def == null:
		return ""
	if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
		return ""
	return OrbitHudFormatterScript.format_inspector_environment_badge(environment_desc)


static func _world_text_for_body(def: BodyDef, planetary_state_desc: Dictionary) -> String:
	if def == null:
		return ""
	if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
		return ""
	return OrbitHudFormatterScript.format_inspector_world_line(planetary_state_desc)


static func _potential_text_for_body(def: BodyDef, life_potential_desc: Dictionary) -> String:
	if def == null:
		return ""
	if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
		return ""
	return OrbitHudFormatterScript.format_inspector_life_potential_line(life_potential_desc)


static func _display_name(def: BodyDef) -> String:
	if def == null:
		return ""
	return def.display_name if def.display_name != "" else String(def.id)
