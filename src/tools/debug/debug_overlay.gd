class_name DebugOverlay
extends CanvasLayer

# Nur-lesendes Debug-Overlay. Schreibt NICHTS in den Sim-Zustand.
# Zeigt autoritative (Zeit, Body-Daten) und abgeleitete (View-Distanzen)
# Groessen nebeneinander und kennzeichnet sie entsprechend.

@onready var _label: RichTextLabel = $Panel/Label

var _registry: Node = null
var _time: Node = null
var _bubble: Node = null


func configure(registry: Node, time_service: Node, bubble: Node) -> void:
	_registry = registry
	_time = time_service
	_bubble = bubble


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
	lines.append("sim_time_s = %.3f   tick_count = %d" % [_time.sim_time_s, _time.tick_count])
	lines.append("time_scale = %.3f   paused = %s" % [_time.time_scale, str(_time.paused)])
	lines.append("body count = %d" % _registry.body_count())
	lines.append("focus_id   = %s  (view)" % str(_bubble.get_focus()))
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
	var world_m: Vector3 = _bubble.compose_world_position_m(id)
	return "  %s  kind=%s  parent=%s  mode=%s  |pf|=%.3g m  w=%.3g m" % [
		String(id),
		BodyType.to_string_kind(def.kind),
		parent_txt,
		mode_txt,
		r,
		world_m.length(),
	]
