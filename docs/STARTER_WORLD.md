# Graviton - Starter World

Debug-fokussierte 18-Koerper-Referenzwelt fuer das Foundation-Testbed.
Alle Werte sind bewusste Toy-Werte - nicht astrophysikalisch korrekt.

## Systemuebersicht

`starter_world` bleibt der groessere BH-Root-Sandkasten:

- Root:
  - `obsidian`
- Sterne:
  - `alpha`, `beta`, `gamma`, `delta`
- Planeten:
  - `alpha_i`, `alpha_ii`, `alpha_iii`
  - `beta_i`, `beta_ii`
  - `gamma_i`, `gamma_ii`, `gamma_iii`, `gamma_iv`
  - `delta_i`
- Monde:
  - `alpha_i_m`
  - `beta_i_m`
  - `gamma_ii_m`

Die vier Sternsysteme sind bewusst ungleich gross:

- `alpha`: 3 Planeten, 1 Mond
- `beta`: 2 Planeten, 1 Mond
- `gamma`: 4 Planeten, 1 Mond
- `delta`: 1 Planet, 0 Monde

Zusatz seit dem kleinen P12A-Folge-Tuning:

- `gamma_iv` ist der erste bewusst sichtbare habitabele Kandidat der
  `starter_world`
- die restliche BH-Referenzwelt darf weiter ueberwiegend thermisch
  extrem bleiben

## Orbit-Modus-Entscheidungen

- **AUTHORED_ORBIT fuer BH-Sterne und Monde:** `r` und `T` bleiben frei
  waehlbar und liefern eine klare, vorhersagbare Visualisierung.
- **KEPLER_APPROX fuer Planeten:** testet weiter die analytische
  Orbit-Pipeline (`OrbitMath.kepler_position`) und bleibt der primaere
  `NUMERIC_LOCAL`-Kandidat.
- **Bewusst nicht in P12B:** elliptische Sternbahnen um `obsidian`.
  Dieser Slice ist content-only; Root-Star-Ellipsen bleiben ein
  spaeterer expliziter Folgeblock.

## Wichtige Asymmetrien

- vier verschiedene BH-Sternradien
- vier verschiedene BH-Sternperioden
- vier verschiedene BH-Sternphasen
- deutlich unterschiedliche Planetenzahlen pro Stern
- nur ein neuer Mond im `gamma`-System statt schematisch pro Stern ein
  weiterer Mond
- mindestens zwei neue Planeten mit explizit nicht-default
  Saison-Azimutwerten (`gamma_ii`, `delta_i`)
- `gamma_iv` sitzt bewusst deutlich weiter draussen und traegt einen
  expliziten Greenhouse-Beitrag, damit der Default-Testbed-Start in der
  grossen BH-Welt nicht nur `HOT`- und `FROZEN`-Beispiele zeigt

## Render-Skalierung

`RENDER_SCALE_M_PER_UNIT = 1e9`: 1 Render-Unit = 1e9 m.

Grobe Sichtbarkeit:

- BH-Sterne von `obsidian`: ca. `150 .. 480 RU`
- Planeten von ihren Sternen: ca. `1.2 .. 5.1 RU`
- Monde von ihren Planeten: ca. `0.24 .. 0.36 RU`

Damit bleibt der Root-Fokus lesbar, waehrend die lokalen Sternsysteme
weiter klar vom Parent getrennt sind.

## Testbed-Steuerung

| Taste | Funktion |
|---|---|
| Tab | Fokus vorwaerts durch `UniverseRegistry.get_update_order()` |
| Shift+Tab | Fokus rueckwaerts |
| Linksklick auf Body | Fokus direkt auf den angeklickten Body |
| Home | Fokus zurueck auf den Root-Body / Gesamtueberblick |
| `Q` / `[` / PageDown | Zeitskala langsamer |
| `E` / `]` / PageUp | Zeitskala schneller |
| HUD-Speed-Slider | Sim-Speed stufenlos logarithmisch |
| `W/A/S/D` | Kamera manuell verschieben |
| Space | Pause / Weiter |
| Mausrad | Zoom ein/aus (20%-2400%) |
| Backspace | View zuruecksetzen |
| F3 | Debug-Overlay ein/ausblenden |

## Visuelle Zielwirkung

- Im Root-Fokus sollen alle vier Sterne gleichzeitig sichtbar sein.
- Bei Default-`250x` soll mindestens einer der Sterne in wenigen Sekunden
  klar erkennbar auf seiner BH-Bahn voranschreiten.
- `gamma` soll als sichtbar reichstes Sternsystem wirken.
- `delta` soll als kleinstes, sparsames Sternsystem lesbar bleiben.

## Aktuelle Einschraenkungen

- `starter_world` bleibt weiterhin eine Toy-Referenzwelt und kein
  astrophysikalisch kalibriertes Mehrsternsystem.
- BH-Sternorbits bleiben absichtlich kreisfoermige `AUTHORED_ORBIT`.
- Der numerische `NUMERIC_LOCAL`-Pfad bleibt auf eligible Planeten
  beschraenkt; BH-Sterne und Monde bleiben authored.
- Thermische, atmosphaerische und Umweltwerte fuer die neuen Bodies sind
  bewusst minimal gehalten; `greenhouse_delta_k` bleibt auf `0.0`, wenn
  nicht explizit anders gesetzt.
- P12A nutzt `starter_world` bewusst **nicht** als habitable
  Showcase-Welt. Die thermischen Extreme im BH-Sandkasten sind kein
  Fehler; der kanonische habitable Referenzkoerper bleibt
  `sample_system.planet_a`.
- Ausnahme: `gamma_iv` ist jetzt als einzelner sichtbar habitabler
  Kandidat bewusst getunt. Das ist ein kleiner Produkt-/Content-Hook,
  kein Umbau der gesamten BH-Welt zu einer freundlichen Referenzwelt.
