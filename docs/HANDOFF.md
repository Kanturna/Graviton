# Atraxis — Handoff

Stand nach dem ersten Foundation-Slice. Lies das zuerst, bevor du
den nächsten Schritt planst.

## Welche Ebene ist aktuell autoritativ

| Ebene                          | Rolle         | Datei                                                        |
|--------------------------------|---------------|--------------------------------------------------------------|
| `TimeService`                  | Wahrheit      | `src/core/time/time_service.gd`                              |
| `UniverseRegistry`             | Wahrheit      | `src/sim/universe/universe_registry.gd`                      |
| `BodyState` (via `OrbitService`) | Wahrheit    | `src/sim/bodies/body_state.gd`, `src/sim/orbit/orbit_service.gd` |
| `LocalBubbleManager`           | abgeleitet    | `src/runtime/local_bubble/local_bubble_manager.gd`           |
| Testbed-Visuals, `DebugOverlay`, `Node3D.position`s | abgeleitet / anzeigend | `scenes/testbeds/`, `src/tools/debug/` |

Nichts im `scenes/`- oder `src/tools/`-Baum enthält autoritativen
Simulationszustand.

## Begriffe, die nur Render-/View-Space bedeuten

- `LocalBubbleManager.world_to_view_m`, `view_to_world_m`,
  `compose_view_position_m` → View-Space, aktuell Identity.
- `Node3D.position` im Testbed → Render-Units (View-Space durch
  `RENDER_SCALE_M_PER_UNIT` geteilt).
- Alles unter `scenes/testbeds/orbit_testbed.tscn` → `Visuals/` ist
  reine Projektion. Keine Logik dort.
- `RENDER_SCALE_M_PER_UNIT` aus `UnitSystem` → Render-only, darf in
  `src/sim/` und `src/core/` **nicht** auftauchen.

## Bewusste Platzhalter

- `LocalBubbleManager.world_to_view_m` ist **Identity**. Das ist
  **kein** finales Design, sondern ein architektonischer Stub. Der
  nächste Schritt ersetzt ihn durch Focus-Offset-Subtraktion plus
  konfigurierbare Skalierung.
- `OrbitMode.Kind.NUMERIC_LOCAL` existiert als Enum-Wert. `OrbitService`
  behandelt ihn aktuell nur mit einer Warnung — bewusst nicht
  implementiert.
- Velocity in `BodyState` wird durch finite Differenz geschätzt
  (aktuelle minus vorherige Position). Für die Foundation-Tests
  reicht das; `NUMERIC_LOCAL` wird später eine echte Velocity-Quelle
  einführen.
- Kein Input, keine Kamera-Steuerung. Kamera im Testbed ist
  statisch.

## Was konkret existiert

- `project.godot` (2 Autoloads: `TimeService`, `UniverseRegistry`).
- `src/core/time/time_service.gd` — fixed-dt Tick, time_scale als
  Multiplikator.
- `src/core/units/unit_system.gd` — SI-Konstanten + Render-Skala.
- `src/core/ids/id_registry.gd` — IDs mit authored/runtime-Trennung.
- `src/core/math/orbit_math.gd` — pure Kepler-/Kreis-Mathematik.
- `src/sim/bodies/{body_type, body_def, body_state}.gd`.
- `src/sim/orbit/{orbit_mode, orbit_profile, orbit_service}.gd`.
- `src/sim/universe/universe_registry.gd` (schlank, siehe ADR).
- `src/runtime/local_bubble/local_bubble_manager.gd` (Identity-Stub).
- `src/tools/debug/debug_overlay.gd|.tscn`.
- `src/tests/test_runner.gd` + `src/tests/orbit/test_orbit.gd`.
- `scenes/bootstrap/main.gd|.tscn` (Entry, leitet ins Testbed).
- `scenes/testbeds/orbit_testbed.gd|.tscn`.
- `data/sample_system.gd` (Sol / Planet A / Moon A).

## Was bewusst NICHT existiert

- Keine Kamera-Steuerung, kein Player-Input.
- Keine lokale Oberfläche, kein Transit, keine Cluster.
- Keine globale Gravitation für viele Bodies.
- Kein Save/Load.
- Kein GUT / kein größeres Test-Framework.
- Keine `.tres`-Dateien für Bodies — bewusst, siehe Daten-first-ADR.
- Keine Content-/Lore-Dateien.

## Verifikation

- `godot --path . --headless --script res://src/tests/test_runner.gd --quit`
  → Exit 0, alle Asserts grün.
- Projekt starten im Editor → Bootstrap lädt, Testbed zeigt drei
  Kugeln. Planet bewegt sich sichtbar, Mond umrundet Planet. Das
  Debug-Overlay listet `sim_time_s` (wachsend), Body-Count 3,
  Parent-IDs, Modi, Parent-Frame-Beträge und Welt-Beträge.
- Registry-Update-Order muss `[sol, planet_a, moon_a]` sein
  (Parent-vor-Kind).

## Logischer nächster Schritt

1. **Echte Bubble-Transformation.** `LocalBubbleManager.world_to_view_m`
   subtrahiert die Welt-Position des Fokus und skaliert so, dass
   Render-Präzision auch bei AU-Distanzen stabil bleibt. Der Fokus
   wird der einzige "nahe" Punkt für Render und Gameplay.
2. **`NUMERIC_LOCAL` für den fokussierten Körper.** Semi-implicit-Euler
   oder Leapfrog, ausschließlich für den Cluster innerhalb der Bubble.
   Umschaltlogik: `KEPLER_APPROX` ↔ `NUMERIC_LOCAL` auf Basis des
   Fokus.
3. **Erweiterter Test-Runner.** Suiten pro Domäne (`bodies/`,
   `universe/`, `bubble/`). Vielleicht später GUT-Migration, sobald
   die Test-Menge > ~20 Suiten erreicht.

Alles, was über diese drei Schritte hinausgeht (Input, Content,
Transit, Saves), wartet bewusst auf eine stabile Bubble-Schicht.
