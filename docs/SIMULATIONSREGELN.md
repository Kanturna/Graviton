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
| `NUMERIC_LOCAL`  | aktiv (minimal) | Velocity-Verlet-Integration um Parent; fuer Bodies im Aktiv-Set mit `KEPLER_APPROX`-Profil, jetzt mit Substepping und `Cap+Warn` |

`OrbitService` ist die **einzige** Stelle, die `BodyState`-Felder
schreibt. Andere Klassen lesen nur.

### NUMERIC_LOCAL - aktuelle Regime-Wechsel-Semantik

> **Minimal implementiert.** `BubbleActivationSet` bleibt read-only
> Aktivierungs-/Relevanzklassifikation. Die eigentliche Regime-Bruecke
> lebt jetzt in `OrbitService.request_numeric_local_candidates()` plus
> `LocalOrbitIntegrator`.

**Eligibility:** Nur Bodies mit `OrbitProfile.mode == KEPLER_APPROX`
koennen zu `NUMERIC_LOCAL` wechseln. `AUTHORED_ORBIT`-Bodies bleiben
immer authored. Root-Bodies bleiben immer bei `ZERO`.

**Eintritt (KEPLER_APPROX -> NUMERIC_LOCAL):** `OrbitService`
initialisiert den Integrator-Zustand aus der Kepler-Loesung zum
Eintritts-Zeitpunkt (Position + Velocity via zentraler finite Differenz,
`VELOCITY_SEED_EPSILON_S = 1.0`). Im Eintritts-Tick wird noch nicht
weiter integriert. `BodyState.current_mode` wechselt zu
`NUMERIC_LOCAL`.

**Austritt (NUMERIC_LOCAL -> KEPLER_APPROX):** `OrbitService` verlaesst
den numerischen Pfad nicht sofort beim ersten fehlenden Wish, sondern
toleriert aktuell genau einen Missing-Request-Tick. Erst nach Ablauf
dieser Grace wird die Kepler-Loesung reevaluiert. Ein kleiner
Diskontinuitaetssprung ist moeglich und dokumentiert -
`OrbitService` loggt ihn explizit via `push_warning` inklusive
Positions- und Velocity-Delta. Kein stiller Datendrift.

**Trigger:** Die Szene (Composition Root) ruft
`orbit_service.request_numeric_local_candidates(active_ids)` nach jedem
`BubbleActivationSet.rebuild()` auf. `OrbitService` entscheidet intern
anhand von Eligibility, welche davon tatsaechlich wechseln.

**Request-Semantik:** Jeder Aufruf ersetzt das bisherige Wunsch-Set
vollstaendig. Ein identischer erneuter Request auf einen bereits
numerischen Body darf keinen Neu-Eintritt und kein Reseeding ausloesen.
Der bekannte `_process()`/`_physics_process()`-Versatz wird dabei nicht
durch die Szene geloest, sondern ueber eine kleine OrbitService-seitige
Grace abgefedert. `BubbleActivationSet` bleibt ohne Hysterese.

**Integrator:** Velocity Verlet, zwei Beschleunigungsauswertungen pro
Schritt. Nur Parentgravitation
(`LocalOrbitIntegrator.gravity_acceleration_mps2`). Fuer grosse `dt`
nutzt `OrbitService` jetzt die reine Substep-Hilfe
`step_velocity_verlet_substepped(...)`. Kein N-Body, keine externen
Kraefte in diesem Schritt.

**Ein-Frame-Versatz:** Das Aktivierungs-Wish entsteht aktuell in
`_process()`, der eigentliche `sim_tick` laeuft in `_physics_process()`.
Dadurch bedient der Wish aus Frame `T` den Tick in Frame `T+1`. Bei
hohen `time_scale` kann das am Aktivierungsrand weiter sichtbar sein,
wird aber jetzt im `OrbitService` ueber genau einen Grace-Tick
abgefedert.

**Overspeed-Policy:** `NUMERIC_LOCAL` nutzt jetzt Substepping mit
konfigurierbarem Ziel-Substep und Max-Budget. Wenn das Budget nicht
reicht, bleibt der Body numerisch und `OrbitService` nutzt `Cap+Warn`
mit Warning-Dedup. Das ist bewusst nur Best-Effort: dauerhaftes
Ueberschreiten des Budgets kann weiter zu langsamer Energie- und
Bahndrift fuehren.

**CONTROLLED-Bodies:** Fuer `BodyType.Kind.CONTROLLED` sind
Regime-Wechsel-Regeln noch nicht definiert - das ist ein bewusster
Design-Gate vor der spaeteren CONTROLLED-/Schub-Schicht. Die
Eligibility-Regel der aktuellen Phase
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
- `north_pole_orbit_frame_azimuth_rad`: Azimut-Richtung der
  Nordpol-Projektion im lokalen Orbit-Frame vor der Rotation in den
  Parent-Frame. Orbit-Frame-Konvention: `+x` = lokale
  Periapsis-/Phase-0-Richtung, `+z` = Orbit-Normale. Fuer Kreisbahnen
  bleibt `+x` ueber die vorhandene Orbit-Orientierung definiert.
- `luminosity_w`: intrinsische Leuchtkraft in Watt. `0.0` bleibt in P3
  bewusst doppeldeutig: entweder nicht-leuchtend oder noch nicht
  modelliert.
- `albedo`: dimensionsloser Reflexionswert im Bereich `0.0 .. 1.0`.

Diese Felder kamen in P3 als reine Datenbasis dazu. Sie beeinflussen
weiterhin keine Orbit-Berechnung und keine View direkt, werden
mittlerweile aber von read-only Derived-Services fuer thermische und
planetare Umweltwerte genutzt.

## Abgeleitete Umweltgroessen - P6/P7/P11 ThermalService

`ThermalService` ist der erste read-only Derived-Service ausserhalb von
Orbit- und Bubble-Kernlogik.

**Bereitstellung:** on-demand, kein Cache, kein `ThermalState`,
kein `rebuild()`.

**Quelle:** der naechste Ancestor mit `luminosity_w > 0.0`.
Die Suche startet beim Parent, nie beim Body selbst.

**`luminosity_w == 0.0`:** bedeutet in P6 pragmatisch "keine Quelle".
Der Body wird uebersprungen und blockiert die Suche nicht.

**Formel:** `F = L / (4 * PI * r^2)` mit `r` aus der Parent-Kette des
aktuellen `BodyState`.

**Absorbierter Fluss (P7):**
`absorbed_flux_wpm2 = (1 - albedo) * F / 4`.

**Gleichgewichtstemperatur (P7):**
`T_eq = pow(absorbed_flux_wpm2 / sigma, 0.25)` mit
`sigma = 5.670374419e-8` (`UnitSystem.STEFAN_BOLTZMANN_WPM2K4`).

**Fast-Rotator-Annahme:** Das `/4`-Redistribution-Modell meint global
gemittelten Fluss und setzt uniforme Oberflaechentemperatur voraus.
`rotation_period_s` wird auch in P11 noch nicht dynamisch genutzt.
Fuer langsame Rotatoren oder tidal lock muss das Modell spaeter
verzweigen.

**Saisonale Geometrie (P11):**

- `source_dir_hat` ist explizit der normierte Vektor `Body -> Quelle`
- die Spinachse im lokalen Orbit-Frame ist:
  - `Vector3(sin(tilt) * cos(azimuth), sin(tilt) * sin(azimuth), cos(tilt))`
- fuer `KEPLER_APPROX` wird dieser Vektor ueber die bestehende
  Orbit-Orientierung in den Parent-Frame rotiert
- fuer `AUTHORED_ORBIT` bleibt der lokale Orbit-Frame in P11 identisch
  zum Parent-`xy`/`z`-Frame
- die subsolare Breite ist:
  - `subsolar_latitude_rad = asin(dot(spin_axis_hat, source_dir_hat))`

**Tagesgemittelte TOA-Insolation (P11):**

- `S = insolation_wpm2`
- `delta = subsolar_latitude_rad`
- `phi = clamp(latitude_rad, -PI/2, PI/2)`

Analytische Faelle:

```text
cosH0 = -tan(phi) * tan(delta)

if -1 < cosH0 < 1:
  H0 = acos(cosH0)
  Q = (S / PI) * (H0 * sin(phi) * sin(delta) + cos(phi) * cos(delta) * sin(H0))
elif cosH0 >= 1:
  Q = 0.0
else:
  Q = S * sin(phi) * sin(delta)
```

Pol-Hinweis:

- fuer `abs(abs(phi) - PI/2) <= 1.0e-6` wird in P11 direkt der
  Polar-Branch benutzt, statt blind `tan(PI/2)` auszuwerten
- fehlende Quelle, inkonsistente Kette oder fehlender Orbit-Frame
  liefern weiter `0.0`

**Nicht-Ziele in P6/P7/P11:**
- keine Atmosphaere
- kein Greenhouse / keine Emissivitaetsvariation
- keine Mehrquellen-Summation
- keine Cross-Root-Suche ausserhalb der Parent-Kette

## Abgeleitete Umweltgroessen - P8/P9 EnvironmentService

`EnvironmentService` ist ein weiterer read-only Derived-Service im
`sim/`-Layer. Er nutzt ab P9 `AtmosphereService`, fuehrt aber bewusst
keine neue State-Schicht ein.

**Basis:** qualitative Umweltklassifikation aus
`surface_temperature_k`.

**Unterstuetzte Koerper in P8/P9:** nur `PLANET` und `MOON`.
`STAR`, `BLACK_HOLE` und sonstige nicht-planetaere Koerper bleiben
im normalen HUD `n/a`.

**Klassenfenster:**
- `HABITABLE`: `273.15 <= T_surface <= 323.15`
- `MARGINAL`: `223.15 <= T_surface < 273.15` oder
  `323.15 < T_surface <= 373.15`
- `HOSTILE`: alles ausserhalb dieser Fenster

**Fehlende Thermalbasis:** Unterstuetzte Bodies ohne gueltige
Waermebasis (`surface_temperature_k <= 0`) werden in P8/P9 als
`HOSTILE` klassifiziert.

**Visual-Creep-Regel:** Qualitative Klassifikationen werden in P8/P9
bewusst nur als Text angezeigt. Jede spaetere farbliche oder
renderer-seitige Repraesentation gehoert in einen expliziten
Visual-Pass - nicht in eine stille Erweiterung des nicht-visuellen
Features.

**Offene Folgefrage ab P11:** `ThermalService` liefert jetzt
latitudenbewusste saisonale Geometrie, waehrend `EnvironmentService`
weiter auf einer skalaren `surface_temperature_k` klassifiziert. Eine
spaetere breiten- oder saisonabhaengige Umweltbewertung braucht deshalb
einen expliziten Folgepass statt einer stillen Erweiterung.

## Abgeleitete Umweltgroessen - P9 AtmosphereService

`AtmosphereService` ist ein weiterer read-only Derived-Service im
`sim/`-Layer. Er legt eine minimale datengetriebene Greenhouse-Schicht
ueber die nackte Strahlungsbasis aus `ThermalService`.

**Neues Datenfeld:** `BodyDef.greenhouse_delta_k`

- additive Oberflaechenerwaermung in Kelvin
- `0.0` = kein modellierter Greenhouse-Beitrag
- nur endliche Werte im Bereich `0.0 .. 2000.0`
- negative Werte sind in P9 bewusst ausgeschlossen

**Modell in P9:**

- `surface_temperature_k = equilibrium_temperature_k + greenhouse_delta_k`

**Wichtig:**

- kein physikalisches Atmosphaerenmodell
- keine Chemie, kein Druck, keine optische Tiefe
- keine Anti-Greenhouse-Kuehlung
- fehlt die thermische Basis (`T_eq <= 0`), bleibt
  `surface_temperature_k = 0.0`
- `greenhouse_delta_k` darf im Report trotzdem sichtbar bleiben

**Caller-Contract:** `ThermalService` und darauf aufbauende
Derived-Services lesen `BodyState.position_parent_frame_m` direkt. Der
Caller muss sicherstellen, dass die States nach dem letzten
`OrbitService`-Tick oder `recompute_all_at_time()` aktuell sind.

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
> Runtime-Service implementiert und wird durch die Szene in
> `OrbitService.request_numeric_local_candidates()` gebridged. Es
> schreibt selbst weiterhin keine `BodyState`-Felder.

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
`current_mode`-Wechsel (`KEPLER_APPROX -> NUMERIC_LOCAL`) werden
ausschliesslich durch `OrbitService.request_numeric_local_candidates()`
plus den naechsten Sim-Tick ausgeloest.

**Klassifikationsgruende** (aktueller Stand):

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
- `BodyState.current_mode`-Wechsel duerfen nur durch `OrbitService`
  erfolgen - nie direkt von aussen.
- `AUTHORED_ORBIT`-Bodies duerfen nicht zu `NUMERIC_LOCAL` wechseln.
- `LocalOrbitIntegrator` darf **niemals** `BodyState` schreiben - er
  ist pure Mathematik.
