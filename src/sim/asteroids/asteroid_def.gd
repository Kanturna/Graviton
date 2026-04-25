class_name AsteroidDef
extends RefCounted

var id: StringName = &""
var root_id: StringName = &""
var anchor_id: StringName = &""
var seed: int = 0
var mass_kg: float = 0.0
var radius_m: float = 0.0
var visual_class: StringName = &"rock"


func _init(
		p_id: StringName = &"",
		p_root_id: StringName = &"",
		p_anchor_id: StringName = &"",
		p_seed: int = 0) -> void:
	id = p_id
	root_id = p_root_id
	anchor_id = p_anchor_id
	seed = p_seed
