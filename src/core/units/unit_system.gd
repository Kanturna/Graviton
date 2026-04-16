class_name UnitSystem
extends RefCounted

# Einzige Wahrheitsquelle fuer Einheiten und astronomische Konstanten.
# Alle Simulationswerte sind in SI: Meter, Sekunden, Kilogramm.
# Die Render-Skala ist ausschliesslich eine Darstellungsgroesse und darf
# NIEMALS in Simulationsberechnungen auftauchen.

const METER: float = 1.0
const SECOND: float = 1.0
const KG: float = 1.0

const AU_M: float = 1.495978707e11
const G: float = 6.67430e-11
const SOLAR_MASS_KG: float = 1.98892e30
const EARTH_MASS_KG: float = 5.9722e24
const LUNAR_MASS_KG: float = 7.342e22

const DAY_S: float = 86400.0
const YEAR_S: float = 365.25 * 86400.0

const TAU_F: float = TAU

# Render-only. Teiler von Weltmetern -> Godot-Rendereinheit.
const RENDER_SCALE_M_PER_UNIT: float = 1.0e9

static func mu_from_mass(mass_kg: float) -> float:
	return G * mass_kg
