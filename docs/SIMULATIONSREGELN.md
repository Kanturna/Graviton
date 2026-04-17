# Graviton - Simulationsregeln

Normative Regeln fuer alle Sim-Beitraege. Wer etwas baut, das gegen
diese Regeln verstoesst, bricht das Fundament.

## Zeit

- Einzige Quelle: `TimeService` (Autoload).
- Physics-Basis: `FIXED_DT = 1/60 s` ist die Referenz-Frequenz des
  Physics-Loops.
- `TimeService` emittiert `sim_tick(dt)` hoechstens **einmal pro
  physics-Frame**.
- `time_scale` wirkt als **Skalierung des simulierten dt pro Frame**:
  - `time_scale == 1.0` -> `sim_tick(1/60 s)` pro Frame.
  - `time_scale == 3.0` -> `sim_tick(3/60 s)` pro Frame.
  - `time_scale == 0.5` -> `sim_tick(0.5/60 s)` pro Frame.
- `paused == true` unterdrueckt alle Ticks.
- `sim_time_s` waechst streng monoton; nur `TimeService.reset()`
  setzt ihn zurueck (ausschliesslich fuer Tests).

## Einheiten

- Simulation rechnet **ausschliesslich in SI**: Meter, Sekunden, kg.
- Konstanten leben in `core/units/unit_system.gd`. Kein zweiter
  Konstantenort.
- `RENDER_SCALE_M_PER_UNIT = 1e9` ist ausschliesslich eine
  Darstellungsgröße. Sie darf **nirgends** in `src/sim/` oder
  `src/core/` auftauchen. Erlaubte Anwendungsstellen:
  ausschliesslich `scenes/` und `src/tools/rendering/`.

## Orbit-Regime

| Mode             | Status      | Verwendung |
|------------------|-------------|------------|
| `AUTHORED_ORBIT` | aktiv       | fest vorgegebene Kreisbahnen |
| `KEPLER_APPROX`  | aktiv       | analytische Kepler-Loesung ums Parent |
| `NUMERIC_LOCAL`  | **geplant** | Velocity-Verlet-Integration um Parent; nur fuer Bodies im Aktiv-Set mit `KEPLER_APPROX`-Profil |

`OrbitService` ist die **einzige** Stelle, die `BodyState`-Felder
schreibt. Andere Klassen lesen nur.

### NUMERIC_LOCAL - geplante Regime-Wechsel-Semantik

> **Teilweise implementiert.** `BubbleActivationSet` existiert jetzt als
> read-only Aktivierungs-/Relevanzklassifikation. Nicht implementiert
> bleiben `LocalOrbitIntegrator` und
> `request_numeric_local_candidates()`. Dieser Abschnitt beschreibt die
> noch offene Regime-Wechsel-Architektur.

**Eligibility:** Nur Bodies mit `OrbitProfile.mode == KEPLER_APPROX`
koennen zu `NUMERIC_LOCAL` wechseln. `AUTHORED_ORBIT`-Bodies bleiben
immer authored. Root-Bodies bleiben immer bei `ZERO`.

**Eintritt (KEPLER_APPROX -> NUMERIC_LOCAL):** `OrbitService`
initialisiert den Integrator-Zustand aus der Kepler-Loesung zum
Eintritts-Zeitpunkt (Position + Velocity via finite Differenz, eps = 1 s).
`BodyState.current_mode` wechselt zu `NUMERIC_LOCAL`.

**Austritt (NUMERIC_LOCAL -> KEPLER_APPROX):** Beim naechsten Tick wird
die Kepler-Loesung reevaluiert. Ein kleiner Diskontinuitaetssprung ist
moeglich und dokumentiert - `OrbitService` loggt ihn explizit via
`push_warning`. Kein stiller Datendrift.

**Trigger:** Die Szene (Composition Root) ruft
`orbit_service.request_numeric_local_candidates(active_ids)` nach jedem
`BubbleActivationSet.rebuild()` auf. `OrbitService` entscheidet intern
anhand von Eligibility, welche davon tatsaechlich wechseln.

**Integrator:** Velocity Verlet, zwei Beschleunigungsauswertungen pro
Schritt. Nur Parentgravitation
(`LocalOrbitIntegrator.gravity_acceleration_mps2`). Kein N-Body, keine
externen Kraefte in diesem Schritt.

**dt-Limitation:** Wenn `NUMERIC_LOCAL` spaeter eingefuehrt wird,
steigt bei hohem `time_scale` direkt das simulierte `dt` pro Frame.
Dann braucht die numerische Bahn voraussichtlich Substepping oder einen
High-Speed-Guardrail. Fuer den aktuellen Foundation-Stand mit
analytischen Orbit-Profilen ist das kein Problem.

**CONTROLLED-Bodies:** Fuer `BodyType.Kind.CONTROLLED` sind
Regime-Wechsel-Regeln noch nicht definiert - das ist ein bewusster
Design-Gate vor Schritt 5. Die Eligibility-Regel der aktuellen Phase
(nur `KEPLER_APPROX`-Profil -> `NUMERIC_LOCAL`) beschreibt
passiv-orbitierende Bodies. Ob sie direkt auf kontrollierte Bodies
anwendbar ist, haengt vom Bewegungsmodell ab.

## Referenzrahmen und Koordinatenraeume

| Raum | Einheit | Repraesentation | Wahrheit? | Wer darf berechnen |
| --- | --- | --- | --- | --- |
| **Sim-Space** | m | `BodyState.position_parent_frame_m` (relativ zum direkten Parent) | **ja** | nur `OrbitService` schreibt |
| **World-Space** | m | konzeptionell; Summe der Parent-Kette - **niemals als gespeicherter Wert** | nein (abgeleitet) | niemand speichert; `compose_root_local_position_m` nur fuer Tests/Debug |
| **View-Space** | m | fokus-relativ; Step 2 nutzt LCA-Komposition, fremde Roots liefern `Vector3.INF` | nein (abgeleitet) | `LocalBubbleManager.compose_view_position_m` |
| **Render-Units** | Godot-Einheit | `Node2D.position` im 2D-Testbed | nein (Projektion) | `src/tools/rendering/` (teilt durch `RENDER_SCALE_M_PER_UNIT`) |

**Wichtig:** World-Space existiert als Konzept, aber **nicht als
gespeicherter Wert**. Es gibt keine oeffentliche Methode, die einen
`Vector3` in absoluten Weltmetern fuer den Render-Pfad zurueckgibt.
`compose_root_local_position_m` ist fuer Tests und Debug-Prints
vorgesehen - nie im Render-Pfad.

Begriffs-Kurzreferenz:

```text
Sim-Space    (Parent-Frame, SI)  -> Wahrheit, in BodyState
World-Space  (komponiert, SI)    -> abgeleitet, NIEMALS persistiert
View-Space   (fokus-relativ, SI) -> abgeleitet, via compose_view_position_m
Render-Units (Godot-Einheit)     -> Projektion, via RENDER_SCALE_M_PER_UNIT
```

### Praezisionshinweis

**Praezisionsgrenze von `BodyState.position_parent_frame_m`:**
`position_parent_frame_m` ist `Vector3` (float32 pro Komponente in
Godot 4). Bei sehr grossen parent-relativen Distanzen (> ~1e9 m vom
Parent) verliert die gespeicherte Position Sim-Space-Praezision. Im
aktuellen StarterWorld-System ist das unkritisch. Wenn Bodies sehr weit
vom Parent entfernt simuliert werden sollen und gleichzeitig praezise
Sim-Space-Berechnungen noetig sind, muss ein Epoch-Relative-Modell fuer
`position_parent_frame_m` eingefuehrt werden.

**Bekannte Zukunftsaufgabe:** Step 2 nutzt jetzt bereits eine
LCA-basierte fokusrelative Transformation mit Double-Praezision
(GDScript `float` = IEEE-754 double). Die offene Folgeaufgabe ist nicht
mehr die Bubble-Grundlogik, sondern die spaetere Aktivierung/Regime-
Schicht auf dieser Basis.

## Wurzel-Konvention

Ein Body mit `parent_id == &""` ist die Simulationswurzel
(z. B. der Stern). Er darf kein `orbit_profile` haben.
`OrbitService` setzt seine Position hart auf `Vector3.ZERO`.

Wenn spaeter multiple voneinander entkoppelte Systeme modelliert
werden, bekommt jedes System eine eigene Wurzel - die Topologie
bleibt ein Wald, keine globale Vollverbindung.

## Statisches Weltmodell in `BodyDef`

- `rotation_period_s`: sidereale Rotationsperiode in Sekunden, also
  relativ zum Fixsternhimmel. `0.0` bedeutet in der aktuellen Phase:
  nicht gesetzt / noch nicht relevant.
- `axial_tilt_rad`: axiale Neigung relativ zur Orbit-Ebene des Bodies
  um seinen Parent. `0.0` bedeutet: keine Neigung / Aequator liegt in
  der Orbitebene.
- `luminosity_w`: intrinsische Leuchtkraft in Watt. `0.0` bleibt in P3
  bewusst doppeldeutig: entweder nicht-leuchtend oder noch nicht
  modelliert.
- `albedo`: dimensionsloser Reflexionswert im Bereich `0.0 .. 1.0`.

Diese Felder sind in P3 reine Datenbasis. Sie beeinflussen noch keine
Orbit-Berechnung, keine View und noch keine abgeleiteten planetaren
Zustandswerte.

## Determinismus

- Jede Orbit-Evaluation ist eine pure Funktion von
  `(def, profile, parent_mu, t)`. Keine Abhaengigkeit von
  Frame-Rate, Reihenfolge oder Zufallszahl.
- `OrbitMath.solve_kepler()` nutzt fuer signed Winkel die kanonische
  Range `[-PI, PI)`. Der Randfall `PI` kann deshalb bewusst als `-PI`
  repraesentiert werden.
- Reihenfolge: `UniverseRegistry.get_update_order()` liefert einen
  topologischen Sort (Parent vor Kind). `OrbitService` folgt ihm.

## Zeitpraezision - wann wird es kritisch

GDScript-`float` ist 64-bit IEEE-754 (double). `sim_time_s` bleibt im
Mikrosekundenbereich stabil bis in die 100-Millionen-Jahre - fuer
Orbit-Simulation unkritisch. Wenn jemand spaeter in Jahrmilliarden
hinein will, wechselt `TimeService` auf ein Epoch-Relative-Modell
(`epoch_s: int` + `offset_s: float`).

## Bubble-Aktivierung

> **Hinweis:** `BubbleActivationSet` ist jetzt als read-only
> Runtime-Service implementiert. Nicht implementiert bleibt die
> eigentliche `NUMERIC_LOCAL`-Anbindung in `OrbitService`.

| Begriff | Bedeutung | Wer entscheidet |
|---|---|---|
| **Fokus** | View-Ankerpunkt; Zentrum des View-Space | `LocalBubbleManager` |
| **Aktiv-Set** | Bodies, deren fokus-relative View-Distanz <= Aktivierungsradius | `BubbleActivationSet` |
| **lokal aktiv** | im Aktiv-Set; Kandidat fuer `NUMERIC_LOCAL` (wenn `KEPLER_APPROX`-Profil) | `BubbleActivationSet` |
| **approximiert** | ausserhalb Aktiv-Set; bleibt bei `AUTHORED_ORBIT` / `KEPLER_APPROX` | `OrbitService` (Kepler-Pfad) |

**Fokus != Aktiv-Set.** Fokus ist eine View-Entscheidung,
Aktiv-Set ist eine geometrische Relevanzklassifikation. Sie sind
orthogonal.

`BubbleActivationSet` schreibt **niemals** `BodyState`.
`current_mode`-Wechsel (`KEPLER_APPROX -> NUMERIC_LOCAL`) werden spaeter
durch `OrbitService.request_numeric_local_candidates()` ausgeloest.

**Klassifikationsgruende** (geplant):

- `ACTIVE` - fokus-relativ erreichbar, innerhalb Radius
- `INACTIVE_DISTANT` - fokus-relativ erreichbar, ausserhalb Radius
- `INACTIVE_NO_LCA` - nicht fokus-relativ vergleichbar (anderer Baum)

## Don'ts

- Keine Physik-Engine (`RigidBody`, `Area` etc.) fuer Orbitdynamik.
- Kein Schreiben von `BodyState` ausserhalb `OrbitService`.
- Kein Speichern von Welt- oder View-Koordinaten.
- Keine Mathematik in `UniverseRegistry`.
- Keine neuen Autoloads ohne ADR-Eintrag in `ARCHITEKTUR.md`.
- `compose_root_local_position_m` darf **nicht** im Render-Pfad erscheinen -
  nur in Tests und Debug-Prints.
- Keine Rueckkehr zu naiver `Vector3`-Subtraktion ueber AU-Distanzen fuer
  fokus-relative Darstellung (Step-2-LCA-Pfad beibehalten).
- `BubbleActivationSet` darf **kein** `BodyState`-Feld schreiben -
  Aktivierungsklassifikation ist abgeleitet.
- Wenn `NUMERIC_LOCAL` implementiert wird:
  `BodyState.current_mode`-Wechsel darf nur durch `OrbitService`
  erfolgen - nie direkt von aussen.
- `AUTHORED_ORBIT`-Bodies duerfen nicht zu `NUMERIC_LOCAL` wechseln.
- Wenn `LocalOrbitIntegrator` implementiert wird: Er darf **niemals**
  `BodyState` schreiben - er ist pure Mathematik.
