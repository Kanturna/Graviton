# Atraxis — Handoff

Stand nach Schritt 2: Echte Bubble-Transformation. Lies das zuerst,
bevor du den nächsten Schritt planst.

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

## Was in Schritt 2 implementiert wurde

### LocalBubbleManager — echte Bubble-Transformation

`compose_view_position_m(target_id)` berechnet die fokus-relative
View-Position über den LCA (Lowest Common Ancestor) der beiden
Parent-Ketten, akkumuliert intern in GDScript-double (3 separate
`float`-Variablen), nicht als `Vector3` (float32). Erst das kleine
fokus-relative Ergebnis wird in `Vector3` gegossen.

Das löst: ~18 km Darstellungsfehler bei naiver `Vector3`-Subtraktion
über 1-AU-Distanzen.

Neue öffentliche API:

| Methode | Raum | Zweck |
|---|---|---|
| `compose_view_position_m(id)` | View-Space (m) | fokus-relativ, LCA-präzise |
| `to_render_units(view_m)` | Render-Units | einzige RENDER_SCALE-Stelle |
| `compose_render_units(id)` | Render-Units | Komfortkette |
| `describe_chain(id)` | — | Debug-Text mit Kette + LCA |
| `debug_compose_world_m(id)` | World-Space | **nur Tests/Debug** |

Entfernt/ersetzt:

- `compose_world_position_m` → `debug_compose_world_m`
- `world_to_view_m` / `view_to_world_m` (Identity-Stubs) → entfernt

### Fehlerpfad "kein gemeinsamer Vorfahre"

`compose_view_position_m` gibt `Vector3.INF` zurück und ruft
`push_error`. Kein stilles `ZERO` — semantisch falsch lokalisierte
Objekte sollen sichtbar sein.

### OrbitService — recompute_all_at_time

Neue Methode: `recompute_all_at_time(t_s: float)`. Wertet alle
Bodies zum angegebenen Zeitpunkt aus, ohne einen Tick zu emittieren.
Intention: initialen konsistenten Zustand vor dem ersten Render-Frame.
`TimeService` bleibt alleiniger Zeitbesitzer.

### Testbed

`_sync_visual` ruft nur noch `_bubble.compose_render_units(id)` auf.
Keine eigene Division durch `RENDER_SCALE_M_PER_UNIT` mehr im Testbed.

### DebugOverlay

Zeigt jetzt pro Body: `|pf|` (Parent-Frame), `|world|` (debug),
`|view|` und `|render|`. Fokus-View-Betrag (muss 0 sein) als
Sanity-Check prominent oben. `describe_chain` pro Body für
LCA/Ketten-Info.

### Tests

Neue Suite: `src/tests/bubble/test_bubble.gd`. Invarianten:
- Fokus-Selbst = ZERO
- Symmetrie (Fokuswechsel)
- AU-Präzision (< 1 m Fehler bei 1 AU)
- Keine BodyState-Mutation durch Bubble-Aufrufe
- `to_render_units` linear
- Kein-LCA → `Vector3.INF`
- `describe_chain` nicht-leer

## Was bewusst NICHT existiert

- Keine Kamera-Steuerung, kein Player-Input.
- Keine Bubble-Aktivierung / Aktiv-Set.
- Kein `NUMERIC_LOCAL`-Modus.
- Kein LOD, kein Culling, keine Cluster-/Transitlogik.
- Kein Save/Load.
- Kein GUT / kein größeres Test-Framework.
- Keine `.tres`-Dateien für Bodies — bewusst, siehe Daten-first-ADR.

## Verifikation

- `godot --path . --headless --script res://src/tests/test_runner.gd --quit`
  → Exit 0, alle Asserts grün (orbit + bubble Suite).
- Projekt starten im Editor → Testbed zeigt drei Kugeln. Fokus auf
  `planet_a`: Sol weit weg (~150 Render-Einheiten), Mond nahe am
  Ursprung. Debug-Overlay zeigt `|focus_view| = 0.000e+00 m`.
- `body count = 3`, Registry-Update-Order `[sol, planet_a, moon_a]`.

## Logischer nächster Schritt

### Schritt 3 — Bubble-Aktivierung / Aktiv-Set

Welche Bodies werden fein simuliert (`NUMERIC_LOCAL`, später),
welche bleiben bei `KEPLER_APPROX`? Einschlusskritierien basierend
auf Fokus-Radius. LCA-Walker ist bereits vorhanden.

### Schritt 4

Erst dann: `NUMERIC_LOCAL` plus Moduswechsel zwischen `KEPLER_APPROX`
und lokaler Numerik.

Alles, was über diese Schritte hinausgeht (Input, Content, Transit,
Saves), wartet auf eine stabile Bubble-Aktivierungsschicht.
