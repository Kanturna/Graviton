# Atraxis — Simulationsregeln

Normative Regeln für alle Sim-Beiträge. Wer etwas baut, das gegen
diese Regeln verstößt, bricht das Fundament.

## Zeit

- Einzige Quelle: `TimeService` (Autoload).
- Fixed Timestep: `FIXED_DT = 1/60 s`. Jedes `sim_tick`-Signal wird
  **immer** mit `dt == FIXED_DT` emittiert.
- `time_scale` wirkt als **Tick-Multiplikator** pro physics-Frame,
  nicht als Skalierung von `dt`:
  - `time_scale == 1.0` → 1 Tick pro Frame.
  - `time_scale == 3.0` → 3 Ticks pro Frame.
  - `time_scale == 0.5` → akkumuliert, emittiert Tick jede 2. Frame.
- `paused == true` unterdrückt alle Ticks.
- `sim_time_s` wächst streng monoton; nur `TimeService.reset()`
  setzt ihn zurück (ausschließlich für Tests).

## Einheiten

- Simulation rechnet **ausschließlich in SI**: Meter, Sekunden, kg.
- Konstanten leben in `core/units/unit_system.gd`. Kein zweiter
  Konstantenort.
- `RENDER_SCALE_M_PER_UNIT = 1e9` ist ausschließlich eine
  Darstellungsgröße. Sie darf **nirgends** in `src/sim/` oder
  `src/core/` auftauchen. Nur im Testbed-Script und im BubbleManager.

## Orbit-Regime

| Mode              | Status im Foundation | Verwendung                             |
|-------------------|----------------------|----------------------------------------|
| `AUTHORED_ORBIT`  | aktiv                | fest vorgegebene Kreisbahnen            |
| `KEPLER_APPROX`   | aktiv                | analytische Kepler-Lösung ums Parent    |
| `NUMERIC_LOCAL`   | reserviert           | später: numerische Integration, nur     |
|                   |                      | für den fokussierten Cluster            |

`OrbitService` ist die **einzige** Stelle, die `BodyState`-Felder
schreibt. Andere Klassen lesen nur.

## Referenzrahmen und Koordinaten

- **Parent-Frame (autoritativ):** `BodyState.position_parent_frame_m`
  ist die Position eines Körpers relativ zu seinem Parent. Wurzeln
  haben `parent_id == &""` und sind auf `Vector3.ZERO` fixiert.
- **World-Space (abgeleitet):** Wird durch Aufsummieren der
  Parent-Kette in `LocalBubbleManager.compose_world_position_m`
  berechnet. Nicht gecached, nicht persistiert.
- **View-Space (abgeleitet):** Ergebnis von `world_to_view_m`. Im
  Foundation Identity — später Focus-Subtraktion + Skalierung.
- **Render-Units:** View-Space `/ RENDER_SCALE_M_PER_UNIT`. Nur in
  `scenes/`.

Begriffs-Kurzreferenz:

```
Sim-Space (Parent-Frame, SI)  ── Wahrheit, in BodyState
World-Space (komponiert, SI)  ── abgeleitet, via Bubble.compose_*
View-Space (Bubble-lokal, SI) ── abgeleitet, via Bubble.world_to_view_m
Render-Units (Godot-Einheit)  ── Testbed-Projektion, visual only
```

## Wurzel-Konvention

Ein Body mit `parent_id == &""` ist die Simulationswurzel (z. B. der
Stern). Er darf kein `orbit_profile` haben. `OrbitService` setzt
seine Position hart auf `Vector3.ZERO`.

Wenn später multiple voneinander entkoppelte Systeme modelliert
werden, bekommt jedes System eine eigene Wurzel — die Topologie
bleibt ein Wald, keine globale Vollverbindung.

## Determinismus

- Jede Orbit-Evaluation ist eine pure Funktion von `(def, profile,
  parent_mu, t)`. Keine Abhängigkeit von Frame-Rate, Reihenfolge,
  Zufallszahl.
- Reihenfolge: `UniverseRegistry.get_update_order()` liefert einen
  topologischen Sort (Parent vor Kind). `OrbitService` folgt ihm.

## Zeitpräzision — wann wird es kritisch

GDScript-`float` ist 64-bit IEEE-754 (double). `sim_time_s` bleibt
im Mikrosekundenbereich stabil bis in die 100-Millionen-Jahre —
für Orbit-Simulation unkritisch. Wenn jemand später in
Jahrmilliarden hinein will, wechselt `TimeService` auf ein
Epoch-Relative-Modell (`epoch_s: int` + `offset_s: float`).

## Don'ts

- Keine Physik-Engine (RigidBody, Area etc.) für Orbitdynamik.
- Kein Schreiben von `BodyState` außerhalb `OrbitService`.
- Kein Speichern von Welt- oder View-Koordinaten.
- Keine Mathematik in `UniverseRegistry`.
- Keine neuen Autoloads ohne ADR-Eintrag in `ARCHITEKTUR.md`.
