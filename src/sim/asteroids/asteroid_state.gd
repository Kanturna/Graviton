class_name AsteroidState
extends RefCounted

var id: StringName = &""
var root_id: StringName = &""
var anchor_id: StringName = &""
var x_m: float = 0.0
var y_m: float = 0.0
var z_m: float = 0.0
var vx_mps: float = 0.0
var vy_mps: float = 0.0
var vz_mps: float = 0.0
var current_attractor_ids: Array[StringName] = []
var last_update_time_s: float = 0.0
var is_active: bool = true


func clone_snapshot(def) -> Dictionary:
	return {
		"id": id,
		"root_id": root_id,
		"anchor_id": anchor_id,
		"x_m": x_m,
		"y_m": y_m,
		"z_m": z_m,
		"vx_mps": vx_mps,
		"vy_mps": vy_mps,
		"vz_mps": vz_mps,
		"current_attractor_ids": current_attractor_ids.duplicate(),
		"last_update_time_s": last_update_time_s,
		"is_active": is_active,
		"spawn_origin_id": def.spawn_origin_id if def != null else StringName(""),
		"radius_m": def.radius_m if def != null else 0.0,
		"mass_kg": def.mass_kg if def != null else 0.0,
		"visual_class": def.visual_class if def != null else StringName(""),
	}
