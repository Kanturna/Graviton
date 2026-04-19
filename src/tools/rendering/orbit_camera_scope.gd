extends RefCounted


const OrbitOrbitGeometryScript = preload("res://src/tools/rendering/orbit_orbit_geometry.gd")

const SCOPE_KIND_INVALID: StringName = &"invalid"
const SCOPE_KIND_ROOT: StringName = &"root"
const SCOPE_KIND_STAR: StringName = &"star"
const SCOPE_KIND_PLANET: StringName = &"planet"
const SCOPE_KIND_MOON: StringName = &"moon"


static func get_scope_frame(
	registry: Node,
	topology,
	focus_id: StringName,
	get_body_view_position: Callable
) -> Dictionary:
	if registry == null or not registry.has_body(focus_id):
		return _default_scope_frame(focus_id)

	var focus_def: BodyDef = registry.get_def(focus_id)
	var center: Vector2 = get_body_view_position.call(focus_id)
	if focus_def == null or not _is_finite_vec2(center):
		return _default_scope_frame(focus_id)

	var scope_ids: Array[StringName] = _scope_ids_for_focus(registry, topology, focus_id, focus_def)
	var scope_set: Dictionary = {}
	for id in scope_ids:
		scope_set[id] = true

	var radius: float = _minimum_scope_radius_ru(focus_def)
	for id in scope_ids:
		var pos: Vector2 = get_body_view_position.call(id)
		if _is_finite_vec2(pos):
			radius = maxf(radius, pos.distance_to(center) + 2.0)

		var def: BodyDef = registry.get_def(id)
		if def == null or def.parent_id == StringName("") or not scope_set.has(def.parent_id):
			continue

		var parent_center: Vector2 = get_body_view_position.call(def.parent_id)
		if not _is_finite_vec2(parent_center):
			continue

		radius = maxf(
			radius,
			parent_center.distance_to(center) + OrbitOrbitGeometryScript.orbit_extent_ru(def)
		)

	return {
		"anchor_id": focus_id,
		"body_ids": scope_ids,
		"scope_kind": _scope_kind_for_focus(focus_def),
		"radius": radius * _scope_frame_margin(focus_def),
	}


static func _default_scope_frame(focus_id: StringName) -> Dictionary:
	return {
		"anchor_id": focus_id,
		"body_ids": [focus_id] if focus_id != StringName("") else [],
		"scope_kind": SCOPE_KIND_INVALID,
		"radius": 120.0,
	}


static func _scope_ids_for_focus(
	registry: Node,
	topology,
	focus_id: StringName,
	focus_def: BodyDef
) -> Array[StringName]:
	var include_ids: Dictionary = {}
	if focus_def == null:
		return []

	if focus_def.is_root() or focus_def.kind == BodyType.Kind.BLACK_HOLE:
		var root_id: StringName = focus_id
		if topology != null:
			var resolved_root_id: StringName = topology.root_id_of(focus_id)
			if resolved_root_id != StringName(""):
				root_id = resolved_root_id
		include_ids[root_id] = true
		if topology != null:
			for descendant_id in topology.descendants_of(root_id):
				include_ids[descendant_id] = true
		return _ordered_ids(registry, include_ids)

	include_ids[focus_id] = true
	match focus_def.kind:
		BodyType.Kind.STAR, BodyType.Kind.PLANET:
			if topology != null:
				for descendant_id in topology.descendants_of(focus_id):
					include_ids[descendant_id] = true
		BodyType.Kind.MOON:
			if focus_def.parent_id != StringName(""):
				include_ids[focus_def.parent_id] = true

	return _ordered_ids(registry, include_ids)


static func _ordered_ids(registry: Node, include_ids: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if registry == null:
		return out

	for id in registry.get_update_order():
		if include_ids.has(id):
			out.append(id)
	return out


static func _scope_kind_for_focus(focus_def: BodyDef) -> StringName:
	if focus_def == null:
		return SCOPE_KIND_INVALID
	if focus_def.is_root() or focus_def.kind == BodyType.Kind.BLACK_HOLE:
		return SCOPE_KIND_ROOT
	match focus_def.kind:
		BodyType.Kind.STAR:
			return SCOPE_KIND_STAR
		BodyType.Kind.PLANET:
			return SCOPE_KIND_PLANET
		BodyType.Kind.MOON:
			return SCOPE_KIND_MOON
		_:
			return SCOPE_KIND_INVALID


static func _minimum_scope_radius_ru(focus_def: BodyDef) -> float:
	if focus_def == null:
		return 8.0
	match focus_def.kind:
		BodyType.Kind.BLACK_HOLE:
			return 12.0
		BodyType.Kind.STAR:
			return 4.6
		BodyType.Kind.MOON:
			return 1.8
		_:
			return 2.8


static func _scope_frame_margin(focus_def: BodyDef) -> float:
	if focus_def == null:
		return 1.18
	match focus_def.kind:
		BodyType.Kind.BLACK_HOLE:
			return 1.16
		BodyType.Kind.STAR:
			return 1.10
		BodyType.Kind.MOON:
			return 1.04
		_:
			return 1.06


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
