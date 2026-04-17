class_name OrbitViewRenderer
extends Node2D

const ORBIT_SAMPLE_COUNT: int = 120
const TRAIL_LINE_WIDTH_PX: float = 2.0
const MIN_TRAIL_STEP_PX: float = 1.2

const BODY_VISUAL_SCRIPT := preload("res://src/tools/rendering/orbit_body_visual.gd")

@onready var _orbit_layer: Node2D = $OrbitLayer
@onready var _trail_layer: Node2D = $TrailLayer
@onready var _body_layer: Node2D = $BodyLayer

var _registry: Node = null
var _bubble: Node = null

var _body_visuals: Dictionary = {}
var _orbit_visuals: Dictionary = {}
var _trail_visuals: Dictionary = {}
var _trail_histories: Dictionary = {}

var _world_scale: float = 1.0
var _focus_id: StringName = &""
var _zoom_bias: float = 1.0


func configure(registry: Node, bubble: Node) -> void:
	_registry = registry
	_bubble = bubble
	_rebuild_visuals()


func set_focus(body_id: StringName) -> void:
	_focus_id = body_id
	for id in _body_visuals.keys():
		var visual: Node2D = _body_visuals[id]
		if visual != null:
			visual.set_focused(id == body_id)
	_apply_focus_emphasis()


func set_world_scale(value: float) -> void:
	_world_scale = maxf(value, 0.001)
	_apply_line_widths()


func set_zoom_bias(value: float) -> void:
	var new_val: float = maxf(value, 0.01)
	if is_equal_approx(new_val, _zoom_bias):
		return
	_zoom_bias = new_val
	_apply_focus_emphasis()


func get_body_view_position_ru(id: StringName) -> Vector2:
	if _bubble == null:
		return Vector2.ZERO
	var view_m: Vector3 = _bubble.compose_view_position_m(id)
	return Vector2(view_m.x, view_m.y) / UnitSystem.RENDER_SCALE_M_PER_UNIT


func get_focus_frame(focus_id: StringName) -> Dictionary:
	if _registry == null or not _registry.has_body(focus_id):
		return {"center": Vector2.ZERO, "radius": 120.0}

	var focus_def: BodyDef = _registry.get_def(focus_id)
	var center: Vector2 = get_body_view_position_ru(focus_id)
	var radius: float = _minimum_focus_radius_ru(focus_def)
	var related_ids: Array[StringName] = _related_ids_for_focus(focus_id)

	for id in related_ids:
		var def: BodyDef = _registry.get_def(id)
		# Only the focus body and its direct children set the zoom frame.
		# Ancestors and grandchildren are in related_ids for visual context but
		# must not drive zoom — in world-space coordinates they are far away and
		# would inflate the radius to system-wide scale even for moon/planet focus.
		if id != focus_id and (def == null or def.parent_id != focus_id):
			continue
		var pos: Vector2 = get_body_view_position_ru(id)
		radius = maxf(radius, pos.distance_to(center) + 2.0)
		# Orbit extent only for direct children (not the focus body's own orbit).
		if id != focus_id and def != null and not def.is_root():
			var parent_center: Vector2 = get_body_view_position_ru(def.parent_id)
			radius = maxf(radius, parent_center.distance_to(center) + _orbit_extent_ru(def))

	return {
		"center": center,
		"radius": radius * _focus_frame_margin(focus_def),
	}


func clear_trails() -> void:
	_trail_histories.clear()
	for line in _trail_visuals.values():
		if line != null:
			line.points = PackedVector2Array()


func _ready() -> void:
	_apply_line_widths()


func _process(_delta: float) -> void:
	_sync_visual_positions()


func _rebuild_visuals() -> void:
	_clear_layer(_orbit_layer)
	_clear_layer(_trail_layer)
	_clear_layer(_body_layer)

	_body_visuals.clear()
	_orbit_visuals.clear()
	_trail_visuals.clear()
	_trail_histories.clear()

	if _registry == null:
		return

	for id in _registry.get_update_order():
		var def: BodyDef = _registry.get_def(id)
		if def == null:
			continue

		if not def.is_root():
			var orbit_line := AntialiasedLine2D.new()
			orbit_line.name = "%sOrbit" % id
			orbit_line.default_color = _orbit_color(def.kind)
			orbit_line.closed = false
			orbit_line.points = _build_orbit_points(def)
			orbit_line.z_index = -6
			_orbit_layer.add_child(orbit_line)
			_orbit_visuals[id] = {
				"line": orbit_line,
				"parent_id": def.parent_id,
				"kind": def.kind,
			}

		var trail_line := AntialiasedLine2D.new()
		trail_line.name = "%sTrail" % id
		trail_line.gradient = _trail_gradient(def.kind)
		trail_line.z_index = -2
		_trail_layer.add_child(trail_line)
		_trail_visuals[id] = trail_line
		_trail_histories[id] = []

		var body_visual = BODY_VISUAL_SCRIPT.new()
		body_visual.name = String(id)
		body_visual.configure(def.kind)
		body_visual.z_index = _body_z_index(def.kind)
		_body_layer.add_child(body_visual)
		_body_visuals[id] = body_visual

	_apply_line_widths()
	_sync_visual_positions(true)
	set_focus(_focus_id)


func _sync_visual_positions(reset_trails: bool = false) -> void:
	if _registry == null or _bubble == null:
		return

	for id in _registry.get_update_order():
		var def: BodyDef = _registry.get_def(id)
		if def == null:
			continue

		var pos: Vector2 = get_body_view_position_ru(id)
		var visual: OrbitBodyVisual = _body_visuals.get(id, null)
		if visual != null:
			visual.position = pos
			var detail_factor: float = _body_detail_factor(id, def)
			visual.scale = Vector2.ONE * (detail_factor / _world_scale)
			visual.set_detail_factor(detail_factor)

		var orbit_entry: Dictionary = _orbit_visuals.get(id, {})
		if not orbit_entry.is_empty():
			var orbit_line: AntialiasedLine2D = orbit_entry.get("line", null)
			var parent_id: StringName = orbit_entry.get("parent_id", &"")
			if orbit_line != null:
				orbit_line.position = get_body_view_position_ru(parent_id)

		_update_trail(id, pos, reset_trails)


func _apply_focus_emphasis() -> void:
	if _registry == null:
		return

	var focus_def: BodyDef = _registry.get_def(_focus_id)
	var show_all: bool = focus_def == null or focus_def.is_root()

	for id in _body_visuals.keys():
		var body_alpha: float = 1.0
		var orbit_alpha: float = 1.0
		var trail_alpha: float = 1.0

		if not show_all:
			var emphasis: Dictionary = _focus_emphasis_for(id, focus_def)
			body_alpha = float(emphasis.get("body", 1.0))
			orbit_alpha = float(emphasis.get("orbit", 1.0))
			trail_alpha = float(emphasis.get("trail", 1.0))

		var body_visual: CanvasItem = _body_visuals.get(id, null)
		if body_visual != null:
			body_visual.modulate = Color(1.0, 1.0, 1.0, body_alpha)

		var orbit_entry: Dictionary = _orbit_visuals.get(id, {})
		var orbit_line: CanvasItem = orbit_entry.get("line", null)
		if orbit_line != null:
			orbit_line.modulate = Color(1.0, 1.0, 1.0, orbit_alpha)

		var trail_line: CanvasItem = _trail_visuals.get(id, null)
		if trail_line != null:
			trail_line.modulate = Color(1.0, 1.0, 1.0, trail_alpha)


func _focus_emphasis_for(id: StringName, focus_def: BodyDef) -> Dictionary:
	if focus_def == null:
		return {"body": 1.0, "orbit": 1.0, "trail": 1.0}

	if id == focus_def.id:
		var focus_orbit_alpha: float = clampf(0.28 / maxf(_zoom_bias * 0.45, 1.0), 0.04, 0.28)
		return {"body": 1.0, "orbit": focus_orbit_alpha, "trail": 0.92}

	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return {"body": 1.0, "orbit": 1.0, "trail": 1.0}

	if def.parent_id == focus_def.id:
		var child_trail_alpha: float = 1.0
		if focus_def.kind == BodyType.Kind.PLANET or focus_def.kind == BodyType.Kind.MOON:
			child_trail_alpha = clampf(0.40 / maxf(_zoom_bias * 0.40, 1.0), 0.02, 0.40)
		return {"body": 1.0, "orbit": 1.0, "trail": child_trail_alpha}

	if _is_descendant_of(id, focus_def.id):
		return {"body": 0.90, "orbit": 0.80, "trail": 0.86}

	if _is_descendant_of(focus_def.id, id):
		return {"body": 0.42, "orbit": 0.10, "trail": 0.18}

	if def.parent_id != StringName("") and def.parent_id == focus_def.parent_id:
		return {"body": 0.52, "orbit": 0.18, "trail": 0.28}

	return {"body": 0.24, "orbit": 0.06, "trail": 0.10}


func _is_descendant_of(candidate_id: StringName, ancestor_id: StringName) -> bool:
	if _registry == null or candidate_id == ancestor_id or ancestor_id == StringName(""):
		return false

	var def: BodyDef = _registry.get_def(candidate_id)
	if def == null:
		return false

	var cursor: StringName = def.parent_id
	var hop_limit: int = 64
	while cursor != StringName("") and hop_limit > 0:
		if cursor == ancestor_id:
			return true
		var cursor_def: BodyDef = _registry.get_def(cursor)
		if cursor_def == null:
			break
		cursor = cursor_def.parent_id
		hop_limit -= 1
	return false


func _body_detail_factor(id: StringName, def: BodyDef) -> float:
	var closeup: float = clampf(pow(_zoom_bias, 0.90), 1.0, 12.0)
	var weight: float = _body_closeup_weight(id, def)
	var factor: float = 1.0 + (closeup - 1.0) * weight
	return clampf(factor, 1.0, _max_body_detail_factor(def.kind))


func _body_closeup_weight(id: StringName, def: BodyDef) -> float:
	if id == _focus_id:
		match def.kind:
			BodyType.Kind.BLACK_HOLE:
				return 0.42
			BodyType.Kind.STAR:
				return 0.72
			BodyType.Kind.MOON:
				return 1.08
			_:
				return 0.96

	if def.parent_id == _focus_id:
		match def.kind:
			BodyType.Kind.MOON:
				return 0.48
			BodyType.Kind.PLANET:
				return 0.42
			_:
				return 0.28

	if _is_descendant_of(id, _focus_id):
		return 0.24

	return 0.0


static func _max_body_detail_factor(kind: int) -> float:
	match kind:
		BodyType.Kind.BLACK_HOLE:
			return 4.0
		BodyType.Kind.STAR:
			return 8.5
		BodyType.Kind.MOON:
			return 12.0
		_:
			return 10.0


func _update_trail(id: StringName, pos: Vector2, reset_trails: bool) -> void:
	var line: AntialiasedLine2D = _trail_visuals.get(id, null)
	if line == null:
		return

	var history: Array = _trail_histories.get(id, [])
	if reset_trails or history.is_empty():
		history = [pos]
	else:
		var threshold: float = MIN_TRAIL_STEP_PX / _world_scale
		var last_pos: Vector2 = history[history.size() - 1]
		if last_pos.distance_to(pos) >= threshold:
			history.append(pos)
		else:
			history[history.size() - 1] = pos

		var def: BodyDef = _registry.get_def(id)
		var max_points: int = _trail_point_budget(def.kind if def != null else BodyType.Kind.PLANET)
		while history.size() > max_points:
			history.pop_front()

	_trail_histories[id] = history
	line.points = PackedVector2Array(history)


func _apply_line_widths() -> void:
	for line in _trail_visuals.values():
		if line != null:
			line.width = TRAIL_LINE_WIDTH_PX / _world_scale
	for entry in _orbit_visuals.values():
		var line: AntialiasedLine2D = entry.get("line", null)
		var kind: int = entry.get("kind", BodyType.Kind.PLANET)
		if line != null:
			line.width = _orbit_line_width(kind) / _world_scale


func _build_orbit_points(def: BodyDef) -> PackedVector2Array:
	var profile: OrbitProfile = def.orbit_profile
	if profile == null:
		return PackedVector2Array()

	var points: PackedVector2Array = PackedVector2Array()
	for i in range(ORBIT_SAMPLE_COUNT):
		var t: float = float(i) / float(ORBIT_SAMPLE_COUNT)
		var point_m: Vector3 = Vector3.ZERO
		match profile.mode:
			OrbitMode.Kind.AUTHORED_ORBIT:
				point_m = OrbitMath.authored_circular_position(
					profile.authored_radius_m,
					1.0,
					t * TAU,
					0.0
				)
			OrbitMode.Kind.KEPLER_APPROX:
				var mean_anomaly: float = t * TAU
				var ecc_anom: float = OrbitMath.solve_kepler(mean_anomaly, profile.eccentricity)
				var nu: float = OrbitMath.true_anomaly_from_eccentric(ecc_anom, profile.eccentricity)
				var plane: Vector2 = OrbitMath.position_in_orbit_plane(
					profile.semi_major_axis_m,
					profile.eccentricity,
					nu
				)
				point_m = OrbitMath.rotate_to_3d(
					plane,
					profile.inclination_rad,
					profile.longitude_ascending_node_rad,
					profile.argument_periapsis_rad
				)
			_:
				point_m = Vector3.ZERO
		points.append(Vector2(point_m.x, point_m.y) / UnitSystem.RENDER_SCALE_M_PER_UNIT)

	if points.size() >= 3:
		return AntialiasedLine2D.construct_closed_line(points)
	return points


func _related_ids_for_focus(focus_id: StringName) -> Array[StringName]:
	if _registry == null or not _registry.has_body(focus_id):
		return []

	var result_map: Dictionary = {}
	result_map[focus_id] = true

	var focus_def: BodyDef = _registry.get_def(focus_id)
	if focus_def == null:
		var fallback: Array[StringName] = []
		fallback.append(focus_id)
		return fallback

	if focus_def.is_root() or focus_def.kind == BodyType.Kind.BLACK_HOLE:
		for id in _registry.get_update_order():
			result_map[id] = true
		return _dict_keys_to_string_names(result_map)

	if focus_def.parent_id != StringName(""):
		result_map[focus_def.parent_id] = true

	match focus_def.kind:
		BodyType.Kind.STAR:
			_collect_descendants(focus_id, result_map)
		BodyType.Kind.PLANET:
			_collect_descendants(focus_id, result_map)
		BodyType.Kind.MOON:
			for sibling in _registry.get_children_of(focus_def.parent_id):
				result_map[sibling] = true
			var parent_def: BodyDef = _registry.get_def(focus_def.parent_id)
			if parent_def != null and parent_def.parent_id != StringName(""):
				result_map[parent_def.parent_id] = true

	return _dict_keys_to_string_names(result_map)


func _collect_descendants(root_id: StringName, out: Dictionary) -> void:
	for child_id in _registry.get_children_of(root_id):
		out[child_id] = true
		_collect_descendants(child_id, out)


static func _clear_layer(layer: Node) -> void:
	for child in layer.get_children():
		child.queue_free()


static func _dict_keys_to_string_names(source: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for key in source.keys():
		out.append(key)
	return out


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


static func _orbit_extent_ru(def: BodyDef) -> float:
	if def == null or def.orbit_profile == null:
		return 0.0
	var profile: OrbitProfile = def.orbit_profile
	match profile.mode:
		OrbitMode.Kind.AUTHORED_ORBIT:
			return profile.authored_radius_m / UnitSystem.RENDER_SCALE_M_PER_UNIT
		OrbitMode.Kind.KEPLER_APPROX:
			return profile.semi_major_axis_m * (1.0 + clampf(profile.eccentricity, 0.0, 0.999999)) / UnitSystem.RENDER_SCALE_M_PER_UNIT
		_:
			return 0.0


static func _trail_point_budget(kind: int) -> int:
	match kind:
		BodyType.Kind.BLACK_HOLE:
			return 72
		BodyType.Kind.STAR:
			return 96
		BodyType.Kind.MOON:
			return 110
		_:
			return 132


static func _body_z_index(kind: int) -> int:
	match kind:
		BodyType.Kind.BLACK_HOLE:
			return 8
		BodyType.Kind.STAR:
			return 7
		BodyType.Kind.PLANET:
			return 6
		BodyType.Kind.MOON:
			return 5
		_:
			return 4


static func _orbit_color(kind: int) -> Color:
	match kind:
		BodyType.Kind.BLACK_HOLE:
			return Color(0.72, 0.38, 0.90, 0.22)
		BodyType.Kind.STAR:
			return Color(1.0, 0.86, 0.46, 0.16)
		BodyType.Kind.MOON:
			return Color(0.85, 0.89, 0.97, 0.16)
		_:
			return Color(0.42, 0.62, 0.94, 0.28)


static func _trail_color(kind: int) -> Color:
	match kind:
		BodyType.Kind.BLACK_HOLE:
			return Color(0.84, 0.48, 1.0, 0.42)
		BodyType.Kind.STAR:
			return Color(1.0, 0.84, 0.34, 0.34)
		BodyType.Kind.MOON:
			return Color(0.86, 0.90, 0.98, 0.30)
		_:
			return Color(0.48, 0.72, 1.0, 0.34)


static func _trail_gradient(kind: int) -> Gradient:
	var base: Color = _trail_color(kind)
	var grad := Gradient.new()
	grad.set_color(0, Color(base.r, base.g, base.b, 0.0))
	grad.set_color(1, base)
	return grad


static func _orbit_line_width(kind: int) -> float:
	match kind:
		BodyType.Kind.PLANET:
			return 1.65
		BodyType.Kind.STAR:
			return 1.05
		BodyType.Kind.MOON:
			return 1.15
		_:
			return 1.35
