class_name RelativeStateResolver
extends RefCounted

# Sim-interner Helfer fuer relative Major-Body-Zustaende.
# Er komponiert BodyState-Positionen entlang des Body-Frame-Graphen und
# speichert selbst keinen Zustand.

var _registry: Node = null
var _topology: UniverseTopology = UniverseTopology.new()


func configure(registry: Node) -> void:
	assert(registry != null, "RelativeStateResolver.configure: registry is null")
	_registry = registry
	_topology.configure(registry)


func resolve_body_relative_to_anchor(target_id: StringName, anchor_id: StringName) -> Dictionary:
	if _registry == null or target_id == StringName("") or anchor_id == StringName(""):
		return _invalid()
	if not _registry.has_body(target_id) or not _registry.has_body(anchor_id):
		return _invalid()
	if _topology.root_id_of(target_id) != _topology.root_id_of(anchor_id):
		return _invalid()

	var target_state := _compose_root_frame_state(target_id)
	var anchor_state := _compose_root_frame_state(anchor_id)
	if not bool(target_state.get("ok", false)) or not bool(anchor_state.get("ok", false)):
		return _invalid()

	return {
		"ok": true,
		"x_m": float(target_state.get("x_m", 0.0)) - float(anchor_state.get("x_m", 0.0)),
		"y_m": float(target_state.get("y_m", 0.0)) - float(anchor_state.get("y_m", 0.0)),
		"z_m": float(target_state.get("z_m", 0.0)) - float(anchor_state.get("z_m", 0.0)),
		"vx_mps": float(target_state.get("vx_mps", 0.0)) - float(anchor_state.get("vx_mps", 0.0)),
		"vy_mps": float(target_state.get("vy_mps", 0.0)) - float(anchor_state.get("vy_mps", 0.0)),
		"vz_mps": float(target_state.get("vz_mps", 0.0)) - float(anchor_state.get("vz_mps", 0.0)),
	}


func _compose_root_frame_state(id: StringName) -> Dictionary:
	var path: Array[StringName] = _topology.ancestor_path_root_to_leaf(id)
	if path.is_empty():
		return _invalid()

	var x_m: float = 0.0
	var y_m: float = 0.0
	var z_m: float = 0.0
	var vx_mps: float = 0.0
	var vy_mps: float = 0.0
	var vz_mps: float = 0.0
	for body_id in path:
		var state: BodyState = _registry.get_state(body_id)
		if state == null:
			return _invalid()
		x_m += state.position_parent_frame_m.x
		y_m += state.position_parent_frame_m.y
		z_m += state.position_parent_frame_m.z
		vx_mps += state.velocity_parent_frame_mps.x
		vy_mps += state.velocity_parent_frame_mps.y
		vz_mps += state.velocity_parent_frame_mps.z

	return {
		"ok": true,
		"x_m": x_m,
		"y_m": y_m,
		"z_m": z_m,
		"vx_mps": vx_mps,
		"vy_mps": vy_mps,
		"vz_mps": vz_mps,
	}


static func _invalid() -> Dictionary:
	return {
		"ok": false,
		"x_m": 0.0,
		"y_m": 0.0,
		"z_m": 0.0,
		"vx_mps": 0.0,
		"vy_mps": 0.0,
		"vz_mps": 0.0,
	}
