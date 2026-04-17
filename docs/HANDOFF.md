# Graviton - Handoff

> Aktueller Stand (2026-04-17):
> Die Praesentationsschicht ist ein stilisiertes 2D-Orbit-Testbed.
> Foundation-Schritte 2-3 sind implementiert, und das Testbed laedt
> Welten jetzt explizit ueber `WorldLoader` statt direkt aus der
> Registry.
> Das Weltmodell in `BodyDef` ist jetzt um erste statische Umgebungs-
> felder verbreitert. `BubbleActivationSet` ist jetzt als read-only
> Runtime-Service implementiert; `NUMERIC_LOCAL` bleibt geplant. Fuer die
> aktuelle Priorisierung lies zuerst `docs/STATUS.md` und
> `docs/NEXT_STEPS.md`.

---

## Autoritative Ebenen

| Ebene | Rolle | Datei |
|---|---|---|
| `TimeService` | Wahrheit | `src/core/time/time_service.gd` |
| `UniverseRegistry` | Wahrheit | `src/sim/universe/universe_registry.gd` |
| `WorldLoader` | Sim-Factory / Weltladepfad | `src/sim/world/world_loader.gd` |
| `BodyDef` | statische Weltdefinition | `src/sim/bodies/body_def.gd` |
| `BodyState` via `OrbitService` | Wahrheit | `src/sim/bodies/body_state.gd`, `src/sim/orbit/orbit_service.gd` |
| `LocalBubbleManager` | abgeleitet (View) | `src/runtime/local_bubble/local_bubble_manager.gd` |
| `BubbleActivationSet` | abgeleitet (read-only) | `src/runtime/local_bubble/bubble_activation_set.gd` |
| Testbed-Visuals und `DebugOverlay` | anzeigend | `scenes/testbeds/`, `src/tools/debug/` |

Nichts im `scenes/`- oder `src/tools/`-Baum enthaelt autoritativen
Simulationszustand.

## Schritt 2 - LocalBubbleManager LCA

Status: implementiert.

Aktuelle API in `src/runtime/local_bubble/local_bubble_manager.gd`:
- `compose_view_position_m(id)` - fokus-relative Step-2-Komposition
- `compose_root_local_position_m(id)` - root-lokale Debug-/Test-Hilfe
- `get_focus()`, `set_focus(id)`

Wichtige Semantik:
- gleiche Roots -> finite fokus-relative Position
- anderer Root als Fokus -> `Vector3.INF`
- kein Fokus -> `Vector3.INF`
- Parent-Frame-Ketten werden als drei separate `float`-Werte akkumuliert

Testabdeckung:
- `src/tests/runtime/test_local_bubble_step2.gd`
- bestehende `test_starter_world.gd` bleibt fuer den Ein-Root-Fall gruen

## Weltladen / WorldLoader

Status: implementiert.

Aktuelle API in `src/sim/world/world_loader.gd`:
- `available_world_ids()`
- `load_named_world(world_id, registry)`
- `load_defs_into_registry(defs, registry)`

Wichtige Semantik:
- `WorldLoader` ist ein Node-Service im `sim/`-Layer, kein Autoload
- benannte Referenzwelten: `starter_world`, `sample_system`
- Laden ist transaktional: erst voll validieren, dann `registry.clear()`
  und in Array-Reihenfolge registrieren
- bei Fehlern bleibt die Registry unveraendert

## Weltmodell / BodyDef

Status: implementiert.

Aktuelle zusaetzliche Felder in `src/sim/bodies/body_def.gd`:
- `rotation_period_s`
- `axial_tilt_rad`
- `luminosity_w`
- `albedo`

Wichtige Semantik:
- reine statische Datenbasis, noch ohne Wirkung auf Orbit, View oder HUD
- `rotation_period_s` ist sidereal gemeint
- `axial_tilt_rad` bezieht sich auf die Orbit-Ebene des Bodies um seinen Parent
- `luminosity_w = 0.0` bleibt in der aktuellen Phase bewusst doppeldeutig
- `albedo` ist auf `0.0 .. 1.0` begrenzt

## Schritt 3 - BubbleActivationSet

Status: implementiert.

Verantwortung:
- Klassifikation in `ACTIVE`, `INACTIVE_DISTANT`, `INACTIVE_NO_LCA`
- liest Bubble/View-Distanzen
- schreibt keine `BodyState`-Felder
- `classify(id)` spiegelt den Zustand des letzten `rebuild()` wider
- `get_active_ids()` folgt der topologischen Registry-Reihenfolge

## Schritt 4 - NUMERIC_LOCAL / Regime-Wechsel

Status: geplant, nicht implementiert.

Geplante Bausteine:
- `src/sim/orbit/local_orbit_integrator.gd`
- `OrbitService.request_numeric_local_candidates(ids)`
- Eligibility nur fuer `KEPLER_APPROX`
- Logging bei Rueckwechseln zu `KEPLER_APPROX`

## Verifikation

Headless-Testlauf:

```text
godot --path . --headless --script res://src/tests/test_runner.gd --quit
```

Erwarteter Stand nach P4:
- `test_orbit`
- `test_registry`
- `test_starter_world`
- `test_local_bubble_step2`
- `test_world_loader`
- `test_body_def_world_model`
- `test_bubble_activation_set`

alle gruen.

## Naechster sinnvoller Schritt

Die aktuelle Projekt-Roadmap priorisiert jetzt:
1. `NUMERIC_LOCAL`
2. danach erste abgeleitete planetare Zustandswerte
3. spaeter Generator-/Systemschritte und weitere Foundation-Folgen

Die Architektur-Schritte 3 und 4 bleiben wichtig, aber der naechste
Roadmap-Hebel liegt jetzt im Aktivierungs-/Regime-Fundament auf Basis
des jetzt verbreiterten Weltmodells.

## Was bewusst noch fehlt

- keine Schiffe / kein Gameplay-Layer
- keine Kraefte ausser Parentgravitation
- kein Save/Load
- keine Transit-/Clusterlogik
- keine prozedurale Generator-Schicht

Erst nach einer stabilen Foundation aus Loader, Weltmodell,
Bubble-Aktivierung und spaeterem Regime-Wechsel sollten Mechanik- oder
Content-Schichten dazukommen.
