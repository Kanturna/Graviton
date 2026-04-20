class_name ScaleupGalaxyCatalogFactory
extends RefCounted


const GalaxyDefScript := preload("res://src/sim/world/galaxy_def.gd")
const PilotGalaxyWorldScript := preload("res://src/sim/world/pilot_galaxy_world.gd")
const GeneratedScaleupRootFactoryScript := preload("res://src/sim/world/generated_scaleup_root_factory.gd")

const HERO_ROOT_ID: StringName = &"obsidian"
const MIN_ROOT_SPACING_FACTOR: float = 3.0
const MAX_RELAX_ATTEMPTS: int = 16


static func build(galaxy_id: StringName, display_name: String, total_root_count: int):
	var pilot_galaxy = PilotGalaxyWorldScript.build()
	var fixed_manifests: Array = _duplicate_manifests(pilot_galaxy.manifests)
	var desired_root_count: int = maxi(total_root_count, fixed_manifests.size())
	var extra_root_count: int = desired_root_count - fixed_manifests.size()
	var generated_manifests: Array = GeneratedScaleupRootFactoryScript.build_extra_manifests(extra_root_count)
	return build_from_manifests(galaxy_id, display_name, fixed_manifests, generated_manifests)


static func build_from_manifests(
		galaxy_id: StringName,
		display_name: String,
		fixed_manifests: Array,
		generated_manifests: Array
	):
	var spacing_result: Dictionary = apply_spacing_guard(fixed_manifests, generated_manifests)
	if not bool(spacing_result.get("ok", false)):
		push_error("ScaleupGalaxyCatalogFactory.build_from_manifests: %s" % String(spacing_result.get("error", "unknown spacing failure")))
		return null

	var galaxy = GalaxyDefScript.new()
	var default_resident_root_ids: Array[StringName] = [HERO_ROOT_ID]
	galaxy.galaxy_id = galaxy_id
	galaxy.display_name = display_name
	galaxy.focus_root_id = HERO_ROOT_ID
	galaxy.default_resident_root_ids = default_resident_root_ids
	galaxy.manifests = spacing_result.get("manifests", [])
	return galaxy


static func apply_spacing_guard(fixed_manifests: Array, generated_manifests: Array) -> Dictionary:
	var accepted_manifests: Array = _duplicate_manifests(fixed_manifests)
	var relaxed_root_ids: Array[StringName] = []

	for manifest_variant in generated_manifests:
		if manifest_variant == null:
			return {
				"ok": false,
				"error": "generated manifest is null",
			}
		var candidate = manifest_variant.duplicate_manifest()
		var relax_result: Dictionary = relax_generated_manifest(candidate, accepted_manifests)
		if not bool(relax_result.get("ok", false)):
			return relax_result
		var relaxed_manifest = relax_result.get("manifest", null)
		if relaxed_manifest == null:
			return {
				"ok": false,
				"error": "relaxed manifest is null",
			}
		accepted_manifests.append(relaxed_manifest)
		if bool(relax_result.get("relaxed", false)):
			relaxed_root_ids.append(relaxed_manifest.root_id)

	var validation_result: Dictionary = validate_pairwise_spacing(accepted_manifests)
	if not bool(validation_result.get("ok", false)):
		return validation_result

	return {
		"ok": true,
		"manifests": accepted_manifests,
		"relaxed_root_ids": relaxed_root_ids,
	}


static func relax_generated_manifest(candidate, accepted_manifests: Array) -> Dictionary:
	if candidate == null:
		return {
			"ok": false,
			"error": "candidate manifest is null",
		}

	var relaxed_manifest = candidate.duplicate_manifest()
	var attempts_used: int = 0
	for attempt in range(MAX_RELAX_ATTEMPTS + 1):
		var conflict: Dictionary = _find_spacing_conflict(relaxed_manifest, accepted_manifests)
		if conflict.is_empty():
			return {
				"ok": true,
				"manifest": relaxed_manifest,
				"relaxed": attempts_used > 0,
				"attempts": attempts_used,
			}
		if attempt >= MAX_RELAX_ATTEMPTS:
			return {
				"ok": false,
				"error": _format_spacing_failure(relaxed_manifest, conflict, attempt),
				"root_id": relaxed_manifest.root_id,
				"conflict": conflict,
			}

		var max_conflicting_extent_m: float = float(conflict.get("max_conflicting_extent_m", 0.0))
		var relax_step_m: float = _relax_step_m(relaxed_manifest.system_extent_m, max_conflicting_extent_m)
		relaxed_manifest.galaxy_position_m = _radially_shift_position(relaxed_manifest.galaxy_position_m, relax_step_m)
		attempts_used = attempt + 1

	return {
		"ok": false,
		"error": "unexpected relax failure for '%s'" % String(relaxed_manifest.root_id),
	}


static func validate_pairwise_spacing(manifests: Array) -> Dictionary:
	for left_index in range(manifests.size()):
		var left_manifest = manifests[left_index]
		if left_manifest == null:
			return {
				"ok": false,
				"error": "manifest at index %d is null" % left_index,
			}
		for right_index in range(left_index + 1, manifests.size()):
			var right_manifest = manifests[right_index]
			if right_manifest == null:
				return {
					"ok": false,
					"error": "manifest at index %d is null" % right_index,
				}
			var min_spacing_m: float = minimum_spacing_m(left_manifest, right_manifest)
			var distance_m: float = left_manifest.galaxy_position_m.distance_to(right_manifest.galaxy_position_m)
			if distance_m >= min_spacing_m:
				continue
			return {
				"ok": false,
				"error": "root '%s' violates spacing against '%s' (distance=%s min_spacing=%s)" % [
					String(left_manifest.root_id),
					String(right_manifest.root_id),
					str(distance_m),
					str(min_spacing_m),
				],
				"left_root_id": left_manifest.root_id,
				"right_root_id": right_manifest.root_id,
				"distance_m": distance_m,
				"min_spacing_m": min_spacing_m,
			}
	return {
		"ok": true,
	}


static func minimum_spacing_m(left_manifest, right_manifest) -> float:
	return MIN_ROOT_SPACING_FACTOR * (float(left_manifest.system_extent_m) + float(right_manifest.system_extent_m))


static func _find_spacing_conflict(candidate, accepted_manifests: Array) -> Dictionary:
	var first_conflict: Dictionary = {}
	var max_conflicting_extent_m: float = 0.0
	for manifest in accepted_manifests:
		if manifest == null:
			continue
		var min_spacing_m: float = minimum_spacing_m(candidate, manifest)
		var distance_m: float = candidate.galaxy_position_m.distance_to(manifest.galaxy_position_m)
		if distance_m >= min_spacing_m:
			continue
		max_conflicting_extent_m = maxf(max_conflicting_extent_m, float(manifest.system_extent_m))
		if first_conflict.is_empty() or distance_m < float(first_conflict.get("distance_m", INF)):
			first_conflict = {
				"conflict_root_id": manifest.root_id,
				"distance_m": distance_m,
				"min_spacing_m": min_spacing_m,
			}
	if first_conflict.is_empty():
		return {}
	first_conflict["max_conflicting_extent_m"] = max_conflicting_extent_m
	return first_conflict


static func _relax_step_m(candidate_extent_m: float, max_conflicting_extent_m: float) -> float:
	# Ein Relax-Schritt entspricht grob einem System-Durchmesser und skaliert
	# dadurch mit den realen Root-Extents statt mit einer magischen Fixzahl.
	return 2.0 * maxf(candidate_extent_m, max_conflicting_extent_m)


static func _radially_shift_position(position_m: Vector3, delta_radius_m: float) -> Vector3:
	var current_radius_m: float = position_m.length()
	var direction: Vector3 = Vector3.RIGHT if current_radius_m <= 0.0 else position_m / current_radius_m
	var next_radius_m: float = current_radius_m + maxf(delta_radius_m, 0.0)
	return direction * next_radius_m


static func _duplicate_manifests(manifests: Array) -> Array:
	var out: Array = []
	for manifest in manifests:
		if manifest != null:
			out.append(manifest.duplicate_manifest())
	return out


static func _format_spacing_failure(candidate, conflict: Dictionary, attempts: int) -> String:
	return "root '%s' failed spacing guard after %d attempts against '%s' (distance=%s min_spacing=%s)" % [
		String(candidate.root_id),
		attempts,
		String(conflict.get("conflict_root_id", StringName(""))),
		str(conflict.get("distance_m", 0.0)),
		str(conflict.get("min_spacing_m", 0.0)),
	]
