# Graviton

Godot-4-Weltraum-/Systemsimulation mit sauber getrennter Foundation-
Architektur und einer stilisierten 2D-Orbit-Praesentation.

## Lies das zuerst

Die kanonischen Kurz-Dokumente fuer den aktuellen Projektstand sind:

- `AGENTS.md`
- `docs/STATUS.md`
- `docs/NEXT_STEPS.md`
- `docs/DECISIONS.md`

Wenn aeltere Detaildokumente davon abweichen, gelten die vier Dateien
oben als aktueller.

## Aktueller Stand

- Foundation-Schritte 1-4 sind vorhanden
- Simulationsschichten bleiben strikt getrennt:
  `core/` -> `sim/` -> `runtime/` -> `scenes/`
- Das fruehere minimalistische 3D-Testbed wurde durch eine stilisierte
  2D-Orbit-Ansicht ersetzt
- Die aktuelle View ist bewusst naeher am Look von `Atraxis`, ohne die
  `Graviton`-Architektur aufzuweichen

## Verzeichnisueberblick

```text
docs/        Architektur, Status, Entscheidungen, naechste Schritte
src/core/    Zeit, Einheiten, IDs, Mathematik
src/sim/     Autoritative Simulationsschicht
src/runtime/ Fokus-relative Ableitung / Bubble
src/tools/   Debug- und Rendering-Hilfen
src/tests/   Test-Runner und Test-Suites
scenes/      Bootstrap und Testbeds
data/        Konkrete Beispielsysteme
```

## Projekt starten

Im Godot-Editor:

1. Projekt in Godot 4.6+ oeffnen.
2. Starten.
3. Die Bootstrap-Szene leitet in das aktuelle Orbit-Testbed weiter.

## Tests

Beispiel ueber die Konsole:

```text
godot_console.exe --headless --path . --script res://src/tests/test_runner.gd --quit
```

## Historische Detaildokumente

Die folgenden Dateien enthalten weiter nuetzlichen Hintergrund, sind aber
nicht automatisch die aktuellste Kurz-Zusammenfassung:

- `docs/ARCHITEKTUR.md`
- `docs/HANDOFF.md`
- `docs/AI_KONTEXT.md`
- `docs/SIMULATIONSREGELN.md`
- `docs/GODOT_UMSETZUNGSPLAN.md`
