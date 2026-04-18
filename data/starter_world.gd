class_name StarterWorld
extends RefCounted

# Factory fuer das Starter-Debug-System.
# Diff-freundlich, reviewbar: das gesamte System ist in dieser Datei lesbar.
# Keine .tres-Binaries, keine Inspector-gepflegte Resource.
#
# Inhalt (18 Koerper, topologische Reihenfolge):
#   obsidian    - Schwarzes Loch, Wurzel
#   alpha       - Stern A, AUTHORED_ORBIT um obsidian
#   beta        - Stern B, AUTHORED_ORBIT um obsidian
#   gamma       - Stern C, AUTHORED_ORBIT um obsidian
#   delta       - Stern D, AUTHORED_ORBIT um obsidian
#   alpha_i     - Planet I um alpha,   KEPLER_APPROX
#   alpha_ii    - Planet II um alpha,  KEPLER_APPROX
#   alpha_iii   - Planet III um alpha, KEPLER_APPROX
#   alpha_i_m   - Mond um alpha_i,     AUTHORED_ORBIT
#   beta_i      - Planet I um beta,    KEPLER_APPROX
#   beta_ii     - Planet II um beta,   KEPLER_APPROX
#   beta_i_m    - Mond um beta_i,      AUTHORED_ORBIT
#   gamma_i     - Planet I um gamma,   KEPLER_APPROX
#   gamma_ii    - Planet II um gamma,  KEPLER_APPROX
#   gamma_iii   - Planet III um gamma, KEPLER_APPROX
#   gamma_iv    - Planet IV um gamma,  KEPLER_APPROX
#   gamma_ii_m  - Mond um gamma_ii,    AUTHORED_ORBIT
#   delta_i     - Planet I um delta,   KEPLER_APPROX
#
# Orbit-Modus-Entscheidungen:
#   AUTHORED_ORBIT fuer BH-Sterne und Monde: erlaubt freie Wahl von r und T
#   unabhaengig von Parentmasse - vorhersagbare Visualisierung, keine
#   Kepler-Rechnung noetig.
#   KEPLER_APPROX fuer Planeten: testet die analytische Orbit-Pipeline
#   (OrbitMath.kepler_position).
#
# Alle Werte sind bewusste Toy-Werte fuer Debugbarkeit, nicht
# astrophysikalisch korrekt. Ziel-Hierarchie fuer die Lesbarkeit:
#   Monde kreisen sichtbar schneller um Planeten als Planeten um Sterne.
#   Planeten kreisen sichtbar schneller um Sterne als Sterne um obsidian.
#   Die vier Sternsysteme sollen im Root-View bewusst asymmetrisch wirken.


static func build() -> Array[BodyDef]:
	var out: Array[BodyDef] = []
	out.append(_build_obsidian())
	out.append(_build_alpha())
	out.append(_build_beta())
	out.append(_build_gamma())
	out.append(_build_delta())
	out.append(_build_alpha_i())
	out.append(_build_alpha_ii())
	out.append(_build_alpha_iii())
	out.append(_build_alpha_i_m())
	out.append(_build_beta_i())
	out.append(_build_beta_ii())
	out.append(_build_beta_i_m())
	out.append(_build_gamma_i())
	out.append(_build_gamma_ii())
	out.append(_build_gamma_iii())
	out.append(_build_gamma_iv())
	out.append(_build_gamma_ii_m())
	out.append(_build_delta_i())
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
# P12B bleibt bewusst content-only: BH-Sterne bleiben Kreise statt schon
# elliptische Root-Orbits zu erzwingen. Asymmetrie entsteht ueber r/T/Phase
# und ungleich grosse Planetensysteme.

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


static func _build_gamma() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 3.45e11
	prof.authored_period_s = 9.5e4
	prof.authored_phase_rad = 4.25

	var d := BodyDef.new()
	d.id = &"gamma"
	d.display_name = "Gamma"
	d.kind = BodyType.Kind.STAR
	# P13: gamma ist bewusst als kompakter Red-Dwarf-artiger Stern
	# parametrisiert. Damit passt die habitable Zone innerhalb einer
	# lokalen Stabilitaetsgrenze in die Hill-Sphere, ohne einen
	# root-skaligen Planet-Ausreisser zu erzwingen.
	d.mass_kg = UnitSystem.SOLAR_MASS_KG * 0.20
	d.radius_m = 1.95e8
	d.rotation_period_s = 18.0 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.0
	d.luminosity_w = 0.0036 * UnitSystem.SOLAR_LUMINOSITY_W
	d.albedo = 0.0
	d.parent_id = &"obsidian"
	d.orbit_profile = prof
	return d


static func _build_delta() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 4.8e11
	prof.authored_period_s = 1.3e5
	prof.authored_phase_rad = 0.95

	var d := BodyDef.new()
	d.id = &"delta"
	d.display_name = "Delta"
	d.kind = BodyType.Kind.STAR
	d.mass_kg = UnitSystem.SOLAR_MASS_KG * 4.2
	d.radius_m = 8.1e8
	d.rotation_period_s = 31.0 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.0
	d.luminosity_w = 5.0 * UnitSystem.SOLAR_LUMINOSITY_W
	d.albedo = 0.0
	d.parent_id = &"obsidian"
	d.orbit_profile = prof
	return d


# --- Planeten (KEPLER_APPROX) ---
# Die Planeten bleiben pro Sternsystem streng von innen nach aussen sortiert.
# P12B verlangt hier keine ausgefeilte Nicht-Ueberlappungsanalyse, aber die
# semi_major_axis_m-Werte bleiben innerhalb desselben Sternsystems bewusst
# paarweise verschieden.

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


static func _build_alpha_iii() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 4.2e9
	prof.eccentricity = 0.18
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 5.10
	prof.mean_anomaly_epoch_rad = 2.55
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"alpha_iii"
	d.display_name = "Alpha III"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG * 1.2
	d.radius_m = 7.2e6
	d.rotation_period_s = 2.10 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.09
	d.luminosity_w = 0.0
	d.albedo = 0.48
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


static func _build_gamma_i() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 2.0e9
	prof.eccentricity = 0.05
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 0.40
	prof.mean_anomaly_epoch_rad = 0.10
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"gamma_i"
	d.display_name = "Gamma I"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG * 0.7
	d.radius_m = 5.1e6
	d.rotation_period_s = 0.70 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.12
	d.luminosity_w = 0.0
	d.albedo = 0.19
	d.parent_id = &"gamma"
	d.orbit_profile = prof
	return d


static func _build_gamma_ii() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 4.5e9
	prof.eccentricity = 0.07
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 2.20
	prof.mean_anomaly_epoch_rad = 1.35
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"gamma_ii"
	d.display_name = "Gamma II"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG * 1.4
	d.radius_m = 7.8e6
	d.rotation_period_s = 1.05 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.44
	d.north_pole_orbit_frame_azimuth_rad = PI / 3.0
	d.luminosity_w = 0.0
	d.albedo = 0.41
	d.parent_id = &"gamma"
	d.orbit_profile = prof
	return d


static func _build_gamma_iii() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 7.2e9
	prof.eccentricity = 0.09
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 4.05
	prof.mean_anomaly_epoch_rad = 2.65
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"gamma_iii"
	d.display_name = "Gamma III"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG * 1.1
	d.radius_m = 6.6e6
	d.rotation_period_s = 1.80 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.08
	d.luminosity_w = 0.0
	d.albedo = 0.55
	d.parent_id = &"gamma"
	d.orbit_profile = prof
	return d


static func _build_gamma_iv() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 9.0e9
	prof.eccentricity = 0.03
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 5.30
	prof.mean_anomaly_epoch_rad = 0.90
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"gamma_iv"
	d.display_name = "Gamma IV"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG * 2.0
	d.radius_m = 8.9e6
	d.rotation_period_s = 2.60 * UnitSystem.DAY_S
	# P13: gamma_iv ist der eine sichtbar habitable Kandidat der
	# StarterWorld, jetzt aber innerhalb eines kompakten lokalen
	# Red-Dwarf-Systems statt als root-skaliger Ausreisserorbit.
	d.axial_tilt_rad = 0.26
	d.luminosity_w = 0.0
	d.albedo = 0.24
	d.greenhouse_delta_k = 35.0
	d.parent_id = &"gamma"
	d.orbit_profile = prof
	return d


static func _build_delta_i() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 1.95e9
	prof.eccentricity = 0.47
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 3.10
	prof.mean_anomaly_epoch_rad = 1.80
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"delta_i"
	d.display_name = "Delta I"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG * 1.7
	d.radius_m = 8.2e6
	d.rotation_period_s = 1.35 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.33
	d.north_pole_orbit_frame_azimuth_rad = -PI / 4.0
	d.luminosity_w = 0.0
	d.albedo = 0.12
	d.parent_id = &"delta"
	d.orbit_profile = prof
	return d


# --- Monde (AUTHORED_ORBIT) ---
# r/T frei gewaehlt fuer Debugbarkeit: Monde bleiben sichtbar, sitzen aber
# enger an ihren Planeten, damit sie lokal gebunden wirken und nicht bis in
# Sternnaehe ausgreifen.

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


static func _build_gamma_ii_m() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 3.6e8
	prof.authored_period_s = 1.1e4
	prof.authored_phase_rad = 0.85

	var d := BodyDef.new()
	d.id = &"gamma_ii_m"
	d.display_name = "Gamma II - Moon"
	d.kind = BodyType.Kind.MOON
	# P12B verteilt Monde bewusst nicht schematisch immer auf den jeweils
	# ersten Planeten eines Sternsystems.
	d.mass_kg = UnitSystem.LUNAR_MASS_KG * 1.3
	d.radius_m = 1.96e6
	d.parent_id = &"gamma_ii"
	d.orbit_profile = prof
	return d
