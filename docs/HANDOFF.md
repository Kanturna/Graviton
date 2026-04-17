# Graviton — Handoff

> **Aktueller Stand (2026-04-17):** Die Präsentationsschicht wurde als
> stilisiertes 2D-Orbit-Testbed neugebaut (`scenes/testbeds/`,
> `src/tools/rendering/`). Die Sim-Foundation (Schritte 1–4) ist als
> Architektur dokumentiert; die aktive Testbed-Szene nutzt Step-1-APIs
> (`LocalBubbleManager` als Identity-Stub, kein BubbleActivationSet,
> kein NUMERIC_LOCAL im Testbed). Für den aktuellen Arbeitsstand lies
> zuerst `docs/STATUS.md`.

---

Architektur-Zieldokumentation: Schritte 1–4 (Step 1 implementiert, 2–4 geplant).

## Welche Ebene ist aktuell autoritativ

| Ebene | Rolle | Datei |
|---|---|---|
| `TimeService` | Wahrheit | `src/core/time/time_service.gd` |
| `UniverseRegistry` | Wahrheit | `src/sim/universe/universe_registry.gd` |
| `BodyState` (via `OrbitService`) | Wahrheit | `src/sim/bodies/body_state.gd`, `src/sim/orbit/orbit_service.gd` |
| `LocalBubbleManager` | abgeleitet (View) | `src/runtime/local_bubble/local_bubble_manager.gd` |
| `BubbleActivationSet` | abgeleitet (Relevanzklassifikation) — **geplant, nicht vorhanden** | `src/runtime/local_bubble/bubble_activation_set.gd` |
| Testbed-Visuals, `DebugOverlay` | anzeigend | `scenes/testbeds/`, `src/tools/debug/` |

Nichts im `scenes/`- oder `src/tools/`-Baum enthält autoritativen
Simulationszustand.

## Architekturplan Schritt 4 — NUMERIC_LOCAL / Regime-Wechsel

> **Nicht implementiert.** `OrbitService` enthält aktuell nur `push_warning`
> für NUMERIC_LOCAL-Bodies. Die folgenden Klassen und Methoden existieren noch nicht.

### LocalOrbitIntegrator — geplante Klasse

Datei: `src/sim/orbit/local_orbit_integrator.gd` *(nicht vorhanden)*

Statische pure Funktionen, kein Zustand:
- `gravity_acceleration_mps2(pos_m, parent_mu) → Vector3`
- `step_velocity_verlet(pos_m, vel_mps, parent_mu, dt_s) → {pos, vel}`

Velocity Verlet (zweite Ordnung, zeitreversibel). Nur Parentgravitation,
kein N-Body, keine externen Kräfte.

### OrbitService — geplante NUMERIC_LOCAL-Erweiterung

Neue Methode: `request_numeric_local_candidates(ids: Array[StringName])`.
Wird nach jedem `BubbleActivationSet.rebuild()` aufgerufen.
OrbitService filtert auf Eligibility (nur KEPLER_APPROX-Profil).

Eligibility-Regeln:
- KEPLER_APPROX-Bodies: eligible
- AUTHORED_ORBIT-Bodies: nie eligible
- Root-Bodies: nie eligible

### Tests Schritt 4 (geplant)

Suite: `src/tests/orbit/test_numeric_local.gd` *(nicht vorhanden)*
Geplante Invarianten: Gravitationswert bei 1 AU, Singularitätsschutz,
Kreisbahn-Radiusstabilität, Energieerhalt, Positionskontinuität beim Eintritt,
Eligibility-Constraints, Regime-Wechsel-Semantik.

---

## Architekturplan Schritt 3 — BubbleActivationSet

> **Nicht implementiert.** `src/runtime/local_bubble/bubble_activation_set.gd`
> existiert nicht. Die folgenden Klassen und Tests sind geplant, nicht vorhanden.

### BubbleActivationSet — geplante Klasse

Datei: `src/runtime/local_bubble/bubble_activation_set.gd` *(nicht vorhanden)*

Klassifiziert Bodies nach fokus-relativer View-Distanz in drei explizite Zustände:
- `ACTIVE` — innerhalb `activation_radius_m` (default: 5.0e8 m)
- `INACTIVE_DISTANT` — erreichbar, aber außerhalb Radius
- `INACTIVE_NO_LCA` — nicht fokus-relativ vergleichbar (anderer Baum)

### Tests Schritt 3 (geplant)

Suite: `src/tests/bubble/test_activation.gd` *(nicht vorhanden)* — 11 geplante Invarianten.

---

## Architekturplan Schritt 2 — LocalBubbleManager LCA

> **Nicht implementiert.** Der aktuelle `LocalBubbleManager` ist ein Identity-Stub
> (Step 1). Die LCA-basierte Transformation und die folgenden Methoden existieren noch nicht.

### LocalBubbleManager — geplante LCA-Erweiterung

Datei: `src/runtime/local_bubble/local_bubble_manager.gd` *(vorhanden, aber Identity-Stub)*

Geplante Erweiterung: echte fokus-relative Komposition via LCA (Lowest Common
Ancestor). Akkumuliert Parent-Frame-Ketten als drei separate `float`-Variablen
(IEEE-754 double) statt `Vector3` (float32), um Katastrophen-Kanzellation bei
AU-Distanzen zu vermeiden.

Geplante neue Methoden:

- `compose_render_units(id)` — direkte Projektion für `Node2D.position` *(nicht vorhanden)*
- `to_render_units(view_m)` — einzige erlaubte RENDER_SCALE-Anwendungsstelle *(nicht vorhanden)*
- `debug_compose_world_m(id)` — nur für Tests/Debug *(nicht vorhanden)*

Bereits vorhanden (Step 1): `compose_view_position_m(id)`, `compose_world_position_m(id)`,
`get_focus()`, `set_focus(id)`.

### Tests Schritt 2 (geplant)

Suite: `src/tests/bubble/test_bubble.gd` *(nicht vorhanden)*

---

## Was bewusst NICHT existiert

- Keine Kamera-Steuerung, kein Player-Input.
- Kein Schiff, keine Kräfte außer Parentgravitation.
- Kein LOD, kein Culling, keine Cluster-/Transitlogik.
- Kein N-Body.
- Kein Save/Load.
- Kein GUT / kein größeres Test-Framework (custom runner; GUT installiert aber nicht genutzt).
- Keine `.tres`-Dateien für Bodies — bewusst, siehe Daten-first-ADR.

## Verifikation (Sim-Layer)

```
godot --path . --headless --script res://src/tests/test_runner.gd --quit
```

Exit 0, alle Asserts grün (test_orbit + test_registry + test_starter_world Suite).

> **Hinweis:** Die alten Testbed-Checks für NUMERIC_LOCAL, NL-Bodies und
> BubbleActivationSet gelten für das frühere 3D-Testbed. Das aktuelle
> 2D-Testbed (StarterWorld, 9 Bodies) zeigt im DebugOverlay (F3) die
> korrekten Positionen aller Bodies und unterstützt Fokus-Navigation per Tab.

## Logischer nächster Schritt

Aktuell: Schritte 2–4 sind als Architektur dokumentiert, aber nicht im Code vorhanden.
Der naheliegende nächste Implementierungsschritt ist Schritt 2 (LocalBubbleManager LCA),
dann 3 (BubbleActivationSet), dann 4 (NUMERIC_LOCAL / Velocity Verlet).

### Design-Gate vor Schritt 5 — Erste Mechanik (Schiff mit Schub)

Erst nach Abschluss von Schritt 4 steht ein expliziter Designschritt an, bevor mit
Mechanik-Implementierung begonnen wird:

- Welchen Body-Typ braucht ein Schiff? (`CONTROLLED` in `BodyType.Kind` ist vorbereitet,
  trägt aber noch keine Bewegungssemantik)
- Wie wird Schub als Kraft in den Verlet-Integrator eingespeist?
- Wo lebt die forces-API? (Erweiterung in OrbitService oder neuer Layer?)
- Welcher Input-Layer ist nötig?
- Wer darf `parent_id` eines CONTROLLED-Bodies ändern (Andocken)?

Alles, was darüber hinausgeht (Oberfläche, Transit, Content, Save/Load),
wartet auf eine stabile Mechanik-Schicht.
