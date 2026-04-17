extends Node3D

# Duennes Foundation-Testbed. Reine Visualisierung des Sim-Kerns.
# Enthaelt KEINE Simulationslogik, KEINE Orbit-Mathematik und KEINE
# Positionsberechnung. Die Node3D.position der Visual-Kinder ist
# eine reine Projektion der Parent-Frame-Wahrheit — niemals die
# Wahrheit selbst.
#
# Fokus-Navigation:
#   Tab / Shift+Tab  — vorwaerts / rueckwaerts durch alle Bodies
#   Home             — zurueck zu obsidian (Wurzel, Gesamtueberblick)
#
# Zeitskalen-Presets:
#   [  — langsamer (naechstes Preset runter)
#   ]  — schneller (naechstes Preset rauf)

@onready var _orbit_service: OrbitService = $OrbitService
@onready var _bubble: LocalBubbleManager = $LocalBubbleManager
@onready var _overlay: DebugOverlay = $DebugOverlay
@onready var _visuals_root: Node3D = $Visuals

var _visuals: Dictionary = {}

const FOCUS_IDS: Array = [
	&"obsidian", &"alpha", &"beta",
	&"alpha_i", &"alpha_ii", &"alpha_i_m",
	&"beta_i", &"beta_ii", &"beta_i_m",
]
var _focus_index: int = 0

const TIME_SCALE_PRESETS: Array = [100.0, 500.0, 1000.0, 5000.0, 10000.0]
var _ts_index: int = 2


func _ready() -> void:
	if UniverseRegistry.body_count() == 0:
		UniverseRegistry.load_from_starter_world()
	_orbit_service.configure(UniverseRegistry, TimeService)
	_orbit_service.recompute_all_at_time(TimeService.sim_time_s)
	_bubble.configure(UniverseRegistry)
	_bubble.set_focus(FOCUS_IDS[_focus_index])
	_overlay.configure(UniverseRegistry, TimeService, _bubble)
	TimeService.set_time_scale(TIME_SCALE_PRESETS[_ts_index])
	_create_visuals()


func _create_visuals() -> void:
	for id in UniverseRegistry.get_update_order():
		var def: BodyDef = UniverseRegistry.get_def(id)
		var mesh_inst := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = _radius_for_kind(def.kind)
		sphere.height = sphere.radius * 2.0
		mesh_inst.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _color_for_kind(def.kind)
		if def.kind == BodyType.Kind.STAR or def.kind == BodyType.Kind.BLACK_HOLE:
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 1.5
		mesh_inst.set_surface_override_material(0, mat)
		mesh_inst.name = String(id)
		_visuals_root.add_child(mesh_inst)
		_visuals[id] = mesh_inst


func _process(_delta: float) -> void:
	for id: StringName in _visuals:
		var view_m: Vector3 = _bubble.compose_view_position_m(id)
		_visuals[id].position = view_m / UnitSystem.RENDER_SCALE_M_PER_UNIT


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_TAB:
			if event.shift_pressed:
				_focus_index = (_focus_index - 1 + FOCUS_IDS.size()) % FOCUS_IDS.size()
			else:
				_focus_index = (_focus_index + 1) % FOCUS_IDS.size()
			_bubble.set_focus(FOCUS_IDS[_focus_index])
		KEY_HOME:
			_focus_index = 0
			_bubble.set_focus(FOCUS_IDS[0])
		KEY_BRACKETLEFT:
			_ts_index = maxi(_ts_index - 1, 0)
			TimeService.set_time_scale(TIME_SCALE_PRESETS[_ts_index])
		KEY_BRACKETRIGHT:
			_ts_index = mini(_ts_index + 1, TIME_SCALE_PRESETS.size() - 1)
			TimeService.set_time_scale(TIME_SCALE_PRESETS[_ts_index])


static func _radius_for_kind(kind: BodyType.Kind) -> float:
	match kind:
		BodyType.Kind.BLACK_HOLE: return 1.5
		BodyType.Kind.STAR: return 0.8
		BodyType.Kind.PLANET: return 0.2
		BodyType.Kind.MOON: return 0.08
	return 0.3


static func _color_for_kind(kind: BodyType.Kind) -> Color:
	match kind:
		BodyType.Kind.BLACK_HOLE: return Color(0.5, 0.1, 0.5, 1)
		BodyType.Kind.STAR: return Color(1.0, 0.85, 0.35, 1)
		BodyType.Kind.PLANET: return Color(0.3, 0.55, 0.9, 1)
		BodyType.Kind.MOON: return Color(0.7, 0.7, 0.7, 1)
	return Color(1.0, 1.0, 1.0, 1)
