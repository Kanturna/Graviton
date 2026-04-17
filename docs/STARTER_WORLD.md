# Graviton — Starter World

Debug-fokussiertes 9-Körper-System für das Foundation-Testbed.
Alle Werte sind bewusste Toy-Werte — nicht astrophysikalisch korrekt.

## Systemübersicht

| ID | Kind | Orbit-Modus | Parent | Schlüsselwerte | Begründung |
|---|---|---|---|---|---|
| obsidian | BLACK_HOLE | root | — | mass=2e33 kg | Toy-Masse ~1000 M☉; als Wurzel immer bei ZERO |
| alpha | STAR | AUTHORED_ORBIT | obsidian | r=1.5e11 m, T=5e4 s | AUTHORED: r/T frei wählbar; 50 s/Umlauf @ 1000× |
| beta | STAR | AUTHORED_ORBIT | obsidian | r=2.5e11 m, T=9e4 s, phase=π | phase=π → Sterne starten gegenüberliegend; sofort erkennbar |
| alpha_i | PLANET | KEPLER_APPROX | alpha | a=2.5e9 m, e=0.02 | 2.5 RU von alpha; T≈68 ks → 68 s @ 1000× |
| alpha_ii | PLANET | KEPLER_APPROX | alpha | a=5e9 m, e=0.01, M0=1.05 | 5 RU von alpha; M0≠0 für sichtbar andere Startphase |
| alpha_i_m | MOON | AUTHORED_ORBIT | alpha_i | r=1.5e9 m, T=1.5e4 s | 1.5 RU vom Planeten; 15 s/Umlauf @ 1000× |
| beta_i | PLANET | KEPLER_APPROX | beta | a=3e9 m, e=0.03, M0=0.5 | 3 RU von beta |
| beta_ii | PLANET | KEPLER_APPROX | beta | a=6e9 m, e=0.015, M0=2.0 | 6 RU von beta; äußere Bahn |
| beta_i_m | MOON | AUTHORED_ORBIT | beta_i | r=1.2e9 m, T=1.2e4 s, phase=π/2 | Versetzt zu alpha_i_m für Erkennbarkeit |

## Orbit-Modus-Entscheidungen

- **AUTHORED_ORBIT für Sterne und Monde:** Debug-Entscheidung. `r` und `T` sind frei wählbar
  unabhängig von der Parentmasse — klare, vorhersagbare Visualisierung ohne Kepler-Rechnung.
  Sterne um ein Schwarzes Loch *könnten* KEPLER_APPROX verwenden, aber die Toy-Massen
  würden unrealistische Umlaufzeiten erzeugen.
- **KEPLER_APPROX für Planeten:** Testet die analytische Orbit-Pipeline
  (`OrbitMath.kepler_position`). Planeten sind der primäre NUMERIC_LOCAL-Kandidat (ab Step 4).

## Render-Skalierung

`RENDER_SCALE_M_PER_UNIT = 1e9`: 1 Render-Unit = 1e9 m.

| Körper | Orbit-Abstand (RU) | Mesh-Radius (RU) | Sichtbare Lücke |
|---|---|---|---|
| alpha/beta von obsidian | 150 / 250 | 0.8 | ~149 / 249 RU |
| Planeten von Stern | 2.5–6 | 0.2 | ≥1.5 RU |
| Monde von Planet | 1.2–1.5 | 0.08 | ≥0.8 RU |

## Farbkodierung

| Kind | Farbe | Emission |
|---|---|---|
| BLACK_HOLE | Dunkelviolett (0.5, 0.1, 0.5) | ja |
| STAR | Gelb (1.0, 0.85, 0.35) | ja |
| PLANET | Blau (0.3, 0.55, 0.9) | nein |
| MOON | Grau (0.7, 0.7, 0.7) | nein |

## Testbed-Steuerung

| Taste | Funktion |
|---|---|
| Tab | Fokus vorwärts (obsidian → alpha → ... → beta_i_m) |
| Shift+Tab | Fokus rückwärts |
| Home | Fokus zurück auf obsidian (Gesamtüberblick) |
| `Q` / `[` | Zeitskala langsamer (Preset ↓) |
| `E` / `]` | Zeitskala schneller (Preset ↑) |
| `W/A/S/D` | Kamera manuell verschieben |
| Space | Pause / Weiter |
| Mausrad | Zoom ein/aus (Bias 0.2×–8×) |
| Backspace | View zurücksetzen (Zoom + Pan) |
| F3 | Debug-Overlay ein/ausblenden |

**Zeitskalen-Presets:** 0.25× / 1× / 10× / 50× / 100× / **250× (Default)** / 500× / 1000× / 2500× / 5000×

Bei **250×** (Default):
- Monde: ~48–60 s/Umlauf
- Innere Planeten: ~4–6 min/Umlauf
- Sterne: ~3–6 min/Umlauf
- Äußere Planeten: ~10–17 min/Umlauf

Bei **1000×**:
- Monde: ~12–15 s/Umlauf
- Innere Planeten: ~68–90 s/Umlauf
- Sterne: ~50–90 s/Umlauf
- Äußere Planeten: ~3–4 min/Umlauf

## Initialzustand

`OrbitService.recompute_all_at_time(0.0)` wird in `_ready()` aufgerufen, bevor der erste
Frame gerendert wird. Alle Bodies starten mit konsistenten Positionen statt Default-ZERO
(außer obsidian, das per Architektur immer bei ZERO bleibt).

## Step-1-Beschränkungen

Diese Welt läuft auf **Step-1-Code**:
- `LocalBubbleManager` ist ein Identity-Stub. Fokus-Wechsel ändert die visuelle Position
  nicht — die Bubble-Transformation (Fokus-Subtraktion) ist Step 2.
- NUMERIC_LOCAL ist nicht implementiert — Planeten bleiben bei KEPLER_APPROX.
- Kein BubbleActivationSet — der Aktivierungsradius existiert noch nicht.

Diese Limits sind bewusst. Phase 2 liefert das Definitions- und Visualisierungsfundament.
