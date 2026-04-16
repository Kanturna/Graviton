class_name LocalBubbleManager
extends Node

# ABGELEITETE Darstellungs-/Lokalisierungsebene.
#
# Wichtige Klarstellung zur Semantik:
#   Die kanonische Wahrheit ueber Koerperpositionen liegt in
#   BodyState.position_parent_frame_m. Dieser Dienst besitzt KEINE
#   autoritativen Zustaende — er leitet Darstellungskoordinaten aus
#   den Parent-Frame-Wahrheiten ab und veraendert sie NIEMALS.
#
# Rueckgabewerte tragen bewusst den Suffix _view_m oder _render_units,
# niemals bloss `position`, damit im Aufruf-Code sichtbar bleibt, dass
# View-Space beschrieben wird, nicht Sim-Space.
#
# Fokus-relative Komposition (LCA-Trick):
#   World-Positionen werden NIEMALS als gespeicherter Wert materialisiert.
#   Der Vektor target - focus wird direkt ueber den LCA (Lowest Common
#   Ancestor) in der Body-Hierarchie berechnet. Die Zwischenrechnung
#   akkumuliert Parent-Frame-Offsets als GDScript-float (IEEE-754 double),
#   nicht als Vector3 (float32-Komponenten). Erst das bereits kleine
#   fokus-relative Ergebnis wird in einen Vector3 gegossen.
#   Das verhindert float32-Praezisionsverlust bei AU-Distanzen.
#
# Koordinatenraeume:
#   Sim-Space    — BodyState.position_parent_frame_m      (Wahrheit)
#   World-Space  — konzeptionell; NIEMALS persistiert
#   View-Space   — fokus-relativ, in Metern               (abgeleitet)
#   Render-Units — View-Space / RENDER_SCALE              (Projektion)
#
# Fehlerpfad "kein gemeinsamer Vorfahre":
#   compose_view_position_m gibt Vector3.INF zurueck und ruft push_error.
#   Kein stilles ZERO — semantisch falsch lokalisierte Objekte sollen
#   sichtbar und nicht unentdeckt falsch sein.

signal focus_changed(new_id: StringName)

const _INVALID_LCA: StringName = &"__NO_LCA__"

var _registry: Node = null
var _focus_id: StringName = &""


func configure(registry: Node) -> void:
	assert(registry != null, "LocalBubbleManager.configure: registry is null")
	_registry = registry


func set_focus(body_id: StringName) -> void:
	if body_id == _focus_id:
		return
	_focus_id = body_id
	focus_changed.emit(body_id)


func get_focus() -> StringName:
	return _focus_id


# Fokus-relative View-Position in Metern.
# Intern double-praezise. Ergebnis als Vector3 (klein, weil Fokus-Offset
# bereits abgezogen).
#
# Fehlerfaelle:
#   _registry null        → Vector3.ZERO
#   kein Fokus gesetzt    → World-Space + push_warning (Praezision kompromittiert)
#   kein gemeinsamer LCA  → Vector3.INF + push_error
func compose_view_position_m(target_id: StringName) -> Vector3:
	if _registry == null:
		return Vector3.ZERO
	if _focus_id == &"":
		push_warning("LocalBubbleManager: kein Fokus gesetzt — World-Space-Fallback fuer '%s'" % target_id)
		return _double_compose_world(target_id)
	var chain_target: Array[StringName] = _chain_to_root(target_id)
	var chain_focus: Array[StringName] = _chain_to_root(_focus_id)
	var lca: StringName = _find_lca(chain_target, chain_focus)
	if lca == _INVALID_LCA:
		push_error("LocalBubbleManager: kein gemeinsamer Vorfahre fuer '%s' und Fokus '%s'" \
				% [target_id, _focus_id])
		return Vector3.INF
	var t: Array[float] = _double_sum_to_lca(chain_target, lca)
	var f: Array[float] = _double_sum_to_lca(chain_focus, lca)
	return Vector3(t[0] - f[0], t[1] - f[1], t[2] - f[2])


# Einzige erlaubte Anwendung von RENDER_SCALE_M_PER_UNIT.
func to_render_units(view_m: Vector3) -> Vector3:
	return view_m / UnitSystem.RENDER_SCALE_M_PER_UNIT


# Komfortkette: compose_view_position_m + to_render_units.
func compose_render_units(target_id: StringName) -> Vector3:
	return to_render_units(compose_view_position_m(target_id))


# Menschenlesbare Kette fuer DebugOverlay und Tests.
# Zeigt: Parent-Kette des Targets, LCA zum Fokus, View-Betrag.
func describe_chain(target_id: StringName) -> String:
	if _registry == null:
		return "describe_chain: nicht konfiguriert"
	var chain_target: Array[StringName] = _chain_to_root(target_id)
	var parts: PackedStringArray = PackedStringArray()
	for id in chain_target:
		parts.append(str(id))
	var chain_txt: String = " -> ".join(parts)
	var lca_txt: String
	var view_txt: String
	if _focus_id == &"":
		lca_txt = "(kein Fokus)"
		view_txt = "World-Fallback"
	else:
		var chain_focus: Array[StringName] = _chain_to_root(_focus_id)
		var lca: StringName = _find_lca(chain_target, chain_focus)
		if lca == _INVALID_LCA:
			lca_txt = "(kein gemeinsamer Vorfahre)"
			view_txt = "INF"
		else:
			lca_txt = str(lca)
			var view_m: Vector3 = compose_view_position_m(target_id)
			view_txt = "%.3e m" % view_m.length()
	return "  Kette: %s | LCA mit Fokus '%s': %s | |view|=%s" \
			% [chain_txt, str(_focus_id), lca_txt, view_txt]


# ACHTUNG: Nur fuer Tests und Debug-Prints.
# Absolute Welt-Position, doppelt-praezise akkumuliert, aber trotzdem
# am Ende float32-Vector3. NIEMALS im Render-Pfad verwenden.
func debug_compose_world_m(target_id: StringName) -> Vector3:
	if _registry == null:
		return Vector3.ZERO
	return _double_compose_world(target_id)


# ──────────────────────────────────────────────────
# Private Hilfsfunktionen
# ──────────────────────────────────────────────────

# Gibt die Parent-Kette von id bis zur Wurzel zurueck: [id, parent, ..., root].
func _chain_to_root(id: StringName) -> Array[StringName]:
	var chain: Array[StringName] = []
	var cursor: StringName = id
	var hop_limit: int = 64
	while cursor != &"" and hop_limit > 0:
		chain.append(cursor)
		var state: BodyState = _registry.get_state(cursor)
		if state == null:
			break
		cursor = state.parent_id
		hop_limit -= 1
	return chain


# Findet den ersten gemeinsamen Vorfahren zweier Ketten.
# Gibt _INVALID_LCA zurueck wenn keiner existiert.
func _find_lca(chain_a: Array[StringName], chain_b: Array[StringName]) -> StringName:
	var set_b: Dictionary = {}
	for id in chain_b:
		set_b[id] = true
	for id in chain_a:
		if set_b.has(id):
			return id
	return _INVALID_LCA


# Akkumuliert Parent-Frame-Positionen als drei separate doubles
# von chain[0] bis (exklusiv) lca_id.
func _double_sum_to_lca(chain: Array[StringName], lca_id: StringName) -> Array[float]:
	var ax: float = 0.0
	var ay: float = 0.0
	var az: float = 0.0
	for id in chain:
		if id == lca_id:
			break
		var state: BodyState = _registry.get_state(id)
		if state == null:
			break
		ax += state.position_parent_frame_m.x
		ay += state.position_parent_frame_m.y
		az += state.position_parent_frame_m.z
	return [ax, ay, az]


# Summiert alle Parent-Frame-Positionen bis zur Wurzel als doubles.
func _double_compose_world(target_id: StringName) -> Vector3:
	var chain: Array[StringName] = _chain_to_root(target_id)
	var ax: float = 0.0
	var ay: float = 0.0
	var az: float = 0.0
	for id in chain:
		var state: BodyState = _registry.get_state(id)
		if state == null:
			break
		ax += state.position_parent_frame_m.x
		ay += state.position_parent_frame_m.y
		az += state.position_parent_frame_m.z
	return Vector3(ax, ay, az)
