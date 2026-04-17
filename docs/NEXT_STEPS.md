# Graviton - Next Steps

Stand: 2026-04-17

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

## Prioritaet 3 - Foundation Phase C: World Model verbreitern

Ziel:
Die statische Simulationswahrheit fuer Bodies so erweitern, dass
spaetere planetare Zustaende, Generatoren und echte Mehrsystem-Welten
auf einer sauberen Datenbasis aufsetzen koennen.

Gemeinte Richtung:

- `BodyDef` um fehlende statische Welt-/Physikfelder erweitern
  (z. B. Rotation, Achsneigung, Luminositaet, Albedo)
- bestehende Toy-Welten mit Defaults kompatibel halten
- noch keine abgeleiteten Temperatur-/Habitability-Systeme einbauen

## Danach - Foundation Phase D: Aktivierung und Regime

- `BubbleActivationSet`
- spaeter `NUMERIC_LOCAL` / `LocalOrbitIntegrator`
- Tests fuer Regime-Wechsel, Praezision und Multi-Root-Komposition
- spaeter Topologie-Helfer sinnvoll zentralisieren, wenn die
  Activation-/Mehrwurzel-Pfade stabil sind

## Danach - Planetare Zustandsableitung

Erst wenn Weltmodell, Loader und Bubble-Fundament tragfaehig sind:

- erste abgeleitete planetare Zustandsgroessen
  - Insolation / Temperatur
  - einfache Bewohnbarkeits- oder Unwirtlichkeitsmarker
  - spaeter Strahlung / Atmosphaerenklassen / weitere Umweltfaktoren

## Spaeter - Prozedurale Systeme

- Generator-Konzept fuer Root-Systeme, Sterne, Planeten und Monde
- Zufallsbereiche fuer Orbitachsen, Exzentrizitaeten und Orientierungen
- deterministische Seeds / reproduzierbare Welten

## Bewusst nicht jetzt

- kein weiterer grosser Visual-Pass
- keine neue Gameplay-/Schiffs-/Fraktionsschicht
- keine ueberhastete Generator-Spielerei ohne sauberes Weltmodell
- keine Ausweitung der Autoload-Liste
