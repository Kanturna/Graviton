# Atraxis — KI-Kontext

Lies das als erstes, wenn du als KI-Agent hier hilfst.

## Was Atraxis ist

Eine Godot-4-Weltraum-/Systemsimulation mit großen Distanzen,
Orbit-Mechanik, mehreren Referenzrahmen und einer lokal detaillierten
Bubble. Das Projekt ist bewusst als mehrschichtige Simulation aufgesetzt,
**nicht** als Arcade-Spiel und **nicht** als Tutorial-Scaffold.

Aktueller Stand: **Foundation-Slice**. Fundament, kein Gameplay.

## Wichtige Grundsätze

1. **Daten sind Wahrheit, Nodes sind Darstellung.**
   Jede Körperposition lebt in `BodyState.position_parent_frame_m`.
   `Node3D.position` im Testbed ist nur Projektion.
2. **Schichten respektieren.** `core/` < `sim/` < `runtime/` <
   `scenes/`. Keine Rückwärtsabhängigkeit.
3. **Eine Wahrheit pro Ebene.** Siehe Tabelle in `ARCHITEKTUR.md`.
4. **Debugbarkeit ist Kernfunktion.** Lieber eine klare Zwischen-
   struktur und ein Debug-Print, als eine "clevere" Einzeiler-Optimierung.

## Don'ts — häufige Fallen

- **Kein** `RigidBody3D` / Physics-Engine für Orbits. Orbits sind
  analytisch/numerisch in `OrbitService` + `OrbitMath`.
- **Kein** `Node.position` als Simulationswahrheit. Positionen werden
  aus `BodyState` gelesen.
- **Kein** Zwischenspeichern von Welt- oder View-Koordinaten. Sie
  sind abgeleitet und werden jeden Frame komponiert.
- **Keine** neue Logik in `UniverseRegistry`. Die Registry ist
  bewusst schlank (siehe ADR).
- **Keine** neuen Autoloads ohne ADR-Eintrag in `ARCHITEKTUR.md`.
- **Keine** Render-Skala (`RENDER_SCALE_M_PER_UNIT`) in Sim-Code.
  Nur Testbed und BubbleManager dürfen sie kennen.
- **Keine** Simulationslogik in Visual-Nodes oder im Testbed-Script
  über die reine Projektion hinaus.
- **Nicht**: versuchte Globalkoordinaten mit einzelnen `float`s über
  viele AUs hinweg. Genau dafür existiert die Bubble-Schicht.

## Wo was lebt

- **Zeit:** `src/core/time/time_service.gd` (Autoload).
- **Einheiten/Konstanten:** `src/core/units/unit_system.gd`.
- **Orbit-Mathematik:** `src/core/math/orbit_math.gd` (pure,
  abhängigkeitsfrei).
- **Body-Daten:** `src/sim/bodies/`. `BodyDef` = statisch,
  `BodyState` = Laufzeit, nur durch `OrbitService` geschrieben.
- **Orbit-Update:** `src/sim/orbit/orbit_service.gd`.
- **Registry:** `src/sim/universe/universe_registry.gd` (Autoload,
  schlank!).
- **Bubble/View:** `src/runtime/local_bubble/local_bubble_manager.gd`
  (aktuell Identity, siehe `HANDOFF.md`).
- **Debug:** `src/tools/debug/debug_overlay.gd`.
- **Tests:** `src/tests/` mit eigenem CLI-Runner.
- **Sample-Daten:** `data/sample_system.gd` (Factory-Skript,
  diff-freundlich).

## Wenn du etwas änderst

- Bleib innerhalb der Schicht, in der du arbeitest.
- Ergänze nie die Registry um Logik (siehe `ARCHITEKTUR.md`).
- Wenn du dir unsicher bist, ob etwas View-Space oder Sim-Space ist:
  es ist meistens Sim-Space in `BodyState` — View-Space ist immer
  nur eine momentane Ableitung.
- Für neue Tests: `src/tests/<domain>/test_<thema>.gd` mit
  `static func run(ctx)`.

## Was bewusst fehlt (und nicht aus Versehen)

- Kameradrehung, Input, Spieler, lokale Oberfläche.
- Echte Bubble-Transformation (Identity bleibt bis zum nächsten Schritt).
- `NUMERIC_LOCAL`-Modus.
- Save/Load, Transit, Cluster-Wechsel, Content.

Wenn ein Nutzer dich fragt, "warum fehlt X", schlage zuerst nach in
`HANDOFF.md`. Wahrscheinlich ist X bewusst ein Folgeschritt.
