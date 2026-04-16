class_name IdRegistry
extends RefCounted

# Vergibt und ueberwacht stabile IDs. Keine Abhaengigkeit auf Autoloads.
# Wird vom UniverseRegistry gehalten; kein eigener Singleton.
#
# Konvention:
#   authored IDs: vom Autor frei gewaehlte StringNames (z. B. &"planet_a").
#   runtime IDs: automatisch vergeben, immer mit Praefix "rt_".

const RUNTIME_PREFIX: String = "rt_"

var _next_runtime: int = 1
var _used: Dictionary = {}


func claim_authored(id: StringName) -> StringName:
	assert(id != StringName(""), "authored id must not be empty")
	assert(not _used.has(id), "authored id already registered: %s" % id)
	_used[id] = true
	return id


func mint_runtime() -> StringName:
	var id := StringName("%s%d" % [RUNTIME_PREFIX, _next_runtime])
	_next_runtime += 1
	_used[id] = true
	return id


func release(id: StringName) -> void:
	_used.erase(id)


func is_known(id: StringName) -> bool:
	return _used.has(id)


func clear() -> void:
	_used.clear()
	_next_runtime = 1
