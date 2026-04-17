# Graviton — KI-Kontext

Lies das als erstes, wenn du als KI-Agent hier hilfst.

## Was Graviton ist

Eine Godot-4-Weltraum-/Systemsimulation mit großen Distanzen,
Orbit-Mechanik, mehreren Referenzrahmen und einer lokal detaillierten
Bubble. Das Projekt ist bewusst als mehrschichtige Simulation aufgesetzt,
**nicht** als Arcade-Spiel und **nicht** als Tutorial-Scaffold.

Aktueller Stand: Foundation-Architektur Schritte 1–4 geplant und dokumentiert.
Die aktive Präsentation ist ein stilisiertes **2D-Orbit-Testbed** (umgebaut nach Schritt 1).

## Wichtige Grundsätze

1. **Daten sind Wahrheit, Nodes sind Darstellung.**
   Jede Körperposition lebt in `BodyState.position_parent_frame_m`.
   `Node2D.position` im 2D-Testbed ist nur Projektion.
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
- **Keine** Render-Skala (`RENDER_SCALE_M_PER_UNIT`) in `src/sim/`
  oder `src/core/`. Die Umrechnung von Metern in Render-Einheiten
  gehört ausschließlich in den Präsentationsbaum (`scenes/` und
  `src/tools/rendering/`).
- **Keine** Simulationslogik in Visual-Nodes oder im Testbed-Script
  über die reine Projektion hinaus.
- **Nicht** versuchte Globalkoordinaten mit einzelnen `float`s über
  viele AUs hinweg. Genau dafür existiert die Bubble-Schicht.
- **`compose_world_position_m` nur in Tests und Debug-Overlay.**
  Die Methode liefert Weltkoordinaten — nützlich für Diagnose,
  aber nie als Grundlage für Render- oder Spiellogik.
- **`BubbleActivationSet` schreibt keine `BodyState`-Felder** *(geplant, nicht vorhanden).*
  Aktivierung ist Klassifikation, nicht Simulationswahrheit.
- **Fokus ≠ Aktiv-Set ≠ NUMERIC_LOCAL.** Drei orthogonale Konzepte *(Steps 2–4, geplant):*
  Fokus (View-Ankerpunkt), Aktiv-Set (geometrische Relevanz), NUMERIC_LOCAL
  (Simulationsregime). Der Pfad Aktiv-Set → NUMERIC_LOCAL geht durch die Szene.
- **`LocalOrbitIntegrator` schreibt kein `BodyState`** *(geplant, nicht vorhanden)* —
  er ist pure Mathematik. Nur `OrbitService` schreibt State.
- **`request_numeric_local_candidates()` ist ein Kandidaten-Angebot**, kein
  Befehl *(geplant, nicht vorhanden).* OrbitService entscheidet über Eligibility.
- **Keine** naive `Vector3`-Addition/Subtraktion über große Distanzen
  (> ~1e9 m). Der aktuelle `LocalBubbleManager` ist ein Identity-Stub (Step 1) —
  LCA-basierte Double-Präzision ist für Schritt 2 geplant.

## Wo was lebt

- **Zeit:** `src/core/time/time_service.gd` (Autoload).
- **Einheiten/Konstanten:** `src/core/units/unit_system.gd`.
- **Orbit-Mathematik:** `src/core/math/orbit_math.gd` (pure,
  abhängigkeitsfrei).
- **Body-Daten:** `src/sim/bodies/`. `BodyDef` = statisch,
  `BodyState` = Laufzeit, nur durch `OrbitService` geschrieben.
- **Orbit-Update:** `src/sim/orbit/orbit_service.gd`.
- **Numerische Integration:** `src/sim/orbit/local_orbit_integrator.gd`
  *(geplant, nicht vorhanden — Schritt 4)*
- **Registry:** `src/sim/universe/universe_registry.gd` (Autoload,
  schlank!).
- **Bubble/View:** `src/runtime/local_bubble/local_bubble_manager.gd`
  (liefert fokus-relative Positionen via `compose_view_position_m`).
- **Debug:** `src/tools/debug/debug_overlay.gd`.
- **Rendering (2D):** `src/tools/rendering/orbit_view_renderer.gd`,
  `orbit_body_visual.gd`, `space_backdrop.gd`.
- **Tests:** `src/tests/` mit eigenem CLI-Runner.
  - `src/tests/orbit/test_orbit.gd` — OrbitMath-Suite
  - `src/tests/sim/test_registry.gd` — UniverseRegistry-Invarianten
  - `src/tests/sim/test_starter_world.gd` — StarterWorld-Invarianten
- **Welt-Daten:** `data/starter_world.gd` (9-Körper-Debug-System,
  diff-freundlich).

## Wenn du etwas änderst

- Bleib innerhalb der Schicht, in der du arbeitest.
- Ergänze nie die Registry um Logik (siehe `ARCHITEKTUR.md`).
- Wenn du dir unsicher bist, ob etwas View-Space oder Sim-Space ist:
  es ist meistens Sim-Space in `BodyState` — View-Space ist immer
  nur eine momentane Ableitung.
- Für neue Tests: `src/tests/<domain>/test_<thema>.gd` mit
  `static func run(ctx)`.
- Render-Skalierung: `RENDER_SCALE_M_PER_UNIT` gehört nur in
  `src/tools/rendering/` und `scenes/` — nie in `src/sim/` oder
  `src/core/`.

## Was bewusst fehlt (und nicht aus Versehen)

- Kameradrehung, Input, Spieler, lokale Oberfläche.
- Kräfte außer Parentgravitation (kein Schub, kein N-Body).
- Save/Load, Transit, Cluster-Wechsel, Content.
- Erste Mechanik (Schiff mit Schub) — bewusst erst nach Schritt 4 (noch nicht implementiert),
  mit explizitem Design-Gate davor.

Wenn ein Nutzer dich fragt, "warum fehlt X", schlage zuerst nach in
`HANDOFF.md`. Wahrscheinlich ist X bewusst ein Folgeschritt.
