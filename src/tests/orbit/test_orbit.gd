extends RefCounted

# Unit-Tests fuer OrbitMath. Vom test_runner per statischer `run(ctx)` geladen.
# Keine Szenen, keine Autoloads — reine Mathematik-Checks.


static func run(ctx) -> void:
	_test_solve_kepler_basic(ctx)
	_test_solve_kepler_converges(ctx)
	_test_authored_period_round_trip(ctx)
	_test_kepler_period_round_trip(ctx)
	_test_zero_inclination_stays_in_plane(ctx)


static func _test_solve_kepler_basic(ctx) -> void:
	var e_anom: float = OrbitMath.solve_kepler(0.0, 0.0)
	ctx.assert_almost(e_anom, 0.0, 1.0e-9, "solve_kepler(0, 0) == 0")
	var e2: float = OrbitMath.solve_kepler(PI, 0.0)
	# Erwartet -PI wegen der halboffenen Normalisierung [-PI, PI); physikalisch
	# ist das aequivalent zu PI.
	ctx.assert_almost(e2, -PI, 1.0e-6, "solve_kepler(PI, 0) canonicalizes to -PI")
	var m_wrapped: float = wrapf(PI, -PI, PI)
	var residual: float = e2 - 0.0 * sin(e2) - m_wrapped
	ctx.assert_almost(residual, 0.0, 1.0e-9, "solve_kepler(PI, 0) residual")


static func _test_solve_kepler_converges(ctx) -> void:
	# Fuer e=0.5 und M=1.0 muss M == E - e*sin(E) nach Loesen gelten.
	var m: float = 1.0
	var e: float = 0.5
	var ecc_anom: float = OrbitMath.solve_kepler(m, e)
	var residual: float = ecc_anom - e * sin(ecc_anom) - m
	ctx.assert_almost(residual, 0.0, 1.0e-8, "solve_kepler(M=1, e=0.5) residual")


static func _test_authored_period_round_trip(ctx) -> void:
	var r: float = 3.844e8
	var period: float = 2.360592e6
	var p0: Vector3 = OrbitMath.authored_circular_position(r, period, 0.0, 0.0)
	var p1: Vector3 = OrbitMath.authored_circular_position(r, period, 0.0, period)
	ctx.assert_vec_almost(p1, p0, r * 1.0e-6, "authored circular returns to start after one period")


static func _test_kepler_period_round_trip(ctx) -> void:
	# Erde um Sonne.
	var a: float = 1.495978707e11
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var n: float = OrbitMath.mean_motion(a, mu)
	var period: float = TAU / n
	var p0: Vector3 = OrbitMath.kepler_position(a, 0.0167, 0.0, 0.0, 0.0, 0.0, 0.0, mu, 0.0)
	var p1: Vector3 = OrbitMath.kepler_position(a, 0.0167, 0.0, 0.0, 0.0, 0.0, 0.0, mu, period)
	ctx.assert_vec_almost(p1, p0, a * 1.0e-4, "kepler returns near start after one period")


static func _test_zero_inclination_stays_in_plane(ctx) -> void:
	var a: float = 1.0e10
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var p: Vector3 = OrbitMath.kepler_position(a, 0.2, 0.0, 0.0, 0.0, 0.7, 0.0, mu, 1234.0)
	ctx.assert_almost(p.z, 0.0, 1.0e-3, "inclination=0 keeps z at 0")
