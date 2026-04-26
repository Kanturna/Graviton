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
	ctx.assert_true(TimeService.last_tick_emit_us >= 0, "last_tick_emit_us misst die sim_tick-Dispatchdauer read-only")
	ctx.assert_true(TimeService.tick_emit_total_us >= TimeService.last_tick_emit_us, "tick_emit_total_us akkumuliert Tick-Dispatchzeit read-only")
	var total_after_first_tick: int = TimeService.tick_emit_total_us
	TimeService._emit_tick(0.5)
	ctx.assert_true(TimeService.tick_count == 2, "tick_count steigt auch beim zweiten emittierten Tick")
	ctx.assert_true(TimeService.tick_emit_total_us >= total_after_first_tick, "tick_emit_total_us bleibt monoton")
	TimeService.reset()
	ctx.assert_almost(TimeService.last_sim_dt_s, 0.0, 1.0e-9, "reset loescht last_sim_dt_s")
	ctx.assert_true(TimeService.last_tick_emit_us == 0, "reset loescht last_tick_emit_us")
	ctx.assert_true(TimeService.tick_emit_total_us == 0, "reset loescht tick_emit_total_us")
