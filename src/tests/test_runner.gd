extends SceneTree

# Minimaler CLI-Test-Runner fuer das Foundation-Slice.
# Aufruf:
#   godot --headless --script res://src/tests/test_runner.gd --quit
#
# Sammelt Tests aus res://src/tests/**/test_*.gd und ruft deren
# statische Funktion `run(ctx: TestContext)` auf. Exit-Code 0 bei
# vollstaendigem Erfolg, 1 bei mindestens einem Fehler.

const TESTS_ROOT: String = "res://src/tests"


class TestContext:
	var passed: int = 0
	var failed: int = 0
	var current_suite: String = ""
	var messages: Array[String] = []

	func assert_true(cond: bool, label: String) -> void:
		if cond:
			passed += 1
		else:
			failed += 1
			messages.append("  [FAIL] %s :: %s" % [current_suite, label])

	func assert_almost(actual: float, expected: float, tol: float, label: String) -> void:
		var ok: bool = absf(actual - expected) <= tol
		if ok:
			passed += 1
		else:
			failed += 1
			messages.append("  [FAIL] %s :: %s (actual=%f expected=%f tol=%f)"
				% [current_suite, label, actual, expected, tol])

	func assert_vec_almost(actual: Vector3, expected: Vector3, tol: float, label: String) -> void:
		var delta: float = (actual - expected).length()
		var ok: bool = delta <= tol
		if ok:
			passed += 1
		else:
			failed += 1
			messages.append("  [FAIL] %s :: %s (delta=%e tol=%e)"
				% [current_suite, label, delta, tol])


func _initialize() -> void:
	var ctx := TestContext.new()
	var suites: Array[String] = _collect_suites(TESTS_ROOT)
	print("[test_runner] %d suite(s) found under %s" % [suites.size(), TESTS_ROOT])
	for suite_path in suites:
		var script: GDScript = load(suite_path) as GDScript
		if script == null:
			print("  [SKIP] could not load %s" % suite_path)
			continue
		ctx.current_suite = suite_path.get_file()
		if not script.has_method("run"):
			print("  [SKIP] %s has no static `run`" % ctx.current_suite)
			continue
		print("[test_runner] running %s" % ctx.current_suite)
		script.run(ctx)

	for m in ctx.messages:
		print(m)
	print("[test_runner] passed=%d failed=%d" % [ctx.passed, ctx.failed])

	var exit_code: int = 0 if ctx.failed == 0 else 1
	quit(exit_code)


func _collect_suites(root: String) -> Array[String]:
	var out: Array[String] = []
	_walk(root, out)
	out.sort()
	return out


func _walk(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full: String = path.path_join(name)
		if dir.current_is_dir():
			_walk(full, out)
		elif name.begins_with("test_") and name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
