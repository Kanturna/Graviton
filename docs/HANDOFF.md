# Graviton - Handoff

> Aktueller Stand (2026-04-17):
> Die Praesentationsschicht ist ein stilisiertes 2D-Orbit-Testbed.
> Foundation-Schritt 2 ist jetzt implementiert:
> `LocalBubbleManager` nutzt LCA-basierte Step-2-Komposition mit
> `Vector3.INF`-Sentinel fuer fremde Roots. `BubbleActivationSet` und
> `NUMERIC_LOCAL` bleiben geplant. Fuer die aktuelle Priorisierung lies
> zuerst `docs/STATUS.md` und `docs/NEXT_STEPS.md`.

---

## Autoritative Ebenen

| Ebene | Rolle | Datei |
|---|---|---|
| `TimeService` | Wahrheit | `src/core/time/time_service.gd` |
| `UniverseRegistry` | Wahrheit | `src/sim/universe/universe_registry.gd` |
| `BodyState` via `OrbitService` | Wahrheit | `src/sim/bodies/body_state.gd`, `src/sim/orbit/orbit_service.gd` |
| `LocalBubbleManager` | abgeleitet (View) | `src/runtime/local_bubble/local_bubble_manager.gd` |
| `BubbleActivationSet` | abgeleitet (geplant) | `src/runtime/local_bubble/bubble_activation_set.gd` |
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

## Schritt 3 - BubbleActivationSet

Status: geplant, nicht implementiert.

Geplante Verantwortung:
- Klassifikation in `ACTIVE`, `INACTIVE_DISTANT`, `INACTIVE_NO_LCA`
- liest Bubble/View-Distanzen
- schreibt keine `BodyState`-Felder

Geplante Datei:
- `src/runtime/local_bubble/bubble_activation_set.gd`

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

Erwarteter Stand nach P1:
- `test_orbit`
- `test_registry`
- `test_starter_world`
- `test_local_bubble_step2`

alle gruen.

## Naechster sinnvoller Schritt

Die aktuelle Projekt-Roadmap priorisiert jetzt:
1. `WorldLoader` / Weltwahl explizit machen
2. `BodyDef` / Weltmodell verbreitern
3. danach `BubbleActivationSet`
4. danach `NUMERIC_LOCAL`

Die Architektur-Schritte 3 und 4 bleiben wichtig, aber sie sind nicht
mehr der unmittelbare naechste Roadmap-Schritt vor dem Loader-/Weltblock.

## Was bewusst noch fehlt

- keine Schiffe / kein Gameplay-Layer
- keine Kraefte ausser Parentgravitation
- kein Save/Load
- keine Transit-/Clusterlogik
- keine prozedurale Generator-Schicht

Erst nach einer stabilen Foundation aus Loader, Weltmodell,
Bubble-Aktivierung und spaeterem Regime-Wechsel sollten Mechanik- oder
Content-Schichten dazukommen.
