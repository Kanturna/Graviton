# Graviton

Godot 4 Weltraum-/Systemsimulation. Dieses Repository enthält den
**Foundation-Slice** (Schritte 1–4): das architektonische Fundament, **kein Gameplay**.

## Was dieser Stand liefert

- Saubere Schichten: `core/` → `sim/` → `runtime/` → `scenes/`
- Autoritative Zeit, Orbitkern (AUTHORED_ORBIT, KEPLER_APPROX), Body-Registry (Schritt 1)
- Fokus-relative Bubble-Transformation, LCA-basiert, double-präzise (Schritt 2)
- BubbleActivationSet: geometrische Relevanzklassifikation (ACTIVE / INACTIVE_DISTANT / INACTIVE_NO_LCA) (Schritt 3)
- NUMERIC_LOCAL-Regime: Velocity-Verlet-Integrator, Regime-Wechsel mit Logging (Schritt 4)
- Debug-Testbed mit Sonne / Planet / Mond als Projektion der Wahrheit
- Vier Test-Suiten (orbit, bubble, activation, numeric_local) über CLI-Runner

## Was dieser Stand NICHT ist

- Kein Spielprototyp, keine Kamerasteuerung, keine lokale Oberfläche
- Keine Transit-/Clusterlogik, kein Save/Load, kein Content
- Keine Kräfte außer Parentgravitation (kein Schub, kein N-Body)

## Architektur in einem Satz

Daten und Simulationszustand sind die Wahrheit. Nodes, Transforms und
Render-Koordinaten sind ausschließlich abgeleitete Darstellung. Siehe
[`docs/ARCHITEKTUR.md`](docs/ARCHITEKTUR.md) und
[`docs/SIMULATIONSREGELN.md`](docs/SIMULATIONSREGELN.md).

## Quickstart

Im Godot-Editor:

1. Projekt öffnen (Godot 4.3+).
2. Projekt starten — die Bootstrap-Szene leitet direkt ins Orbit-Testbed.
3. Im Fenster zeigt das Debug-Overlay Simulationszeit, Bodies, Modi und
   ihre Parent-Frame-Beträge.

Unit-Tests via Kommandozeile:

```
godot --path . --headless --script res://src/tests/test_runner.gd --quit
```

Exit-Code `0` bei grünem Lauf.

## Verzeichnis-Überblick

```
docs/        Architektur, Simulationsregeln, KI-Kontext, Handoff, Umsetzungsplan
src/core/    Zeit, Einheiten, IDs, Math (Schicht ohne Abhängigkeiten)
src/sim/     Bodies, Orbit, Universe (autoritative Sim-Schicht)
src/runtime/ Lokalisierung / Bubble (abgeleitete View-Ebene)
src/tools/   Debug-Hilfen
src/tests/   CLI-Test-Runner + Suites
scenes/      Bootstrap + Testbeds (dünn, nur Projektion)
data/        Factory-Skripte für konkrete Systeme
```

## Nächster Schritt

Siehe [`docs/HANDOFF.md`](docs/HANDOFF.md). Kurz: bewusster Design-Gate
vor erster Mechanik (Schiff/Schub) — vier offene Designfragen müssen
explizit beantwortet werden, bevor Schritt 5 beginnt.
