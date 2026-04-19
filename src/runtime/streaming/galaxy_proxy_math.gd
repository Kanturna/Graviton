class_name GalaxyProxyMath
extends RefCounted


const VELOCITY_EPSILON_S: float = 1.0


static func star_local_state(star_manifest, t_s: float) -> Dictionary:
	var position_parent_frame_m: Vector3 = OrbitMath.authored_circular_position(
		star_manifest.orbit_radius_m,
		star_manifest.orbit_period_s,
		star_manifest.orbit_phase_rad,
		t_s
	)
	var pos_prev: Vector3 = OrbitMath.authored_circular_position(
		star_manifest.orbit_radius_m,
		star_manifest.orbit_period_s,
		star_manifest.orbit_phase_rad,
		t_s - VELOCITY_EPSILON_S
	)
	var pos_next: Vector3 = OrbitMath.authored_circular_position(
		star_manifest.orbit_radius_m,
		star_manifest.orbit_period_s,
		star_manifest.orbit_phase_rad,
		t_s + VELOCITY_EPSILON_S
	)
	return {
		"position_parent_frame_m": position_parent_frame_m,
		"velocity_parent_frame_mps": (pos_next - pos_prev) / (2.0 * VELOCITY_EPSILON_S),
	}
