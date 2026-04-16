# Graviton — Handoff

Stand nach Schritt 4: NUMERIC_LOCAL / Regime-Wechsel. Lies das zuerst,
bevor du den nächsten Schritt planst.

## Welche Ebene ist aktuell autoritativ

| Ebene | Rolle | Datei |
|---|---|---|
| `TimeService` | Wahrheit | `src/core/time/time_service.gd` |
| `UniverseRegistry` | Wahrheit | `src/sim/universe/universe_registry.gd` |
| `BodyState` (via `OrbitService`) | Wahrheit | `src/sim/bodies/body_state.gd`, `src/sim/orbit/orbit_service.gd` |
| `LocalBubbleManager` | abgeleitet (View) | `src/runtime/local_bubble/local_bubble_manager.gd` |
| `BubbleActivationSet` | abgeleitet (Relevanzklassifikation) | `src/runtime/local_bubble/bubble_activation_set.gd` |
| Testbed-Visuals, `DebugOverlay` | anzeigend | `scenes/testbeds/`, `src/tools/debug/` |

Nichts im `scenes/`- oder `src/tools/`-Baum enthält autoritativen
Simulationszustand.

## Was in Schritt 4 implementiert wurde

### LocalOrbitIntegrator — reine Integrations-Mathematik

Neue Klasse: `src/sim/orbit/local_orbit_integrator.gd`.

Statische pure Funktionen, kein Zustand:
- `gravity_acceleration_mps2(pos_m, parent_mu) → Vector3`
- `step_velocity_verlet(pos_m, vel_mps, parent_mu, dt_s) → {pos, vel}`

Velocity Verlet (zweite Ordnung, zeitreversibel, zwei a-Auswertungen/Schritt).
Nur Parentgravitation. Kein N-Body, keine externen Kräfte.

### OrbitService — NUMERIC_LOCAL-Pfad + Regime-Wechsel

Neue öffentliche Methode: `request_numeric_local_candidates(ids: Array[StringName])`.
Wird von der Szene nach jedem `BubbleActivationSet.rebuild()` aufgerufen.
OrbitService filtert intern auf Eligibility (nur KEPLER_APPROX-Profil).

Neue private Methoden:
- `_enter_numeric_local()` — initialisiert Zustand aus Kepler, setzt `current_mode = NUMERIC_LOCAL`
- `_exit_numeric_local()` — loggt Sprung via `push_warning`, setzt `current_mode = KEPLER_APPROX`
- `_update_numeric_local()` — Verlet-Integration pro Tick
- `_kepler_velocity_at()` — finite Differenz (ε = 1.0 s) für Eintrittszustand

Eligibility-Regel:
- KEPLER_APPROX-Bodies: eligible
- AUTHORED_ORBIT-Bodies: nie eligible (immer authored)
- Root-Bodies: nie eligible

### Composition Root (Testbed) — Bridge

`orbit_testbed.gd._process()` ruft jetzt:
```gdscript
_activation.rebuild()
_orbit_service.request_numeric_local_candidates(_activation.get_active_ids())
```

`time_scale` auf 1 000 gesetzt (statt 1 000 000) — NUMERIC_LOCAL-Integration
ist bei 1M× zu instabil für beobachtbare Verifikation.

### DebugOverlay

Neuer Header-Eintrag: `NL-Bodies = X / Y` — zeigt, wie viele Bodies aktuell
numerisch integriert werden.

### Tests

Neue Suite: `src/tests/orbit/test_numeric_local.gd` — 10 Invarianten:
1. Bekannter Gravitationswert bei 1 AU
2. Singularitätsschutz (pos = ZERO → ZERO)
3. Kreisbahn-Radiusstabilität (< 0.5 % Drift nach 1 000 Schritten)
4. Energieerhalt (< 1 % Änderung nach 1 Umlauf)
5. Positionskontinuität beim Eintritt (< 100 m Sprung)
6. AUTHORED_ORBIT nie in `_numeric_local_ids`
7. Root-Body nie in `_numeric_local_ids`
8. Austritt: Set leer, nächster Tick → KEPLER_APPROX
9. Keine Mutation durch `request_numeric_local_candidates` allein
10. `current_mode` bleibt NUMERIC_LOCAL nach mehreren Ticks

---

## Was in Schritt 3 implementiert wurde

### BubbleActivationSet — fokus-relative geometrische Relevanzklassifikation

Neue Klasse: `src/runtime/local_bubble/bubble_activation_set.gd`.

Klassifiziert Bodies nach fokus-relativer View-Distanz in drei explizite Zustände:
- `ACTIVE` — innerhalb `activation_radius_m` (default: 5.0e8 m)
- `INACTIVE_DISTANT` — erreichbar, aber außerhalb Radius
- `INACTIVE_NO_LCA` — nicht fokus-relativ vergleichbar (anderer Baum)

Neue Tests: `src/tests/bubble/test_activation.gd` — 11 Invarianten.

---

## Was bewusst NICHT existiert

- Keine Kamera-Steuerung, kein Player-Input.
- Kein Schiff, keine Kräfte außer Parentgravitation.
- Kein LOD, kein Culling, keine Cluster-/Transitlogik.
- Kein N-Body.
- Kein Save/Load.
- Kein GUT / kein größeres Test-Framework.
- Keine `.tres`-Dateien für Bodies — bewusst, siehe Daten-first-ADR.

## Verifikation

- `godot --path . --headless --script res://src/tests/test_runner.gd --quit`
  → Exit 0, alle Asserts grün (orbit + numeric_local + bubble + activation Suite).
- Testbed starten (time_scale = 1 000):
  - Overlay zeigt `planet_a: mode=NUMERIC_LOCAL`, `NL-Bodies = 1 / 3`
  - `moon_a: mode=AUTHORED_ORBIT` (unverändert)
  - Aktivierungsradius auf 0 → planet_a wechselt auf `KEPLER_APPROX`, Sprung im Log

## Logischer nächster Schritt

### Schritt 5 — Erste Mechanik (Schiff mit Schub)

Nach Schritt 4 ist das Projekt bereit, die erste Mechanik **bewusst zu definieren**
(nicht sofort zu bauen). Ein expliziter kleiner Designschritt steht davor:

- Welchen Body-Typ braucht ein Schiff? (`SHIP` in `BodyType.Kind`)
- Wie wird Schub als Kraft in den Verlet-Integrator eingespeist?
- Wo lebt die forces-API? (Erweiterung in OrbitService oder neuer Layer?)
- Welcher Input-Layer ist nötig?

Erst wenn dieser Designschritt abgeschlossen ist, sollte mit der Implementierung
begonnen werden.

Alles, was darüber hinausgeht (Oberfläche, Transit, Content, Save/Load),
wartet auf eine stabile Mechanik-Schicht.
