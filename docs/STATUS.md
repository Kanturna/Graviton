# Graviton - Status

Stand: 2026-04-18

## Kurzfassung

`Graviton` hat aktuell eine saubere Foundation-Architektur fuer eine
Weltraum-/Systemsimulation und eine erste stilisierte 2D-
Praesentationsschicht.

Die Simulationsbasis bleibt getrennt von der Darstellung:

- `src/core/` -> Zeit, Einheiten, IDs, Mathematik
- `src/sim/` -> autoritative Simulationsdaten und Orbit-Update
- `src/runtime/` -> fokus-relative Ableitung / Bubble
- `scenes/` und `src/tools/rendering/` -> View und Projektion

## Was aktuell umgesetzt ist

### Simulation / Architektur

- Foundation-Schritt 1 ist implementiert (OrbitService `AUTHORED_ORBIT` +
  `KEPLER_APPROX`, StarterWorld).
- `LocalBubbleManager` nutzt jetzt die dokumentierte Step-2-
  Bubble-Komposition via LCA statt der frueheren einfachen
  Fokus-Subtraktion.
- `WorldLoader` laedt benannte Welten jetzt explizit im `sim/`-Layer;
  `orbit_testbed.gd` laedt nicht mehr direkt `StarterWorld`.
- `BodyDef` enthaelt jetzt erste statische Weltmodell-Felder fuer
  Rotation, Achsneigung, deren saisonale Orbit-Frame-Orientierung,
  Leuchtkraft und Albedo.
- `BubbleActivationSet` klassifiziert Bodies jetzt read-only relativ
  zum aktuellen Fokus in `ACTIVE`, `INACTIVE_DISTANT` und
  `INACTIVE_NO_LCA`.
- `OrbitService` bridged das aktuelle Aktiv-Set jetzt explizit in den
  Sim-Layer und schaltet eligible `KEPLER_APPROX`-Bodies minimal auf
  `NUMERIC_LOCAL`.
- `LocalOrbitIntegrator` ist als pure Parent-Only-Mathematik via
  Velocity Verlet implementiert und hat jetzt einen reinen
  Substep-Helper fuer grosse numerische `dt`.
- `OrbitService` haertet den numerischen Pfad jetzt mit
  OrbitService-seitiger Missing-Request-Grace, Substepping sowie
  `Cap+Warn`-Dedup gegen dt-Spitzen und Wish-Rand-Thrashing.
- `ThermalService` liefert jetzt on-demand minimale Insolation,
  global gemittelten absorbierten Fluss und einfache
  Gleichgewichtstemperatur aus `luminosity_w`, `albedo`, Parent-Kette
  und aktuellem `BodyState`.
- `ThermalService` nutzt jetzt zusaetzlich `axial_tilt_rad` und
  `north_pole_orbit_frame_azimuth_rad` fuer saisonale Geometrie und
  liefert on-demand subsolare Breite sowie tagesgemittelte TOA-
  Insolation fuer ausgewaehlte Breiten.
- `AtmosphereService` legt jetzt on-demand ein minimales,
  datengetriebenes Greenhouse-Modell (`greenhouse_delta_k`) auf
  `T_eq` und liefert daraus `surface_temperature_k`.
- `EnvironmentService` klassifiziert `PLANET`- und `MOON`-Bodies jetzt
  read-only als `HABITABLE`, `MARGINAL` oder `HOSTILE` auf Basis von
  `surface_temperature_k` und macht das im normalen HUD fuer den Fokus
  sichtbar.
- Bodies aus einem anderen Root als der aktuelle Fokus liefern bewusst
  `Vector3.INF` und werden im Renderer nicht lokalisiert.
- `TimeService` und `UniverseRegistry` sind die zentralen Autoloads.
- `OrbitService` schreibt autoritativ die `BodyState`-Positionsdaten.
- Die Sim-Mathematik nutzt weiter `Vector3`, auch wenn die aktuelle
  Praesentation 2D ist. Das ist bewusst und kein Fehler.

### Aktuelle Praesentation

- Das fruehere minimalistische 3D-Testbed wurde durch eine stilisierte
  2D-Orbit-Ansicht ersetzt.
- Bodies werden jetzt als 2D-Visuals mit Glow, Orbit-Linien und Trails
  dargestellt.
- Es gibt ein HUD fuer Fokus, Sim-Zeit, Zeitskala und Status.
- Die normale Environment-Zeile zeigt fuer unterstuetzte Fokus-Bodies
  jetzt Klasse, `Tsurf` und modellierten Greenhouse-Beitrag.
- Das normale HUD zeigt fuer Bodies mit saisonaler Basis jetzt
  zusaetzlich eine kleine `Season: subsolar ...`-Zeile.
- Das HUD zeigt zusaetzlich FPS und die aktuelle Speed-Preset-Stufe.
- Die Sim-Speed kann ueber einen logarithmischen HUD-Slider geregelt
  werden.
- Hohe Speedstufen erzeugen keinen Tick-Sturm pro Frame mehr;
  `time_scale` skaliert das simulierte `dt` pro Physics-Frame.
- Die Fokusansicht bewegt und zoomt weich auf den relevanten Ausschnitt.
- Unter `100%` kann die Ansicht von jedem Fokus aus bis zum globalen
  Systemueberblick herauszoomen.
- `100%` bleibt der lokale Fokus-Fit; der Nahzoom reicht bis `2400%`.
- Root-Fokus und globaler Ueberblick werden dynamisch ueber den
  Root-Body bestimmt statt implizit ueber `obsidian`.
- Das Testbed unterstuetzt Camera-Panning, klickbaren Fokus und
  staerkere Zeitskalen.
- Das Testbed kann jetzt explizit zwischen `starter_world` und
  `sample_system` als Referenzwelten umgeschaltet werden.
- `starter_world` ist jetzt als groessere asymmetrische BH-
  Referenzwelt ausgebaut: vier Sterne unter `obsidian`, ungleich grosse
  Planetensysteme und bewusst keine neue Spiegel-Symmetrie.
- Die Toy-Orbitwerte der `starter_world` bleiben so getunt, dass Monde
  sichtbar schneller als Planeten und Planeten sichtbar schneller als
  ihre Sterne um `obsidian` kreisen; die BH-Sterne bleiben dabei in
  diesem Slice bewusst kreisfoermige `AUTHORED_ORBIT`.

## Ziel dieser Praesentationsschicht

- `Graviton` soll nicht wie ein technisches Roh-Testbed wirken.
- Der Look darf stilisiert und attraktiv sein.
- Die View soll trotzdem nur Projektion bleiben und keine neue Wahrheit
  ueber Bodies, Positionen oder Zeit einfuehren.

## Wichtige zuletzt geaenderte Dateien

- `src/core/math/orbit_math.gd`
- `src/tests/orbit/test_orbit.gd`
- `src/sim/world/world_loader.gd`
- `src/tests/sim/test_world_loader.gd`
- `src/sim/bodies/body_def.gd`
- `data/sample_system.gd`
- `src/tests/sim/test_body_def_world_model.gd`
- `src/runtime/local_bubble/bubble_activation_set.gd`
- `src/tests/runtime/test_bubble_activation_set.gd`
- `src/sim/orbit/local_orbit_integrator.gd`
- `src/tests/orbit/test_local_orbit_integrator.gd`
- `src/tests/sim/test_orbit_service_numeric_local.gd`
- `src/sim/thermal/thermal_service.gd`
- `src/tests/sim/test_thermal_service.gd`
- `src/sim/atmosphere/atmosphere_service.gd`
- `src/tests/sim/test_atmosphere_service.gd`
- `src/sim/environment/environment_service.gd`
- `src/tests/sim/test_environment_service.gd`
- `docs/SIMULATIONSREGELN.md`
- `src/runtime/local_bubble/local_bubble_manager.gd`
- `src/tests/runtime/test_local_bubble_step2.gd`
- `src/tools/rendering/orbit_view_renderer.gd`
- `scenes/testbeds/orbit_testbed.gd`
- `scenes/testbeds/orbit_testbed.tscn`
- `src/tools/rendering/orbit_body_visual.gd`
- `src/tools/rendering/space_backdrop.gd`
- `src/tools/debug/debug_overlay.gd`

## Bekannte offene Punkte

- Schritte 1-4 sind jetzt minimal implementiert; der erste
  `NUMERIC_LOCAL`-Guardrail ist jetzt ebenfalls eingezogen. Offene
  Folgearbeit im Regime-Fundament ist damit eher spaeteres Tuning
  jenseits des aktuellen `Cap+Warn`-Best-Effort-Pfads als ein
  fehlender Guardrail-Block.
- `LocalBubbleManager` liefert jetzt die dokumentierte LCA-/
  praezisionsbewusste Bubble-Komposition fuer same-root-Faelle.
- `BubbleActivationSet` ist jetzt implementiert, wird im Testbed pro
  Frame rebuilt und wird jetzt read-only als Wish-Quelle fuer
  `OrbitService.request_numeric_local_candidates(...)` genutzt.
- Das Projekt ist topologisch offen fuer mehrere Root-Systeme und hat
  jetzt eine explizite Loader-, Aktivierungs- und erste
  Stabilitaetsschicht fuer hohe `time_scale` im numerischen Pfad.
- `BodyDef` traegt jetzt erste statische Weltmodell-Felder, aber
  daraus werden bislang nur minimale Thermalwerte
  (Insolation / absorbierter Fluss / `T_eq`) sowie ein minimales
  additives Greenhouse-Modell und eine erste qualitative
  Umweltklassifikation abgeleitet -
  noch keine Atmosphaerenchemie oder Druckmodelle.
- `ThermalService` ist jetzt latitudenbewusst, waehrend
  `EnvironmentService` weiter auf einer skalaren `surface_temperature_k`
  klassifiziert; eine spaetere breiten- oder saisonabhaengige
  Umweltbewertung bleibt damit eine bewusste Folgeaufgabe.
- Der Wish-Pfad fuer `NUMERIC_LOCAL` bleibt bewusst um einen Frame
  gegenueber `sim_tick` versetzt (`_process()` vs. `_physics_process()`),
  wird jetzt aber im `OrbitService` ueber einen Grace-Tick abgefedert.
- `Cap+Warn` ist bewusst nur eine Best-Effort-Policy: bei dauerhaft
  gecappten Bodies kann weiter langsame Energie- und Bahndrift
  auftreten, auch wenn der Body im numerischen Regime bleibt.
- Topologie-Helfer liegen aktuell noch an mehreren Stellen
  (`OrbitViewRenderer`, `LocalBubbleManager`, Debug/Test-Helfer) und
  koennen spaeter sinnvoll zentralisiert werden.
- `phantom_camera` ist im Projekt vorhanden, wird aber in der aktuellen
  Runtime noch nicht aktiv genutzt.
- Die Praesentation ist fuer das aktuelle Testbed gut genug; der
  groesste Engpass liegt momentan nicht mehr im Look, sondern im
  Welt-/Frame- und Regime-Fundament.
- Orbit-Linienpunkte fuer KEPLER-Orbits werden gleichmaessig in M
  (mittlere Anomalie) gesampelt - bei den aktuellen Toy-Ellipsen meist
  okay, aber nicht physikalisch gleichmaessig verteilt.

## Was als naechstes wahrscheinlich sinnvoll ist

- als naechsten grossen Simulationsschritt weitere planetare
  Umweltfaktoren jenseits des additiven Greenhouse-Toy-Modells
  betrachten
- dabei bewusst in Richtung globaler planetarer Oekosystem-Typen
  weitergehen statt bei nur skalaren Temperatur- und
  Habitability-Werten stehenzubleiben
- parallel die Referenzwelt unter `obsidian` spaeter in Richtung eines
  noch reicheren Mehrstern-Roots weiterdenken: elliptischere
  BH-Sternbahnen, noch mehr Sterne und ggf. weitere Referenzwelten
- parallel kleine nicht-kanonische Doku-Drift bereinigen, wenn sie
  wieder sichtbar wird
- spaeter numerische Guardrail-Parameter oder strengere Overspeed-
  Policies nachziehen, falls hohe `time_scale`-Faelle das praktisch
  noetig machen
- spaeter Topologie-Helfer konsolidieren, wenn Bubble-/Activation-
  Schicht und Mehrwurzel-Pfade stabil sind
