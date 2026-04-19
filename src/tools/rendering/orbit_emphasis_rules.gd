extends RefCounted

const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")

const DETAIL_TAIL_START_RATIO: float = 15.0
const DETAIL_TAIL_MAX_CLOSEUP: float = 20.0


static func focus_emphasis_for(
	id: StringName,
	focus_def: BodyDef,
	registry: Node,
	topology,
	focus_closeup_ratio: float
) -> Dictionary:
	if focus_def == null:
		return {"body": 1.0, "orbit": 1.0, "trail": 1.0}

	if id == focus_def.id:
		var focus_orbit_alpha: float = clampf(0.28 / maxf(focus_closeup_ratio * 0.45, 1.0), 0.04, 0.28)
		return {"body": 1.0, "orbit": focus_orbit_alpha, "trail": 0.92}

	var def: BodyDef = registry.get_def(id)
	if def == null:
		return {"body": 1.0, "orbit": 1.0, "trail": 1.0}

	if def.parent_id == focus_def.id:
		var child_trail_alpha: float = 1.0
		if focus_def.kind == BodyType.Kind.PLANET or focus_def.kind == BodyType.Kind.MOON:
			child_trail_alpha = clampf(0.40 / maxf(focus_closeup_ratio * 0.40, 1.0), 0.02, 0.40)
		return {"body": 1.0, "orbit": 1.0, "trail": child_trail_alpha}

	if topology != null and topology.is_descendant_of(id, focus_def.id):
		return {"body": 0.90, "orbit": 0.80, "trail": 0.86}

	if topology != null and topology.is_descendant_of(focus_def.id, id):
		return {"body": 0.42, "orbit": 0.10, "trail": 0.18}

	if def.parent_id != StringName("") and def.parent_id == focus_def.parent_id:
		return {"body": 0.52, "orbit": 0.18, "trail": 0.28}

	return {"body": 0.24, "orbit": 0.06, "trail": 0.10}


static func body_detail_factor(
	id: StringName,
	def: BodyDef,
	focus_id: StringName,
	topology,
	focus_closeup_ratio: float
) -> float:
	var closeup: float = detail_closeup_for_ratio(focus_closeup_ratio)
	var weight: float = _body_closeup_weight(id, def, focus_id, topology)
	var factor: float = 1.0 + (closeup - 1.0) * weight
	return clampf(factor, 1.0, _max_body_detail_factor(def.kind))


static func detail_closeup_for_ratio(focus_closeup_ratio: float) -> float:
	var safe_ratio: float = maxf(focus_closeup_ratio, 1.0)
	if safe_ratio <= DETAIL_TAIL_START_RATIO:
		return pow(safe_ratio, 0.90)

	var tail_start_closeup: float = pow(DETAIL_TAIL_START_RATIO, 0.90)
	var tail_t: float = clampf(
		log(safe_ratio / DETAIL_TAIL_START_RATIO) / log(OrbitZoomModelScript.MAX_ZOOM_FACTOR / DETAIL_TAIL_START_RATIO),
		0.0,
		1.0
	)
	return lerpf(tail_start_closeup, DETAIL_TAIL_MAX_CLOSEUP, smoothstep(0.0, 1.0, tail_t))


static func star_closeup_phase(
	id: StringName,
	def: BodyDef,
	focus_id: StringName,
	focus_closeup_ratio: float
) -> float:
	if def == null or def.kind != BodyType.Kind.STAR or id != focus_id:
		return 0.0
	var safe_ratio: float = maxf(focus_closeup_ratio, 1.0)
	return clampf(log(safe_ratio) / log(6.0), 0.0, 1.0)


static func star_focus_scale(star_closeup_phase_value: float) -> float:
	return lerpf(1.0, 1.5, clampf(star_closeup_phase_value, 0.0, 1.0))


static func _body_closeup_weight(id: StringName, def: BodyDef, focus_id: StringName, topology) -> float:
	if def == null:
		return 0.0
	if not _shares_root_with_focus(id, focus_id, topology):
		return 0.0
	match def.kind:
		BodyType.Kind.BLACK_HOLE:
			return 0.42
		BodyType.Kind.STAR:
			return 0.72
		BodyType.Kind.MOON:
			return 1.08
		_:
			return 0.96


static func _shares_root_with_focus(id: StringName, focus_id: StringName, topology) -> bool:
	if id == focus_id:
		return true
	if topology == null:
		return false
	var focus_root: StringName = topology.root_id_of(focus_id)
	if focus_root == StringName(""):
		return false
	return topology.root_id_of(id) == focus_root


static func _max_body_detail_factor(kind: int) -> float:
	match kind:
		BodyType.Kind.BLACK_HOLE:
			return 9.0
		BodyType.Kind.STAR:
			return 15.0
		BodyType.Kind.MOON:
			return 22.0
		_:
			return 20.0
