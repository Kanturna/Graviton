extends Node

# Autoload. Einzige autoritative Quelle fuer Simulationszeit.
#
# Kontrakt:
#   - sim_tick(dt) wird hoechstens einmal pro physics-Frame emittiert.
#   - Eine Aenderung von time_scale skaliert das simulierte dt pro Frame.
#   - sim_time_s waechst streng monoton, nur durch diesen Service.
#   - Keine andere Klasse darf sim_time_s schreiben.

const FIXED_DT: float = 1.0 / 60.0

signal sim_tick(dt: float)
signal time_scale_changed(new_scale: float)
signal paused_changed(is_paused: bool)

var sim_time_s: float = 0.0
var tick_count: int = 0
var time_scale: float = 1.0
var paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if paused:
		return
	var sim_dt: float = delta * maxf(0.0, time_scale)
	if sim_dt <= 0.0:
		return
	_emit_tick(sim_dt)


func _emit_tick(sim_dt: float) -> void:
	sim_time_s += sim_dt
	tick_count += 1
	sim_tick.emit(sim_dt)


func set_time_scale(s: float) -> void:
	var clamped: float = maxf(0.0, s)
	if is_equal_approx(clamped, time_scale):
		return
	time_scale = clamped
	time_scale_changed.emit(time_scale)


func set_paused(p: bool) -> void:
	if p == paused:
		return
	paused = p
	paused_changed.emit(paused)


func reset() -> void:
	sim_time_s = 0.0
	tick_count = 0
