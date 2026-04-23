class_name OrbitReadoutService
extends Node


const OrbitPeriodHelperScript = preload("res://src/sim/orbit/orbit_period_helper.gd")

const KEY_BODY_ID: StringName = &"body_id"
const KEY_HAS_ROTATION_BASIS: StringName = &"has_rotation_basis"
const KEY_ROTATION_PERIOD_S: StringName = &"rotation_period_s"
const KEY_HAS_ORBITAL_PERIOD_BASIS: StringName = &"has_orbital_period_basis"
const KEY_ORBITAL_PERIOD_S: StringName = &"orbital_period_s"

var _registry: Node = null


func configure(registry: Node) -> void:
	assert(registry != null, "OrbitReadoutService.configure: registry is null")
	_registry = registry


func describe_body(id: StringName) -> Dictionary:
	var description: Dictionary = _default_description(id)
	if _registry == null:
		return description
	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return description
	var rotation_period_s: float = float(def.rotation_period_s)
	if rotation_period_s > 0.0 and is_finite(rotation_period_s):
		description[KEY_HAS_ROTATION_BASIS] = true
		description[KEY_ROTATION_PERIOD_S] = rotation_period_s
	var orbital_period_s: float = OrbitPeriodHelperScript.orbital_period_s_for_def(
		def,
		_def_lookup_for_body(id)
	)
	if orbital_period_s > 0.0 and is_finite(orbital_period_s):
		description[KEY_HAS_ORBITAL_PERIOD_BASIS] = true
		description[KEY_ORBITAL_PERIOD_S] = orbital_period_s
	return description


func _def_lookup_for_body(body_id: StringName) -> Dictionary:
	var lookup: Dictionary = {}
	if _registry == null:
		return lookup
	var current_id: StringName = body_id
	var hop_limit: int = 64
	while current_id != StringName("") and hop_limit > 0:
		var current_def: BodyDef = _registry.get_def(current_id)
		if current_def == null:
			return {}
		lookup[current_id] = current_def
		current_id = current_def.parent_id
		hop_limit -= 1
	if current_id != StringName(""):
		return {}
	return lookup


static func _default_description(id: StringName) -> Dictionary:
	return {
		KEY_BODY_ID: id,
		KEY_HAS_ROTATION_BASIS: false,
		KEY_ROTATION_PERIOD_S: 0.0,
		KEY_HAS_ORBITAL_PERIOD_BASIS: false,
		KEY_ORBITAL_PERIOD_S: 0.0,
	}
