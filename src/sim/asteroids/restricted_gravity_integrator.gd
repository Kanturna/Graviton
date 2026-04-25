class_name RestrictedGravityIntegrator
extends RefCounted

const G_M3_PER_KG_S2: float = 6.67430e-11
const MIN_DISTANCE_M: float = 1.0


static func integrate(
		state,
		attractors: Array,
		dt_s: float,
		target_substep_s: float,
		max_substeps_per_tick: int) -> Dictionary:
	if state == null:
		return _empty_result()
	if dt_s <= 0.0 or attractors.is_empty():
		return {
			"substep_count": 0,
			"substep_dt_s": 0.0,
			"hit_substep_cap": false,
		}

	var substeps: int = maxi(1, int(ceil(dt_s / maxf(target_substep_s, 0.001))))
	var cap: int = maxi(1, max_substeps_per_tick)
	var hit_cap: bool = substeps > cap
	substeps = mini(substeps, cap)
	var h: float = dt_s / float(substeps)

	var x: float = state.x_m
	var y: float = state.y_m
	var z: float = state.z_m
	var vx: float = state.vx_mps
	var vy: float = state.vy_mps
	var vz: float = state.vz_mps

	for _idx in range(substeps):
		var a0: Dictionary = _acceleration_at(x, y, z, attractors)
		x += vx * h + 0.5 * float(a0.get("ax", 0.0)) * h * h
		y += vy * h + 0.5 * float(a0.get("ay", 0.0)) * h * h
		z += vz * h + 0.5 * float(a0.get("az", 0.0)) * h * h
		var a1: Dictionary = _acceleration_at(x, y, z, attractors)
		vx += 0.5 * (float(a0.get("ax", 0.0)) + float(a1.get("ax", 0.0))) * h
		vy += 0.5 * (float(a0.get("ay", 0.0)) + float(a1.get("ay", 0.0))) * h
		vz += 0.5 * (float(a0.get("az", 0.0)) + float(a1.get("az", 0.0))) * h

	state.x_m = x
	state.y_m = y
	state.z_m = z
	state.vx_mps = vx
	state.vy_mps = vy
	state.vz_mps = vz

	return {
		"substep_count": substeps,
		"substep_dt_s": h,
		"hit_substep_cap": hit_cap,
	}


static func _acceleration_at(x: float, y: float, z: float, attractors: Array) -> Dictionary:
	var ax: float = 0.0
	var ay: float = 0.0
	var az: float = 0.0
	for entry in attractors:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var dx: float = float(entry.get("x_m", 0.0)) - x
		var dy: float = float(entry.get("y_m", 0.0)) - y
		var dz: float = float(entry.get("z_m", 0.0)) - z
		var r2: float = maxf(dx * dx + dy * dy + dz * dz, MIN_DISTANCE_M * MIN_DISTANCE_M)
		var inv_r: float = 1.0 / sqrt(r2)
		var inv_r3: float = inv_r * inv_r * inv_r
		var scale: float = float(entry.get("mu_m3ps2", 0.0)) * inv_r3
		ax += dx * scale
		ay += dy * scale
		az += dz * scale
	return {"ax": ax, "ay": ay, "az": az}


static func _empty_result() -> Dictionary:
	return {
		"substep_count": 0,
		"substep_dt_s": 0.0,
		"hit_substep_cap": false,
	}
