# Graviton - Status

Stand: 2026-04-17

## Kurzfassung

`Graviton` hat aktuell eine saubere Foundation-Architektur fuer eine
Weltraum-/Systemsimulation und eine erste stilisierte 2D-Praesentationsschicht.

Die Simulationsbasis bleibt getrennt von der Darstellung:

- `src/core/` -> Zeit, Einheiten, IDs, Mathematik
- `src/sim/` -> autoritative Simulationsdaten und Orbit-Update
- `src/runtime/` -> fokus-relative Ableitung / Bubble
- `scenes/` und `src/tools/rendering/` -> View und Projektion

## Was aktuell umgesetzt ist

### Simulation / Architektur

- Foundation-Schritt 1 ist implementiert (OrbitService `AUTHORED_ORBIT` +
  `KEPLER_APPROX`, StarterWorld).
- `LocalBubbleManager` nutzt jetzt eine einfache fokus-relative
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
- Das HUD zeigt jetzt zusaetzlich FPS und die aktuelle Speed-Preset-Stufe.
- Die Fokusansicht bewegt und zoomt weich auf den relevanten Ausschnitt.
- Unter `100%` kann die Ansicht jetzt von jedem Fokus aus wieder bis zum
  globalen Systemueberblick herauszoomen.
- `100%` bleibt der lokale Fokus-Fit; der Nahzoom reicht jetzt bis `2400%`.
- Root-Fokus und globaler Ueberblick werden jetzt dynamisch ueber den
  Root-Body bestimmt statt implizit ueber `obsidian`.
- Close-Up-Zoom kann fokussierte Bodies jetzt auch sichtbar vergroessern,
  statt nur deren Umgebungsabstaende auseinanderzuziehen.
- Der sichtbare Nahzoom ist nicht mehr frueh an einer niedrigen internen
  View-/Detail-Grenze gedeckelt.
- Das Testbed unterstuetzt jetzt auch manuelles Camera-Panning (`W/A/S/D`),
  einen groesseren Zoom-Bereich, klickbaren Fokus und staerkere Zeitskalen.
- Die Darstellung ist bewusst naeher am Look von `Atraxis`, ohne die
  `Graviton`-Architektur zu opfern.

## Ziel dieser Praesentationsschicht

- `Graviton` soll nicht wie ein technisches Roh-Testbed wirken.
- Der Look darf stilisiert und attraktiv sein.
- Die View soll trotzdem nur Projektion bleiben und keine neue Wahrheit
  ueber Bodies, Positionen oder Zeit einfuehren.

## Wichtige zuletzt geaenderte Dateien

- `src/runtime/local_bubble/local_bubble_manager.gd` - fokus-relative View-Stabilisierung
- `src/tools/rendering/orbit_view_renderer.gd` - Fokus-Zoom-Logik und Fokus-Gewichtung
- `scenes/testbeds/orbit_testbed.gd` - Trail-Reset, globale Zoom-Out-Semantik, 2400%-Close-up
- `scenes/testbeds/orbit_testbed.tscn`
- `src/tools/rendering/orbit_body_visual.gd`
- `src/tools/rendering/space_backdrop.gd`
- `src/tools/debug/debug_overlay.gd`

## Bekannte offene Punkte

- Schritte 2-4 sind als Architektur dokumentiert, aber noch nicht implementiert
  (`BubbleActivationSet`, `LocalOrbitIntegrator`, `NUMERIC_LOCAL`-Regime).
- `phantom_camera` ist im Projekt vorhanden, wird aber in der aktuellen
  Runtime noch nicht aktiv genutzt.
- Die Praesentation ist deutlich besser als vorher, aber noch nicht auf
  dem finalen Qualitaetsniveau von `Atraxis`.
- Orbit-Linienpunkte fuer KEPLER-Orbits werden gleichmaessig in M
  (mittlere Anomalie) gesampelt - bei geringer Exzentrizitaet (0.01-0.03)
  kaum sichtbar, aber nicht physikalisch gleichmaessig verteilt.

## Was als naechstes wahrscheinlich sinnvoll ist

- Fokus-Zittern und lokale Lesbarkeit im Testbed weiter verifizieren
- danach wieder staerker auf Gameplay-/Mechanik-Design fokussieren
