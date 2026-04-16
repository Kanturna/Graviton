extends Node3D

# Duennes Foundation-Testbed. Reine Visualisierung des Sim-Kerns.
# Enthaelt KEINE Simulationslogik, KEINE Orbit-Mathematik und KEINE
# Positionsberechnung. Die Node3D.position der Visual-Kinder ist
# eine reine Projektion der Parent-Frame-Wahrheit — niemals die
# Wahrheit selbst.

@onready var _orbit_service: OrbitService = $OrbitService
@onready var _bubble: LocalBubbleManager = $LocalBubbleManager
@onready var _overlay: DebugOverlay = $DebugOverlay

@onready var _visual_sol: Node3D = $Visuals/SolVisual
@onready var _visual_planet_a: Node3D = $Visuals/PlanetAVisual
@onready var _visual_moon_a: Node3D = $Visuals/MoonAVisual


func _ready() -> void:
	if UniverseRegistry.body_count() == 0:
		UniverseRegistry.load_from_sample_system()
	_orbit_service.configure(UniverseRegistry, TimeService)
	_orbit_service.recompute_all_at_time(TimeService.sim_time_s)
	_bubble.configure(UniverseRegistry)
	_bubble.set_focus(&"planet_a")
	_overlay.configure(UniverseRegistry, TimeService, _bubble)
	TimeService.set_time_scale(1_000_000.0)


func _process(_delta: float) -> void:
	_sync_visual(&"sol", _visual_sol)
	_sync_visual(&"planet_a", _visual_planet_a)
	_sync_visual(&"moon_a", _visual_moon_a)


func _sync_visual(id: StringName, node: Node3D) -> void:
	if node == null:
		return
	node.position = _bubble.compose_render_units(id)
