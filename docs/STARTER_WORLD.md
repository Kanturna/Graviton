# Graviton - Starter World

Debug-fokussiertes 9-Koerper-System fuer das Foundation-Testbed.
Alle Werte sind bewusste Toy-Werte - nicht astrophysikalisch korrekt.

## Systemuebersicht

| ID | Kind | Orbit-Modus | Parent | Schluesselwerte | Begruendung |
|---|---|---|---|---|---|
| obsidian | BLACK_HOLE | root | - | mass=2e33 kg | Toy-Masse ~1000 Solarmassen; als Wurzel immer bei ZERO |
| alpha | STAR | AUTHORED_ORBIT | obsidian | r=1.5e11 m, T=4e4 s | AUTHORED: etwas schnellerer Root-View; Parentmasse frei |
| beta | STAR | AUTHORED_ORBIT | obsidian | r=2.5e11 m, T=7e4 s, phase=PI | phase=PI -> Sterne starten gegenueberliegend; sofort erkennbar |
| alpha_i | PLANET | KEPLER_APPROX | alpha | a=1.4e9 m, e=0.18 | kompakter, jetzt klarer elliptisch sichtbar |
| alpha_ii | PLANET | KEPLER_APPROX | alpha | a=2.2e9 m, e=0.12, M0=1.05 | aeussere Alpha-Bahn, weiter schneller als alpha |
| alpha_i_m | MOON | AUTHORED_ORBIT | alpha_i | r=3.0e8 m, T=8e3 s | enger an alpha_i gebunden; klar schneller als alpha_i |
| beta_i | PLANET | KEPLER_APPROX | beta | a=1.6e9 m, e=0.20, M0=0.5 | kompakt und jetzt deutlich elliptischer |
| beta_ii | PLANET | KEPLER_APPROX | beta | a=2.8e9 m, e=0.14, M0=2.0 | aeussere Beta-Bahn; weiter lesbar im lokalen Fokus |
| beta_i_m | MOON | AUTHORED_ORBIT | beta_i | r=2.4e8 m, T=6e3 s, phase=PI/2 | enger am Planeten; schnellster sichtbarer Orbit |

## Orbit-Modus-Entscheidungen

- **AUTHORED_ORBIT fuer Sterne und Monde:** `r` und `T` sind frei waehlbar,
  unabhaengig von der Parentmasse. Das liefert eine klare, vorhersagbare
  Visualisierung ohne Kepler-Rechnung.
- **KEPLER_APPROX fuer Planeten:** Testet die analytische Orbit-Pipeline
  (`OrbitMath.kepler_position`). Planeten sind die primaeren
  `NUMERIC_LOCAL`-Kandidaten fuer spaetere Schritte.

## Render-Skalierung

`RENDER_SCALE_M_PER_UNIT = 1e9`: 1 Render-Unit = 1e9 m.

| Koerper | Orbit-Abstand (RU) | Mesh-Radius (RU) | Sichtbare Luecke |
|---|---|---|---|
| alpha/beta von obsidian | 150 / 250 | 0.8 | ~149 / 249 RU |
| Planeten von Stern | 1.4-2.8 | 0.2 | >=1.2 RU |
| Monde von Planet | 0.24-0.3 | 0.08 | >=0.16 RU |

## Testbed-Steuerung

| Taste | Funktion |
|---|---|
| Tab | Fokus vorwaerts (Root -> alpha -> ... -> beta_i_m) |
| Shift+Tab | Fokus rueckwaerts |
| Linksklick auf Body | Fokus direkt auf den angeklickten Body |
| Home | Fokus zurueck auf den Root-Body / Gesamtueberblick |
| `Q` / `[` / PageDown | Zeitskala langsamer (Preset runter) |
| `E` / `]` / PageUp | Zeitskala schneller (Preset hoch) |
| HUD-Speed-Slider | Sim-Speed stufenlos logarithmisch zwischen langsam und sehr schnell |
| `W/A/S/D` | Kamera manuell verschieben |
| Space | Pause / Weiter |
| Mausrad | Zoom ein/aus (20%-2400%) |
| Backspace | View zuruecksetzen (100% + Pan) |
| F3 | Debug-Overlay ein/ausblenden |

Hinweis:
Der starke Nahzoom kann jetzt auch visuell weiter greifen; Bodies und
Abstaende bleiben nicht mehr frueh an einer niedrigen internen
Detail-/View-Grenze stehen.

Orbit-Hierarchie:

- Monde sind im Starter-World-Tuning bewusst die schnellsten sichtbaren Orbits.
- Planeten kreisen sichtbar schneller um ihre Sterne als die Sterne um `obsidian`.
- Die Planetenbahnen sind jetzt deutlich genug elliptisch, dass ihre Bahnform
  im Testbed nicht mehr wie ein perfekter Kreis-Testfall wirkt.
- Die Monde sitzen wieder deutlich enger an ihren Planeten, damit sie lokal
  gebunden wirken und nicht visuell bis in Sternnaehe ausgreifen.

Zoom-Semantik:

- `100%` = lokaler Fokus-Fit
- `20%` = globaler Ueberblick mit zusaetzlichem Weitwinkel, auch von Stern-/Planeten-/Mondfokus aus
- `2400%` = tieferer Close-up-Zoom ohne fruehen internen Scale-Cap

HUD:

- zeigt jetzt Fokus, Sim-Zeit, Step-Count, FPS, Speed-Multiplikator, Speed-Preset-Stufe, Zoom und Run/Pause-Status
- Speed kann jetzt zusaetzlich ueber einen logarithmischen HUD-Slider geregelt werden; Hotkeys und Slider bleiben synchron

Hinweis zur Sim-Speed:

- Hohe `time_scale`-Werte skalieren jetzt das simulierte `dt` pro Physics-Frame,
  statt hunderte Einzel-Ticks pro Frame zu emittieren. Das haelt hohe Speedstufen
  deutlich fluessiger.

**Zeitskalen-Presets:** 0.25x / 1x / 10x / 50x / 100x / **250x (Default)** / 500x / 1000x / 2500x / 5000x

Bei **250x** (Default):

- Monde: ~24-32 s/Umlauf
- Innere Planeten: ~1-1.5 min/Umlauf
- Sterne: ~2.5-4.7 min/Umlauf
- Aeussere Planeten: ~2-3 min/Umlauf

Bei **1000x**:

- Monde: ~6-8 s/Umlauf
- Innere Planeten: ~16-20 s/Umlauf
- Sterne: ~40-70 s/Umlauf
- Aeussere Planeten: ~32-47 s/Umlauf

## Initialzustand

`OrbitService.recompute_all_at_time(0.0)` wird in `_ready()` aufgerufen, bevor der erste
Frame gerendert wird. Alle Bodies starten mit konsistenten Positionen statt Default-ZERO
(ausser obsidian, das per Architektur immer bei ZERO bleibt).

## Aktuelle Einschraenkungen

- `LocalBubbleManager` nutzt bereits eine einfache Fokus-Subtraktion fuer
  die Darstellung, aber noch keine volle Bubble-/LCA-Logik.
- `NUMERIC_LOCAL` ist nicht implementiert - Planeten bleiben bei `KEPLER_APPROX`.
- Es gibt noch kein `BubbleActivationSet`.

Diese Limits sind bewusst. Die spaeteren Architektur-Schritte bauen darauf auf.
