# Graviton - KI-Kontext

Lies das als erstes, wenn du als KI-Agent hier hilfst.

## Was Graviton ist

Eine Godot-4-Weltraum-/Systemsimulation mit grossen Distanzen,
Orbit-Mechanik, mehreren Referenzrahmen und einer lokal detaillierten
Bubble. Das Projekt ist bewusst als mehrschichtige Simulation
aufgesetzt, nicht als Arcade-Spiel und nicht als Tutorial-Scaffold.

Aktueller Stand:
- Foundation-Schritte 1-5 sind implementiert
- Weltladen laeuft jetzt explizit ueber `WorldLoader`
- `BodyDef` enthaelt jetzt erste statische Weltmodell-Felder
- Schritt 3 (`BubbleActivationSet`) ist implementiert
- Schritt 4 (`NUMERIC_LOCAL`) ist als minimaler Slice implementiert
- Schritt 5 (`ThermalService` / Insolation + `T_eq`) ist als read-only Slice implementiert
- Schritt 6 (`EnvironmentService` / Habitability-Klassifikation) ist als read-only Slice implementiert
- die aktive Praesentation ist ein stilisiertes 2D-Orbit-Testbed

## Wichtige Grundsaetze

1. Daten sind Wahrheit, Nodes sind Darstellung.
2. Schichten respektieren: `core/` < `sim/` < `runtime/` < `scenes/`.
3. Eine Wahrheit pro Ebene. Siehe Tabelle in `ARCHITEKTUR.md`.
4. Debugbarkeit ist Kernfunktion.

## Don'ts - haeufige Fallen

- Kein `RigidBody3D` oder Godot-Physik fuer Orbits.
- Kein `Node.position` als Simulationswahrheit.
- Kein Zwischenspeichern von Welt- oder View-Koordinaten.
- Keine neue Logik in `UniverseRegistry`.
- Keine neuen Autoloads ohne ADR-Eintrag in `ARCHITEKTUR.md`.
- Keine Render-Skala (`RENDER_SCALE_M_PER_UNIT`) in `src/sim/` oder `src/core/`.
- Keine Simulationslogik in Visual-Nodes oder im Testbed-Script ueber reine Projektion hinaus.
- `compose_root_local_position_m` nur in Tests und Debug-Overlay.
- `BubbleActivationSet` schreibt keine `BodyState`-Felder.
- Fokus, Aktiv-Set und `NUMERIC_LOCAL` sind drei verschiedene Konzepte.
- `LocalOrbitIntegrator` ist pure Mathematik und schreibt kein `BodyState`.
- `ThermalService` ist read-only Derived-Logik und schreibt kein `BodyState`.
- Keine naive `Vector3`-Addition/Subtraktion ueber grosse Distanzen (> ~1e9 m).
  `LocalBubbleManager` nutzt dafuer jetzt den Step-2-LCA-Pfad; diese
  Praezisionsentscheidung darf nicht wieder durch einen globalen
  Step-1-Subtraktionspfad aufgeweicht werden.

## Wo was lebt

- Zeit: `src/core/time/time_service.gd`
- Einheiten/Konstanten: `src/core/units/unit_system.gd`
- Orbit-Mathematik: `src/core/math/orbit_math.gd`
- Body-Daten: `src/sim/bodies/`
- Weltmodell aktuell zusaetzlich in `BodyDef`:
  `rotation_period_s`, `axial_tilt_rad`, `luminosity_w`, `albedo`
- Orbit-Update: `src/sim/orbit/orbit_service.gd`
- Weltladen: `src/sim/world/world_loader.gd`
- Numerische Integration: `src/sim/orbit/local_orbit_integrator.gd`
- Insolation / Derived-Umweltlogik: `src/sim/thermal/thermal_service.gd`
- dort jetzt auch absorbierter Fluss und einfache Gleichgewichtstemperatur
- qualitative Umweltklassifikation: `src/sim/environment/environment_service.gd`
- Registry: `src/sim/universe/universe_registry.gd`
- Bubble/View: `src/runtime/local_bubble/local_bubble_manager.gd`
- Bubble-Aktivierung: `src/runtime/local_bubble/bubble_activation_set.gd`
- Debug: `src/tools/debug/debug_overlay.gd`
- Rendering: `src/tools/rendering/`
- Tests: `src/tests/`
- Welt-Daten: `data/starter_world.gd`, `data/sample_system.gd`

## Wenn du etwas aenderst

- Bleib innerhalb der Schicht, in der du arbeitest.
- Ergaenze nie die Registry um Logik.
- Wenn du unsicher bist, ob etwas View-Space oder Sim-Space ist:
  meist ist es Sim-Space in `BodyState`; View-Space ist immer nur
  momentane Ableitung.
- Fuer neue Tests: `src/tests/<domain>/test_<thema>.gd` mit
  `static func run(ctx)`.
- Render-Skalierung gehoert nur in `src/tools/rendering/` und `scenes/`.

## Was bewusst fehlt

- Kameradrehung, Player-Input, lokale Oberflaechen
- Kraefte ausser Parentgravitation
- Save/Load, Transit, Cluster-Wechsel, Content
- Schiffe mit Schub - bewusst erst nach dem aktuellen NUMERIC_LOCAL-Slice
  und einem expliziten Design-Gate

Wenn ein Nutzer fragt, warum etwas fehlt, schlage zuerst in
`docs/HANDOFF.md` und `docs/NEXT_STEPS.md` nach. Meist ist es ein
bewusster Folgeschritt.
