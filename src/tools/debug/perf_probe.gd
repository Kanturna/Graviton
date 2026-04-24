class_name PerfProbe
extends Node

# Persistente Perf-Probe fuer die Diagnose-Szenario-Matrix.
#
# Sammelt pro Renderframe:
#   - Godot-Performance-Monitore (FPS, ms, Draw Calls, Objects, Primitives, Nodes)
#   - Custom-Counter (inkrementell gezaehlt) und Custom-Samples (Momentanwerte)
#
# Nutzung:
#   PerfProbe.bump(&"trail_point_writes")
#   PerfProbe.sample(&"numeric_local_count", count)
#   PerfProbe.dump_csv("user://perf_probe.csv")
#
# Der Ringpuffer haelt MAX_SAMPLES Zeilen, danach werden alte Zeilen
# verworfen, damit lange Sessions keinen Speicher fressen. Die Probe
# schreibt niemals BodyState und greift nicht in den Sim-Pfad ein.

const MAX_SAMPLES: int = 4096
const COUNTER_RESET_PER_FRAME: bool = true

static var _instance: PerfProbe = null

var _counters: Dictionary = {}
var _samples_row: Dictionary = {}
var _ring: Array[Dictionary] = []
var _enabled: bool = true
var _last_dump_path: String = ""
var _last_dump_rows: int = 0


func _ready() -> void:
	_instance = self
	# Unabhaengig vom Pause-Zustand messen, damit auch paused-Szenarios
	# eine Zeitreihe liefern.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _process(_delta: float) -> void:
	if not _enabled:
		return
	_capture_frame_row()


static func get_instance() -> PerfProbe:
	return _instance


static func bump(counter_name: StringName, delta: int = 1) -> void:
	if _instance == null:
		return
	var current: int = int(_instance._counters.get(counter_name, 0))
	_instance._counters[counter_name] = current + delta


static func sample(name: StringName, value: Variant) -> void:
	if _instance == null:
		return
	_instance._samples_row[name] = value


static func set_enabled(value: bool) -> void:
	if _instance == null:
		return
	_instance._enabled = value


static func clear() -> void:
	if _instance == null:
		return
	_instance._ring.clear()
	_instance._counters.clear()
	_instance._samples_row.clear()


static func dump_csv(path: String) -> int:
	if _instance == null:
		return 0
	return _instance._dump_csv_internal(path)


static func rows_captured() -> int:
	if _instance == null:
		return 0
	return _instance._ring.size()


static func last_dump_summary() -> Dictionary:
	if _instance == null:
		return {"path": "", "rows": 0}
	return {
		"path": _instance._last_dump_path,
		"rows": _instance._last_dump_rows,
	}


func _capture_frame_row() -> void:
	var row: Dictionary = {
		"t_msec": Time.get_ticks_msec(),
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"render_primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	}
	for key in _counters.keys():
		row[key] = _counters[key]
	for key in _samples_row.keys():
		row[key] = _samples_row[key]

	_ring.append(row)
	if _ring.size() > MAX_SAMPLES:
		_ring.pop_front()

	if COUNTER_RESET_PER_FRAME:
		for key in _counters.keys():
			_counters[key] = 0

	_samples_row.clear()


func _dump_csv_internal(path: String) -> int:
	if _ring.is_empty():
		_last_dump_path = path
		_last_dump_rows = 0
		return 0
	var keys: Array = _collect_csv_keys()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("PerfProbe: cannot open '%s' for write" % path)
		return 0
	file.store_line(",".join(keys))
	for row_variant in _ring:
		var row: Dictionary = row_variant
		var cells: PackedStringArray = PackedStringArray()
		for key in keys:
			cells.append(_cell_to_csv(row.get(key, "")))
		file.store_line(",".join(cells))
	file.close()
	_last_dump_path = path
	_last_dump_rows = _ring.size()
	return _last_dump_rows


func _collect_csv_keys() -> Array:
	var seen: Dictionary = {}
	var ordered: Array = [
		"t_msec",
		"fps",
		"process_ms",
		"physics_ms",
		"node_count",
		"draw_calls",
		"render_objects",
		"render_primitives",
	]
	for key in ordered:
		seen[key] = true
	for row_variant in _ring:
		var row: Dictionary = row_variant
		for key in row.keys():
			if seen.has(key):
				continue
			seen[key] = true
			ordered.append(String(key))
	return ordered


static func _cell_to_csv(value: Variant) -> String:
	var text: String = str(value)
	if text.find(",") < 0 and text.find("\"") < 0 and text.find("\n") < 0:
		return text
	return "\"%s\"" % text.replace("\"", "\"\"")
