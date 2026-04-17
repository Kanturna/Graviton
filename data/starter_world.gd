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
# Ziel-Hierarchie fuer die Lesbarkeit:
#   Monde kreisen sichtbar schneller um Planeten als Planeten um Sterne.
#   Planeten kreisen sichtbar schneller um Sterne als Sterne um obsidian.


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
	d.rotation_period_s = 0.0
	d.axial_tilt_rad = 0.0
	d.luminosity_w = 0.0
	d.albedo = 0.0
	d.parent_id = &""
	d.orbit_profile = null
	return d


# --- Sterne (AUTHORED_ORBIT um obsidian) ---
# T=4e4/7e4 s: Sterne bleiben klar langsamer als ihre Planeten, sind aber
# im Root-View frueher wahrnehmbar als mit den vorherigen sehr traegen Toy-Werten.
# phase=PI fuer beta: Sterne starten gegenueberliegend -> sofort erkennbar.
# `3.0 * SOLAR_LUMINOSITY_W` ist bewusst Toy-Luminositaet und wird hier
# nicht aus der Sternmasse abgeleitet. Debug-Lesbarkeit hat Vorrang vor
# astrophysikalischer Genauigkeit.

static func _build_alpha() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 1.5e11
	prof.authored_period_s = 4.0e4
	prof.authored_phase_rad = 0.0

	var d := BodyDef.new()
	d.id = &"alpha"
	d.display_name = "Alpha"
	d.kind = BodyType.Kind.STAR
	# Erhoehte Toy-Masse: haelt kompakte Planetensysteme lesbar und trotzdem
	# sichtbar schneller als die BH-Sternorbits.
	d.mass_kg = UnitSystem.SOLAR_MASS_KG * 3.0
	d.radius_m = 6.957e8
	d.rotation_period_s = 25.0 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.0
	d.luminosity_w = 3.0 * UnitSystem.SOLAR_LUMINOSITY_W
	d.albedo = 0.0
	d.parent_id = &"obsidian"
	d.orbit_profile = prof
	return d


static func _build_beta() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 2.5e11
	prof.authored_period_s = 7.0e4
	prof.authored_phase_rad = PI

	var d := BodyDef.new()
	d.id = &"beta"
	d.display_name = "Beta"
	d.kind = BodyType.Kind.STAR
	d.mass_kg = UnitSystem.SOLAR_MASS_KG * 3.0
	d.radius_m = 6.957e8
	d.rotation_period_s = 25.0 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.0
	d.luminosity_w = 3.0 * UnitSystem.SOLAR_LUMINOSITY_W
	d.albedo = 0.0
	d.parent_id = &"obsidian"
	d.orbit_profile = prof
	return d


# --- Planeten (KEPLER_APPROX) ---
# a/e-Werte so gewaehlt, dass bei RENDER_SCALE=1e9 m/Unit die Planeten
# klar sichtbar von ihrem Stern getrennt sind, dabei aber in der Toy-Hierarchie
# schneller um den Stern kreisen als der Stern um obsidian.
# e ist bewusst hoeher als in einem "milden" Realismus-Setup, damit die
# Ellipsen im Testbed auch wirklich erkennbar werden.
# argument_periapsis_rad ist pro Planet unterschiedlich, damit die Bahnen
# nicht alle gleich ausgerichtet wie technisch verschobene Kreise wirken.
# mean_anomaly_epoch_rad unterschiedlich fuer sichtbar verschiedene Startphasen.

static func _build_alpha_i() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 1.4e9
	prof.eccentricity = 0.36
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 0.75
	prof.mean_anomaly_epoch_rad = 0.0
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"alpha_i"
	d.display_name = "Alpha I"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG
	d.radius_m = 6.371e6
	d.rotation_period_s = 0.80 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.18
	d.luminosity_w = 0.0
	d.albedo = 0.28
	d.parent_id = &"alpha"
	d.orbit_profile = prof
	return d


static func _build_alpha_ii() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 2.52e9
	prof.eccentricity = 0.22
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 2.35
	prof.mean_anomaly_epoch_rad = 1.05
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"alpha_ii"
	d.display_name = "Alpha II"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG
	d.radius_m = 6.371e6
	d.rotation_period_s = 1.30 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.52
	d.luminosity_w = 0.0
	d.albedo = 0.36
	d.parent_id = &"alpha"
	d.orbit_profile = prof
	return d


static func _build_beta_i() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 1.6e9
	prof.eccentricity = 0.40
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 1.55
	prof.mean_anomaly_epoch_rad = 0.5
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"beta_i"
	d.display_name = "Beta I"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG
	d.radius_m = 6.371e6
	d.rotation_period_s = 0.90 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.30
	d.luminosity_w = 0.0
	d.albedo = 0.34
	d.parent_id = &"beta"
	d.orbit_profile = prof
	return d


static func _build_beta_ii() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 3.25e9
	prof.eccentricity = 0.28
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 3.95
	prof.mean_anomaly_epoch_rad = 2.0
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"beta_ii"
	d.display_name = "Beta II"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG
	d.radius_m = 6.371e6
	d.rotation_period_s = 1.60 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.61
	d.luminosity_w = 0.0
	d.albedo = 0.42
	d.parent_id = &"beta"
	d.orbit_profile = prof
	return d


# --- Monde (AUTHORED_ORBIT) ---
# r/T frei gewaehlt fuer Debugbarkeit: Monde bleiben sichtbar, sitzen jetzt aber
# deutlich enger an ihren Planeten, damit sie lokal gebunden wirken und nicht
# visuell bis in Sternnaehe ausgreifen.

static func _build_alpha_i_m() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 3.0e8
	prof.authored_period_s = 8.0e3
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
	prof.authored_radius_m = 2.4e8
	prof.authored_period_s = 6.0e3
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
