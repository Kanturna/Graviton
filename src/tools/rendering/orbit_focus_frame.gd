extends RefCounted


const OrbitOrbitGeometryScript = preload("res://src/tools/rendering/orbit_orbit_geometry.gd")


static func get_focus_frame(
	registry: Node,
	topology,
	focus_id: StringName,
	get_body_view_position: Callable
) -> Dictionary:
	if registry == null or not registry.has_body(focus_id):
		return {"center": Vector2.ZERO, "radius": 120.0}

	var focus_def: BodyDef = registry.get_def(focus_id)
	var center: Vector2 = get_body_view_position.call(focus_id)
	if not _is_finite_vec2(center):
		return {"center": Vector2.ZERO, "radius": 120.0}

	var radius: float = _minimum_focus_radius_ru(focus_def)
	var related_ids: Array[StringName] = related_ids_for_focus(registry, topology, focus_id)
	for id in related_ids:
		var def: BodyDef = registry.get_def(id)
		if id != focus_id and (def == null or def.parent_id != focus_id):
			continue

		var pos: Vector2 = get_body_view_position.call(id)
		if not _is_finite_vec2(pos):
			continue
		radius = maxf(radius, pos.distance_to(center) + 2.0)

		if id != focus_id and def != null and not def.is_root():
			var parent_center: Vector2 = get_body_view_position.call(def.parent_id)
			if not _is_finite_vec2(parent_center):
				continue
			radius = maxf(
				radius,
				parent_center.distance_to(center) + OrbitOrbitGeometryScript.orbit_extent_ru(def)
			)

	return {
		"center": center,
		"radius": radius * _focus_frame_margin(focus_def),
	}


static func related_ids_for_focus(registry: Node, topology, focus_id: StringName) -> Array[StringName]:
	if registry == null or not registry.has_body(focus_id):
		return []

	var focus_def: BodyDef = registry.get_def(focus_id)
	if focus_def == null:
		return [focus_id]

	if focus_def.is_root() or focus_def.kind == BodyType.Kind.BLACK_HOLE:
		return registry.get_update_order()

	var out: Array[StringName] = []
	var seen: Dictionary = {}
	_append_unique(out, seen, focus_id)

	if focus_def.parent_id != StringName(""):
		_append_unique(out, seen, focus_def.parent_id)

	match focus_def.kind:
		BodyType.Kind.STAR, BodyType.Kind.PLANET:
			if topology != null:
				for child_id in topology.descendants_of(focus_id):
					_append_unique(out, seen, child_id)
		BodyType.Kind.MOON:
			for sibling in registry.get_children_of(focus_def.parent_id):
				_append_unique(out, seen, sibling)
			var parent_def: BodyDef = registry.get_def(focus_def.parent_id)
			if parent_def != null and parent_def.parent_id != StringName(""):
				_append_unique(out, seen, parent_def.parent_id)

	return out


static func _append_unique(out: Array[StringName], seen: Dictionary, id: StringName) -> void:
	if seen.has(id):
		return
	seen[id] = true
	out.append(id)


static func _minimum_focus_radius_ru(focus_def: BodyDef) -> float:
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


static func _focus_frame_margin(focus_def: BodyDef) -> float:
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
