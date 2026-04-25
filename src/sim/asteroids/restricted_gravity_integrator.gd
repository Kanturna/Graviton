class_name RestrictedGravityIntegrator
extends RefCounted

const MIN_DISTANCE_M: float = 1.0


static func integrate(
		state,
		attractors,
		dt_s: float,
		target_substep_s: float,
		max_substeps_per_tick: int) -> Dictionary:
	if state == null:
		return _empty_result()
	if dt_s <= 0.0:
		return _empty_result()
	if _attractor_count(attractors) <= 0:
		state.x_m += state.vx_mps * dt_s
		state.y_m += state.vy_mps * dt_s
		state.z_m += state.vz_mps * dt_s
		return {
			"substep_count": 0,
			"substep_dt_s": dt_s,
			"hit_substep_cap": false,
			"free_drift": true,
		}
	if typeof(attractors) == TYPE_PACKED_FLOAT64_ARRAY:
		return _integrate_packed(state, attractors, dt_s, target_substep_s, max_substeps_per_tick)
	return _integrate_dictionary_array(state, attractors, dt_s, target_substep_s, max_substeps_per_tick)


static func _integrate_packed(
		state,
		attractors: PackedFloat64Array,
		dt_s: float,
		target_substep_s: float,
		max_substeps_per_tick: int) -> Dictionary:
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
		var ax0: float = 0.0
		var ay0: float = 0.0
		var az0: float = 0.0
		for entry_idx in range(0, attractors.size(), 4):
			var dx0: float = attractors[entry_idx] - x
			var dy0: float = attractors[entry_idx + 1] - y
			var dz0: float = attractors[entry_idx + 2] - z
			var r20: float = maxf(dx0 * dx0 + dy0 * dy0 + dz0 * dz0, MIN_DISTANCE_M * MIN_DISTANCE_M)
			var inv_r0: float = 1.0 / sqrt(r20)
			var inv_r30: float = inv_r0 * inv_r0 * inv_r0
			var scale0: float = attractors[entry_idx + 3] * inv_r30
			ax0 += dx0 * scale0
			ay0 += dy0 * scale0
			az0 += dz0 * scale0

		x += vx * h + 0.5 * ax0 * h * h
		y += vy * h + 0.5 * ay0 * h * h
		z += vz * h + 0.5 * az0 * h * h

		var ax1: float = 0.0
		var ay1: float = 0.0
		var az1: float = 0.0
		for entry_idx in range(0, attractors.size(), 4):
			var dx1: float = attractors[entry_idx] - x
			var dy1: float = attractors[entry_idx + 1] - y
			var dz1: float = attractors[entry_idx + 2] - z
			var r21: float = maxf(dx1 * dx1 + dy1 * dy1 + dz1 * dz1, MIN_DISTANCE_M * MIN_DISTANCE_M)
			var inv_r1: float = 1.0 / sqrt(r21)
			var inv_r31: float = inv_r1 * inv_r1 * inv_r1
			var scale1: float = attractors[entry_idx + 3] * inv_r31
			ax1 += dx1 * scale1
			ay1 += dy1 * scale1
			az1 += dz1 * scale1

		vx += 0.5 * (ax0 + ax1) * h
		vy += 0.5 * (ay0 + ay1) * h
		vz += 0.5 * (az0 + az1) * h

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
		"free_drift": false,
	}


static func _integrate_dictionary_array(
		state,
		attractors: Array,
		dt_s: float,
		target_substep_s: float,
		max_substeps_per_tick: int) -> Dictionary:

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
		var ax0: float = 0.0
		var ay0: float = 0.0
		var az0: float = 0.0
		for entry in attractors:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var dx0: float = float(entry.get("x_m", 0.0)) - x
			var dy0: float = float(entry.get("y_m", 0.0)) - y
			var dz0: float = float(entry.get("z_m", 0.0)) - z
			var r20: float = maxf(dx0 * dx0 + dy0 * dy0 + dz0 * dz0, MIN_DISTANCE_M * MIN_DISTANCE_M)
			var inv_r0: float = 1.0 / sqrt(r20)
			var inv_r30: float = inv_r0 * inv_r0 * inv_r0
			var scale0: float = float(entry.get("mu_m3ps2", 0.0)) * inv_r30
			ax0 += dx0 * scale0
			ay0 += dy0 * scale0
			az0 += dz0 * scale0

		x += vx * h + 0.5 * ax0 * h * h
		y += vy * h + 0.5 * ay0 * h * h
		z += vz * h + 0.5 * az0 * h * h

		var ax1: float = 0.0
		var ay1: float = 0.0
		var az1: float = 0.0
		for entry in attractors:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var dx1: float = float(entry.get("x_m", 0.0)) - x
			var dy1: float = float(entry.get("y_m", 0.0)) - y
			var dz1: float = float(entry.get("z_m", 0.0)) - z
			var r21: float = maxf(dx1 * dx1 + dy1 * dy1 + dz1 * dz1, MIN_DISTANCE_M * MIN_DISTANCE_M)
			var inv_r1: float = 1.0 / sqrt(r21)
			var inv_r31: float = inv_r1 * inv_r1 * inv_r1
			var scale1: float = float(entry.get("mu_m3ps2", 0.0)) * inv_r31
			ax1 += dx1 * scale1
			ay1 += dy1 * scale1
			az1 += dz1 * scale1

		vx += 0.5 * (ax0 + ax1) * h
		vy += 0.5 * (ay0 + ay1) * h
		vz += 0.5 * (az0 + az1) * h

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
		"free_drift": false,
	}


static func _attractor_count(attractors) -> int:
	match typeof(attractors):
		TYPE_PACKED_FLOAT64_ARRAY:
			return int(attractors.size() / 4)
		TYPE_ARRAY:
			return attractors.size()
		_:
			return 0


static func _empty_result() -> Dictionary:
	return {
		"substep_count": 0,
		"substep_dt_s": 0.0,
		"hit_substep_cap": false,
		"free_drift": false,
	}
