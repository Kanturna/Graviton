# Graviton - Status

Stand: 2026-04-19

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
  `T_eq`, liefert daraus `surface_temperature_k` und meldet jetzt
  zusaetzlich bandbewusste Oberflaechentemperaturen fuer `-60deg`,
  `Eq` und `+60deg`.
- `EnvironmentService` klassifiziert `PLANET`- und `MOON`-Bodies jetzt
  read-only zonenbewusst ueber drei feste Breitenbaender als
  `HABITABLE`, `MARGINAL` oder `HOSTILE` und leitet zusaetzlich erste
  planetare Oekosystem-Typen (`FROZEN`, `TEMPERATE`, `SEASONAL`,
  `HOT`) ab.
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
  jetzt die Habitability-Aussage plus `Climate: ...` als Welttyp.
- Das normale HUD zeigt fuer unterstuetzte Fokus-Bodies jetzt
  zusaetzlich eine `Bands:`-Zeile mit den rohen bandbewussten
  Temperaturen fuer `-60deg`, `Eq` und `+60deg`.
- Das normale HUD zeigt fuer Bodies mit saisonaler Basis jetzt
  zusaetzlich eine kleine `Season: subsolar ...`-Zeile.
- Das HUD zeigt zusaetzlich FPS und die aktuelle Speed-Preset-Stufe.
- Die Sim-Speed kann ueber einen logarithmischen HUD-Slider geregelt
  werden.
- Hohe Speedstufen erzeugen keinen Tick-Sturm pro Frame mehr;
  `time_scale` skaliert das simulierte `dt` pro Physics-Frame.
- Die Fokusansicht bewegt und zoomt weich auf den relevanten Ausschnitt.
- Die Kamera nutzt jetzt ein bewusstes Hybrid-Zoommodell:
  `0.5% .. 100%` interpoliert jetzt nicht nur den Scale von
  Welt-Ueberblick zu `fit current focus`, sondern auch den Kameraanker
  vom aktuellen Root zum Fokus; oberhalb von `100%` wird Zoom wieder als
  lokaler Closeup relativ zum aktuellen Fokus interpretiert.
- `100%` bedeutet im Testbed wieder explizit `fit current focus`;
  `Backspace` springt auf genau diesen Fokus-Fit zurueck.
- Der Zoombereich bleibt bei `0.5%` bis `10000%`; der gute globale
  Rauszoom bleibt erhalten, aber fokussierte Sterne, Planeten und Monde
  koennen wieder deutlich naeher herangezoomt werden als unter P14.1.
- Das HUD macht die Zoom-Semantik jetzt explizit sichtbar:
  `Zoom ... world`, `Zoom 100% fit` und `Zoom ... focus`.
- Unter `Zoom ... world` bleibt der gewaehlte Body damit raeumlich im
  selben Root/System verortet, statt die ganze Welt im Fernblick still
  fokuszentriert ins Bildschirmzentrum zu ziehen.
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
- `starter_world` enthaelt jetzt mit `gamma` bewusst ein kompakteres
  Red-Dwarf-artiges Sternsystem; `gamma_iv` ist darin der erste lokal
  plausible sichtbare habitabele Kandidat statt eines root-skaligen
  Ausreisserorbits.
- Die player-facing HUD-Sprache wurde bewusst geschaerft:
  `Class.MARGINAL` bleibt intern stabil, wird fuer Spieler aber als
  `HARSH` angezeigt; `Eco` heisst jetzt `Climate`, und die
  Temperaturzeile heisst `Bands`.
- `PLANET`- und `MOON`-Bodies leiten jetzt zusaetzlich
  shaderbasierte Klima-Archetypen aus der bestehenden Umweltbeschreibung
  ab: `TEMPERATE_OCEAN`, `FROZEN`, `HOT_SCORCHED` und `BARREN`.
- Der neue Klima-Look bleibt bewusst projektionstreu:
  `FROZEN`, `HOT_SCORCHED` und `BARREN` lesen sich direkt aus den
  momentanen Umweltzustaenden; `TEMPERATE_OCEAN` ist dagegen eine
  explizit stilisierte, semi-realistische Interpretation ohne
  simuliertes Wasserinventar oder echte Wolkenphysik.
- Monde laufen jetzt durch denselben Klima-Resolver wie Planeten,
  bleiben aber ueber gedimmte Theme-Intensitaeten sichtbar als Monde
  lesbar statt wie kleine Vollplaneten zu wirken.
- Sterne lesen sich jetzt als runde, warme Sonnen mit deutlich
  aktiverer, NASA-naher Photosphaere: die P14.3-Rundheits-Invariante
  bleibt erhalten (`alpha` haengt weiter nur an `t`), aber der Shader
  traegt jetzt zusaetzlich eine zweite Solar-Activity-Ebene mit
  helleren aktiven Regionen und dunkleren Filament-/Channel-Zonen.
- Der Stern-Look ist jetzt ueber explizite Star-Uniforms lesbarer
  getuned (`star_core_color`, `activity_strength`, `filament_strength`,
  `rim_hotness`, `edge_activity_strength` etc.), aber weiterhin nur im
  `STAR`-Pfad und ohne neue Simulationswahrheit.
- Die sichtbare Energie sitzt jetzt staerker im shaderseitigen heissen
  Innenrand und in der Oberflaechenaktivitaet; der fruehere Ring-Glow in
  `_draw_star_glow()` wurde bewusst subtiler gemacht, damit Sterne
  weniger nach konzentrischen Glow-Scheiben und mehr nach aktiven Sonnen
  lesen. Alle Sterne teilen weiter bewusst denselben Sun-Look;
  Spektralklassen-/Typ-Unterscheidung ist explizit vertagt.
- P14.5 vertieft den Stern-Look jetzt zusaetzlich ueber eine
  mehrskalige Surface-Hierarchie: ein statisches grobes Macro-Feld,
  eine neue Meso-Breakup-Zwischenskala, die bestehende Activity-Ebene,
  feine Granulation und dunkle Channel-Layer arbeiten jetzt als feste
  Frequenzleiter zusammen statt nur als guter Einzel-Pattern-Shader.
- Die neue Tiefe bleibt bewusst shader-only und entsteht nur ueber
  Farb-/Luminanzmodulation: Macro-Feld wirkt multiplikativ, Meso- und
  Activity-Faculae additiv, Channels schneiden zuletzt dunkler ein;
  `alpha` bleibt weiter unangetastet und der sichtbare Stern-Footprint
  waechst nicht.
- Der Sternshader traegt dafuer jetzt eigene kleine Noise-/FBM-Helfer
  sowie neue Star-Uniforms fuer Macro-/Meso-Staerke und
  Oberflaechenkontrast (`macro_surface_strength`,
  `meso_breakup_strength`, `granulation_contrast`,
  `channel_contrast`, `hotspot_contrast`), die ausschliesslich im
  `STAR`-Pfad von `OrbitBodyVisual` gesetzt werden.

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
- `data/starter_world.gd`
- `src/tests/sim/test_starter_world.gd`
- `src/sim/thermal/thermal_service.gd`
- `src/tests/sim/test_thermal_service.gd`
- `src/sim/atmosphere/atmosphere_service.gd`
- `src/tests/sim/test_atmosphere_service.gd`
- `src/sim/environment/environment_service.gd`
- `src/tests/sim/test_environment_service.gd`
- `docs/SIMULATIONSREGELN.md`
- `docs/STARTER_WORLD.md`
- `docs/NEXT_STEPS.md`
- `docs/DECISIONS.md`
- `src/runtime/local_bubble/local_bubble_manager.gd`
- `src/tests/runtime/test_local_bubble_step2.gd`
- `src/tools/rendering/orbit_view_renderer.gd`
- `src/tools/rendering/orbit_zoom_model.gd`
- `scenes/testbeds/orbit_testbed.gd`
- `scenes/testbeds/orbit_testbed.tscn`
- `src/tools/rendering/orbit_body_visual.gd`
- `src/tools/rendering/planet_visual_theme.gd`
- `src/tools/rendering/planet_visual_profile.gd`
- `src/tools/rendering/shaders/body_sphere.gdshader`
- `src/tools/rendering/shaders/body_star.gdshader`
- `src/tests/rendering/test_planet_visual_profile.gd`
- `src/tests/rendering/test_orbit_zoom_model.gd`
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
- `BodyDef` traegt jetzt erste statische Weltmodell-Felder, und daraus
  werden mittlerweile saisonale Thermalgeometrie, additive
  Greenhouse-Erwaermung, bandbewusste Oberflaechentemperaturen und eine
  erste zonale Umweltklassifikation abgeleitet -
  weiterhin aber noch keine Atmosphaerenchemie, kein Druckmodell und
  keine Wasser-/Volatile-Logik.
- Die zonale `EnvironmentService`-Klassifikation in P12A ist bewusst
  **momentan**: sie mittelt nicht ueber Jahreszyklen und kann bei Tilt
  oder exzentrischen Bahnen sichtbar ueber das Orbitaljahr
  oszillieren.
- `sample_system` ist jetzt der explizite habitable Showcase fuer die
  neue zonale Umweltkette; `starter_world` bleibt weitgehend der
  thermisch extreme Mehrstern-Sandkasten, traegt jetzt aber bewusst
  genau einen sichtbaren habitablen Kandidaten in einem kompakt
  neu skalierten `gamma`-System.
- Die zugrunde liegende zonale Umweltlogik blieb in P13.1 unveraendert;
  nur die HUD-Sprache trennt jetzt klarer zwischen Habitability-Urteil
  (`Environment`), Welttyp (`Climate`) und Rohdaten (`Bands`).
- Der neue Klima-Archetypen-Pass bleibt bewusst shader-first und
  texturfrei; `DESERT` wurde in diesem ersten Slice ausdruecklich nicht
  eingefuehrt, weil dafuer noch keine staerkere Sim-Basis fuer Ariditaet
  oder Wasserverteilung existiert.
- Der Zoom nutzt weiter einen beim Load gecachten Root-Overview-Radius
  als Weltanker fuer den guten Fernblick, gibt oberhalb von `100%` aber
  den global vergleichbaren Welt-Massstab bewusst zugunsten eines
  brauchbaren lokalen Fokus-Closeups wieder auf.
- Renderer-Nahdetail bleibt weiterhin getrennt fokus-relativ, damit die
  P14-Archetypen bei gleicher lokaler Naehe dieselben Detail-Schwellen
  behalten.
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
  Umweltfaktoren jenseits des additiven Greenhouse-Toy-Modells und der
  momentanen Drei-Band-Klassifikation betrachten
- dabei bewusst in Richtung globaler planetarer Oekosystem-Typen mit
  Wasser-/Volatile-Logik und spaeterer Jahresmittel-/Stabilitaetslogik
  weitergehen
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
