# Graviton - Next Steps

Stand: 2026-04-18

## Prioritaet 0 - Test-Baseline wieder gruen machen - erledigt

Ziel:
Die Foundation sollte vor den naechsten groesseren Architektur-Schritten
wieder eine saubere gruene Test-Basis haben.

Erledigt:

- `solve_kepler(PI, 0)` als bewusste signed-range-Konvention
  `[-PI, PI)` festgezogen
- Orbit-Test auf kanonischen Rueckgabewert plus Residual-Check
  umgestellt
- Test-Baseline wieder als verlaessliche Basis hergestellt

## Prioritaet 1 - Foundation Phase A: Step 2 Bubble / Frame-Modell - erledigt

Ziel:
Den `LocalBubbleManager` vom frueheren Fokus-Subtraktionsmodell auf das
dokumentierte Step-2-Zielbild bringen.

Erledigt:

- LCA-/praezisionsbewusste Komposition fuer `compose_view_position_m`
- `Vector3.INF`-Sentinel fuer Bodies ohne gemeinsamen Root mit dem Fokus
- root-lokale Debug-Hilfe `compose_root_local_position_m`
- Renderer-Toleranz fuer nicht-finite Bodies inkl. Trail-Cleanup

## Prioritaet 2 - Foundation Phase B: WorldLoader / Weltwahl explizit machen - erledigt

Ziel:
Das Testbed soll nicht mehr direkt eine bestimmte Welt hart laden,
sondern eine explizite Loader-/World-Schicht nutzen.

Erledigt:

- neuer `WorldLoader` als Node-Service im `src/sim/`-Layer
- `orbit_testbed.gd` laedt Welten jetzt explizit ueber
  `initial_world_id`
- `starter_world` und `sample_system` laufen ueber denselben
  transaktionalen Loader-Pfad
- `UniverseRegistry` ist wieder auf Registry-Scope zurueckgefuehrt

## Prioritaet 3 - Foundation Phase C: World Model verbreitern - erledigt

Ziel:
Die statische Simulationswahrheit fuer Bodies so erweitern, dass
spaetere planetare Zustaende, Generatoren und echte Mehrsystem-Welten
auf einer sauberen Datenbasis aufsetzen koennen.

Erledigt:

- `BodyDef` um Rotation, Achsneigung, Leuchtkraft und Albedo erweitert
- Referenzwelten explizit mit ersten Weltmodell-Werten befuellt
- neue Validierungs- und BodyDef-World-Model-Tests ergaenzt
- weiterhin noch keine abgeleiteten Temperatur-/Habitability-Systeme

## Prioritaet 4 - Foundation Phase D: BubbleActivationSet - erledigt

Ziel:
Bodies relativ zum aktuellen Fokus read-only in Aktivierungszustaende
klassifizieren, ohne schon Regime-Wechsel oder `BodyState`-Mutation
einzufuehren.

Erledigt:

- `BubbleActivationSet` als eigener Runtime-Service
- Klassifikation in `ACTIVE`, `INACTIVE_DISTANT`, `INACTIVE_NO_LCA`
- Debug-Overlay-Hook fuer Aktivierungsradius und Body-States
- neue Runtime-Tests fuer Multi-Root, Boundary-Fall `radius = 0.0` und
  Auto-Rebuild bei `focus_changed`

## Prioritaet 5 - Foundation Phase D: Regime-Wechsel / NUMERIC_LOCAL - erledigt

Ziel:
Das Aktiv-Set aus der Bubble-Schicht als expliziten Wunsch in den
Sim-Layer bridgen und einen minimalen numerischen Parent-Only-Pfad fuer
eligible `KEPLER_APPROX`-Bodies einziehen.

Erledigt:

- `LocalOrbitIntegrator` als pure Mathematik im `src/sim/`-Layer
- `OrbitService.request_numeric_local_candidates(ids)` als
  Replace-API fuer das aktuelle Wunsch-Set
- Regime-Wechsel nur ueber `BodyState.current_mode`, nicht ueber
  `OrbitProfile.mode`
- analytisches Velocity-Seeding via zentraler finite Differenz
  (`VELOCITY_SEED_EPSILON_S = 1.0`)
- Exit-Warnings mit Positions-/Velocity-Deltas beim Rueckwechsel auf
  `KEPLER_APPROX`
- neue Tests fuer Integrator, Idempotenz, Replace-Semantik und
  Regime-Wechsel

## Prioritaet 6 - Derived Phase A: Insolation / ThermalService - erledigt

Ziel:
Den ersten read-only Derived-Service ausserhalb von Orbit-/Bubble-
Kernlogik einfuehren und minimale Insolation direkt aus Foundation-
Wahrheit ableiten.

Erledigt:

- `ThermalService` als on-demand-Service im `src/sim/`-Layer
- Quellenregel: naechster leuchtender Ancestor mit `luminosity_w > 0.0`
- keine Selbstbestrahlung; die Suche startet beim Parent
- Debug-Overlay-Hook fuer `insolation` und `source`
- neue Tests fuer SampleSystem, StarterWorld, Cross-Root-Isolation und
  `describe_body(...)`

## Danach - Planetare Zustandsableitung

Erst wenn Weltmodell, Loader und Bubble-/Regime-Fundament tragfaehig sind:

- erste abgeleitete planetare Zustandsgroessen
  - absorbierte Leistung / Temperatur
  - einfache Bewohnbarkeits- oder Unwirtlichkeitsmarker
  - spaeter Strahlung / Atmosphaerenklassen / weitere Umweltfaktoren

## Offene Folgeaufgabe - Stabilitaets-Guardrail fuer NUMERIC_LOCAL

- spaeter Substepping / High-Speed-Guardrail fuer hohe `time_scale`
- moegliche Hysterese oder andere Anti-Thrashing-Massnahmen am
  Aktivierungsrand
- spaeter Topologie-Helfer sinnvoll zentralisieren, wenn die
  Activation-/Mehrwurzel-Pfade stabil sind

## Spaeter - Prozedurale Systeme

- Generator-Konzept fuer Root-Systeme, Sterne, Planeten und Monde
- Zufallsbereiche fuer Orbitachsen, Exzentrizitaeten und Orientierungen
- deterministische Seeds / reproduzierbare Welten

## Bewusst nicht jetzt

- kein weiterer grosser Visual-Pass
- keine neue Gameplay-/Schiffs-/Fraktionsschicht
- keine ueberhastete Generator-Spielerei ohne sauberes Weltmodell
- keine Ausweitung der Autoload-Liste
