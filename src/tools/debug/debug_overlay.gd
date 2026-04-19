class_name DebugOverlay
extends CanvasLayer

const BubbleActivationSetScript = preload("res://src/runtime/local_bubble/bubble_activation_set.gd")
const ThermalServiceScript = preload("res://src/sim/thermal/thermal_service.gd")

# Nur-lesendes Debug-Overlay. Schreibt NICHTS in den Sim-Zustand.
# Zeigt autoritative (Zeit, Body-Daten) und abgeleitete (View-Distanzen)
# Groessen nebeneinander und kennzeichnet sie entsprechend.

@onready var _label: RichTextLabel = $Panel/Label

var _registry: Node = null
var _time: Node = null
var _bubble: Node = null
var _activation_set: Node = null
var _thermal_service: Node = null
var _snapshot_cache = null
var _backdrop = null


func configure(registry: Node, time_service: Node, bubble: Node, activation_set: Node = null, thermal_service: Node = null, snapshot_cache = null, backdrop = null) -> void:
	_registry = registry
	_time = time_service
	_bubble = bubble
	_activation_set = activation_set
	_thermal_service = thermal_service
	_snapshot_cache = snapshot_cache
	_backdrop = backdrop


func _process(_delta: float) -> void:
	if _label == null:
		return
	if _registry == null or _time == null or _bubble == null:
		_label.text = "[DebugOverlay] not configured"
		return
	_label.text = _build_text()


func _build_text() -> String:
	var lines: Array[String] = []
	lines.append("[b]Graviton Testbed[/b]")
	lines.append("sim_time_s = %.3f   step_count = %d" % [_time.sim_time_s, _time.tick_count])
	lines.append("time_scale = %.3f   paused = %s" % [_time.time_scale, str(_time.paused)])
	lines.append("body count = %d" % _registry.body_count())
	lines.append("focus_id   = %s  (view)" % str(_bubble.get_focus()))
	if _activation_set != null:
		var activation_desc: Dictionary = _activation_set.describe()
		lines.append(
			"activation_radius_m = %s   active_count = %d"
			% [
				_format_metric(float(activation_desc.get(BubbleActivationSetScript.KEY_ACTIVATION_RADIUS_M, 0.0))),
				int(activation_desc.get(BubbleActivationSetScript.KEY_ACTIVE_COUNT, 0))
			]
		)
	if _backdrop != null and _backdrop.has_method("debug_snapshot"):
		var backdrop_desc: Dictionary = _backdrop.debug_snapshot()
		lines.append(
			"backdrop control=%s  viewport=%s  render=%s  bake=%s  composition=%s"
			% [
				str(backdrop_desc.get("control_size", Vector2.ZERO)),
				str(backdrop_desc.get("viewport_rect_size", Vector2.ZERO)),
				str(backdrop_desc.get("render_target_size", Vector2.ZERO)),
				str(backdrop_desc.get("bake_size", Vector2.ZERO)),
				str(backdrop_desc.get("composition_size", Vector2.ZERO)),
			]
		)
		lines.append(
			"backdrop sync/bake=%d/%d  resize=%d  viewport_resize=%d"
			% [
				int(backdrop_desc.get("sync_count", 0)),
				int(backdrop_desc.get("bake_count", 0)),
				int(backdrop_desc.get("resize_count", 0)),
				int(backdrop_desc.get("viewport_resize_count", 0)),
			]
		)
	lines.append("")
	lines.append("[b]Bodies (truth: parent-frame)[/b]")
	for id in _registry.get_update_order():
		lines.append(_format_body_line(id))
	return "\n".join(lines)


func _format_body_line(id: StringName) -> String:
	var def: BodyDef = _registry.get_def(id)
	var state: BodyState = _registry.get_state(id)
	if def == null or state == null:
		return "  %s: <missing>" % id
	var parent_txt: String = "(root)" if def.is_root() else str(def.parent_id)
	var mode_txt: String = OrbitMode.to_string_kind(state.current_mode)
	var pos: Vector3 = state.position_parent_frame_m
	var r: float = pos.length()
	var root_local_m: Vector3 = _bubble.compose_root_local_position_m(id)
	var activation_txt: String = ""
	if _activation_set != null:
		activation_txt = "  activation=%s" % _activation_set.to_string_state(_activation_set.classify(id))
	var thermal_txt: String = ""
	if _snapshot_cache != null or _thermal_service != null:
		var thermal_desc: Dictionary = _snapshot_cache.get_thermal_desc(id) if _snapshot_cache != null else _thermal_service.describe_body(id)
		var source_id: StringName = thermal_desc.get(ThermalServiceScript.KEY_SOURCE_ID, StringName(""))
		var source_txt: String = "none" if source_id == StringName("") else String(source_id)
		thermal_txt = "  primary_source=%s  insolation=%s W/m^2  absorbed=%s W/m^2  teq=%s K" % [
			source_txt,
			_format_metric(float(thermal_desc.get(ThermalServiceScript.KEY_INSOLATION_WPM2, 0.0))),
			_format_metric(float(thermal_desc.get(ThermalServiceScript.KEY_ABSORBED_FLUX_WPM2, 0.0))),
			_format_metric(float(thermal_desc.get(ThermalServiceScript.KEY_EQUILIBRIUM_TEMPERATURE_K, 0.0))),
		]
	return "  %s  kind=%s  parent=%s  mode=%s  |pf|=%s m  root_local=%s m%s" % [
		String(id),
		BodyType.to_string_kind(def.kind),
		parent_txt,
		mode_txt,
		_format_metric(r),
		_format_optional_metric(root_local_m),
		activation_txt + thermal_txt,
	]


static func _format_metric(value: float) -> String:
	if absf(value) >= 1.0e6 or (absf(value) > 0.0 and absf(value) < 1.0):
		return str(value)
	return str(snappedf(value, 0.001))


static func _format_optional_metric(value: Vector3) -> String:
	if not is_finite(value.x) or not is_finite(value.y) or not is_finite(value.z):
		return "n/a"
	return _format_metric(value.length())
