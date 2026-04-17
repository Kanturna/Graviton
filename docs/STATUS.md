# Graviton - Status

Stand: 2026-04-17

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
- Die Toy-Orbitwerte der `StarterWorld` sind jetzt so getunt, dass Monde
  sichtbar schneller als Planeten und Planeten sichtbar schneller als
  ihre Sterne um `obsidian` kreisen; die Planetenbahnen sind zudem
  sichtbar elliptischer und pro Planet unterschiedlich ausgerichtet.

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

- Schritt 2 ist jetzt implementiert; Schritte 3-4 bleiben als
  Architektur dokumentiert, aber noch nicht im Code vorhanden
  (`BubbleActivationSet`, `LocalOrbitIntegrator`, `NUMERIC_LOCAL`-
  Regime).
- `LocalBubbleManager` liefert jetzt die dokumentierte LCA-/
  praezisionsbewusste Bubble-Komposition fuer same-root-Faelle.
- Das Projekt ist topologisch offen fuer mehrere Root-Systeme und hat
  jetzt eine explizite Loader-Schicht, aber noch kein Aktivierungs-
  system fuer mehrere schwarze Loecher.
- `BodyDef` ist fuer aktuelle Orbit-/Toy-Welten ausreichend, aber noch
  zu schmal fuer spaetere planetare Zustaende, Generatoren und
  Weltparameter wie Rotation, Achsneigung oder Luminositaet.
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

- `BodyDef` / Weltmodell fuer spaetere planetare Zustaende und
  Generatoren verbreitern
- anschliessend Aktivierungs- und Regime-Schritte (`BubbleActivationSet`,
  `NUMERIC_LOCAL`) auf der jetzt sauberen Bubble-Basis angehen
- spaeter Topologie-Helfer konsolidieren, wenn Bubble-/Activation-
  Schicht und Mehrwurzel-Pfade stabil sind
