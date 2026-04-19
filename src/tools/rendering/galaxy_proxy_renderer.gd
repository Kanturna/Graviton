class_name GalaxyProxyRenderer
extends Node2D


const GalaxyProxyMathScript := preload("res://src/runtime/streaming/galaxy_proxy_math.gd")

const ROOT_PROXY_RADIUS_PX: float = 7.0
const STAR_PROXY_RADIUS_PX: float = 3.0
const PICK_RADIUS_PX: float = 16.0

var _galaxy = null
var _registry: Node = null
var _bubble = null
var _topology = null
var _time_service: Node = null
var _streaming_controller = null
var _detail_renderer = null

var _root_local_positions_ru: Dictionary = {}


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
	queue_redraw()


func pick_root_at_screen(screen_pos: Vector2) -> StringName:
	var canvas_xform: Transform2D = get_global_transform_with_canvas()
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
	queue_redraw()


func _draw() -> void:
	_root_local_positions_ru.clear()
	if _galaxy == null or _bubble == null or _topology == null or _time_service == null or _detail_renderer == null:
		return
	var focus_id: StringName = _bubble.get_focus()
	var focus_root_id: StringName = _topology.root_id_of(focus_id)
	if focus_root_id == StringName(""):
		return
	var focus_manifest = _galaxy.get_manifest(focus_root_id)
	if focus_manifest == null:
		return
	var focus_root_view_ru: Vector2 = _detail_renderer.get_body_view_position_ru(focus_root_id)
	if not _is_finite_vec2(focus_root_view_ru):
		focus_root_view_ru = Vector2.ZERO
	var resident_roots: Array[StringName] = [] if _streaming_controller == null else _streaming_controller.get_resident_root_ids()
	var t_s: float = _time_service.sim_time_s

	for manifest in _galaxy.manifests:
		if manifest == null or manifest.root_id == focus_root_id:
			continue
		var relative_root_ru: Vector2 = Vector2(
			(manifest.galaxy_position_m.x - focus_manifest.galaxy_position_m.x) / UnitSystem.RENDER_SCALE_M_PER_UNIT,
			(manifest.galaxy_position_m.y - focus_manifest.galaxy_position_m.y) / UnitSystem.RENDER_SCALE_M_PER_UNIT
		)
		var root_pos_ru: Vector2 = focus_root_view_ru + relative_root_ru
		_root_local_positions_ru[manifest.root_id] = root_pos_ru

		var root_color: Color = Color(0.72, 0.38, 0.90, 0.82)
		if resident_roots.has(manifest.root_id):
			root_color = Color(0.82, 0.62, 0.98, 0.92)
		draw_circle(root_pos_ru, ROOT_PROXY_RADIUS_PX, root_color)
		draw_arc(root_pos_ru, ROOT_PROXY_RADIUS_PX + 4.0, 0.0, TAU, 32, Color(root_color.r, root_color.g, root_color.b, 0.18), 1.5)

		for star_manifest in manifest.star_manifests:
			var star_state: Dictionary = GalaxyProxyMathScript.star_local_state(star_manifest, t_s)
			var star_pos_m: Vector3 = star_state.get("position_parent_frame_m", Vector3.ZERO)
			var star_pos_ru: Vector2 = root_pos_ru + Vector2(
				star_pos_m.x / UnitSystem.RENDER_SCALE_M_PER_UNIT,
				star_pos_m.y / UnitSystem.RENDER_SCALE_M_PER_UNIT
			)
			draw_line(root_pos_ru, star_pos_ru, Color(1.0, 0.82, 0.36, 0.15), 1.0, true)
			draw_circle(star_pos_ru, STAR_PROXY_RADIUS_PX, Color(1.0, 0.86, 0.48, 0.90))


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
