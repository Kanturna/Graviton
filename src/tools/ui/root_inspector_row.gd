class_name RootInspectorRow
extends Control

signal focus_requested(body_id: StringName)
signal life_details_requested(body_id: StringName)

const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const SurveyVisualThemeScript = preload("res://src/tools/ui/survey_visual_theme.gd")

const ROW_PADDING_X: float = 10.0
const ROW_PADDING_Y: float = 8.0
const ROW_MIN_WIDTH: float = 328.0
const ROW_HEIGHT: float = 38.0
const ROW_DETAIL_HEIGHT: float = 58.0
const TEXT_GAP_PX: float = 7.0
const CHIP_GAP_PX: float = 6.0
const CHIP_PADDING_X: float = 7.0
const CHIP_PADDING_Y: float = 3.0
const CHIP_HEIGHT_PX: float = 20.0
const NAME_FONT_SIZE: int = 13
const NAME_PLANETARY_FONT_SIZE: int = 14
const META_FONT_SIZE: int = 13
const CHIP_FONT_SIZE: int = 12
const DETAIL_FONT_SIZE: int = 12
const ELLIPSIS: String = "..."

var _body_id: StringName = StringName("")
var _row: Dictionary = {}
var _indent_px: int = 18
var _is_hovered: bool = false
var _life_chip_rect: Rect2 = Rect2()
var _normal_style: StyleBoxFlat = null
var _hover_style: StyleBoxFlat = null
var _active_style: StyleBoxFlat = null
var _chip_style_by_key: Dictionary = {}


func configure(row: Dictionary, body_id: StringName, indent_px: int) -> void:
	_body_id = body_id
	_row = row.duplicate(true)
	_indent_px = indent_px
	name = "Row_%s" % _node_name_fragment(body_id)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0.0, ROW_DETAIL_HEIGHT if _has_detail_text() else ROW_HEIGHT)
	_ensure_styles()
	_connect_hover_signals()
	_recompute_hit_rects()
	queue_redraw()


func get_body_id() -> StringName:
	return _body_id


func get_debug_snapshot() -> Dictionary:
	var environment_class: int = int(_row.get(
		"environment_class",
		EnvironmentServiceScript.Class.HOSTILE
	))
	var ecosystem_type: int = int(_row.get(
		"ecosystem_type",
		EnvironmentServiceScript.EcosystemType.FROZEN_WORLD
	))
	var biosphere_stage: int = int(_row.get("biosphere_stage", 0))
	return {
		"body_id": _body_id,
		"name_text": String(_row.get("name_text", "")),
		"kind_text": String(_row.get("kind_text", "")),
		"environment_chip_text": EnvironmentServiceScript.to_string_class(environment_class)
				if bool(_row.get("has_environment_badge", false)) else "",
		"climate_chip_text": EnvironmentServiceScript.to_string_ecosystem(ecosystem_type)
				if bool(_row.get("has_environment_badge", false)) else "",
		"life_chip_text": String(_row.get("life_badge_text", ""))
				if bool(_row.get("has_life_badge", false)) else "",
		"note_text": String(_row.get("note_text", "")),
		"detail_text": String(_row.get("detail_text", "")),
		"has_environment_badge": bool(_row.get("has_environment_badge", false)),
		"has_life_badge": bool(_row.get("has_life_badge", false)),
		"is_focused": bool(_row.get("is_focused", false)),
		"name_color": SurveyVisualThemeScript.color_for_body_kind(int(_row.get("kind_id", -1))),
		"environment_color": SurveyVisualThemeScript.color_for_environment_class(environment_class),
		"climate_color": SurveyVisualThemeScript.color_for_ecosystem_type(ecosystem_type),
		"life_color": SurveyVisualThemeScript.color_for_life_stage(biosphere_stage),
		"life_chip_rect": _life_chip_rect,
	}


func _draw() -> void:
	_recompute_hit_rects()
	var row_rect := Rect2(Vector2.ZERO, Vector2(maxf(size.x, ROW_MIN_WIDTH), custom_minimum_size.y))
	draw_style_box(_row_style(), row_rect)

	var font: Font = _row_font()
	if font == null:
		return

	var x: float = ROW_PADDING_X + float(int(_row.get("depth", 0)) * _indent_px)
	var y: float = ROW_PADDING_Y
	var max_right: float = maxf(size.x, ROW_MIN_WIDTH) - ROW_PADDING_X
	var baseline_y: float = y + 14.0
	var name_text: String = String(_row.get("name_text", ""))
	var kind_text: String = String(_row.get("kind_text", ""))
	var kind_id: int = int(_row.get("kind_id", -1))
	var name_size: int = NAME_PLANETARY_FONT_SIZE if _is_planetary_kind(kind_id) else NAME_FONT_SIZE
	x = _draw_text_segment(
		font,
		name_text,
		Vector2(x, baseline_y),
		max_right - x,
		name_size,
		SurveyVisualThemeScript.color_for_body_kind(kind_id)
	) + TEXT_GAP_PX
	x = _draw_text_segment(
		font,
		kind_text,
		Vector2(x, baseline_y),
		max_right - x,
		META_FONT_SIZE,
		Color(0.772549, 0.835294, 0.952941, 0.86)
	) + TEXT_GAP_PX

	if bool(_row.get("has_life_badge", false)):
		var life_stage: int = int(_row.get("biosphere_stage", 0))
		x = _draw_chip(
			font,
			String(_row.get("life_badge_text", "")),
			SurveyVisualThemeScript.color_for_life_stage(life_stage),
			Vector2(x, y + 1.0),
			max_right,
			true
		) + CHIP_GAP_PX

	if bool(_row.get("has_environment_badge", false)):
		var environment_class: int = int(_row.get(
			"environment_class",
			EnvironmentServiceScript.Class.HOSTILE
		))
		x = _draw_chip(
			font,
			EnvironmentServiceScript.to_string_class(environment_class),
			SurveyVisualThemeScript.color_for_environment_class(environment_class),
			Vector2(x, y + 1.0),
			max_right
		) + CHIP_GAP_PX

		var ecosystem_type: int = int(_row.get(
			"ecosystem_type",
			EnvironmentServiceScript.EcosystemType.FROZEN_WORLD
		))
		x = _draw_chip(
			font,
			EnvironmentServiceScript.to_string_ecosystem(ecosystem_type),
			SurveyVisualThemeScript.color_for_ecosystem_type(ecosystem_type),
			Vector2(x, y + 1.0),
			max_right
		) + CHIP_GAP_PX

	var note_text: String = String(_row.get("note_text", ""))
	if note_text != "" and x < max_right:
		_draw_text_segment(
			font,
			note_text,
			Vector2(x, baseline_y),
			max_right - x,
			META_FONT_SIZE,
			Color(0.862745, 0.905882, 0.984314, 0.88)
		)

	var detail_text: String = String(_row.get("detail_text", ""))
	if detail_text != "":
		_draw_text_segment(
			font,
			detail_text,
			Vector2(ROW_PADDING_X + float(int(_row.get("depth", 0)) * _indent_px), y + 34.0),
			max_right - ROW_PADDING_X,
			DETAIL_FONT_SIZE,
			Color(0.764706, 0.843137, 0.976471, 0.88)
		)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		_recompute_hit_rects()
		accept_event()
		if _life_chip_rect.has_point(mouse_event.position):
			life_details_requested.emit(_body_id)
		else:
			focus_requested.emit(_body_id)


func _connect_hover_signals() -> void:
	var entered := Callable(self, "_on_mouse_entered")
	if not mouse_entered.is_connected(entered):
		mouse_entered.connect(entered)
	var exited := Callable(self, "_on_mouse_exited")
	if not mouse_exited.is_connected(exited):
		mouse_exited.connect(exited)


func _on_mouse_entered() -> void:
	if _is_hovered:
		return
	_is_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	if not _is_hovered:
		return
	_is_hovered = false
	queue_redraw()


func _recompute_hit_rects() -> void:
	_life_chip_rect = Rect2()
	if not bool(_row.get("has_life_badge", false)):
		return
	var font: Font = _row_font()
	if font == null:
		return
	var x: float = ROW_PADDING_X + float(int(_row.get("depth", 0)) * _indent_px)
	var y: float = ROW_PADDING_Y + 1.0
	var max_right: float = maxf(size.x, ROW_MIN_WIDTH) - ROW_PADDING_X
	x += _text_width(font, String(_row.get("name_text", "")), NAME_FONT_SIZE) + TEXT_GAP_PX
	x += _text_width(font, String(_row.get("kind_text", "")), META_FONT_SIZE) + TEXT_GAP_PX
	if x >= max_right:
		return
	var life_width: float = minf(_chip_width(font, String(_row.get("life_badge_text", ""))), max_right - x)
	_life_chip_rect = Rect2(Vector2(x, y), Vector2(life_width, CHIP_HEIGHT_PX))


func _draw_text_segment(
		font: Font,
		text: String,
		position: Vector2,
		max_width: float,
		font_size: int,
		color: Color
	) -> float:
	if text == "" or max_width <= 0.0:
		return position.x
	var fitted: String = _fit_text(font, text, font_size, max_width)
	draw_string(font, position, fitted, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, color)
	return position.x + minf(_text_width(font, fitted, font_size), max_width)


func _draw_chip(
		font: Font,
		text: String,
		accent_color: Color,
		position: Vector2,
		max_right: float,
		is_life_chip: bool = false
	) -> float:
	if text == "" or position.x >= max_right:
		return position.x
	var chip_width: float = minf(_chip_width(font, text), max_right - position.x)
	var rect := Rect2(position, Vector2(chip_width, CHIP_HEIGHT_PX))
	if is_life_chip:
		_life_chip_rect = rect
	draw_style_box(_chip_style_for(accent_color), rect)
	var fitted: String = _fit_text(font, text, CHIP_FONT_SIZE, maxf(chip_width - CHIP_PADDING_X * 2.0, 0.0))
	draw_string(
		font,
		Vector2(rect.position.x + CHIP_PADDING_X, rect.position.y + 14.0),
		fitted,
		HORIZONTAL_ALIGNMENT_LEFT,
		chip_width - CHIP_PADDING_X * 2.0,
		CHIP_FONT_SIZE,
		accent_color
	)
	return rect.position.x + rect.size.x


func _fit_text(font: Font, text: String, font_size: int, max_width: float) -> String:
	if text == "" or max_width <= 0.0:
		return ""
	if _text_width(font, text, font_size) <= max_width:
		return text
	if _text_width(font, ELLIPSIS, font_size) > max_width:
		return ""
	var lo: int = 0
	var hi: int = text.length()
	var best: String = ELLIPSIS
	while lo <= hi:
		var mid: int = int((lo + hi) / 2)
		var candidate: String = "%s%s" % [text.left(mid), ELLIPSIS]
		if _text_width(font, candidate, font_size) <= max_width:
			best = candidate
			lo = mid + 1
		else:
			hi = mid - 1
	return best


func _text_width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


func _row_font() -> Font:
	var font: Font = get_theme_font("font", "Label")
	if font != null:
		return font
	return ThemeDB.get_fallback_font()


func _chip_width(font: Font, text: String) -> float:
	return _text_width(font, text, CHIP_FONT_SIZE) + CHIP_PADDING_X * 2.0


func _has_detail_text() -> bool:
	return String(_row.get("detail_text", "")) != ""


func _row_style() -> StyleBoxFlat:
	if bool(_row.get("is_focused", false)):
		return _active_style
	if _is_hovered:
		return _hover_style
	return _normal_style


func _chip_style_for(accent_color: Color) -> StyleBoxFlat:
	var key: String = "%.3f|%.3f|%.3f|%.3f" % [
		accent_color.r,
		accent_color.g,
		accent_color.b,
		accent_color.a,
	]
	if not _chip_style_by_key.has(key):
		_chip_style_by_key[key] = _make_chip_style(accent_color)
	return _chip_style_by_key[key]


func _ensure_styles() -> void:
	if _normal_style != null:
		return
	_normal_style = _make_row_style(Color(0.0509804, 0.0705882, 0.129412, 0.30), Color(0.243137, 0.364706, 0.556863, 0.22))
	_hover_style = _make_row_style(Color(0.0784314, 0.109804, 0.180392, 0.82), Color(0.411765, 0.619608, 0.917647, 0.30))
	_active_style = _make_row_style(Color(0.105882, 0.14902, 0.243137, 0.94), Color(0.576471, 0.784314, 0.992157, 0.48))


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
	style.content_margin_left = ROW_PADDING_X
	style.content_margin_top = ROW_PADDING_Y
	style.content_margin_right = ROW_PADDING_X
	style.content_margin_bottom = ROW_PADDING_Y
	return style


static func _make_chip_style(accent_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent_color.r * 0.22, accent_color.g * 0.22, accent_color.b * 0.22, 0.34)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.34)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style


static func _is_planetary_kind(kind: int) -> bool:
	return kind == BodyType.Kind.PLANET or kind == BodyType.Kind.MOON


static func _node_name_fragment(body_id: StringName) -> String:
	return String(body_id).replace(":", "_").replace(".", "_").replace("/", "_")
