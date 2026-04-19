extends Control

const _BACKDROP_SHADER := preload("res://src/tools/rendering/shaders/space_backdrop.gdshader")

var _seed: int = 424242
var _star_density: float = 1.0
var _band_strength: float = 1.0
var _nebula_strength: float = 1.0
var _composition_viewport_size: Vector2 = Vector2.ZERO
var _display_rect: TextureRect = null
var _bake_viewport: SubViewport = null
var _bake_fill: ColorRect = null
var _sync_count: int = 0
var _bake_count: int = 0
var _resize_count: int = 0
var _viewport_resize_count: int = 0

@export var seed: int:
	get:
		return _seed
	set(value):
		_seed = value
		_sync_shader_params()
@export_range(0.25, 2.50, 0.01) var star_density: float:
	get:
		return _star_density
	set(value):
		_star_density = value
		_sync_shader_params()
@export_range(0.0, 2.0, 0.01) var band_strength: float:
	get:
		return _band_strength
	set(value):
		_band_strength = value
		_sync_shader_params()
@export_range(0.0, 2.0, 0.01) var nebula_strength: float:
	get:
		return _nebula_strength
	set(value):
		_nebula_strength = value
		_sync_shader_params()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_bake_nodes()
	_ensure_material()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_sync_shader_params()
	call_deferred("_capture_initial_composition_viewport")


func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.disconnect(_on_viewport_size_changed)


func _on_resized() -> void:
	_resize_count += 1
	_capture_composition_viewport_size_if_needed()
	_sync_shader_params()


func _on_viewport_size_changed() -> void:
	_viewport_resize_count += 1
	_sync_shader_params()


func _capture_initial_composition_viewport() -> void:
	_capture_composition_viewport_size_if_needed()
	_sync_shader_params()


func _ensure_bake_nodes() -> void:
	if _display_rect == null:
		_display_rect = TextureRect.new()
		_display_rect.name = "BackdropDisplay"
		_display_rect.anchor_right = 1.0
		_display_rect.anchor_bottom = 1.0
		_display_rect.offset_left = 0.0
		_display_rect.offset_top = 0.0
		_display_rect.offset_right = 0.0
		_display_rect.offset_bottom = 0.0
		_display_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_display_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_display_rect.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(_display_rect)

	if _bake_viewport == null:
		_bake_viewport = SubViewport.new()
		_bake_viewport.name = "BackdropBakeViewport"
		_bake_viewport.disable_3d = true
		_bake_viewport.transparent_bg = false
		_bake_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_bake_viewport)

	if _bake_fill == null:
		_bake_fill = ColorRect.new()
		_bake_fill.name = "BackdropBakeFill"
		_bake_fill.color = Color.WHITE
		_bake_fill.anchor_right = 1.0
		_bake_fill.anchor_bottom = 1.0
		_bake_fill.offset_left = 0.0
		_bake_fill.offset_top = 0.0
		_bake_fill.offset_right = 0.0
		_bake_fill.offset_bottom = 0.0
		_bake_viewport.add_child(_bake_fill)

	if _display_rect != null and _bake_viewport != null:
		_display_rect.texture = _bake_viewport.get_texture()


func _ensure_material() -> ShaderMaterial:
	_ensure_bake_nodes()
	var mat := _bake_fill.material as ShaderMaterial if _bake_fill != null else null
	if mat != null and mat.shader == _BACKDROP_SHADER:
		return mat

	mat = ShaderMaterial.new()
	mat.shader = _BACKDROP_SHADER
	if _bake_fill != null:
		_bake_fill.material = mat
	return mat


func _sync_shader_params() -> void:
	var mat := _ensure_material()
	var bake_size := _current_bake_size()
	var composition_size := _composition_viewport_size if _composition_viewport_size != Vector2.ZERO else bake_size
	mat.set_shader_parameter("viewport_size", composition_size)
	mat.set_shader_parameter("render_size", bake_size)
	mat.set_shader_parameter("seed", float(_seed))
	mat.set_shader_parameter("star_density", _star_density)
	mat.set_shader_parameter("band_strength", _band_strength)
	mat.set_shader_parameter("nebula_strength", _nebula_strength)
	_sync_count += 1
	if is_inside_tree():
		_queue_bake()


func _queue_bake() -> void:
	_ensure_bake_nodes()
	if _bake_viewport == null or _bake_fill == null:
		return
	var bake_size := _current_bake_size()
	if bake_size.x <= 0.0 or bake_size.y <= 0.0:
		return
	_bake_viewport.size = Vector2i(
		maxi(int(round(bake_size.x)), 1),
		maxi(int(round(bake_size.y)), 1)
	)
	_bake_fill.size = bake_size
	_bake_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_bake_count += 1


func _capture_composition_viewport_size_if_needed() -> void:
	if _composition_viewport_size != Vector2.ZERO:
		return
	var viewport_size := _current_render_target_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	# Freeze the large-scale dust composition once so later editor/view
	# resizes do not remap the whole backdrop.
	_composition_viewport_size = viewport_size


static func composition_uv_for_screen_px(screen_px: Vector2, composition_size: Vector2) -> Vector2:
	var safe_composition := Vector2(maxf(composition_size.x, 1.0), maxf(composition_size.y, 1.0))
	var composition_px: Vector2 = screen_px
	return Vector2(
		composition_px.x / safe_composition.x,
		composition_px.y / safe_composition.y
	)


func debug_snapshot() -> Dictionary:
	return {
		"control_size": size,
		"viewport_rect_size": get_viewport_rect().size if is_inside_tree() else size,
		"render_target_size": _current_render_target_size(),
		"bake_size": _current_bake_size(),
		"composition_size": _composition_viewport_size if _composition_viewport_size != Vector2.ZERO else _current_render_target_size(),
		"sync_count": _sync_count,
		"bake_count": _bake_count,
		"resize_count": _resize_count,
		"viewport_resize_count": _viewport_resize_count,
	}


func _current_draw_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2.ZERO


func _current_render_target_size() -> Vector2:
	if is_inside_tree():
		var viewport := get_viewport()
		if viewport != null:
			var viewport_texture := viewport.get_texture()
			if viewport_texture != null:
				var texture_size := viewport_texture.get_size()
				if texture_size.x > 0.0 and texture_size.y > 0.0:
					return texture_size
		return get_viewport_rect().size
	return size


func _current_bake_size() -> Vector2:
	var draw_size := _current_draw_size()
	if draw_size.x > 0.0 and draw_size.y > 0.0:
		return draw_size
	return _current_render_target_size()
