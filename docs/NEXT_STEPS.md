# Graviton - Next Steps

Stand: 2026-04-17

## Prioritaet 1 - Doku-Drift bereinigen

Ziel:
Die historischen Hinweise auf `Node3D`, altes Testbed-Vokabular und
fruehere Render-APIs sollen in den wichtigsten Doku-Dateien bereinigt
werden.

Betroffene Kandidaten:

- `docs/HANDOFF.md`
- `docs/AI_KONTEXT.md`
- `docs/SIMULATIONSREGELN.md`
- `docs/GODOT_UMSETZUNGSPLAN.md`

## Prioritaet 1b - View-Cleanup (teils erledigt)

Erledigt:

- `get_focus_frame` Radius-Inflation bei Nicht-BH-Fokus behoben
- Trail-Reset bei Fokus-Wechsel implementiert

Noch offen (niedrige Prioritaet):

- `_build_orbit_points` AUTHORED-Pfad nutzt API unidomatisch
  (phase=t*TAU, period=1.0 statt Zeit-Sweep) — funktional korrekt
- KEPLER-Orbit-Punkte gleichmaessig in M gesampelt statt physikalisch
  aequidistant — bei Exzentrizitaet 0.01-0.03 visuell kaum relevant

## Prioritaet 2 - Zweiter Visual-Pass

Ziel:
Die neue 2D-Praesentation soll noch naeher an den Qualitaetseindruck von
`Atraxis` kommen.

Wahrscheinliche Themen:

- feinere Trails
- bessere Orbit-Linien
- staerkeres Tiefengefuehl / Layering
- hochwertigeres HUD
- visuelle Balance zwischen Lesbarkeit und Atmosphaere

## Prioritaet 3 - Addon-Nutzung bewusst entscheiden

Ziel:
Klaeren, ob `phantom_camera` wirklich gebraucht wird oder aktuell nur
mitgeschleppt wird.

## Spaeter - Mechanik-Design fortsetzen

Erst nach dem View- und Doku-Cleanup:

- Design-Gate fuer steuerbare Bodies / Schub / erste Mechanik
- keine ueberhastete Gameplay-Implementierung vor sauberer Festlegung
