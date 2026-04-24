class_name PlanetBadgeOverlay
extends CanvasLayer

signal life_details_requested(body_id: StringName)

const OrbitCameraFramingScript := preload("res://src/tools/rendering/orbit_camera_framing.gd")
const OrbitHudFormatterScript := preload("res://src/tools/rendering/orbit_hud_formatter.gd")

const MAX_BADGES: int = 24
const MIN_BADGE_RADIUS_PX: float = 12.0
const BADGE_OFFSET_X_PX: float = 10.0
const BADGE_OFFSET_Y_PX: float = 10.0
const VIEWPORT_MARGIN_PX: float = 4.0

var _registry: Node = null
var _topology = null
var _bubble = null
var _snapshot_cache = null
var _renderer = null
var _frame_label: StringName = OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK
var _root: Control = null
var _badge_pool: Array[Dictionary] = []


func _ready() -> void:
	_ensure_ui()
	_ensure_badge_pool()


func configure(registry: Node, topology, bubble, snapshot_cache, renderer) -> void:
	_registry = registry
	_topology = topology
	_bubble = bubble
	_snapshot_cache = snapshot_cache
	_renderer = renderer
	_ensure_ui()
	_ensure_badge_pool()


func set_frame_label(frame_label: StringName) -> void:
	_frame_label = frame_label


func refresh() -> void:
	_ensure_ui()
	_sync_root_rect()
	_ensure_badge_pool()
	if _registry == null or _topology == null or _bubble == null or _snapshot_cache == null or _renderer == null:
		_hide_all_badges()
		return
	if _frame_label == OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW:
		_hide_all_badges()
		return

	var focus_id: StringName = _bubble.get_focus()
	var focus_root_id: StringName = _topology.root_id_of(focus_id)
	if focus_root_id == StringName(""):
		_hide_all_badges()
		return

	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size if viewport != null else Vector2.ZERO
	var candidates: Array[Dictionary] = []
	for id_variant in _registry_update_order():
		var id: StringName = id_variant
		var def: BodyDef = _registry.get_def(id)
		if def == null:
			continue
		if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
			continue
		if _topology.root_id_of(id) != focus_root_id:
			continue
		var screen_metrics: Dictionary = _renderer.get_body_screen_metrics(id)
		if not bool(screen_metrics.get("visible", false)):
			continue
		var projected_radius_px: float = float(screen_metrics.get("projected_radius_px", 0.0))
		if projected_radius_px < MIN_BADGE_RADIUS_PX:
			continue
		var center_px: Vector2 = screen_metrics.get("center_px", Vector2(INF, INF))
		if not _is_finite_vec2(center_px):
			continue
		if _is_offscreen(center_px, projected_radius_px, viewport_size):
			continue

		var biosphere_desc: Dictionary = _snapshot_cache.get_biosphere_scale_desc(id)
		var native_species_desc: Dictionary = _snapshot_cache.get_native_species_desc(id)
		var lines: PackedStringArray = build_badge_text_lines(biosphere_desc, native_species_desc)
		if lines.is_empty():
			continue
		candidates.append({
			"body_id": id,
			"center_px": center_px,
			"projected_radius_px": projected_radius_px,
			"lines": lines,
		})

	candidates.sort_custom(Callable(self, "_sort_candidates_by_radius_desc"))
	var limit: int = mini(candidates.size(), MAX_BADGES)
	for index in range(limit):
		_apply_badge(_badge_pool[index], candidates[index], viewport_size)
	for index in range(limit, _badge_pool.size()):
		_set_badge_visible(_badge_pool[index], false)


func get_debug_snapshot() -> Dictionary:
	var visible_count: int = 0
	var visible_badges: Array[Dictionary] = []
	for badge_variant in _badge_pool:
		var badge: Dictionary = badge_variant
		var panel: Control = badge.get("panel", null)
		if panel != null and panel.visible:
			visible_count += 1
			visible_badges.append({
				"body_id": badge.get("body_id", StringName("")),
				"visible": true,
			})
	return {
		"frame_label": _frame_label,
		"visible_badge_count": visible_count,
		"visible_badges": visible_badges,
		"max_badges": MAX_BADGES,
		"min_badge_radius_px": MIN_BADGE_RADIUS_PX,
	}


static func build_badge_text_lines(biosphere_desc: Dictionary, native_species_desc: Dictionary) -> PackedStringArray:
	var stage_short: String = OrbitHudFormatterScript.compact_life_stage_text(biosphere_desc)
	if stage_short == "":
		return PackedStringArray()
	var out := PackedStringArray(["LIFE %s" % stage_short])
	var density_text: String = OrbitHudFormatterScript.compact_density_text(biosphere_desc)
	var species_text: String = OrbitHudFormatterScript.compact_species_text(native_species_desc)
	if species_text != "" and density_text != "":
		out.append("%s %s" % [density_text, species_text])
	elif density_text != "":
		out.append(density_text)
	return out


func _sort_candidates_by_radius_desc(a: Dictionary, b: Dictionary) -> bool:
	var a_radius: float = float(a.get("projected_radius_px", 0.0))
	var b_radius: float = float(b.get("projected_radius_px", 0.0))
	if is_equal_approx(a_radius, b_radius):
		return String(a.get("body_id", "")).naturalnocasecmp_to(String(b.get("body_id", ""))) < 0
	return a_radius > b_radius


func _ensure_ui() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "BadgeRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_sync_root_rect()


func _sync_root_rect() -> void:
	if _root == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	_root.position = Vector2.ZERO
	_root.size = viewport.get_visible_rect().size


func _ensure_badge_pool() -> void:
	if _root == null:
		return
	while _badge_pool.size() < MAX_BADGES:
		_badge_pool.append(_make_badge(_badge_pool.size()))


func _make_badge(index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_theme_stylebox_override("panel", _make_badge_style())
	panel.gui_input.connect(_on_badge_gui_input.bind(index), CONNECT_DEFERRED)
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	var line_one := _make_badge_line_button(index, Color(0.972549, 0.980392, 1.0, 0.96), 12)
	vbox.add_child(line_one)

	var line_two := _make_badge_line_button(index, Color(0.819608, 0.886275, 0.984314, 0.90), 11)
	vbox.add_child(line_two)

	return {
		"panel": panel,
		"line_one": line_one,
		"line_two": line_two,
		"body_id": StringName(""),
	}


func _apply_badge(badge: Dictionary, candidate: Dictionary, viewport_size: Vector2) -> void:
	var panel: Control = badge.get("panel", null)
	var line_one: Button = badge.get("line_one", null)
	var line_two: Button = badge.get("line_two", null)
	if panel == null or line_one == null or line_two == null:
		return
	var lines: PackedStringArray = candidate.get("lines", PackedStringArray())
	line_one.text = lines[0] if not lines.is_empty() else ""
	line_two.text = lines[1] if lines.size() > 1 else ""
	line_two.visible = line_two.text != ""
	line_one.custom_minimum_size = line_one.get_combined_minimum_size()
	line_two.custom_minimum_size = line_two.get_combined_minimum_size() if line_two.visible else Vector2.ZERO
	badge["body_id"] = candidate.get("body_id", StringName(""))
	panel.visible = true
	var badge_size: Vector2 = panel.get_combined_minimum_size()
	panel.custom_minimum_size = badge_size
	panel.size = badge_size
	var center_px: Vector2 = candidate.get("center_px", Vector2.ZERO)
	var projected_radius_px: float = float(candidate.get("projected_radius_px", 0.0))
	var desired_pos: Vector2 = center_px + Vector2(
		projected_radius_px + BADGE_OFFSET_X_PX,
		-(projected_radius_px + BADGE_OFFSET_Y_PX)
	)
	panel.position = _clamp_badge_position(desired_pos, badge_size, viewport_size)


func _hide_all_badges() -> void:
	for badge_variant in _badge_pool:
		_set_badge_visible(badge_variant, false)


static func _set_badge_visible(badge: Dictionary, is_visible: bool) -> void:
	var panel: Control = badge.get("panel", null)
	if panel != null:
		panel.visible = is_visible
	if not is_visible:
		badge["body_id"] = StringName("")


static func _clamp_badge_position(pos: Vector2, badge_size: Vector2, viewport_size: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, VIEWPORT_MARGIN_PX, maxf(viewport_size.x - badge_size.x - VIEWPORT_MARGIN_PX, VIEWPORT_MARGIN_PX)),
		clampf(pos.y, VIEWPORT_MARGIN_PX, maxf(viewport_size.y - badge_size.y - VIEWPORT_MARGIN_PX, VIEWPORT_MARGIN_PX))
	)


static func _is_offscreen(center_px: Vector2, projected_radius_px: float, viewport_size: Vector2) -> bool:
	return center_px.x < -projected_radius_px \
		or center_px.y < -projected_radius_px \
		or center_px.x > viewport_size.x + projected_radius_px \
		or center_px.y > viewport_size.y + projected_radius_px


func _registry_update_order() -> Array[StringName]:
	if _registry == null:
		return []
	if _registry.has_method("get_update_order_ref"):
		return _registry.get_update_order_ref()
	return _registry.get_update_order()


func _on_badge_pressed(index: int) -> void:
	if index < 0 or index >= _badge_pool.size():
		return
	var badge: Dictionary = _badge_pool[index]
	var body_id: StringName = badge.get("body_id", StringName(""))
	if body_id == StringName(""):
		return
	life_details_requested.emit(body_id)


func _on_badge_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			_on_badge_pressed(index)


func _make_badge_line_button(index: int, text_color: Color, font_size: int) -> Button:
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color.lightened(0.12))
	button.add_theme_color_override("font_pressed_color", text_color.darkened(0.08))
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(_on_badge_pressed.bind(index), CONNECT_DEFERRED)
	return button


static func _make_badge_style(
		bg_color: Color = Color(0.0352941, 0.0509804, 0.0941176, 0.82),
		border_color: Color = Color(0.388235, 0.592157, 0.87451, 0.28)
	) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
