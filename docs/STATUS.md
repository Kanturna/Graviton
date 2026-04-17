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
- `LocalBubbleManager` nutzt aktuell noch eine einfache fokus-relative
  View-Transformation, damit fokussierte Bodies visuell stabil liegen.
- Die volle Bubble-/LCA-Logik aus den spaeteren Architektur-Schritten ist
  noch nicht implementiert.
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

- `src/runtime/local_bubble/local_bubble_manager.gd`
- `src/tools/rendering/orbit_view_renderer.gd`
- `scenes/testbeds/orbit_testbed.gd`
- `scenes/testbeds/orbit_testbed.tscn`
- `src/tools/rendering/orbit_body_visual.gd`
- `src/tools/rendering/space_backdrop.gd`
- `src/tools/debug/debug_overlay.gd`

## Bekannte offene Punkte

- Der Headless-Testlauf ist aktuell nicht komplett gruen:
  `src/tests/orbit/test_orbit.gd` scheitert zurzeit an der Frage,
  ob `solve_kepler(PI, 0)` als `PI` oder `-PI` zurueckkommt.
- Schritte 2-4 sind als Architektur dokumentiert, aber noch nicht
  implementiert (`BubbleActivationSet`, `LocalOrbitIntegrator`,
  `NUMERIC_LOCAL`-Regime).
- `LocalBubbleManager` ist weiterhin nur die einfache fokus-relative
  Step-1-Loesung und noch nicht die dokumentierte LCA-/
  praezisionsbewusstere Bubble-Komposition.
- Das Projekt ist topologisch offen fuer mehrere Root-Systeme, hat aber
  noch keine echte Welt-/Loader-Schicht und noch kein sauberes
  Multi-Root-Frame-Modell fuer mehrere schwarze Loecher.
- `BodyDef` ist fuer aktuelle Orbit-/Toy-Welten ausreichend, aber noch
  zu schmal fuer spaetere planetare Zustaende, Generatoren und
  Weltparameter wie Rotation, Achsneigung oder Luminositaet.
- `phantom_camera` ist im Projekt vorhanden, wird aber in der aktuellen
  Runtime noch nicht aktiv genutzt.
- Die Praesentation ist fuer das aktuelle Testbed gut genug; der
  groesste Engpass liegt momentan nicht mehr im Look, sondern im
  Welt-/Frame- und Regime-Fundament.
- Orbit-Linienpunkte fuer KEPLER-Orbits werden gleichmaessig in M
  (mittlere Anomalie) gesampelt - bei den aktuellen Toy-Ellipsen meist
  okay, aber nicht physikalisch gleichmaessig verteilt.

## Was als naechstes wahrscheinlich sinnvoll ist

- erst die Test-Baseline wieder komplett gruen bekommen
- den dokumentierten Step-2-Pfad fuer Bubble-/Frame-Komposition
  priorisieren, bevor neue grosse Gameplay- oder Visual-Bloecke kommen
- Weltladen ueber eine explizite Loader-/World-Schicht statt direkt im
  Testbed organisieren
- danach `BodyDef` / Weltmodell fuer spaetere planetare Zustaende und
  Generatoren verbreitern
