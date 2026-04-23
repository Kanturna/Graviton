class_name RootInspectorOverlay
extends PanelContainer


signal focus_requested(body_id: StringName)
signal closed

const RootInspectorModelBuilderScript = preload("res://src/tools/ui/root_inspector_model_builder.gd")
const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")

const PANEL_MIN_WIDTH: float = 392.0
const ROW_INDENT_PX: int = 18
const SIM_TICK_REBUILD_COOLDOWN_USEC: int = 100_000

var _registry: Node = null
var _topology = null
var _snapshot_cache = null
var _builder = RootInspectorModelBuilderScript.new()

var _root_id: StringName = &""
var _focused_body_id: StringName = &""
var _current_model: Dictionary = {}
var _row_body_ids: Array[StringName] = []
var _last_sim_tick_rebuild_usec: int = 0
var _rebuild_count: int = 0

var _title_label: Label = null
var _type_label: Label = null
var _summary_label: Label = null
var _rows_vbox: VBoxContainer = null

var _row_style_normal: StyleBoxFlat = null
var _row_style_hover: StyleBoxFlat = null
var _row_style_active: StyleBoxFlat = null


func _ready() -> void:
	_ensure_ui()
	visible = false


func _exit_tree() -> void:
	if _snapshot_cache != null and _snapshot_cache.snapshot_refreshed.is_connected(_on_snapshot_refreshed):
		_snapshot_cache.snapshot_refreshed.disconnect(_on_snapshot_refreshed)


func configure(registry: Node, topology, snapshot_cache) -> void:
	_ensure_ui()
	_registry = registry
	_topology = topology
	if _snapshot_cache != null and _snapshot_cache.snapshot_refreshed.is_connected(_on_snapshot_refreshed):
		_snapshot_cache.snapshot_refreshed.disconnect(_on_snapshot_refreshed)
	_snapshot_cache = snapshot_cache
	_builder.configure(registry, topology, snapshot_cache)
	if _snapshot_cache != null and not _snapshot_cache.snapshot_refreshed.is_connected(_on_snapshot_refreshed):
		_snapshot_cache.snapshot_refreshed.connect(_on_snapshot_refreshed)


func set_root_context(root_id: StringName, focused_body_id: StringName, auto_open: bool = false) -> void:
	_root_id = root_id
	_focused_body_id = focused_body_id
	_last_sim_tick_rebuild_usec = 0
	if auto_open:
		visible = true
	if visible or auto_open:
		_rebuild()


func close_panel(emit_close_signal: bool = true) -> void:
	visible = false
	_last_sim_tick_rebuild_usec = 0
	if emit_close_signal:
		closed.emit()


func clear_state() -> void:
	visible = false
	_root_id = StringName("")
	_focused_body_id = StringName("")
	_current_model.clear()
	_row_body_ids.clear()
	_last_sim_tick_rebuild_usec = 0
	_apply_empty_model()


func is_open() -> bool:
	return visible


func get_root_id() -> StringName:
	return _root_id


func get_debug_snapshot() -> Dictionary:
	return {
		"is_open": visible,
		"root_id": _root_id,
		"focused_body_id": _focused_body_id,
		"row_body_ids": _row_body_ids.duplicate(),
		"summary": _current_model.get("summary", {}).duplicate(),
		"rebuild_count": _rebuild_count,
	}


func _ensure_ui() -> void:
	if _rows_vbox != null:
		return

	custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_theme_stylebox_override("panel", _make_panel_style())
	_row_style_normal = _make_row_style(Color(0.0509804, 0.0705882, 0.129412, 0.30), Color(0.243137, 0.364706, 0.556863, 0.22))
	_row_style_hover = _make_row_style(Color(0.0784314, 0.109804, 0.180392, 0.82), Color(0.411765, 0.619608, 0.917647, 0.30))
	_row_style_active = _make_row_style(Color(0.105882, 0.14902, 0.243137, 0.94), Color(0.576471, 0.784314, 0.992157, 0.48))

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.name = "VBox"
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	var header_hbox := HBoxContainer.new()
	header_hbox.name = "Header"
	root_vbox.add_child(header_hbox)

	var header_vbox := VBoxContainer.new()
	header_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_vbox.add_theme_constant_override("separation", 4)
	header_hbox.add_child(header_vbox)

	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color(0.937255, 0.968627, 1.0, 1.0))
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.text = "Root Inspector"
	header_vbox.add_child(_title_label)

	_type_label = Label.new()
	_type_label.add_theme_color_override("font_color", Color(0.654902, 0.772549, 0.937255, 0.78))
	_type_label.text = "BLACK_HOLE"
	header_vbox.add_child(_type_label)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(_on_close_pressed)
	header_hbox.add_child(close_button)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_color_override("font_color", Color(0.901961, 0.933333, 0.984314, 0.92))
	_summary_label.text = "No root selected"
	root_vbox.add_child(_summary_label)

	var separator := HSeparator.new()
	root_vbox.add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_rows_vbox = VBoxContainer.new()
	_rows_vbox.name = "Rows"
	_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows_vbox)

	_apply_empty_model()


func _rebuild() -> void:
	_rebuild_count += 1
	if _registry == null or _topology == null or _snapshot_cache == null:
		_apply_empty_model()
		return
	if _root_id == StringName("") or not _registry.has_body(_root_id):
		_apply_empty_model()
		return
	_current_model = _builder.build(_root_id, _focused_body_id)
	if _current_model.is_empty():
		_apply_empty_model()
		return
	_apply_model(_current_model)


func _apply_empty_model() -> void:
	_clear_rows()
	if _title_label != null:
		_title_label.text = "Root Inspector"
	if _type_label != null:
		_type_label.text = "BLACK_HOLE"
	if _summary_label != null:
		_summary_label.text = "No root selected"


func _apply_model(model: Dictionary) -> void:
	_clear_rows()
	_row_body_ids.clear()
	_title_label.text = String(model.get("root_name", "Root Inspector"))
	_type_label.text = String(model.get("root_kind_text", "BLACK_HOLE"))

	var summary: Dictionary = model.get("summary", {})
	_summary_label.text = "Stars %d   Planets %d   Moons %d\nHABITABLE %d   HARSH %d   HOSTILE %d" % [
		int(summary.get("stars", 0)),
		int(summary.get("planets", 0)),
		int(summary.get("moons", 0)),
		int(summary.get("habitable", 0)),
		int(summary.get("harsh", 0)),
		int(summary.get("hostile", 0)),
	]

	for row_variant in model.get("rows", []):
		var row: Dictionary = row_variant
		var body_id: StringName = row.get("body_id", StringName(""))
		_row_body_ids.append(body_id)

		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", int(row.get("depth", 0)) * ROW_INDENT_PX)
		indent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows_vbox.add_child(indent)

		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = _format_row_text(row)
		button.clip_text = false
		# The inspector rebuilds while the sim runs, so release-based buttons can
		# lose their click between mouse-down and mouse-up. Fire on press-down.
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", _row_style_active if bool(row.get("is_focused", false)) else _row_style_normal)
		button.add_theme_stylebox_override("hover", _row_style_hover)
		button.add_theme_stylebox_override("pressed", _row_style_active)
		button.add_theme_stylebox_override("focus", _row_style_active)
		button.add_theme_color_override("font_color", Color(0.972549, 0.980392, 1.0, 1.0) if bool(row.get("is_focused", false)) else Color(0.890196, 0.92549, 0.988235, 0.94))
		button.add_theme_font_size_override("font_size", 13)
		# Inspector clicks rebuild the row list via snapshot refresh, so route the
		# focus request deferred to avoid freeing the active button mid-signal.
		button.pressed.connect(_on_row_pressed.bind(body_id), CONNECT_DEFERRED)
		indent.add_child(button)


func _clear_rows() -> void:
	if _rows_vbox == null:
		return
	for child in _rows_vbox.get_children():
		_rows_vbox.remove_child(child)
		child.queue_free()


static func _format_row_text(row: Dictionary) -> String:
	var parts: Array[String] = []
	for part_variant in [
		String(row.get("name_text", "")),
		String(row.get("kind_text", "")),
		String(row.get("badge_text", "")),
		String(row.get("life_badge_text", "")),
		String(row.get("note_text", "")),
	]:
		var part_text: String = String(part_variant)
		if part_text != "":
			parts.append(part_text)
	var line_one: String = "   ".join(parts)
	var detail_text: String = String(row.get("detail_text", ""))
	if detail_text == "":
		return line_one
	return "%s\n%s" % [line_one, detail_text]


func _on_row_pressed(body_id: StringName) -> void:
	focus_requested.emit(body_id)


func _on_close_pressed() -> void:
	close_panel()


func _on_snapshot_refreshed(reason: StringName) -> void:
	if not visible:
		return
	if reason == DerivedSnapshotCacheScript.REASON_SIM_TICK:
		var now_usec: int = Time.get_ticks_usec()
		if now_usec - _last_sim_tick_rebuild_usec < SIM_TICK_REBUILD_COOLDOWN_USEC:
			return
		_last_sim_tick_rebuild_usec = now_usec
	_rebuild()


static func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0352941, 0.0509804, 0.0941176, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.388235, 0.592157, 0.87451, 0.33)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 10
	return style


static func _make_row_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
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
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style
