class_name LocalOrbitIntegrator
extends RefCounted

# Reine Numerik fuer lokale Parent-gebundene Bahnintegration.
# Diese Klasse liest und schreibt keinen BodyState und ist bewusst
# zustandslos, damit sie rein ueber Unit-Tests verifiziert werden kann.


static func gravity_acceleration_mps2(position_parent_frame_m: Vector3, parent_mu: float) -> Vector3:
	if parent_mu <= 0.0:
		return Vector3.ZERO
	if not _is_finite_vec3(position_parent_frame_m):
		return Vector3.ZERO
	var radius_sq: float = position_parent_frame_m.length_squared()
	if radius_sq <= 0.0:
		return Vector3.ZERO
	var radius: float = sqrt(radius_sq)
	var scale: float = -parent_mu / (radius_sq * radius)
	return position_parent_frame_m * scale


static func step_velocity_verlet(position_parent_frame_m: Vector3,
		velocity_parent_frame_mps: Vector3,
		dt_s: float,
		parent_mu: float) -> Dictionary:
	if dt_s <= 0.0 or not is_finite(dt_s):
		return {
			"position_parent_frame_m": position_parent_frame_m,
			"velocity_parent_frame_mps": velocity_parent_frame_mps,
		}
	if not _is_finite_vec3(position_parent_frame_m) or not _is_finite_vec3(velocity_parent_frame_mps):
		return {
			"position_parent_frame_m": position_parent_frame_m,
			"velocity_parent_frame_mps": velocity_parent_frame_mps,
		}

	var a0: Vector3 = gravity_acceleration_mps2(position_parent_frame_m, parent_mu)
	var next_position: Vector3 = position_parent_frame_m \
		+ velocity_parent_frame_mps * dt_s \
		+ 0.5 * a0 * dt_s * dt_s
	var a1: Vector3 = gravity_acceleration_mps2(next_position, parent_mu)
	var next_velocity: Vector3 = velocity_parent_frame_mps + 0.5 * (a0 + a1) * dt_s
	return {
		"position_parent_frame_m": next_position,
		"velocity_parent_frame_mps": next_velocity,
	}


static func step_velocity_verlet_substepped(position_parent_frame_m: Vector3,
		velocity_parent_frame_mps: Vector3,
		dt_s: float,
		parent_mu: float,
		target_substep_s: float,
		max_substeps: int) -> Dictionary:
	if dt_s <= 0.0 or not is_finite(dt_s):
		return _unchanged_substep_result(position_parent_frame_m, velocity_parent_frame_mps)
	if not _is_finite_vec3(position_parent_frame_m) or not _is_finite_vec3(velocity_parent_frame_mps):
		return _unchanged_substep_result(position_parent_frame_m, velocity_parent_frame_mps)
	if target_substep_s <= 0.0 or not is_finite(target_substep_s):
		return _unchanged_substep_result(position_parent_frame_m, velocity_parent_frame_mps)
	if max_substeps < 1:
		return _unchanged_substep_result(position_parent_frame_m, velocity_parent_frame_mps)

	var ideal_substeps: int = int(ceil(dt_s / target_substep_s))
	var substep_count: int = clampi(ideal_substeps, 1, max_substeps)
	var substep_dt_s: float = dt_s / float(substep_count)
	var hit_substep_cap: bool = ideal_substeps > max_substeps
	var current_position: Vector3 = position_parent_frame_m
	var current_velocity: Vector3 = velocity_parent_frame_mps

	for _step in range(substep_count):
		var stepped: Dictionary = step_velocity_verlet(
			current_position,
			current_velocity,
			substep_dt_s,
			parent_mu
		)
		current_position = stepped.get("position_parent_frame_m", current_position)
		current_velocity = stepped.get("velocity_parent_frame_mps", current_velocity)

	return {
		"position_parent_frame_m": current_position,
		"velocity_parent_frame_mps": current_velocity,
		"substep_count": substep_count,
		"substep_dt_s": substep_dt_s,
		"hit_substep_cap": hit_substep_cap,
	}


static func _is_finite_vec3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _unchanged_substep_result(position_parent_frame_m: Vector3,
		velocity_parent_frame_mps: Vector3) -> Dictionary:
	return {
		"position_parent_frame_m": position_parent_frame_m,
		"velocity_parent_frame_mps": velocity_parent_frame_mps,
		"substep_count": 0,
		"substep_dt_s": 0.0,
		"hit_substep_cap": false,
	}
