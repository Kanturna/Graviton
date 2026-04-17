class_name StarterWorld
extends RefCounted

# Factory fuer das Starter-Debug-System.
# Diff-freundlich, reviewbar: das gesamte System ist in dieser Datei lesbar.
# Keine .tres-Binaries, keine Inspector-gepflegte Resource.
#
# Inhalt (9 Koerper, topologische Reihenfolge):
#   obsidian    — Schwarzes Loch, Wurzel
#   alpha       — Stern A, AUTHORED_ORBIT um obsidian
#   beta        — Stern B, AUTHORED_ORBIT um obsidian
#   alpha_i     — Planet I um alpha,  KEPLER_APPROX
#   alpha_ii    — Planet II um alpha, KEPLER_APPROX
#   alpha_i_m   — Mond um alpha_i,   AUTHORED_ORBIT
#   beta_i      — Planet I um beta,  KEPLER_APPROX
#   beta_ii     — Planet II um beta, KEPLER_APPROX
#   beta_i_m    — Mond um beta_i,    AUTHORED_ORBIT
#
# Orbit-Modus-Entscheidungen:
#   AUTHORED_ORBIT fuer Sterne und Monde: erlaubt freie Wahl von r und T unabhaengig
#   von Parentmasse — vorhersagbare Visualisierung, keine Kepler-Rechnung noetig.
#   KEPLER_APPROX fuer Planeten: testet die analytische Orbit-Pipeline (OrbitMath.kepler_position).
#
# Alle Werte sind bewusste Toy-Werte fuer Debugbarkeit, nicht astrophysikalisch korrekt.


static func build() -> Array[BodyDef]:
	var out: Array[BodyDef] = []
	out.append(_build_obsidian())
	out.append(_build_alpha())
	out.append(_build_beta())
	out.append(_build_alpha_i())
	out.append(_build_alpha_ii())
	out.append(_build_alpha_i_m())
	out.append(_build_beta_i())
	out.append(_build_beta_ii())
	out.append(_build_beta_i_m())
	return out


# --- Wurzel ---

static func _build_obsidian() -> BodyDef:
	var d := BodyDef.new()
	d.id = &"obsidian"
	d.display_name = "Obsidian"
	d.kind = BodyType.Kind.BLACK_HOLE
	d.mass_kg = 2.0e33
	d.radius_m = 3.0e9
	d.parent_id = &""
	d.orbit_profile = null
	return d


# --- Sterne (AUTHORED_ORBIT um obsidian) ---
# T=5e4/9e4 s: bei time_scale=1000 jeweils 50/90 s pro Umlauf sichtbar.
# phase=PI fuer beta: Sterne starten gegenueberliegend -> sofort erkennbar.

static func _build_alpha() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 1.5e11
	prof.authored_period_s = 5.0e4
	prof.authored_phase_rad = 0.0

	var d := BodyDef.new()
	d.id = &"alpha"
	d.display_name = "Alpha"
	d.kind = BodyType.Kind.STAR
	d.mass_kg = UnitSystem.SOLAR_MASS_KG
	d.radius_m = 6.957e8
	d.parent_id = &"obsidian"
	d.orbit_profile = prof
	return d


static func _build_beta() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 2.5e11
	prof.authored_period_s = 9.0e4
	prof.authored_phase_rad = PI

	var d := BodyDef.new()
	d.id = &"beta"
	d.display_name = "Beta"
	d.kind = BodyType.Kind.STAR
	d.mass_kg = UnitSystem.SOLAR_MASS_KG
	d.radius_m = 6.957e8
	d.parent_id = &"obsidian"
	d.orbit_profile = prof
	return d


# --- Planeten (KEPLER_APPROX) ---
# a-Werte so gewaehlt, dass bei RENDER_SCALE=1e9 m/Unit die Planeten
# klar sichtbar von ihrem Stern getrennt sind (2.5/5 RU vs. Stern-Mesh 0.8 RU).
# mean_anomaly_epoch_rad unterschiedlich fuer sichtbar verschiedene Startphasen.

static func _build_alpha_i() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 2.5e9
	prof.eccentricity = 0.02
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 0.0
	prof.mean_anomaly_epoch_rad = 0.0
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"alpha_i"
	d.display_name = "Alpha I"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG
	d.radius_m = 6.371e6
	d.parent_id = &"alpha"
	d.orbit_profile = prof
	return d


static func _build_alpha_ii() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 5.0e9
	prof.eccentricity = 0.01
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 0.0
	prof.mean_anomaly_epoch_rad = 1.05
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"alpha_ii"
	d.display_name = "Alpha II"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG
	d.radius_m = 6.371e6
	d.parent_id = &"alpha"
	d.orbit_profile = prof
	return d


static func _build_beta_i() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 3.0e9
	prof.eccentricity = 0.03
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 0.0
	prof.mean_anomaly_epoch_rad = 0.5
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"beta_i"
	d.display_name = "Beta I"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG
	d.radius_m = 6.371e6
	d.parent_id = &"beta"
	d.orbit_profile = prof
	return d


static func _build_beta_ii() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 6.0e9
	prof.eccentricity = 0.015
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 0.0
	prof.mean_anomaly_epoch_rad = 2.0
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"beta_ii"
	d.display_name = "Beta II"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG
	d.radius_m = 6.371e6
	d.parent_id = &"beta"
	d.orbit_profile = prof
	return d


# --- Monde (AUTHORED_ORBIT) ---
# r/T frei gewaehlt fuer Debugbarkeit: Monde bei 1.2-1.5 RU von Planet (Mesh 0.2 RU),
# Umlaufzeit 12-15 s bei time_scale=1000.

static func _build_alpha_i_m() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 1.5e9
	prof.authored_period_s = 1.5e4
	prof.authored_phase_rad = 0.0

	var d := BodyDef.new()
	d.id = &"alpha_i_m"
	d.display_name = "Alpha I - Moon"
	d.kind = BodyType.Kind.MOON
	d.mass_kg = UnitSystem.LUNAR_MASS_KG
	d.radius_m = 1.7374e6
	d.parent_id = &"alpha_i"
	d.orbit_profile = prof
	return d


static func _build_beta_i_m() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 1.2e9
	prof.authored_period_s = 1.2e4
	prof.authored_phase_rad = 1.5707963

	var d := BodyDef.new()
	d.id = &"beta_i_m"
	d.display_name = "Beta I - Moon"
	d.kind = BodyType.Kind.MOON
	d.mass_kg = UnitSystem.LUNAR_MASS_KG
	d.radius_m = 1.7374e6
	d.parent_id = &"beta_i"
	d.orbit_profile = prof
	return d
