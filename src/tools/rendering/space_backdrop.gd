extends Control

const _BACKDROP_SHADER := preload("res://src/tools/rendering/shaders/space_backdrop.gdshader")

var _seed: int = 424242
var _star_density: float = 1.0
var _band_strength: float = 1.0
var _nebula_strength: float = 1.0
var _composition_viewport_size: Vector2 = Vector2.ZERO

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
	_ensure_material()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_capture_composition_viewport_size_if_needed()
	_sync_shader_params()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, true)


func _on_resized() -> void:
	_capture_composition_viewport_size_if_needed()
	_sync_shader_params()


func _ensure_material() -> ShaderMaterial:
	var mat := material as ShaderMaterial
	if mat != null and mat.shader == _BACKDROP_SHADER:
		return mat

	mat = ShaderMaterial.new()
	mat.shader = _BACKDROP_SHADER
	material = mat
	return mat


func _sync_shader_params() -> void:
	var mat := _ensure_material()
	var composition_size := _composition_viewport_size if _composition_viewport_size != Vector2.ZERO else size
	mat.set_shader_parameter("viewport_size", composition_size)
	mat.set_shader_parameter("seed", float(_seed))
	mat.set_shader_parameter("star_density", _star_density)
	mat.set_shader_parameter("band_strength", _band_strength)
	mat.set_shader_parameter("nebula_strength", _nebula_strength)
	if is_inside_tree():
		queue_redraw()


func _capture_composition_viewport_size_if_needed() -> void:
	if _composition_viewport_size != Vector2.ZERO:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# Freeze the large-scale dust composition once so later editor/view
	# resizes do not remap the whole backdrop.
	_composition_viewport_size = size
