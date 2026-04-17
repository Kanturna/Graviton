# Graviton - Decisions

## 2026-04-17 - Sim und View bleiben strikt getrennt

Die Architektur von `Graviton` bleibt wichtiger als ein schneller
visueller Port aus `Atraxis`.

Konsequenz:

- Simulationswahrheit bleibt in `core/`, `sim/` und `runtime/`
- Praesentation darf stark verbessert werden
- View-Code bekommt keine autoritativen Simulationsabkuerzungen

## 2026-04-17 - 2D-Praesentation statt altes 3D-Minimal-Testbed

Das fruehere minimalistische 3D-Testbed wird nicht weiter ausgebaut.
Stattdessen nutzt `Graviton` jetzt eine stilisierte 2D-Orbit-Ansicht,
weil sie den bisherigen `Atraxis`-Look deutlich besser trifft.

Konsequenz:

- 3D-Rendering-Node-Strukturen wurden aus dem aktiven Testbed entfernt
- Orbit-Ringe, Trails, Glow-Body-Visuals und HUD sind Teil der neuen
  Standardansicht
- Die Simulationsmathematik darf weiterhin `Vector3` nutzen

## 2026-04-17 - `Vector3` in der Sim ist kein 3D-Altlastproblem

`Vector3` und 3D-Orbitparameter in `OrbitMath`, `OrbitService`,
`BodyState` oder `OrbitProfile` gelten aktuell als legitime Simulations-
 und Frame-Mathematik, nicht als View-Altlast.

Konsequenz:

- Nicht blind alles auf `Vector2` umstellen
- Erst unterscheiden zwischen Sim-Mathematik und Praesentationscode

## 2026-04-17 - Zoom-Frame berechnet nur Fokus + direkte Kinder

`get_focus_frame` in `OrbitViewRenderer` beschraenkt die Radius-Berechnung
auf den Fokus-Koerper selbst und seine direkten Kinder. Vorfahren und
Enkel-Koerper aus `related_ids` werden fuer den Zoom-Frame uebersprungen.

Konsequenz:

- BH-Fokus: zeigt beide Sterne (direkte Kinder von obsidian) vollstaendig
- Stern-Fokus: zeigt das Planetensystem des Sterns (~5-10 RU Rahmen)
- Planet-Fokus: zeigt den Planeten und seine Monde
- Mond-Fokus: enger Rahmen um den Mond; Planet und Stern sind durch
  den Mindest-Radius von 8 RU sichtbar, setzen aber den Zoom nicht

Hintergrund: In Step-1 (Identity-Bubble, Weltkoordinaten) fuehren
Vorfahren-Koerper im Zoom-Rahmen zu System-weiter Aufloesung, da ihre
Distanz vom Fokus in absoluten Koordinaten gross ist.

## 2026-04-17 - Repo braucht kanonische Kurz-Dokumente

Damit kuenftige Agenten nicht jedes Mal denselben Kontext aus Prompts
rekonstruieren muessen, gibt es drei kurze kanonische Dateien:

- `docs/STATUS.md`
- `docs/NEXT_STEPS.md`
- `docs/DECISIONS.md`

Ergaenzt durch `AGENTS.md` im Repo-Root.
