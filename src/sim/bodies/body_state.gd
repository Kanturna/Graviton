class_name BodyState
extends RefCounted

# Laufzeitstatus eines Koerpers. Mutierbar, aber schreibend NUR durch
# den OrbitService. Alle Leser muessen davon ausgehen, dass die Werte
# zwischen zwei sim_tick-Events stabil bleiben.
#
# WICHTIG: position_parent_frame_m ist im Bezugssystem des Parents ausgedrueckt.
# Welt- oder View-Koordinaten werden NICHT hier gespeichert — sie sind
# abgeleitete Groessen und werden durch LocalBubbleManager komponiert.

var id: StringName = &""
var parent_id: StringName = &""
var position_parent_frame_m: Vector3 = Vector3.ZERO
var velocity_parent_frame_mps: Vector3 = Vector3.ZERO
var current_mode: int = OrbitMode.Kind.AUTHORED_ORBIT
var last_update_time_s: float = 0.0


func _init(p_id: StringName = &"", p_parent_id: StringName = &"") -> void:
	id = p_id
	parent_id = p_parent_id
