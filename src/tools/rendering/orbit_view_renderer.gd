class_name OrbitViewRenderer
extends Node2D

const ORBIT_SAMPLE_COUNT: int = 120
const TRAIL_LINE_WIDTH_PX: float = 2.0
const MIN_TRAIL_STEP_PX: float = 1.2

const UniverseTopologyScript := preload("res://src/sim/topology/universe_topology.gd")
const OrbitCameraFramingScript := preload("res://src/tools/rendering/orbit_camera_framing.gd")
const OrbitCameraScopeScript := preload("res://src/tools/rendering/orbit_camera_scope.gd")
const OrbitEmphasisRulesScript := preload("res://src/tools/rendering/orbit_emphasis_rules.gd")
const OrbitOrbitGeometryScript := preload("res://src/tools/rendering/orbit_orbit_geometry.gd")
const BODY_VISUAL_SCRIPT := preload("res://src/tools/rendering/orbit_body_visual.gd")
const PlanetVisualProfileScript := preload("res://src/tools/rendering/planet_visual_profile.gd")

@onready var _orbit_layer: Node2D = $OrbitLayer
@onready var _trail_layer: Node2D = $TrailLayer
@onready var _body_layer: Node2D = $BodyLayer

var _registry: Node = null
var _bubble: Node = null
var _topology = null
var _environment_service: Node = null
var _derived_snapshot_cache = null

var _body_visuals: Dictionary = {}
var _orbit_visuals: Dictionary = {}
var _trail_visuals: Dictionary = {}
var _trail_histories: Dictionary = {}
var _paused_trail_histories: Dictionary = {}
var _body_view_is_finite: Dictionary = {}
var _applied_environment_snapshot_revision: int = -1

var _world_scale: float = 1.0
var _focus_id: StringName = &""
var _focus_closeup_ratio: float = 1.0
var _frame_label: StringName = OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK

var _compose_view_position_body_ids: Dictionary = {}
var _trail_update_body_ids: Dictionary = {}
var _last_debug_snapshot: Dictionary = {
	"frame_label": OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK,
	"root_overview_active": false,
	"compose_view_position_distinct_body_count": 0,
	"trail_update_distinct_body_count": 0,
	"overview_hidden_descendant_count": 0,
	"overview_visible_star_count": 0,
}


func configure(registry: Node, bubble: Node, topology = null) -> void:
	_registry = registry
	_bubble = bubble
	_topology = topology
	if _topology == null and _registry != null:
		_topology = UniverseTopologyScript.new()
		_topology.configure(_registry)
	_rebuild_visuals()


func set_environment_service(environment_service: Node) -> void:
	_environment_service = environment_service
	if _registry != null and _bubble != null:
		_sync_visual_positions()


func set_derived_snapshot_cache(snapshot_cache) -> void:
	_derived_snapshot_cache = snapshot_cache
	_applied_environment_snapshot_revision = -1
	if _registry != null and _bubble != null:
		_apply_environment_visuals()


func set_focus(body_id: StringName) -> void:
	_focus_id = body_id
	for id in _body_visuals.keys():
		var visual: Node2D = _body_visuals[id]
		if visual != null:
			visual.set_focused(id == body_id)
	_apply_focus_emphasis()


func set_frame_label(frame_label: StringName) -> void:
	_frame_label = frame_label


func set_world_scale(value: float) -> void:
	_world_scale = maxf(value, 0.001)
	_apply_line_widths()


func set_focus_closeup_ratio(value: float) -> void:
	var new_val: float = maxf(value, 1.0)
	if is_equal_approx(new_val, _focus_closeup_ratio):
		return
	_focus_closeup_ratio = new_val
	_apply_focus_emphasis()


func pick_body_at_screen(screen_pos: Vector2) -> StringName:
	if _registry == null:
		return StringName("")

	var best_id: StringName = StringName("")
	var best_score: float = INF
	var best_priority: int = -1
	for id in _registry.get_update_order():
		var visual: OrbitBodyVisual = _body_visuals.get(id, null)
		var def: BodyDef = _registry.get_def(id)
		if visual == null or def == null or not visual.visible:
			continue

		var canvas_xform: Transform2D = visual.get_global_transform_with_canvas()
		var center: Vector2 = canvas_xform.origin
		var scale_x: float = canvas_xform.x.length()
		var radius_px: float = _pick_radius_local(def.kind) * scale_x + 8.0
		var dist: float = center.distance_to(screen_pos)
		if dist > radius_px:
			continue

		var score: float = dist / maxf(radius_px, 1.0)
		var priority: int = _pick_priority(def.kind)
		if score < best_score or (is_equal_approx(score, best_score) and priority > best_priority):
			best_id = id
			best_score = score
			best_priority = priority

	return best_id


func get_body_view_position_ru(id: StringName) -> Vector2:
	return _compute_body_view_position_ru(id, false)


func get_scope_frame(focus_id: StringName) -> Dictionary:
	return OrbitCameraScopeScript.get_scope_frame(
		_registry,
		_topology,
		focus_id,
		Callable(self, "get_body_view_position_ru")
	)


func clear_trails() -> void:
	for id in _trail_visuals.keys():
		_clear_trail(id)


func get_debug_snapshot() -> Dictionary:
	return _last_debug_snapshot.duplicate(true)


func rebuild_from_registry() -> void:
	_rebuild_visuals()


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
	_paused_trail_histories.clear()
	_body_view_is_finite.clear()
	_applied_environment_snapshot_revision = -1
	_compose_view_position_body_ids.clear()
	_trail_update_body_ids.clear()

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
			orbit_line.points = OrbitOrbitGeometryScript.build_orbit_points(def, ORBIT_SAMPLE_COUNT)
			orbit_line.z_index = -6
			_orbit_layer.add_child(orbit_line)
			_orbit_visuals[id] = {
				"line": orbit_line,
				"parent_id": def.parent_id,
				"kind": def.kind,
			}

		if def.kind == BodyType.Kind.PLANET or def.kind == BodyType.Kind.MOON:
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
	_apply_environment_visuals()
	_compose_view_position_body_ids.clear()
	_trail_update_body_ids.clear()
	var overview_hidden_descendant_count: int = 0
	var overview_visible_star_count: int = 0
	var root_overview_active: bool = _is_root_overview_active()
	var positions_by_id: Dictionary = {}

	for id in _registry.get_update_order():
		var def: BodyDef = _registry.get_def(id)
		if def == null:
			continue

		var visual: OrbitBodyVisual = _body_visuals.get(id, null)
		var orbit_entry: Dictionary = _orbit_visuals.get(id, {})
		var orbit_line: AntialiasedLine2D = orbit_entry.get("line", null)
		var trail_line: AntialiasedLine2D = _trail_visuals.get(id, null)

		if root_overview_active and _should_hide_in_root_overview(id, def):
			overview_hidden_descendant_count += 1
			_hide_visual_stack(visual, orbit_line, trail_line)
			_pause_trail(id)
			continue

		var pos: Vector2 = _compute_body_view_position_ru(id, true)
		positions_by_id[id] = pos
		var is_finite: bool = _is_finite_vec2(pos)
		var was_finite: bool = bool(_body_view_is_finite.get(id, false))
		_body_view_is_finite[id] = is_finite

		if not is_finite:
			_hide_visual_stack(visual, orbit_line, trail_line)
			if was_finite or reset_trails:
				_clear_trail(id)
			continue

		if visual != null:
			visual.visible = true
			visual.position = pos
			var detail_factor: float = OrbitEmphasisRulesScript.body_detail_factor(
				id,
				def,
				_focus_id,
				_topology,
				_focus_closeup_ratio
			)
			var star_phase: float = OrbitEmphasisRulesScript.star_closeup_phase(
				id,
				def,
				_focus_id,
				_focus_closeup_ratio
			)
			var star_scale: float = OrbitEmphasisRulesScript.star_focus_scale(star_phase)
			visual.scale = Vector2.ONE * ((detail_factor / _world_scale) * star_scale)
			visual.set_detail_factor(detail_factor)
			visual.set_star_closeup_phase(star_phase)

		if root_overview_active and _is_visible_root_overview_star(def):
			overview_visible_star_count += 1

		if not orbit_entry.is_empty():
			var parent_id: StringName = orbit_entry.get("parent_id", &"")
			if orbit_line != null:
				var orbit_visible: bool = not root_overview_active or _should_show_orbit_in_root_overview(def)
				orbit_line.visible = orbit_visible
				if orbit_visible:
					var parent_pos: Vector2 = positions_by_id.get(parent_id, Vector2(INF, INF))
					if not _is_finite_vec2(parent_pos):
						parent_pos = _compute_body_view_position_ru(parent_id, true)
						positions_by_id[parent_id] = parent_pos
					orbit_line.position = parent_pos

		if trail_line != null:
			var show_trail: bool = not root_overview_active
			trail_line.visible = show_trail
			if show_trail:
				var trail_parent_pos: Vector2 = positions_by_id.get(def.parent_id, Vector2(INF, INF))
				if not _is_finite_vec2(trail_parent_pos):
					trail_parent_pos = _compute_body_view_position_ru(def.parent_id, true)
					positions_by_id[def.parent_id] = trail_parent_pos
				var parent_frame_pos_ru: Vector2 = _body_parent_frame_position_ru(id)
				if _is_finite_vec2(trail_parent_pos) and _is_finite_vec2(parent_frame_pos_ru):
					trail_line.position = trail_parent_pos
					_resume_trail_if_paused(id, parent_frame_pos_ru)
					_update_trail(id, parent_frame_pos_ru, reset_trails)
				else:
					_pause_trail(id)
			else:
				_pause_trail(id)

	_last_debug_snapshot = {
		"frame_label": _frame_label,
		"root_overview_active": root_overview_active,
		"compose_view_position_distinct_body_count": _compose_view_position_body_ids.size(),
		"trail_update_distinct_body_count": _trail_update_body_ids.size(),
		"overview_hidden_descendant_count": overview_hidden_descendant_count,
		"overview_visible_star_count": overview_visible_star_count,
	}


func _apply_environment_visuals() -> void:
	if _registry == null:
		return
	if _is_root_overview_active():
		return

	if _derived_snapshot_cache != null:
		var revision: int = _derived_snapshot_cache.get_revision()
		if revision == _applied_environment_snapshot_revision:
			return
		for id in _registry.get_update_order():
			var def: BodyDef = _registry.get_def(id)
			var visual: OrbitBodyVisual = _body_visuals.get(id, null)
			if visual == null or def == null:
				continue
			if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
				continue
			var environment_desc: Dictionary = _derived_snapshot_cache.get_environment_desc(id)
			visual.apply_planet_theme(PlanetVisualProfileScript.resolve(def, environment_desc))
		_applied_environment_snapshot_revision = revision
		return

	if _environment_service == null:
		return
	for id in _registry.get_update_order():
		var def: BodyDef = _registry.get_def(id)
		var visual: OrbitBodyVisual = _body_visuals.get(id, null)
		if visual == null or def == null:
			continue
		if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
			continue
		var environment_desc: Dictionary = _environment_service.describe_body(id)
		visual.apply_planet_theme(PlanetVisualProfileScript.resolve(def, environment_desc))


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
			var emphasis: Dictionary = OrbitEmphasisRulesScript.focus_emphasis_for(
				id,
				focus_def,
				_registry,
				_topology,
				_focus_closeup_ratio
			)
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


func _update_trail(id: StringName, pos: Vector2, reset_trails: bool) -> void:
	var line: AntialiasedLine2D = _trail_visuals.get(id, null)
	if line == null:
		return
	_trail_update_body_ids[id] = true

	var history: Array = _trail_histories.get(id, [])
	if reset_trails or history.is_empty():
		history = [pos]
	else:
		var last_pos: Vector2 = history[history.size() - 1]
		if not last_pos.is_equal_approx(pos):
			history.append(pos)

		var def: BodyDef = _registry.get_def(id)
		var max_points: int = _trail_point_budget(def.kind if def != null else BodyType.Kind.PLANET)
		while history.size() > max_points:
			history.pop_front()

	_trail_histories[id] = history
	line.points = PackedVector2Array(history)


func _clear_trail(id: StringName) -> void:
	_trail_histories[id] = []
	_paused_trail_histories.erase(id)
	var line: AntialiasedLine2D = _trail_visuals.get(id, null)
	if line != null:
		line.points = PackedVector2Array()


func _pause_trail(id: StringName) -> void:
	if _paused_trail_histories.has(id):
		return
	var history: Array = _trail_histories.get(id, [])
	if history.is_empty():
		return
	_paused_trail_histories[id] = history.duplicate(true)


func _resume_trail_if_paused(id: StringName, pos: Vector2) -> void:
	if not _paused_trail_histories.has(id):
		return
	_trail_histories[id] = [pos]
	var line: AntialiasedLine2D = _trail_visuals.get(id, null)
	if line != null:
		line.points = PackedVector2Array(_trail_histories[id])
	_paused_trail_histories.erase(id)


func _apply_line_widths() -> void:
	for line in _trail_visuals.values():
		if line != null:
			line.width = TRAIL_LINE_WIDTH_PX / _world_scale
	for entry in _orbit_visuals.values():
		var line: AntialiasedLine2D = entry.get("line", null)
		var kind: int = entry.get("kind", BodyType.Kind.PLANET)
		if line != null:
			line.width = _orbit_line_width(kind) / _world_scale


static func _clear_layer(layer: Node) -> void:
	for child in layer.get_children():
		child.queue_free()


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


static func _pick_radius_local(kind: int) -> float:
	match kind:
		BodyType.Kind.BLACK_HOLE:
			return 20.0
		BodyType.Kind.STAR:
			return 22.0
		BodyType.Kind.MOON:
			return 8.0
		_:
			return 11.0


static func _pick_priority(kind: int) -> int:
	match kind:
		BodyType.Kind.MOON:
			return 3
		BodyType.Kind.PLANET:
			return 2
		BodyType.Kind.STAR:
			return 1
		_:
			return 0


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


static func _is_finite_vec3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _compute_body_view_position_ru(id: StringName, count_for_frame: bool = false) -> Vector2:
	if _bubble == null:
		return Vector2.ZERO
	if not _body_shares_focus_root(id):
		return Vector2(INF, INF)
	if count_for_frame:
		_compose_view_position_body_ids[id] = true
	var view_m: Vector3 = _bubble.compose_view_position_m(id)
	if not _is_finite_vec3(view_m):
		return Vector2(INF, INF)
	return Vector2(view_m.x, view_m.y) / UnitSystem.RENDER_SCALE_M_PER_UNIT


func _is_root_overview_active() -> bool:
	if _frame_label != OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW:
		return false
	var focus_def: BodyDef = null if _registry == null else _registry.get_def(_focus_id)
	return focus_def != null and focus_def.is_root()


func _should_hide_in_root_overview(id: StringName, def: BodyDef) -> bool:
	if not _is_root_overview_active():
		return false
	if def == null:
		return false
	if id == _focus_id:
		return false
	return not _is_visible_root_overview_star(def)


func _is_visible_root_overview_star(def: BodyDef) -> bool:
	return def != null and def.kind == BodyType.Kind.STAR and def.parent_id == _focus_id


func _body_parent_frame_position_ru(id: StringName) -> Vector2:
	if _registry == null:
		return Vector2(INF, INF)
	var state: BodyState = _registry.get_state(id)
	if state == null:
		return Vector2(INF, INF)
	var pos_m: Vector3 = state.position_parent_frame_m
	if not _is_finite_vec3(pos_m):
		return Vector2(INF, INF)
	return Vector2(pos_m.x, pos_m.y) / UnitSystem.RENDER_SCALE_M_PER_UNIT


func _should_show_orbit_in_root_overview(def: BodyDef) -> bool:
	return _is_visible_root_overview_star(def)


static func _hide_visual_stack(visual: CanvasItem, orbit_line: CanvasItem, trail_line: CanvasItem) -> void:
	if visual != null:
		visual.visible = false
	if orbit_line != null:
		orbit_line.visible = false
	if trail_line != null:
		trail_line.visible = false


func _body_shares_focus_root(id: StringName) -> bool:
	if _topology == null or _focus_id == StringName(""):
		return true
	var focus_root_id: StringName = _topology.root_id_of(_focus_id)
	if focus_root_id == StringName(""):
		return true
	var body_root_id: StringName = _topology.root_id_of(id)
	if body_root_id == StringName(""):
		return true
	return body_root_id == focus_root_id
