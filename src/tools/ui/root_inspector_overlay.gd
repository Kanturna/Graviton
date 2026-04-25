class_name RootInspectorOverlay
extends PanelContainer


signal focus_requested(body_id: StringName)
signal life_details_requested(body_id: StringName)
signal closed

const RootInspectorModelBuilderScript = preload("res://src/tools/ui/root_inspector_model_builder.gd")
const RootInspectorRowScript = preload("res://src/tools/ui/root_inspector_row.gd")
const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")

const PANEL_MIN_WIDTH: float = 392.0
const ROW_INDENT_PX: int = 18
const SIM_TICK_REBUILD_COOLDOWN_USEC: int = 100_000
const EMPTY_MODEL_SIGNATURE: String = "<empty>"

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
var _model_apply_count: int = 0
var _last_model_signature: String = ""
var _compact_root_overview: bool = false
var _compact_focus_branch: bool = false

var _title_label: Label = null
var _type_label: Label = null
var _summary_label: Label = null
var _rows_vbox: VBoxContainer = null


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


func set_compact_root_overview(value: bool) -> void:
	_set_compact_display_modes(value, _compact_focus_branch)


func set_compact_focus_branch(value: bool) -> void:
	_set_compact_display_modes(_compact_root_overview, value)


func set_compact_display_modes(root_overview: bool, focus_branch: bool) -> void:
	_set_compact_display_modes(root_overview, focus_branch)


func _set_compact_display_modes(root_overview: bool, focus_branch: bool) -> void:
	if root_overview:
		focus_branch = false
	if root_overview == _compact_root_overview and focus_branch == _compact_focus_branch:
		return
	_compact_root_overview = root_overview
	_compact_focus_branch = focus_branch
	_last_sim_tick_rebuild_usec = 0
	if visible:
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
	_last_model_signature = ""
	_compact_root_overview = false
	_compact_focus_branch = false
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
		"visible_row_count": _row_body_ids.size(),
		"full_row_count": _full_model_row_count(),
		"compact_root_overview": _compact_root_overview,
		"compact_focus_branch": _compact_focus_branch,
		"summary": _current_model.get("summary", {}).duplicate(),
		"rebuild_count": _rebuild_count,
		"model_apply_count": _model_apply_count,
		"model_signature": _last_model_signature,
	}


func _ensure_ui() -> void:
	if _rows_vbox != null:
		return

	custom_minimum_size = Vector2(PANEL_MIN_WIDTH, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_theme_stylebox_override("panel", _make_panel_style())

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
	var display_model: Dictionary = _display_model_for_current_mode(_current_model)
	var next_signature: String = _model_signature(display_model)
	if next_signature == _last_model_signature:
		return
	_last_model_signature = next_signature
	_apply_model(display_model)


func _apply_empty_model() -> void:
	if _last_model_signature == EMPTY_MODEL_SIGNATURE:
		return
	_last_model_signature = EMPTY_MODEL_SIGNATURE
	_model_apply_count += 1
	_current_model.clear()
	_row_body_ids.clear()
	_clear_rows()
	if _title_label != null:
		_title_label.text = "Root Inspector"
	if _type_label != null:
		_type_label.text = "BLACK_HOLE"
	if _summary_label != null:
		_summary_label.text = "No root selected"


func _apply_model(model: Dictionary) -> void:
	_model_apply_count += 1
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

		_rows_vbox.add_child(_make_row_control(row, body_id))


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


func _display_model_for_current_mode(model: Dictionary) -> Dictionary:
	if _compact_root_overview:
		return _compact_root_overview_model(model)
	if _compact_focus_branch:
		return _compact_focus_branch_model(model)
	return model


func _compact_root_overview_model(model: Dictionary) -> Dictionary:
	var compact_model: Dictionary = model.duplicate(true)
	var compact_rows: Array[Dictionary] = []
	for row_variant in model.get("rows", []):
		var row: Dictionary = row_variant
		if _is_compact_root_overview_row(row):
			compact_rows.append(row)
	compact_model["rows"] = compact_rows
	compact_model["display_mode"] = "compact_root_overview"
	return compact_model


func _compact_focus_branch_model(model: Dictionary) -> Dictionary:
	var compact_model: Dictionary = model.duplicate(true)
	var compact_rows: Array[Dictionary] = []
	var rows: Array = model.get("rows", [])
	var parent_by_id: Dictionary = _parent_map_for_rows(rows)
	for row_variant in rows:
		var row: Dictionary = row_variant
		if _is_compact_focus_branch_row(row, _focused_body_id, parent_by_id):
			compact_rows.append(row)
	compact_model["rows"] = compact_rows
	compact_model["display_mode"] = "compact_focus_branch:%s" % String(_focused_body_id)
	return compact_model


static func _is_compact_root_overview_row(row: Dictionary) -> bool:
	return int(row.get("depth", 0)) <= 1


static func _is_compact_focus_branch_row(row: Dictionary, focused_body_id: StringName, parent_by_id: Dictionary) -> bool:
	if int(row.get("depth", 0)) <= 1:
		return true
	var body_id: StringName = row.get("body_id", StringName(""))
	if focused_body_id == StringName("") or body_id == StringName(""):
		return false
	return _is_same_or_ancestor(body_id, focused_body_id, parent_by_id) \
		or _is_same_or_ancestor(focused_body_id, body_id, parent_by_id)


static func _is_same_or_ancestor(candidate_id: StringName, body_id: StringName, parent_by_id: Dictionary) -> bool:
	var current_id: StringName = body_id
	while current_id != StringName(""):
		if current_id == candidate_id:
			return true
		current_id = StringName(parent_by_id.get(current_id, StringName("")))
	return false


static func _parent_map_for_rows(rows: Array) -> Dictionary:
	var parent_by_id: Dictionary = {}
	for row_variant in rows:
		var row: Dictionary = row_variant
		var body_id: StringName = row.get("body_id", StringName(""))
		if body_id == StringName(""):
			continue
		parent_by_id[body_id] = StringName(row.get("parent_id", StringName("")))
	return parent_by_id


func _full_model_row_count() -> int:
	var rows: Array = _current_model.get("rows", [])
	return rows.size()


static func _model_signature(model: Dictionary) -> String:
	var parts: Array[String] = [
		"root",
		String(model.get("display_mode", "full")),
		String(model.get("root_id", StringName(""))),
		String(model.get("root_name", "")),
		String(model.get("root_kind_text", "")),
	]
	var summary: Dictionary = model.get("summary", {})
	for key in ["stars", "planets", "moons", "habitable", "harsh", "hostile"]:
		parts.append("%s=%s" % [key, int(summary.get(key, 0))])
	for row_variant in model.get("rows", []):
		var row: Dictionary = row_variant
		parts.append("row")
		parts.append(String(row.get("body_id", StringName(""))))
		parts.append(String(row.get("parent_id", StringName(""))))
		parts.append(str(int(row.get("depth", 0))))
		parts.append(str(int(row.get("kind_id", -1))))
		parts.append(String(row.get("name_text", "")))
		parts.append(String(row.get("kind_text", "")))
		parts.append(_bool_signature(bool(row.get("has_environment_badge", false))))
		parts.append(str(int(row.get("environment_class", -1))))
		parts.append(str(int(row.get("ecosystem_type", -1))))
		parts.append(_bool_signature(bool(row.get("has_life_badge", false))))
		parts.append(String(row.get("life_badge_text", "")))
		parts.append(str(int(row.get("biosphere_stage", -1))))
		parts.append(String(row.get("note_text", "")))
		parts.append(String(row.get("detail_text", "")))
		parts.append(_bool_signature(bool(row.get("is_focused", false))))
	return "|".join(parts)


static func _bool_signature(value: bool) -> String:
	return "1" if value else "0"


func _make_row_control(row: Dictionary, body_id: StringName) -> Control:
	var row_control = RootInspectorRowScript.new()
	row_control.configure(row, body_id, ROW_INDENT_PX)
	# Inspector rows can rebuild while the sim runs. Route row signals
	# deferred so a rebuild never frees this row inside its own input event.
	row_control.focus_requested.connect(_on_row_pressed, CONNECT_DEFERRED)
	row_control.life_details_requested.connect(_on_life_chip_pressed, CONNECT_DEFERRED)
	return row_control


func _on_row_gui_input(event: InputEvent, body_id: StringName) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			_on_row_pressed(body_id)


func _on_row_pressed(body_id: StringName) -> void:
	focus_requested.emit(body_id)


func _on_life_chip_pressed(body_id: StringName) -> void:
	life_details_requested.emit(body_id)


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


static func _node_name_fragment(body_id: StringName) -> String:
	return String(body_id).replace(":", "_").replace(".", "_").replace("/", "_")
