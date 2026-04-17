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

## 2026-04-17 - Repo braucht kanonische Kurz-Dokumente

Damit kuenftige Agenten nicht jedes Mal denselben Kontext aus Prompts
rekonstruieren muessen, gibt es drei kurze kanonische Dateien:

- `docs/STATUS.md`
- `docs/NEXT_STEPS.md`
- `docs/DECISIONS.md`

Ergaenzt durch `AGENTS.md` im Repo-Root.
