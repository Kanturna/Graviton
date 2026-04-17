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

- Foundation-Schritt 1 ist implementiert (OrbitService AUTHORED_ORBIT +
  KEPLER_APPROX, Identity-Bubble, StarterWorld). Schritte 2–4 sind als
  Architektur dokumentiert, aber noch nicht im Code vorhanden.
- `TimeService` und `UniverseRegistry` sind die zentralen Autoloads.
- `OrbitService` schreibt autoritativ die `BodyState`-Positionsdaten.
- `LocalBubbleManager` liefert abgeleitete fokus-relative Positionen.
- Die Sim-Mathematik nutzt weiter `Vector3`, auch wenn die aktuelle
  Praesentation 2D ist. Das ist bewusst und kein Fehler.

### Aktuelle Praesentation

- Das fruehere minimalistische 3D-Testbed wurde durch eine stilisierte
  2D-Orbit-Ansicht ersetzt.
- Bodies werden jetzt als 2D-Visuals mit Glow, Orbit-Linien und Trails
  dargestellt.
- Es gibt ein HUD fuer Fokus, Sim-Zeit, Zeitskala und Status.
- Die Fokusansicht bewegt und zoomt weich auf den relevanten Ausschnitt.
- Die Darstellung ist bewusst naeher am Look von `Atraxis`, ohne die
  `Graviton`-Architektur zu opfern.

## Ziel dieser Praesentationsschicht

- `Graviton` soll nicht wie ein technisches Roh-Testbed wirken.
- Der Look darf stilisiert und attraktiv sein.
- Die View soll trotzdem nur Projektion bleiben und keine neue Wahrheit
  ueber Bodies, Positionen oder Zeit einfuehren.

## Wichtige zuletzt geaenderte Dateien

- `src/tools/rendering/orbit_view_renderer.gd` — Fokus-Zoom-Logik bereinigt
- `scenes/testbeds/orbit_testbed.gd` — Trail-Reset bei Fokus-Wechsel
- `scenes/testbeds/orbit_testbed.tscn`
- `src/tools/rendering/orbit_body_visual.gd`
- `src/tools/rendering/space_backdrop.gd`
- `src/tools/debug/debug_overlay.gd`

## Bekannte offene Punkte

- Einige aeltere Doku-Dateien enthalten noch historische Hinweise auf
  das fruehere 3D-Testbed oder auf APIs, die inzwischen nicht mehr die
  gelebte View-Schicht beschreiben.
- `phantom_camera` ist im Projekt vorhanden, wird aber in der aktuellen
  Runtime noch nicht aktiv genutzt.
- Die Praesentation ist deutlich besser als vorher, aber noch nicht auf
  dem finalen Qualitaetsniveau von `Atraxis`.
- Orbit-Linienpunkte fuer KEPLER-Orbits werden gleichmaessig in M
  (mittlere Anomalie) gesampelt — bei geringer Exzentrizitaet (0.01-0.03)
  kaum sichtbar, aber nicht physikalisch gleichmaessig verteilt.

## Was als naechstes wahrscheinlich sinnvoll ist

- Dokumentationsdrift aufraeumen
- zweiten Visual-Pass fuer Rendering/HUD machen
- danach wieder staerker auf Gameplay-/Mechanik-Design fokussieren
