class_name LifeDetailPanel
extends PanelContainer


const OrbitHudFormatterScript = preload("res://src/tools/rendering/orbit_hud_formatter.gd")

const PANEL_MIN_WIDTH: float = 360.0

var _registry: Node = null
var _snapshot_cache = null
var _body_id: StringName = &""

var _title_label: Label = null
var _kind_label: Label = null
var _lines_vbox: VBoxContainer = null
var _line_labels: Array[Label] = []
var _placeholder_labels: Array[Label] = []


func _ready() -> void:
	_ensure_ui()
	visible = false


func configure(registry: Node, snapshot_cache) -> void:
	_registry = registry
	_snapshot_cache = snapshot_cache
	_ensure_ui()


func open_for_body(body_id: StringName) -> void:
	_ensure_ui()
	if visible and _body_id == body_id:
		close_panel()
		return
	_body_id = body_id
	_apply_body(body_id)
	visible = true


func close_panel() -> void:
	visible = false
	_body_id = StringName("")


func get_debug_snapshot() -> Dictionary:
	return {
		"is_open": visible,
		"body_id": _body_id,
		"title_text": "" if _title_label == null else _title_label.text,
		"kind_text": "" if _kind_label == null else _kind_label.text,
		"line_texts": _label_texts(_line_labels),
		"placeholder_texts": _label_texts(_placeholder_labels),
	}


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			close_panel()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()


func _ensure_ui() -> void:
	if _lines_vbox != null:
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
	_title_label.name = "TitleLabel"
	_title_label.text = "Life Details"
	_title_label.add_theme_color_override("font_color", Color(0.937255, 0.968627, 1.0, 1.0))
	_title_label.add_theme_font_size_override("font_size", 20)
	header_vbox.add_child(_title_label)

	_kind_label = Label.new()
	_kind_label.name = "KindLabel"
	_kind_label.text = "PLANET"
	_kind_label.add_theme_color_override("font_color", Color(0.654902, 0.772549, 0.937255, 0.78))
	header_vbox.add_child(_kind_label)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(close_panel)
	header_hbox.add_child(close_button)

	var separator := HSeparator.new()
	root_vbox.add_child(separator)

	_lines_vbox = VBoxContainer.new()
	_lines_vbox.name = "Lines"
	_lines_vbox.add_theme_constant_override("separation", 6)
	root_vbox.add_child(_lines_vbox)

	for _index in range(7):
		var label := _make_line_label()
		_lines_vbox.add_child(label)
		_line_labels.append(label)

	var placeholder_separator := HSeparator.new()
	root_vbox.add_child(placeholder_separator)

	for placeholder_text in [
		"Population: not established",
		"Native forms: pending",
		"Visual profile: pending",
	]:
		var placeholder_label := _make_line_label()
		placeholder_label.text = placeholder_text
		placeholder_label.add_theme_color_override("font_color", Color(0.760784, 0.835294, 0.945098, 0.84))
		root_vbox.add_child(placeholder_label)
		_placeholder_labels.append(placeholder_label)


func _apply_body(body_id: StringName) -> void:
	var body_def: BodyDef = null
	if _registry != null and _registry.has_body(body_id):
		body_def = _registry.get_def(body_id)
	_title_label.text = "Life Details: %s" % _display_name(body_def, body_id)
	_kind_label.text = BodyType.to_string_kind(body_def.kind) if body_def != null else "UNKNOWN"

	var biosphere_desc: Dictionary = _snapshot_cache.get_biosphere_scale_desc(body_id) if _snapshot_cache != null else {}
	var genetic_species_desc: Dictionary = _snapshot_cache.get_genetic_species_desc(body_id) if _snapshot_cache != null and _snapshot_cache.has_method("get_genetic_species_desc") else {}
	var life_ecology_desc: Dictionary = _snapshot_cache.get_life_ecology_desc(body_id) if _snapshot_cache != null and _snapshot_cache.has_method("get_life_ecology_desc") else {}
	var lines: Array[String] = [
		OrbitHudFormatterScript.format_environment(_snapshot_cache.get_environment_desc(body_id) if _snapshot_cache != null else {}),
		OrbitHudFormatterScript.format_world(_snapshot_cache.get_planetary_state_desc(body_id) if _snapshot_cache != null else {}),
		OrbitHudFormatterScript.format_life(biosphere_desc),
		OrbitHudFormatterScript.format_density(biosphere_desc),
		OrbitHudFormatterScript.format_life_detail_species_or_dominant(
			_snapshot_cache.get_native_species_desc(body_id) if _snapshot_cache != null else {},
			genetic_species_desc,
			biosphere_desc
		),
		OrbitHudFormatterScript.format_life_potential(_snapshot_cache.get_life_potential_desc(body_id) if _snapshot_cache != null else {}),
		OrbitHudFormatterScript.format_biomass(biosphere_desc),
	]
	for index in range(_line_labels.size()):
		_line_labels[index].text = lines[index] if index < lines.size() else ""
	var placeholder_lines: Array[String] = [
		OrbitHudFormatterScript.format_population(life_ecology_desc),
		OrbitHudFormatterScript.format_native_forms(genetic_species_desc),
		OrbitHudFormatterScript.format_visual_profile(genetic_species_desc),
	]
	for index in range(_placeholder_labels.size()):
		_placeholder_labels[index].text = placeholder_lines[index] if index < placeholder_lines.size() else ""


static func _make_line_label() -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color(0.901961, 0.933333, 0.984314, 0.94))
	label.add_theme_font_size_override("font_size", 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0352941, 0.0509804, 0.0941176, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.388235, 0.592157, 0.87451, 0.38)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 10
	return style


static func _display_name(body_def: BodyDef, fallback_id: StringName) -> String:
	if body_def == null:
		return String(fallback_id)
	return body_def.display_name if body_def.display_name != "" else String(body_def.id)


static func _label_texts(labels: Array[Label]) -> PackedStringArray:
	var out := PackedStringArray()
	for label in labels:
		if label != null:
			out.append(label.text)
	return out
