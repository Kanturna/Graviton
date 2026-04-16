class_name DebugOverlay
extends CanvasLayer

# Nur-lesendes Debug-Overlay. Schreibt NICHTS in den Sim-Zustand.
# Zeigt autoritative (Zeit, Body-Daten) und abgeleitete (View, Render,
# Aktiv-Set) Groessen nebeneinander und kennzeichnet sie entsprechend.

@onready var _label: RichTextLabel = $Panel/Label

var _registry: Node = null
var _time: Node = null
var _bubble: Node = null
var _activation: Node = null


func configure(registry: Node, time_service: Node, bubble: Node, activation: Node = null) -> void:
	_registry = registry
	_time = time_service
	_bubble = bubble
	_activation = activation


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

	var focus_id: StringName = _bubble.get_focus()
	var focus_view_len: float = 0.0
	if focus_id != &"":
		focus_view_len = _bubble.compose_view_position_m(focus_id).length()
	lines.append("focus_id   = %s  |focus_view| = %.3e m  (muss 0 sein)" \
			% [str(focus_id), focus_view_len])
	lines.append("render_scale = %.3e m/unit" % UnitSystem.RENDER_SCALE_M_PER_UNIT)

	if _activation != null:
		lines.append("activation   = %s" % _activation.describe())
	lines.append("")
	lines.append("[b]Bodies (Wahrheit: parent-frame | abgeleitet: view, render, aktiv)[/b]")
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
	var pf_len: float = state.position_parent_frame_m.length()
	var world_m: Vector3 = _bubble.debug_compose_world_m(id)
	var view_m: Vector3 = _bubble.compose_view_position_m(id)
	var render_u: Vector3 = _bubble.to_render_units(view_m)
	var activation_txt: String = ""
	if _activation != null:
		match _activation.get_status(id):
			BubbleActivationSet.ActivationStatus.ACTIVE:
				activation_txt = "[ACTIVE]"
			BubbleActivationSet.ActivationStatus.INACTIVE_DISTANT:
				activation_txt = "[~approx]"
			BubbleActivationSet.ActivationStatus.INACTIVE_NO_LCA:
				activation_txt = "[~no-lca]"
	return ("  %s %s  kind=%s  parent=%s  mode=%s\n"
		+ "    [truth]  |pf|=%.3e m  |world|=%.3e m\n"
		+ "    [view]   |view|=%.3e m  |render|=%.3e u\n"
		+ "    %s") % [
			activation_txt,
			id,
			BodyType.to_string_kind(def.kind),
			parent_txt,
			mode_txt,
			pf_len,
			world_m.length(),
			view_m.length(),
			render_u.length(),
			_bubble.describe_chain(id),
		]
