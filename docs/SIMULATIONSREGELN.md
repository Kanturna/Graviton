# Graviton — Simulationsregeln

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
  `src/core/` auftauchen. Erlaubte Anwendungsstellen: ausschließlich
  `scenes/` und `src/tools/rendering/`.

## Orbit-Regime

| Mode              | Status     | Verwendung                                                   |
|-------------------|------------|--------------------------------------------------------------|
| `AUTHORED_ORBIT`  | aktiv      | fest vorgegebene Kreisbahnen                                 |
| `KEPLER_APPROX`   | aktiv      | analytische Kepler-Lösung ums Parent                         |
| `NUMERIC_LOCAL`   | aktiv      | Velocity-Verlet-Integration um Parent; nur für Bodies im Aktiv-Set mit KEPLER_APPROX-Profil |

`OrbitService` ist die **einzige** Stelle, die `BodyState`-Felder
schreibt. Andere Klassen lesen nur.

### NUMERIC_LOCAL — Regime-Wechsel-Semantik

**Eligibility:** Nur Bodies mit `OrbitProfile.mode == KEPLER_APPROX` können zu
`NUMERIC_LOCAL` wechseln. AUTHORED_ORBIT-Bodies bleiben immer authored. Root-Bodies
bleiben immer bei ZERO.

**Eintritt (KEPLER_APPROX → NUMERIC_LOCAL):** `OrbitService` initialisiert den
Integrator-Zustand aus der Kepler-Lösung zum Eintritts-Zeitpunkt (Position +
Velocity via finite Differenz, ε = 1 s). `BodyState.current_mode` wechselt zu
`NUMERIC_LOCAL`.

**Austritt (NUMERIC_LOCAL → KEPLER_APPROX):** Beim nächsten Tick wird die
Kepler-Lösung reevaluiert. Ein kleiner Diskontinuitätssprung ist möglich und
dokumentiert — `OrbitService` loggt ihn explizit via `push_warning`. Kein stiller
Datendrift.

**Trigger:** Die Szene (Composition Root) ruft
`orbit_service.request_numeric_local_candidates(active_ids)` nach jedem
`BubbleActivationSet.rebuild()` auf. OrbitService entscheidet intern anhand von
Eligibility, welche davon tatsächlich wechseln.

**Integrator:** Velocity Verlet, zwei Beschleunigungsauswertungen pro Schritt.
Nur Parentgravitation (`LocalOrbitIntegrator.gravity_acceleration_mps2`).
Kein N-Body, keine externen Kräfte in diesem Schritt.

**dt-Limitation:** NUMERIC_LOCAL ist stabil bei time_scale ≤ ~1 000 (dt ≈ 1/60 s).
Bei sehr hoher Zeitbeschleunigung divergiert die numerische Bahn von der
Kepler-Bahn — erwartetes Verhalten, kein Bug. Bei dt > 300 s (sim) loggt
OrbitService eine Warnung.

**CONTROLLED-Bodies:** Für `BodyType.Kind.CONTROLLED` sind Regime-Wechsel-Regeln
noch nicht definiert — das ist ein bewusster Design-Gate vor Schritt 5. Die
Eligibility-Regel der aktuellen Phase (nur KEPLER_APPROX-Profil → NUMERIC_LOCAL)
beschreibt passiv-orbitierende Bodies. Ob sie direkt auf kontrollierte Bodies
anwendbar ist, hängt vom Bewegungsmodell ab.

## Referenzrahmen und Koordinatenräume

| Raum           | Einheit       | Repräsentation                                  | Wahrheit? | Wer darf berechnen              |
|----------------|---------------|-------------------------------------------------|-----------|---------------------------------|
| **Sim-Space**  | m             | `BodyState.position_parent_frame_m` (relativ zum direkten Parent) | **ja** | nur `OrbitService` schreibt |
| **World-Space**| m             | konzeptionell; Summe der Parent-Kette — **niemals als gespeicherter Wert** | nein (abgeleitet) | niemand speichert; nur intern in `LocalBubbleManager` als Double-Tripel |
| **View-Space** | m             | fokus-relativ; `target_chain - focus_chain` bis LCA | nein (abgeleitet) | `LocalBubbleManager.compose_view_position_m` |
| **Render-Units** | Godot-Einheit | `Node2D.position` im 2D-Testbed            | nein (Projektion) | `src/tools/rendering/` (teilt durch `RENDER_SCALE_M_PER_UNIT`) |

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

### Präzisionshinweis

**Präzisionsgrenze von `BodyState.position_parent_frame_m`:**
`position_parent_frame_m` ist `Vector3` (float32 pro Komponente in Godot 4).
Bei sehr großen parent-relativen Distanzen (> ~1e9 m vom Parent) verliert die
gespeicherte Position Sim-Space-Präzision. Im aktuellen StarterWorld-System
ist das unkritisch. Wenn Bodies sehr weit vom Parent entfernt simuliert werden
sollen und gleichzeitig präzise Sim-Space-Berechnungen nötig sind, muss ein
Epoch-Relative-Modell für `position_parent_frame_m` eingeführt werden.

**Bekannte Zukunftsaufgabe:** Eine echte LCA-basierte fokus-relative
Transformation mit Double-Präzision (GDScript `float` = IEEE-754 double) wäre
für AU-skalierte Systeme nötig, um ~18 km Subtraktionsfehler bei naiver
`Vector3`-Akkumulation zu vermeiden. Der aktuelle `LocalBubbleManager` ist
ein Identity-Stub (Step 1).

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

## Bubble-Aktivierung (geplante Architektur)

> **Hinweis:** Der `BubbleActivationSet`-Layer und NUMERIC_LOCAL-Regime sind als
> Architektur beschrieben, aber noch nicht implementiert. Aktuell ist
> `LocalBubbleManager` ein Identity-Stub; NUMERIC_LOCAL erzeugt nur eine Warnung
> in `OrbitService`.

| Begriff | Bedeutung | Wer entscheidet |
|---|---|---|
| **Fokus** | View-Ankerpunkt; Zentrum des View-Space | `LocalBubbleManager` |
| **Aktiv-Set** | Bodies, deren fokus-relative View-Distanz ≤ Aktivierungsradius | `BubbleActivationSet` (geplant) |
| **lokal aktiv** | im Aktiv-Set; Kandidat für NUMERIC_LOCAL (wenn KEPLER_APPROX-Profil) | `BubbleActivationSet` (geplant) |
| **approximiert** | außerhalb Aktiv-Set; bleibt bei AUTHORED_ORBIT / KEPLER_APPROX | `OrbitService` (Kepler-Pfad) |

**Fokus ≠ Aktiv-Set.** Fokus ist eine View-Entscheidung, Aktiv-Set ist eine
geometrische Relevanzklassifikation. Sie sind orthogonal.

Wenn `BubbleActivationSet` implementiert wird, gilt: Es schreibt **niemals**
`BodyState`. `current_mode`-Wechsel (KEPLER_APPROX → NUMERIC_LOCAL) werden durch
`OrbitService.request_numeric_local_candidates()` ausgelöst.

**Klassifikationsgründe** (geplant):

- `ACTIVE` — fokus-relativ erreichbar, innerhalb Radius
- `INACTIVE_DISTANT` — fokus-relativ erreichbar, außerhalb Radius
- `INACTIVE_NO_LCA` — nicht fokus-relativ vergleichbar (anderer Baum)

## Don'ts

- Keine Physik-Engine (RigidBody, Area etc.) für Orbitdynamik.
- Kein Schreiben von `BodyState` außerhalb `OrbitService`.
- Kein Speichern von Welt- oder View-Koordinaten.
- Keine Mathematik in `UniverseRegistry`.
- Keine neuen Autoloads ohne ADR-Eintrag in `ARCHITEKTUR.md`.
- `compose_world_position_m` darf **nicht** im Render-Pfad erscheinen —
  nur in Tests und Debug-Prints.
- Keine naive `Vector3`-Subtraktion über AU-Distanzen für
  fokus-relative Darstellung (zukünftige LCA-Implementierung beachten).
- Wenn `BubbleActivationSet` implementiert wird: Es darf **kein**
  `BodyState`-Feld schreiben — Aktivierungsklassifikation ist abgeleitet.
- Wenn NUMERIC_LOCAL implementiert wird: `BodyState.current_mode`-Wechsel
  darf nur durch `OrbitService` erfolgen — nie direkt von außen.
- AUTHORED_ORBIT-Bodies dürfen nicht zu NUMERIC_LOCAL wechseln.
- Wenn `LocalOrbitIntegrator` implementiert wird: Er darf **niemals**
  `BodyState` schreiben — er ist pure Mathematik.
