class_name BodyDef
extends Resource

# Statische Definition eines Koerpers. Zur Laufzeit unveraenderlich.
# Wurzelkoerper: `parent_id == &""` UND `orbit_profile == null`.
# Alle anderen Koerper muessen sowohl parent_id als auch orbit_profile haben.
#
# P3 haelt Weltmodell-Felder bewusst flach und diff-freundlich direkt in
# `BodyDef`. Ein spaeterer Split in typ-spezifische Subresources bleibt
# offen, ist aber nicht Teil dieses Foundation-Schritts.

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: int = BodyType.Kind.PLANET
@export var mass_kg: float = 0.0
@export var radius_m: float = 0.0
# Sidereale Rotationsperiode in Sekunden, also relativ zum Fixsternhimmel.
# `0.0` bedeutet in P3: nicht gesetzt / fuer diese Welt noch nicht relevant.
@export var rotation_period_s: float = 0.0
# Axiale Neigung relativ zur Orbit-Ebene des Bodies um seinen Parent.
# `0.0` bedeutet: keine Neigung / der Aequator liegt in der Orbitebene.
@export var axial_tilt_rad: float = 0.0
# Intrinsische Leuchtkraft in Watt. `0.0` bleibt in P3 bewusst doppeldeutig:
# entweder nicht-leuchtend oder noch nicht modelliert.
@export var luminosity_w: float = 0.0
# Dimensionsloser Reflexionswert im Bereich `0.0 .. 1.0`.
@export var albedo: float = 0.0
# Definiert den Frame-Parent dieses Koerpers. BodyState.parent_id spiegelt
# diesen Wert zur Laufzeit wider (Lesekopie, nie separat beschrieben).
@export var parent_id: StringName = &""
@export var orbit_profile: OrbitProfile = null


func is_root() -> bool:
	return parent_id == StringName("")


func is_valid() -> bool:
	if id == StringName(""):
		return false
	if mass_kg <= 0.0:
		return false
	if not is_finite(radius_m) or not is_finite(rotation_period_s) or not is_finite(axial_tilt_rad):
		return false
	if not is_finite(luminosity_w) or not is_finite(albedo):
		return false
	if rotation_period_s < 0.0:
		return false
	if luminosity_w < 0.0:
		return false
	if albedo < 0.0 or albedo > 1.0:
		return false
	if is_root():
		return orbit_profile == null
	return orbit_profile != null
