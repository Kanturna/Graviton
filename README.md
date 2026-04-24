# Graviton

Godot-4-Weltraum-/Systemsimulation mit sauber getrennter Foundation-
Architektur und einer stilisierten 2D-Orbit-Praesentation.

## Lies das zuerst

Die kanonischen Kurz-Dokumente fuer den aktuellen Projektstand sind:

- `AGENTS.md`
- `docs/STATUS.md`
- `docs/NEXT_STEPS.md`
- `docs/DECISIONS.md`
- `docs/ARCHITEKTUR.md`

Wenn aeltere Detaildokumente davon abweichen, gelten die fuenf Dateien
oben als aktueller.

## Aktueller Stand

- Die Foundation-Architektur ist vorhanden und bleibt strikt getrennt:
  `core/` -> `sim/` -> `runtime/` -> `scenes/`
- Auf dieser Basis liegen inzwischen planetare Derived-Services,
  `Life v2`, ein read-only Species-Layer, `Survey UX v2` und produktive
  Large-World-Welten bis `scaleup_galaxy_100`
- Das fruehere minimalistische 3D-Testbed wurde durch eine stilisierte
  2D-Orbit-Ansicht ersetzt
- Die Bootstrap-Szene leitet in das aktuelle Orbit-Testbed; der
  im Repo eingecheckte Szenen-Override startet dort derzeit mit
  `scaleup_galaxy_100`

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
3. Die Bootstrap-Szene leitet in das aktuelle Orbit-Testbed weiter;
   der im Repo eingecheckte Start-Override der Szene liegt aktuell auf
   `scaleup_galaxy_100`.

## Tests

Beispiel ueber die Konsole:

```text
godot_console.exe --headless --path . --script res://src/tests/test_runner.gd --quit
```

Im Repo ist dafuer ausserdem `run_tests.bat` als lokaler Testpfad
vorhanden. Das Script nutzt `GODOT_BIN`, falls gesetzt, sonst
`godot_console.exe` aus `PATH`.

## Historische Detaildokumente

Die folgenden Dateien enthalten weiter nuetzlichen Hintergrund, sind aber
nicht automatisch die aktuellste Kurz-Zusammenfassung:

- `docs/HANDOFF.md`
- `docs/AI_KONTEXT.md`
- `docs/SIMULATIONSREGELN.md`
- `docs/GODOT_UMSETZUNGSPLAN.md`
