extends RefCounted


static func run(ctx) -> void:
	ctx.current_suite = "test_time_service"
	_test_last_sim_dt_tracks_authoritative_tick(ctx)


static func _test_last_sim_dt_tracks_authoritative_tick(ctx) -> void:
	TimeService.reset()
	TimeService._emit_tick(2.5)
	ctx.assert_almost(TimeService.sim_time_s, 2.5, 1.0e-9, "sim_time_s folgt dem emittierten Tick")
	ctx.assert_true(TimeService.tick_count == 1, "tick_count steigt pro emittiertem Tick")
	ctx.assert_almost(TimeService.last_sim_dt_s, 2.5, 1.0e-9, "last_sim_dt_s merkt den letzten Sim-Tick")
	TimeService.reset()
	ctx.assert_almost(TimeService.last_sim_dt_s, 0.0, 1.0e-9, "reset loescht last_sim_dt_s")
