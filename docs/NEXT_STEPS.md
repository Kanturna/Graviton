# Graviton - Next Steps

Stand: 2026-04-17

## Prioritaet 0 - Test-Baseline wieder gruen machen

Ziel:
Die Foundation soll vor den naechsten groesseren Architektur-Schritten
wieder eine saubere gruenen Test-Basis haben.

Gemeinte Richtung:

- realen Test-Fail in `src/tests/orbit/test_orbit.gd` bereinigen
- semantisch klar entscheiden, ob `solve_kepler(PI, 0)` als `PI` oder
  `-PI` behandelt wird
- danach Testlauf wieder als verlaessliche Basis nutzen

## Prioritaet 1 - Foundation Phase A: Step 2 Bubble / Frame-Modell

Ziel:
Den aktuellen `LocalBubbleManager` von Fokus-Subtraktion in Richtung des
dokumentierten Step-2-Zielbilds weiterbringen.

Gemeinte Richtung:

- LCA-/praezisionsbewusste Komposition
- multi-root-tauglicher Frame-/Bubble-Layer
- keine erneute Vermischung von View und autoritativer
  Simulationswahrheit

## Prioritaet 2 - Foundation Phase B: WorldLoader / Weltwahl explizit machen

Ziel:
Das Testbed soll nicht mehr direkt eine bestimmte Welt hart laden,
sondern eine explizite Loader-/World-Schicht nutzen.

Gemeinte Richtung:

- Weltladen aus `orbit_testbed.gd` herausziehen
- `StarterWorld` und spaetere Weltvarianten ueber einen klaren Loader
  anbinden
- spaetere Multi-Root- / Generator-Welten vorbereiten

## Prioritaet 3 - Foundation Phase C: World Model verbreitern

Ziel:
Die statische Simulationswahrheit fuer Bodies so erweitern, dass
spaetere planetare Zustaende, Generatoren und echte Mehrsystem-Welten
auf einer sauberen Datenbasis aufsetzen koennen.

Gemeinte Richtung:

- `BodyDef` um fehlende statische Welt-/Physikfelder erweitern
  (z. B. Rotation, Achsneigung, Luminositaet, Albedo)
- bestehende Toy-Welten mit Defaults kompatibel halten
- noch keine abgeleiteten Temperatur-/Habitability-Systeme einbauen

## Danach - Foundation Phase D: Aktivierung und Regime

- `BubbleActivationSet`
- spaeter `NUMERIC_LOCAL` / `LocalOrbitIntegrator`
- Tests fuer Regime-Wechsel, Praezision und Multi-Root-Komposition

## Danach - Planetare Zustandsableitung

Erst wenn Weltmodell, Loader und Bubble-Fundament tragfaehig sind:

- erste abgeleitete planetare Zustandsgroessen
  - Insolation / Temperatur
  - einfache Bewohnbarkeits- oder Unwirtlichkeitsmarker
  - spaeter Strahlung / Atmosphaerenklassen / weitere Umweltfaktoren

## Spaeter - Prozedurale Systeme

- Generator-Konzept fuer Root-Systeme, Sterne, Planeten und Monde
- Zufallsbereiche fuer Orbitachsen, Exzentrizitaeten und Orientierungen
- deterministische Seeds / reproduzierbare Welten

## Bewusst nicht jetzt

- kein weiterer grosser Visual-Pass
- keine neue Gameplay-/Schiffs-/Fraktionsschicht
- keine ueberhastete Generator-Spielerei ohne sauberes Weltmodell
- keine Ausweitung der Autoload-Liste
