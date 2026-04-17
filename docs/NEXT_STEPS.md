# Graviton - Next Steps

Stand: 2026-04-17

## Prioritaet 1 - Doku-Drift bereinigen ✓ erledigt

Bereinigt (zwei Passes):

- `docs/HANDOFF.md` — Steps 2–4 klar als geplant/nicht vorhanden markiert;
  Step-2-API-Liste korrigiert; "Logischer nächster Schritt" auf aktuellen Stand gebracht
- `docs/AI_KONTEXT.md` — Node3D→Node2D, `local_orbit_integrator` als geplant,
  Don'ts um Step-2–4-Marker ergänzt, double-präzise Bubble-Beschreibung korrigiert
- `docs/SIMULATIONSREGELN.md` — NUMERIC_LOCAL-Status auf geplant gesetzt,
  Regime-Wechsel-Abschnitt mit Callout versehen, Koordinatenräume-Tabelle bereinigt,
  Kurzreferenz und Methodenname korrigiert
- `docs/GODOT_UMSETZUNGSPLAN.md` — Schritte-Tabelle mit Code-Stand ergänzt
- `docs/STATUS.md` — offene Punkte aktualisiert

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

## Spaeter - Prozedurale Systeme und planetare Zustaende

Wenn das aktuelle Testbed und die Kern-Sim stabil genug sind:

- Generator-Konzept fuer Root-Systeme, Sterne, Planeten und Monde
- Zufallsbereiche fuer Orbitachsen, Exzentrizitaeten und Orientierungen
- erste planetare Zustandsgroessen ableiten:
  - Temperatur / Naehe zum Stern
  - einfache Bewohnbarkeits- oder Unwirtlichkeitsmarker
- Jahreszeiten spaeter nicht nur ueber Bahnellipse, sondern vor allem
  ueber Achsneigung und Strahlungsgeometrie denken
