class_name GalaxyProxyRenderer
extends Node2D


const GalaxyProxyMathScript := preload("res://src/runtime/streaming/galaxy_proxy_math.gd")
const OrbitBodyVisualScript := preload("res://src/tools/rendering/orbit_body_visual.gd")

const STAR_PROXY_RADIUS_PX: float = 3.0
const STAR_PROXY_LINE_WIDTH_PX: float = 1.0
const PICK_RADIUS_PX: float = 36.0
const STAR_PROXY_ENTER_PROJECTED_EXTENT_PX: float = 96.0
const STAR_PROXY_EXIT_PROJECTED_EXTENT_PX: float = 80.0
const PROXY_CULL_MARGIN_PX: float = 128.0

var _galaxy = null
var _registry: Node = null
var _bubble = null
var _topology = null
var _time_service: Node = null
var _streaming_controller = null
var _detail_renderer = null

var _root_local_positions_ru: Dictionary = {}
var _star_proxy_visible_by_root: Dictionary = {}
var _cached_proxy_state: Dictionary = {"entries": [], "screen_scale": 1.0}
var _last_redraw_signature: Dictionary = {}
var _proxy_state_dirty: bool = true
var _redraw_queued: bool = false
var _proxy_state_recompute_count: int = 0
var _redraw_request_count: int = 0
var _last_debug_snapshot: Dictionary = {
	"bh_only_root_count": 0,
	"star_proxy_root_count": 0,
	"star_proxy_count": 0,
	"visible_root_count": 0,
	"culled_root_count": 0,
}


func configure(
		galaxy,
		registry: Node,
		bubble,
		topology,
		time_service: Node,
		streaming_controller,
		detail_renderer
	) -> void:
	_galaxy = galaxy
	_registry = registry
	_bubble = bubble
	_topology = topology
	_time_service = time_service
	_streaming_controller = streaming_controller
	_detail_renderer = detail_renderer
	_star_proxy_visible_by_root.clear()
	_cached_proxy_state = {"entries": [], "screen_scale": 1.0}
	_last_redraw_signature.clear()
	_proxy_state_dirty = true
	_redraw_queued = false
	_proxy_state_recompute_count = 0
	_redraw_request_count = 0
	_last_debug_snapshot = {
		"bh_only_root_count": 0,
		"star_proxy_root_count": 0,
		"star_proxy_count": 0,
		"visible_root_count": 0,
		"culled_root_count": 0,
	}
	_request_proxy_redraw()


func pick_root_at_screen(screen_pos: Vector2) -> StringName:
	if not visible:
		return StringName("")
	var canvas_xform: Transform2D = _canvas_xform()
	var best_id: StringName = StringName("")
	var best_score: float = INF
	for root_id_variant in _root_local_positions_ru.keys():
		var root_id: StringName = root_id_variant
		var local_pos: Vector2 = _root_local_positions_ru[root_id]
		var screen_proxy_pos: Vector2 = canvas_xform * local_pos
		var dist: float = screen_proxy_pos.distance_to(screen_pos)
		if dist > PICK_RADIUS_PX:
			continue
		if dist < best_score:
			best_id = root_id
			best_score = dist
	return best_id


func _process(_delta: float) -> void:
	if not visible:
		return
	var signature: Dictionary = _redraw_signature()
	if _proxy_state_dirty or signature != _last_redraw_signature:
		_proxy_state_dirty = true
		_request_proxy_redraw()


func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = _last_debug_snapshot.duplicate(true)
	snapshot["proxy_state_dirty"] = _proxy_state_dirty
	snapshot["redraw_queued"] = _redraw_queued
	snapshot["proxy_state_recompute_count"] = _proxy_state_recompute_count
	snapshot["redraw_request_count"] = _redraw_request_count
	return snapshot


func recompute_proxy_state() -> Dictionary:
	_proxy_state_recompute_count += 1
	_root_local_positions_ru.clear()
	if _galaxy == null or _bubble == null or _topology == null or _time_service == null or _detail_renderer == null:
		_last_debug_snapshot = {
			"bh_only_root_count": 0,
			"star_proxy_root_count": 0,
			"star_proxy_count": 0,
			"visible_root_count": 0,
			"culled_root_count": 0,
		}
		return _store_proxy_state({"entries": [], "screen_scale": maxf(absf(scale.x), 0.001)})
	var focus_id: StringName = _bubble.get_focus()
	var focus_root_id: StringName = _topology.root_id_of(focus_id)
	if focus_root_id == StringName(""):
		_last_debug_snapshot = {
			"bh_only_root_count": 0,
			"star_proxy_root_count": 0,
			"star_proxy_count": 0,
			"visible_root_count": 0,
			"culled_root_count": 0,
		}
		return _store_proxy_state({"entries": [], "screen_scale": maxf(absf(scale.x), 0.001)})
	var focus_manifest = _galaxy.get_manifest(focus_root_id)
	if focus_manifest == null:
		_last_debug_snapshot = {
			"bh_only_root_count": 0,
			"star_proxy_root_count": 0,
			"star_proxy_count": 0,
			"visible_root_count": 0,
			"culled_root_count": 0,
		}
		return _store_proxy_state({"entries": [], "screen_scale": maxf(absf(scale.x), 0.001)})
	var focus_root_view_ru: Vector2 = _detail_renderer.get_body_view_position_ru(focus_root_id)
	if not _is_finite_vec2(focus_root_view_ru):
		focus_root_view_ru = Vector2.ZERO
	var resident_roots: Array[StringName] = [] if _streaming_controller == null else _streaming_controller.get_resident_root_ids()
	var t_s: float = _time_service.sim_time_s
	var screen_scale: float = maxf(absf(scale.x), 0.001)
	var canvas_xform: Transform2D = _canvas_xform()
	var viewport_size_px: Vector2 = _viewport_size_px()
	var bh_only_root_count: int = 0
	var star_proxy_root_count: int = 0
	var star_proxy_count: int = 0
	var visible_root_count: int = 0
	var culled_root_count: int = 0
	var entries: Array = []

	for manifest in _galaxy.manifests:
		if manifest == null or manifest.root_id == focus_root_id:
			continue
		var relative_root_ru: Vector2 = Vector2(
			(manifest.galaxy_position_m.x - focus_manifest.galaxy_position_m.x) / UnitSystem.RENDER_SCALE_M_PER_UNIT,
			(manifest.galaxy_position_m.y - focus_manifest.galaxy_position_m.y) / UnitSystem.RENDER_SCALE_M_PER_UNIT
		)
		var root_pos_ru: Vector2 = focus_root_view_ru + relative_root_ru
		var projected_extent_px: float = (float(manifest.system_extent_m) / UnitSystem.RENDER_SCALE_M_PER_UNIT) * screen_scale
		var show_star_proxies: bool = _resolve_star_proxy_visibility(manifest.root_id, projected_extent_px)
		var proxy_envelope_px: float = PROXY_CULL_MARGIN_PX + (projected_extent_px if show_star_proxies else 0.0)
		var screen_root_pos: Vector2 = canvas_xform * root_pos_ru
		if should_cull_root_proxy(screen_root_pos, viewport_size_px, proxy_envelope_px):
			culled_root_count += 1
			continue

		_root_local_positions_ru[manifest.root_id] = root_pos_ru
		visible_root_count += 1
		var entry := {
			"root_id": manifest.root_id,
			"root_pos_ru": root_pos_ru,
			"is_resident": resident_roots.has(manifest.root_id),
			"show_star_proxies": show_star_proxies,
			"star_positions_ru": [],
		}
		if show_star_proxies:
			star_proxy_root_count += 1
			for star_manifest in manifest.star_manifests:
				var star_state: Dictionary = GalaxyProxyMathScript.star_local_state(star_manifest, t_s)
				var star_pos_m: Vector3 = star_state.get("position_parent_frame_m", Vector3.ZERO)
				var star_pos_ru: Vector2 = root_pos_ru + Vector2(
					star_pos_m.x / UnitSystem.RENDER_SCALE_M_PER_UNIT,
					star_pos_m.y / UnitSystem.RENDER_SCALE_M_PER_UNIT
				)
				entry["star_positions_ru"].append(star_pos_ru)
				star_proxy_count += 1
		else:
			bh_only_root_count += 1
		entries.append(entry)

	_last_debug_snapshot = {
		"bh_only_root_count": bh_only_root_count,
		"star_proxy_root_count": star_proxy_root_count,
		"star_proxy_count": star_proxy_count,
		"visible_root_count": visible_root_count,
		"culled_root_count": culled_root_count,
	}
	return _store_proxy_state({
		"entries": entries,
		"screen_scale": screen_scale,
	})


func _draw() -> void:
	var state: Dictionary = recompute_proxy_state() if _proxy_state_dirty else _cached_proxy_state
	_redraw_queued = false
	var entries: Array = state.get("entries", [])
	var screen_scale: float = float(state.get("screen_scale", maxf(absf(scale.x), 0.001)))
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		var root_pos_ru: Vector2 = entry.get("root_pos_ru", Vector2.ZERO)
		_draw_root_proxy(root_pos_ru, bool(entry.get("is_resident", false)), screen_scale)
		if not bool(entry.get("show_star_proxies", false)):
			continue
		for star_pos_variant in entry.get("star_positions_ru", []):
			var star_pos_ru: Vector2 = star_pos_variant
			draw_line(
				root_pos_ru,
				star_pos_ru,
				Color(1.0, 0.82, 0.36, 0.15),
				screen_px_to_local_units(STAR_PROXY_LINE_WIDTH_PX, screen_scale),
				true
			)
			draw_circle(
				star_pos_ru,
				screen_px_to_local_units(STAR_PROXY_RADIUS_PX, screen_scale),
				Color(1.0, 0.86, 0.48, 0.90)
			)


func _request_proxy_redraw() -> void:
	if _redraw_queued:
		return
	_redraw_queued = true
	_redraw_request_count += 1
	queue_redraw()


func _store_proxy_state(state: Dictionary) -> Dictionary:
	_cached_proxy_state = state
	_last_redraw_signature = _redraw_signature()
	_proxy_state_dirty = false
	_redraw_queued = false
	return _cached_proxy_state


func _redraw_signature() -> Dictionary:
	var focus_id: StringName = StringName("")
	var focus_root_id: StringName = StringName("")
	var focus_root_view_ru: Vector2 = Vector2.ZERO
	if _bubble != null:
		focus_id = _bubble.get_focus()
	if _topology != null and focus_id != StringName(""):
		focus_root_id = _topology.root_id_of(focus_id)
	if _detail_renderer != null and focus_root_id != StringName(""):
		focus_root_view_ru = _detail_renderer.get_body_view_position_ru(focus_root_id)
		if not _is_finite_vec2(focus_root_view_ru):
			focus_root_view_ru = Vector2.ZERO
	var canvas_xform: Transform2D = _canvas_xform()
	return {
		"configured": _galaxy != null and _bubble != null and _topology != null and _time_service != null and _detail_renderer != null,
		"focus_id": focus_id,
		"focus_root_id": focus_root_id,
		"focus_root_view_ru": focus_root_view_ru,
		"canvas_x": canvas_xform.x,
		"canvas_y": canvas_xform.y,
		"canvas_origin": canvas_xform.origin,
		"viewport_size_px": _viewport_size_px(),
		"sim_time_s": _sim_time_signature(),
		"resident_roots": _resident_roots_signature(),
	}


func _sim_time_signature() -> float:
	if _time_service == null:
		return 0.0
	if int(_last_debug_snapshot.get("star_proxy_count", 0)) <= 0:
		return 0.0
	return _time_service.sim_time_s


func _resident_roots_signature() -> Array[StringName]:
	var out: Array[StringName] = []
	if _streaming_controller == null:
		return out
	out.append_array(_streaming_controller.get_resident_root_ids())
	return out


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


static func root_proxy_visual_spec() -> Dictionary:
	return OrbitBodyVisualScript.black_hole_base_visual_spec()


static func resolve_star_proxy_visibility(was_visible: bool, projected_extent_px: float) -> bool:
	if was_visible:
		return projected_extent_px >= STAR_PROXY_EXIT_PROJECTED_EXTENT_PX
	return projected_extent_px >= STAR_PROXY_ENTER_PROJECTED_EXTENT_PX


static func should_cull_root_proxy(screen_pos: Vector2, viewport_size_px: Vector2, proxy_envelope_px: float) -> bool:
	var envelope_px: float = maxf(proxy_envelope_px, 0.0)
	return (
		screen_pos.x < -envelope_px
		or screen_pos.y < -envelope_px
		or screen_pos.x > viewport_size_px.x + envelope_px
		or screen_pos.y > viewport_size_px.y + envelope_px
	)


static func screen_px_to_local_units(screen_px: float, screen_scale: float) -> float:
	return screen_px / maxf(absf(screen_scale), 0.001)


func _draw_root_proxy(root_pos_ru: Vector2, is_resident: bool, screen_scale: float) -> void:
	var spec: Dictionary = root_proxy_visual_spec()
	var alpha_scale: float = 1.10 if is_resident else 0.90
	draw_circle(
		root_pos_ru,
		screen_px_to_local_units(float(spec.get("outer_glow_radius_px", 32.0)), screen_scale),
		_alpha_scaled(spec.get("outer_glow_color", Color(0.40, 0.12, 0.56, 0.04)), alpha_scale)
	)
	draw_circle(
		root_pos_ru,
		screen_px_to_local_units(float(spec.get("mid_glow_radius_px", 26.0)), screen_scale),
		_alpha_scaled(spec.get("mid_glow_color", Color(0.45, 0.18, 0.62, 0.08)), alpha_scale)
	)
	draw_circle(
		root_pos_ru,
		screen_px_to_local_units(float(spec.get("inner_glow_radius_px", 18.0)), screen_scale),
		_alpha_scaled(spec.get("inner_glow_color", Color(0.28, 0.10, 0.42, 0.12)), alpha_scale)
	)
	draw_arc(
		root_pos_ru,
		screen_px_to_local_units(float(spec.get("ring_radius_px", 13.0)), screen_scale),
		0.0,
		TAU,
		72,
		_alpha_scaled(spec.get("ring_color", Color(0.84, 0.48, 1.0, 0.58)), alpha_scale),
		screen_px_to_local_units(float(spec.get("ring_width_px", 2.4)), screen_scale),
		true
	)
	draw_circle(
		root_pos_ru,
		screen_px_to_local_units(float(spec.get("core_radius_px", 8.2)), screen_scale),
		spec.get("core_color", Color(0.05, 0.04, 0.09, 1.0))
	)
	draw_circle(
		root_pos_ru,
		screen_px_to_local_units(float(spec.get("center_glow_radius_px", 3.0)), screen_scale),
		_alpha_scaled(spec.get("center_glow_color", Color(0.72, 0.34, 0.88, 0.18)), alpha_scale)
	)


static func _alpha_scaled(color: Color, scale_factor: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(color.a * scale_factor, 0.0, 1.0))


func _resolve_star_proxy_visibility(root_id: StringName, projected_extent_px: float) -> bool:
	var was_visible: bool = bool(_star_proxy_visible_by_root.get(root_id, false))
	var next_visible: bool = resolve_star_proxy_visibility(was_visible, projected_extent_px)
	_star_proxy_visible_by_root[root_id] = next_visible
	return next_visible


func _viewport_size_px() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	return get_viewport_rect().size


func _canvas_xform() -> Transform2D:
	return get_global_transform_with_canvas()
