extends Node

# Autoload. Einzige autoritative Quelle fuer Simulationszeit.
#
# Kontrakt:
#   - sim_tick(dt) wird IMMER mit dt == FIXED_DT emittiert.
#   - Eine Aenderung von time_scale veraendert NICHT dt, sondern die
#     Anzahl Ticks pro physics-Frame. Sub-1-Scales werden akkumuliert.
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

var _scale_accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(_delta: float) -> void:
	if paused:
		return
	_scale_accum += maxf(0.0, time_scale)
	while _scale_accum >= 1.0:
		_scale_accum -= 1.0
		_emit_tick()


func _emit_tick() -> void:
	sim_time_s += FIXED_DT
	tick_count += 1
	sim_tick.emit(FIXED_DT)


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
	_scale_accum = 0.0
