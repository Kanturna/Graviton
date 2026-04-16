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
  `src/core/` auftauchen. Die einzige erlaubte Anwendungsstelle ist
  `LocalBubbleManager.to_render_units()`.

## Orbit-Regime

| Mode              | Status im Foundation | Verwendung                             |
|-------------------|----------------------|----------------------------------------|
| `AUTHORED_ORBIT`  | aktiv                | fest vorgegebene Kreisbahnen            |
| `KEPLER_APPROX`   | aktiv                | analytische Kepler-Lösung ums Parent    |
| `NUMERIC_LOCAL`   | reserviert           | später: numerische Integration, nur     |
|                   |                      | für den fokussierten Cluster            |

`OrbitService` ist die **einzige** Stelle, die `BodyState`-Felder
schreibt. Andere Klassen lesen nur.

## Referenzrahmen und Koordinatenräume

| Raum           | Einheit       | Repräsentation                                  | Wahrheit? | Wer darf berechnen              |
|----------------|---------------|-------------------------------------------------|-----------|---------------------------------|
| **Sim-Space**  | m             | `BodyState.position_parent_frame_m` (relativ zum direkten Parent) | **ja** | nur `OrbitService` schreibt |
| **World-Space**| m             | konzeptionell; Summe der Parent-Kette — **niemals als gespeicherter Wert** | nein (abgeleitet) | niemand speichert; nur intern in `LocalBubbleManager` als Double-Tripel |
| **View-Space** | m             | fokus-relativ; `target_chain - focus_chain` bis LCA | nein (abgeleitet) | `LocalBubbleManager.compose_view_position_m` |
| **Render-Units** | Godot-Einheit | `Node3D.position` im Testbed               | nein (Projektion) | `LocalBubbleManager.to_render_units` |

**Wichtig:** World-Space existiert als Konzept, aber **nicht als gespeicherter Wert**. Es gibt
keine öffentliche Methode, die einen `Vector3` in absoluten Weltmetern für den Render-Pfad
zurückgibt. `debug_compose_world_m` ist die bewusst klobig benannte Ausnahme — ausschließlich
für Tests und Debug-Prints, erkennbar am `debug_`-Präfix.

Begriffs-Kurzreferenz:

```
Sim-Space    (Parent-Frame, SI)  ── Wahrheit, in BodyState
World-Space  (komponiert, SI)    ── abgeleitet, NIEMALS persistiert
View-Space   (fokus-relativ, SI) ── abgeleitet, via compose_view_position_m
Render-Units (Godot-Einheit)     ── Projektion, via to_render_units
```

### Präzisionsschutz

`LocalBubbleManager` akkumuliert Parent-Frame-Offsets als drei separate
GDScript-`float`-Variablen (IEEE-754 double). Vector3-Komponenten sind
float32 — naive `Vector3`-Subtraktion bei AU-Distanzen erzeugt ~18 km
Fehler. Die LCA-basierte Doppelakkumulation vermeidet das vollständig.

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
- `debug_compose_world_m` darf **niemals** im Render-Pfad oder in
  Produktionslogik erscheinen — nur in Tests und Debug-Prints.
- Keine `Vector3`-Akkumulation über AU-Distanzen; immer über
  `_double_sum_to_lca` im `LocalBubbleManager`.
