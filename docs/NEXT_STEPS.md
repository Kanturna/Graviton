# Graviton - Next Steps

Stand: 2026-04-23

## Prioritaet 0 - Planetary-State Acceptance Gate

Ziel:
Die neue `Planetary State Foundation` im echten Editor-/Playtest-Lauf
validieren, bevor daraus `Life Potential v1` oder eine groessere
Survey-/Atlas-Schicht weitergezogen wird.

Konkreter Ablauf:

- `orbit_testbed.tscn` im Editor oeffnen
- nacheinander diese Fokusfaelle pruefen:
  - `sample_system` -> `planet_a`
  - `starter_world` -> `gamma_iv`
  - `starter_world` -> ein klar heisser Referenzplanet
  - `starter_world` -> ein klar kalter Referenzplanet oder Mond
- jeweils dieselben Dinge lesen:
  - normales Fokus-HUD
  - Root-Inspector-Zeile fuer denselben Body
  - `Environment` / `Climate` gegen `World`
- dabei bewusst auf diese Punkte achten:
  - `Environment` bleibt die Aussage fuer **jetzt**
  - `World` liest als **Jahrescharakter** statt als zweite
    Momentaufnahme
  - die `World:`-Zeile wirkt informativ, aber noch nicht wie heimlich
    eingebaute Life- oder Biosphaeren-Logik
  - `planet_a` liest weiter als reich/gut gepuffert, ohne die alte
    `sample_system`-Umweltsemantik zu verlieren
  - `gamma_iv` bleibt aktuell brauchbar, darf aber jahresweise klar nur
    `WINDOWED`/saisonal lesen

## Prioritaet 1 - Large-World Regression Gate mit offener World-Zeile

Ziel:
Sicherstellen, dass die neue planetare Desc-Familie den ruhigen
Large-World-Pfad nicht regressiert.

Konkreter Ablauf:

- `scaleup_galaxy_30` und `scaleup_galaxy_100` im Editor vergleichen
- in beiden Welten bewusst dieselben Faelle pruefen:
  - `ROOT_OVERVIEW`, Inspector zu
  - `ROOT_OVERVIEW`, Inspector offen
  - Detailblick nach Fokus auf Stern / Planet / Mond
- dabei besonders bestaetigen:
  - `resident_root_ids` bleibt weiter `1..2`
  - der Inspector zeigt fuer residente Planeten/Monde jetzt zusaetzlich
    die kompakte `World:`-Lesart
  - `ROOT_OVERVIEW + Inspector offen` bleibt auf `scaleup_galaxy_100`
    weiter ruhig und interaktiv
  - Proxy-Culling, BH-only-/Stern-Proxy-Tiering und Streaming-Hysterese
    lesen weiter stabil

Wenn dieser Gate kippt:

- keinen neuen Simulationsblock anfangen
- stattdessen einen kleinen Korrekturblock direkt aus Inspector-,
  Snapshot- oder Derived-Interest-Befunden schneiden

## Prioritaet 2 - Naechster Simulationsblock: Life Potential v1 oder Mehrquellenstrahlung

Ziel:
Nach einem sauberen Acceptance-Run den naechsten grossen planetaren
Simulationsschritt bewusst waehlen.

Bevorzugte Richtung:

- `Life Potential v1` auf Basis der neuen `World`-Achsen
- read-only und status-/textbasiert
- noch keine Populationen, Wesen oder Zivilisation
- unterschiedliche Chemiepfade bleiben moeglich, weil die Foundation
  bewusst chemie-agnostisch gebaut ist

Fallback-Reihenfolge:

- wenn im Playtest `has_primary_source_only_basis` fuer Mehrstern-Faelle
  stoert, zuerst einen `Mehrquellenstrahlung`-Block vorziehen
- erst danach einen Life-Potential-Pass darueberlegen

## Akut - Backdrop-Flicker im Editor beseitigen - erledigt

Erledigt:

- der live geshaderte Backdrop wurde auf einen Bake-Pfad ueber
  `SubViewport` + `TextureRect` umgestellt
- damit verschwanden das gemeldete Nebel-Springen und das Stern-
  Britzeln bei `WASD`/Zoom
- der kurz getestete Kamera-Kopplungsversuch blieb bewusst nicht
  erhalten; der funktionierende Fix ist der statische Bake-Pfad

## Prioritaet 0 - Test-Baseline wieder gruen machen - erledigt

Ziel:
Die Foundation sollte vor den naechsten groesseren Architektur-Schritten
wieder eine saubere gruene Test-Basis haben.

Erledigt:

- `solve_kepler(PI, 0)` als bewusste signed-range-Konvention
  `[-PI, PI)` festgezogen
- Orbit-Test auf kanonischen Rueckgabewert plus Residual-Check
  umgestellt
- Test-Baseline wieder als verlaessliche Basis hergestellt

## Prioritaet 2 - Foundation Phase A: Step 2 Bubble / Frame-Modell - erledigt

Ziel:
Den `LocalBubbleManager` vom frueheren Fokus-Subtraktionsmodell auf das
dokumentierte Step-2-Zielbild bringen.

Erledigt:

- LCA-/praezisionsbewusste Komposition fuer `compose_view_position_m`
- `Vector3.INF`-Sentinel fuer Bodies ohne gemeinsamen Root mit dem Fokus
- root-lokale Debug-Hilfe `compose_root_local_position_m`
- Renderer-Toleranz fuer nicht-finite Bodies inkl. Trail-Cleanup

## Prioritaet 2 - Foundation Phase B: WorldLoader / Weltwahl explizit machen - erledigt

Ziel:
Das Testbed soll nicht mehr direkt eine bestimmte Welt hart laden,
sondern eine explizite Loader-/World-Schicht nutzen.

Erledigt:

- neuer `WorldLoader` als Node-Service im `src/sim/`-Layer
- `orbit_testbed.gd` laedt Welten jetzt explizit ueber
  `initial_world_id`
- `starter_world` und `sample_system` laufen ueber denselben
  transaktionalen Loader-Pfad
- `UniverseRegistry` ist wieder auf Registry-Scope zurueckgefuehrt

## Prioritaet 3 - Foundation Phase C: World Model verbreitern - erledigt

Ziel:
Die statische Simulationswahrheit fuer Bodies so erweitern, dass
spaetere planetare Zustaende, Generatoren und echte Mehrsystem-Welten
auf einer sauberen Datenbasis aufsetzen koennen.

Erledigt:

- `BodyDef` um Rotation, Achsneigung, Leuchtkraft und Albedo erweitert
- Referenzwelten explizit mit ersten Weltmodell-Werten befuellt
- neue Validierungs- und BodyDef-World-Model-Tests ergaenzt
- weiterhin noch keine abgeleiteten Temperatur-/Habitability-Systeme

## Prioritaet 4 - Foundation Phase D: BubbleActivationSet - erledigt

Ziel:
Bodies relativ zum aktuellen Fokus read-only in Aktivierungszustaende
klassifizieren, ohne schon Regime-Wechsel oder `BodyState`-Mutation
einzufuehren.

Erledigt:

- `BubbleActivationSet` als eigener Runtime-Service
- Klassifikation in `ACTIVE`, `INACTIVE_DISTANT`, `INACTIVE_NO_LCA`
- Debug-Overlay-Hook fuer Aktivierungsradius und Body-States
- neue Runtime-Tests fuer Multi-Root, Boundary-Fall `radius = 0.0` und
  Auto-Rebuild bei `focus_changed`

## Prioritaet 5 - Foundation Phase D: Regime-Wechsel / NUMERIC_LOCAL - erledigt

Ziel:
Das Aktiv-Set aus der Bubble-Schicht als expliziten Wunsch in den
Sim-Layer bridgen und einen minimalen numerischen Parent-Only-Pfad fuer
eligible `KEPLER_APPROX`-Bodies einziehen.

Erledigt:

- `LocalOrbitIntegrator` als pure Mathematik im `src/sim/`-Layer
- `OrbitService.request_numeric_local_candidates(ids)` als
  Replace-API fuer das aktuelle Wunsch-Set
- Regime-Wechsel nur ueber `BodyState.current_mode`, nicht ueber
  `OrbitProfile.mode`
- analytisches Velocity-Seeding via zentraler finite Differenz
  (`VELOCITY_SEED_EPSILON_S = 1.0`)
- Exit-Warnings mit Positions-/Velocity-Deltas beim Rueckwechsel auf
  `KEPLER_APPROX`
- neue Tests fuer Integrator, Idempotenz, Replace-Semantik und
  Regime-Wechsel

## Prioritaet 6 - Derived Phase A: Insolation / ThermalService - erledigt

Ziel:
Den ersten read-only Derived-Service ausserhalb von Orbit-/Bubble-
Kernlogik einfuehren und minimale Insolation direkt aus Foundation-
Wahrheit ableiten.

Erledigt:

- `ThermalService` als on-demand-Service im `src/sim/`-Layer
- Quellenregel: naechster leuchtender Ancestor mit `luminosity_w > 0.0`
- keine Selbstbestrahlung; die Suche startet beim Parent
- Debug-Overlay-Hook fuer `insolation` und `source`
- neue Tests fuer SampleSystem, StarterWorld, Cross-Root-Isolation und
  `describe_body(...)`

## Prioritaet 7 - Derived Phase B: Absorbierter Fluss / Gleichgewichtstemperatur - erledigt

Ziel:
Den bestehenden `ThermalService` ohne neuen State-Container um den
naechsten physikalisch sinnvollen Minimal-Slice erweitern.

Erledigt:

- `compute_absorbed_flux_wpm2(id)` und `compute_equilibrium_temperature_k(id)`
- `UnitSystem.STEFAN_BOLTZMANN_WPM2K4`
- Fast-Rotator-/`/4`-Redistribution als explizite Modellannahme
- Debug-Overlay-Hook fuer `absorbed` und `teq`
- neue Tests fuer Earth-like-Sanity, Albedo-Grenzen und
  Temperatur-Ordnungsrelationen

## Prioritaet 8 - Derived Phase C: EnvironmentService / Habitability-Klassifikation - erledigt

Ziel:
Die ersten quantitativen Thermalwerte in eine kleine, sichtbare
Umwelt-Aussage fuer planetare Bodies ueberfuehren, ohne `ThermalService`
zu einer Sammelklasse auszubauen.

Erledigt:

- neuer `EnvironmentService` als separater read-only Derived-Service
- Klassifikation in `HABITABLE`, `MARGINAL`, `HOSTILE`
- Support nur fuer `PLANET` und `MOON`
- minimale normale HUD-Zeile fuer den aktuellen Fokus
- harte Boundary-Tests via Stub-ThermalService

## Prioritaet 9 - Derived Phase D: AtmosphereService / minimales Greenhouse - erledigt

Ziel:
Auf die nackte Strahlungsbasis einen kleinen, datengetriebenen
Atmosphaeren-/Greenhouse-Layer setzen, ohne `ThermalService` oder
`EnvironmentService` zu Sammelklassen auszubauen.

Erledigt:

- neuer `AtmosphereService` als separater read-only Derived-Service
- neues `BodyDef`-Feld `greenhouse_delta_k`
- `surface_temperature_k = T_eq + greenhouse_delta_k`
- `EnvironmentService` klassifiziert jetzt auf `surface_temperature_k`
- bestehende normale HUD-Zeile zeigt jetzt Klasse, `Tsurf` und `G+... K`

## Prioritaet 10 - Foundation Phase D: NUMERIC_LOCAL Guardrails / Stabilitaet - erledigt

Ziel:
Den bestehenden `NUMERIC_LOCAL`-Pfad gegen grosse `dt` und den
dokumentierten Wish-Versatz haerten, ohne `BubbleActivationSet` mit
Hysterese aufzublasen oder `BodyState` zu erweitern.

Erledigt:

- `LocalOrbitIntegrator.step_velocity_verlet_substepped(...)` als
  pure Substep-Hilfe
- `OrbitService`-Guardrails als exportierte Tuning-Felder
  (`target_substep`, `max_substeps`, `missing_request_grace_ticks`)
- Anti-Thrashing bewusst im `OrbitService`, nicht im
  `BubbleActivationSet`
- `Cap+Warn`-Policy mit Warning-Dedup statt hartem Kepler-Fallback
- Exit-Rejoin-Budgets fuer `NUMERIC_LOCAL -> KEPLER_APPROX`; bei
  ueberschrittenem Delta bleibt der Body numerisch und integriert
  weiter statt analytisch zu snappen
- neue Regressionen fuer blocked Exit im Sim-Pfad und fuer
  `ThermalService`-Kontinuitaet ohne stillen Rueck-Snap
- neue Tests fuer grosse `dt`, Grace-Verhalten und Warning-Dedup

## Prioritaet 11 - Derived Phase E: Saisonale Insolation / Tilt-Geometrie - erledigt

Ziel:
Den bestehenden `ThermalService` um eine erste latitudenbewusste,
tilt-getriebene Saison-Geometrie erweitern, ohne einen neuen
Derived-Service einzuziehen oder `EnvironmentService` still mitzuziehen.

Erledigt:

- neues `BodyDef`-Feld `north_pole_orbit_frame_azimuth_rad`
- `ThermalService.compute_subsolar_latitude_rad(id)`
- `ThermalService.compute_daily_mean_insolation_wpm2(id, latitude_rad)`
- `describe_body(...)` meldet jetzt auch saisonale Geometrie und
  Tagesmittel fuer Aequator / Nordpol / Suedpol
- kleine normale HUD-Zeile fuer `Season: subsolar ...`
- neue Tests fuer Azimut-Vorzeichen, Polar-Faelle und
  `AUTHORED_ORBIT`-Saisonbasis

## Prioritaet 12 - Content Slice: Asymmetrische BH-Referenzwelt - erledigt

Ziel:
`starter_world` als groessere, sichtbar asymmetrische
Schwarzes-Loch-Referenzwelt ausbauen, ohne neue Simulationsmechanik
einzuziehen.

Erledigt:

- `starter_world` traegt jetzt vier Sterne unter `obsidian`
- die Sternsysteme sind bewusst ungleich gross (3/2/4/1 Planeten)
- die Welt bleibt content-only: BH-Sterne bleiben
  `AUTHORED_ORBIT`-Kreise
- neue StarterWorld-Tests sichern Body-Anzahl, Topologie,
  Sternorbit-Unikate und paarweise verschiedene planetare
  `semi_major_axis_m` innerhalb jedes Sternsystems ab

## Prioritaet 13 - Derived Phase F: Zonenbewusste Umweltklassifikation - erledigt

Ziel:
Die bestehende Thermal-/Atmosphaeren-/Umweltkette ohne neue Services
von einem globalen Temperaturskalar auf eine kleine, sichtbare
Zonenbewertung fuer planetare Bodies erweitern.

Erledigt:

- `AtmosphereService` liefert jetzt bandbewusste
  `surface_temperature_k` fuer `-60deg`, `Eq` und `+60deg`
- `EnvironmentService` klassifiziert jetzt auf Basis dieser drei
  Breitenbaender statt auf einem globalen Einzelskalar
- neue `EcosystemType`-Ableitung (`FROZEN`, `TEMPERATE`, `SEASONAL`,
  `HOT`) sowie `has_habitable_band` und `has_liquid_water_band`
- normales HUD zeigt jetzt `Environment: ...   Eco ...` plus eine
  `Climate:`-Zeile
- `sample_system` bleibt der kanonische habitable Showcase; die
  thermisch extreme `starter_world` wurde bewusst nicht retuned

## Prioritaet 13.1 - Content-Follow-up: `gamma` lokal plausibel als kompaktes Red-Dwarf-System aufsetzen - erledigt

Ziel:
Die grosse BH-Referenzwelt soll nicht nur extreme hot/frozen-Beispiele
zeigen, sondern mindestens einen im laufenden Testbed auffindbaren
habitablen Kandidaten tragen, ohne dafuer einen root-skaligen
Ausreisserorbit zu erzwingen.

Erledigt:

- das fruehere ad-hoc-`gamma_iv`-Follow-up wurde bewusst nicht
  konserviert
- `gamma` ist jetzt als kompakter Red-Dwarf-artiger Stern
  neu parametrisiert
- das gesamte `gamma`-Planetensystem wurde lokal neu skaliert
- `gamma_iv` bleibt als habitabler Kandidat erhalten, jetzt aber in
  einem kompakten lokalen Orbit mit expliziter Hill-Sphere-Guardrail
- Tests pinnen jetzt die neuen `gamma`-Werte sowie
  `gamma_iv @ t=0.0 => HABITABLE + SEASONAL_WORLD`

## Prioritaet 13.2 - UX-Pass: Environment-/Climate-/Bands-Labels klaeren - erledigt

Ziel:
Die zonenbewusste Umweltkette soll fuer Spieler klarer lesbar werden,
ohne ihre Logik, Schwellen oder Service-Grenzen zu veraendern.

Erledigt:

- `Class.MARGINAL` bleibt intern stabil, wird player-facing aber
  bewusst als `HARSH` dargestellt
- das HUD trennt jetzt klarer zwischen `Environment` (Habitability),
  `Climate` (Welttyp / `ecosystem_type`) und `Bands` (Rohdaten)
- die Temperaturzeile wurde von `Climate:` auf `Bands:` umbenannt
- neue String-Tests sichern die Display-Mappings gegen spaetere
  Rueckbenennungen ab

## Prioritaet 14 - View Phase A: Klima-Archetypen fuer Planeten und Monde - erledigt

Ziel:
Die bestehende planetare Umweltsemantik im Renderer sichtbar machen,
ohne neue Simulationswahrheit zu erzeugen oder auf Texturimporte zu
wechseln.

Erledigt:

- neuer reiner View-Resolver fuer Klima-Archetypen unter
  `src/tools/rendering/`
- `PLANET` und `MOON` teilen sich jetzt denselben Klima-Resolver, damit
  HUD und Darstellung nicht auseinanderlaufen
- shaderbasierte Archetypen `TEMPERATE_OCEAN`, `FROZEN`,
  `HOT_SCORCHED` und `BARREN`
- `TEMPERATE_OCEAN` ist bewusst als stilisierte Interpretation
  markiert; `DESERT` wurde fuer einen spaeteren Sim-staerkeren Pass
  zurueckgestellt
- neue Rendering-Tests pinnen synthetische Resolver-Regeln plus die
  stabilen Live-Welt-Faelle `planet_a` und `gamma_iv @ t=0.0`

## Prioritaet 14.1 - View Phase B: Stabilen Weltanker fuer den Kamera-Zoom einfuehren - erledigt

Ziel:
Den globalen Weltblick an einen stabilen, beim Load gecachten
Weltanker binden, ohne die bestehende Fokus-Topologie oder die
P14-Nahdetail-Schwellen zu brechen.

Historischer Zwischenstand:
Die P14.1-Weltanker-Invariante wurde spaeter in P16 bewusst wieder
aufgegeben. Der Eintrag bleibt nur als Verlaufsschritt stehen.

Erledigt:

- beim Load gecachter Root-Overview-Radius als Weltanker
- Zoombereich fuer den manuellen Nahzoom-Follow-up auf `0.5%-10000%`
  erweitert
- Renderer-Nahdetail und Fokus-Emphasis laufen weiter fokus-relativ
  ueber einen separaten `focus_closeup_ratio`
- neuer reiner Zoom-Helper-Testblock fuer Weltanker, Mapping und
  fokus-relatives Closeup-Verhaeltnis

## Prioritaet 14.2 - View Phase C: Hybrid-Zoom fuer Weltblick und lokalen Nahzoom - erledigt

Ziel:
Den guten globalen Rauszoom aus P14.1 behalten, aber fokussierte
Sterne, Planeten und Monde wieder mit einem brauchbaren lokalen
Nahzoom erreichbar machen.

Historischer Zwischenstand:
Das P14.2-Hybridmodell wurde spaeter in P16 bewusst durch
scope-relatives Zoom ersetzt. Der Eintrag bleibt nur als
Zwischenetappe dokumentiert.

Erledigt:

- `0.5% .. 100%` bilden jetzt explizit `world -> fit current focus` ab
- der `world`-Abschnitt interpoliert jetzt zusaetzlich den Kameraanker
  `root -> focus` statt nur die Skala; Root-Fernblick bleibt damit auch
  bei Stern-/Planetenfokus raeumlich konsistent
- `100%` bedeutet wieder exakt `fit current focus`
- `100% .. 10000%` sind jetzt bewusster lokaler Fokus-Closeup statt
  global vergleichbarer Welt-Massstab
- Fokuswechsel behalten den Sliderwert, interpretieren hohe Zoomwerte
  aber unter dem neuen Fokus lokal neu
- HUD-Zoomwerte zeigen jetzt explizit den Modus
  (`world` / `fit` / `focus`)
- die fruehere P14.1-Invariante "gleiche Zoomzahl = gleicher
  Welt-Massstab unabhaengig vom Fokus" wurde bewusst zurueckgenommen

## Prioritaet 14.3 - View Phase D: Sterne als runde Photosphaeren mit Corona - erledigt

Ziel:
Sterne endlich als runde, lebendige Sonnen lesbar machen - warme Palette,
sichtbare Photosphaere, echter Corona-Halo - ohne Kamera-, Orbit-,
Planeten- oder Body-Size-Aenderung.

Erledigt:

- Alpha-Silhouette im Sternshader vom zeitgetriebenen Warp entkoppelt
  (`alpha = smoothstep(..., t)` statt `t_w`); innere Animation fuer Limb,
  Farbe und Rim bleibt erhalten
- Palette gesaettigter: `center_col` etwas waermer, `edge_col` deutlich
  orangefarbener
- Granulations-Amplitude ueber `df_t` angehoben, Photosphaere jetzt auch
  in Uebersicht/Mittelsicht lesbar
- Lane-Temperature-Tint und Rim-Intensitaet leicht verstaerkt
- bestehende Granulations-Morphologie (hexagonale 3-Richtungs-Zellen,
  Domain-Warp, asymmetrische Lanes `bright*0.60 - dark*1.35`) bewusst
  unveraendert
- Corona-Halo in `_draw_star_glow` von 3 auf 5 Ringe erweitert, weicher
  Gradient, Aussenradius 25 px - Stern-Footprint bleibt innerhalb des
  frueheren 22-px-Ringes plus minimaler Gradient-Rand
- optionaler TIME-Atem nur auf Alpha des aeussersten Rings, nie auf
  Radius; Form bleibt perfekt rund
- alle Sterne teilen in P14.3 bewusst denselben Sun-Look

Offen / spaeter:

- Star-Typisierung / Spektralklassen / luminosity-getriebene Palette als
  eigener spaeterer Pass (`gamma` ist physikalisch weiter Red-Dwarf,
  visuell aber bewusst noch Teil derselben Sonnenfamilie)

## Prioritaet 14.4 - View Phase E: Sterne in Richtung NASA-naher aktiver Sonnenoberflaeche ziehen - erledigt

Ziel:
Den P14.3-Sternlook von "runde warme Sonne mit Halo" in Richtung einer
deutlich aktiveren solaren Photosphaere verschieben, ohne Kamera,
Body-Size, Planeten oder Sim-Schichten anzufassen.

Erledigt:

- der bestehende Sternshader behaelt seine runde Alpha-Silhouette und
  seine P14.3-Granulationsbasis; neue Aktivitaet moduliert bewusst nur
  Farbe und nie `alpha`
- zusaetzliche grobskalige Solar-Activity-Ebene fuer hellere aktive
  Regionen und dunklere Filament-/Channel-Zonen
- explizite Star-Uniforms im `STAR`-Pfad von `OrbitBodyVisual`, damit
  Palette, Activity, Filamente und hot rim nicht weiter in
  Shader-Konstanten versteckt bleiben
- innere Randenergie jetzt staerker shaderseitig ueber `rim_hotness`
  und `edge_activity_strength`
- `_draw_star_glow()` bewusst subtiler getunt; weniger Ring-Lesbarkeit,
  mehr warmes Atmosphaeren-Fading ohne Footprint-Wachstum
- dekorativer Star-Overlay-Arc entfernt, damit Sternaktivitaet nicht wie
  ein UI-Effekt liest

Offen / spaeter:

- echte aussen sichtbare Prominenzen / Protuberanzen bleiben ein
  moeglicher spaeterer separater Follow-up und wurden in P14.4 bewusst
  nicht eingefuehrt
- Star-Typisierung / Spektralklassen / luminosity-getriebene Palette als
  eigener spaeterer Pass (`gamma` ist physikalisch weiter Red-Dwarf,
  visuell aber bewusst noch Teil derselben Sonnenfamilie)

## Prioritaet 14.5 - View Phase F: Sterne von gutem Pattern zu tiefer mehrskaliger Sonnen-Textur weiterziehen - erledigt

Ziel:
Die verbleibende Schwaeche des P14.4-Sternlooks lag nicht mehr in
Rundheit oder Glow, sondern in der fehlenden Materialtiefe. P14.5 zieht
die Sternoberflaeche deshalb ueber eine feste mehrskalige
Frequenzhierarchie von "gutem Pattern" zu deutlich tieferer, NASA-naher
Solartextur weiter - weiterhin vollstaendig shader-only.

Erledigt:

- `body_star.gdshader` hat jetzt eine feste 4+1-Frequenzleiter:
  statisches Macro-Feld (`1.35`), neue Meso-Breakup-Zwischenskala
  (`2.40`), bestehende Activity (`4.20`), Filament-Channels (`3.10`)
  und feine Granulation (`~11.0`)
- neues internes Noise-/FBM-Set (`_hash21`, `_noise`, `_fbm`) lebt
  ausschliesslich im Sternshader; keine Asset-Texturen und keine
  gemeinsame Shader-Bibliothek
- Macro-Feld bleibt bewusst komplett statisch (kein `TIME`); Meso
  driftet nur sehr langsam und organisiert die Oberflaeche, ohne den
  ganzen Stern unruhig zu machen
- Blending-Reihenfolge ist jetzt explizit festgezogen:
  Basisfarbe -> Macro multiplikativ -> Granulation multiplikativ ->
  Meso additiv -> Activity additiv -> Channels dunkler Mix -> Rim/Edge
  zuletzt
- neue Star-Uniforms fuer Surface-Tiefe und Kontrast
  (`macro_surface_strength`, `meso_breakup_strength`,
  `granulation_contrast`, `channel_contrast`, `hotspot_contrast`) werden
  ausschliesslich im `STAR`-Pfad von `OrbitBodyVisual` gesetzt
- `alpha` bleibt weiter rein ueber `t` definiert; auch P14.5 moduliert
  niemals die Silhouette

Offen / spaeter:

- echte aussen sichtbare Prominenzen / Protuberanzen bleiben weiter ein
  moeglicher spaeterer Follow-up
- Star-Typisierung / Spektralklassen / luminosity-getriebene Palette als
  eigener spaeterer Pass (`gamma` ist physikalisch weiter Red-Dwarf,
  visuell aber bewusst noch Teil derselben Sonnenfamilie)

## Prioritaet 14.6 - View Phase G: Sterne mit eigenem Closeup-Mode, Detailmap und solarer Randaktivitaet auf NASA-Naehe ziehen - erledigt

Ziel:
Die P14.5-Prozeduralbasis blieb fuer wirklich NASA-nahe Fokussterne noch
zu nah an "kleiner Pattern-Disc". P14.6 fuehrt deshalb bewusst einen
sternspezifischen Closeup-Mode ein, der nur fuer den fokussierten Stern
zusaetzliche Surface- und Randlesbarkeit freischaltet.

Erledigt:

- neuer P14.6-Closeup-Helfer in `OrbitEmphasisRules`:
  `star_closeup_phase = clamp(log(focus_closeup_ratio) / log(6.0), 0.0, 1.0)`
- der fokussierte Stern bekommt jetzt kontrolliert mehr Footprint
  (`1.0 -> 1.5`) statt nur weiter denselben generischen `df_t`-Pfad
  vergroessert zu sehen
- `OrbitBodyVisual` hat jetzt einen eigenen Stern-Closeup-State und
  bindet im `STAR`-Pfad zusaetzlich eine `star_detailmap.png`
- neues Ableitungsskript erzeugt diese Detailmap reproduzierbar aus
  `sun.png`; eine Asset-Notiz dokumentiert Herkunft und Regeneration
- `body_star.gdshader` ist jetzt hybrid: P14.5-Prozeduralbasis plus
  Detailmap fuer additive Faculae und dunklere Sunspot-/Channel-
  Komplexe, weiterhin nur ueber `col`, nie ueber `alpha`
- `_draw_star_glow()` bleibt die Basis des P14.5-Halos, bekommt im
  Stern-Closeup aber zusaetzlich begrenzte echte Randaktivitaet
  (Spicules + kleine prominence-artige Boegen) mit maximal `+6 px`
  Zusatzradius
- neuer Rendering-Test pinnt die P14.6-Closeup-Phase und die
  konservative Fokusstern-Skalierung

Offen / spaeter:

- weitergehende Spektralklassen-/Star-Typisierung bleibt weiterhin ein
  spaeterer separater Pass
- falls die neue Detailmap optisch zu stark oder zu direkt liest, ist
  das erste Nachjustieren ueber `detailmap_strength`,
  `prominence_strength`, `sunspot_strength` und die Fokusstern-Skalierung
  vorgesehen, nicht ueber einen neuen Kamera-Umbau

## Prioritaet 14.6b - View Phase G Follow-up: Detailmap entkoppeln, zentrieren und als statische Closeup-Hauptschicht fuehren - erledigt

Ziel:
Der erste P14.6-Hybridpfad machte zwei Probleme gleichzeitig sichtbar:
die abgeleitete Bildmap war nicht sauber disc-zentriert und sie lief im
Shader mit einer eigenen `TIME`-Translation gegen die prozedurale
Sternoberflaeche. P14.6b zieht diesen Closeup-Pfad deshalb auf eine
statische, zentrierte und im High-Closeup dominante Surface-Lesart
zurecht.

Erledigt:

- `derive_star_detailmap.py` bestimmt jetzt den Disc-Bereich aus der
  Referenz, schneidet aeussere Protuberanzen ab und erzeugt eine
  zentrierte `512x512`-Structure-Map statt nur eines quadratischen
  Roh-Crops
- `star_detailmap.png` wurde entsprechend neu generiert; die
  Asset-Notiz dokumentiert jetzt zentrierte Disc-Nutzung und statisches
  Shader-Sampling ohne `TIME`-Translation
- `body_star.gdshader` sampelt die Detailmap jetzt komplett statisch
  und disc-zentriert
- im High-Closeup wird die Detailmap als sichtbare Surface-Leader-Lage
  gefuehrt; Granulation, Activity, Filamente und Meso-Layer werden ueber
  einen `smoothstep`-Gate nur amplitude-seitig gedimmt, bleiben aber als
  subtil animierter Unterbau erhalten
- das statische Macro-Feld bleibt bewusst ungedaempft, damit die
  Sternscheibe trotz staerkerer Bildstruktur nicht flach wird

## Prioritaet 15 - Architektur-Cleanup: Topologie, Test-Harness und View-Split - erledigt

Ziel:
Die bestehende Architektur ohne Bruch aufraeumen: verteilte
Topologie-Helfer zentralisieren, wiederkehrende Test-Setups
vereinheitlichen und die Kamera-/HUD-/Renderer-Verantwortungen sauberer
trennen.

Erledigt:

- neuer read-only `UniverseTopology`-Helper ueber `UniverseRegistry`
- `LocalBubbleManager`, `OrbitViewRenderer` und `orbit_testbed.gd`
  nutzen jetzt denselben Topologie-Pfad statt eigener Root-/Descendant-
  Logik
- neuer `SimTestHarness` mit festem Named-World-Build-/Teardown-Pfad
- Migration der grossen Named-World-Suites auf den Harness
  (`thermal`, `atmosphere`, `environment`, `planet_visual_profile`)
- neuer `OrbitCameraController` fuer Zoom/Pan/Anker/View-State
- neuer `OrbitHudFormatter` fuer player-facing HUD-Strings
- neuer `OrbitTimeScaleController` fuer HUD-Slider, Preset-Schritte und
  logaritmisches Time-Scale-Mapping
- `OrbitViewRenderer` in Node-/Canvas-Arbeit plus reine Helper fuer
  Camera-Scope, Emphasis und Orbit-Geometrie getrennt
- service-lokale `KEY_*`-Konstanten fuer `ThermalService`,
  `AtmosphereService`, `EnvironmentService` und `BubbleActivationSet`
  eingefuehrt; Produzenten und die wichtigsten Runtime-/HUD-Konsumenten
  haengen jetzt daran
- neue Tests fuer `UniverseTopology`, `SimTestHarness` und
  `OrbitCameraController`
- neuer Test fuer `OrbitTimeScaleController`

Offen / spaeter:

- manuelle Editor-/Playtest-Pruefung der neuen Camera-/Renderer-
  Aufteilung als kurze visuelle Regression-Sanity
- optionaler weiterer Trim-Pass fuer `orbit_testbed.gd`, falls die
  verbleibende Input-/Hint-Verdrahtung noch aus dem Scene-Script
  herausgezogen werden soll

## Prioritaet 16 - View Phase E: Scope-relatives Zoom statt Root-Anker-Hybrid - erledigt

Ziel:
Die Kamera-Semantik wieder an das Spieler-Mental-Model angleichen:
Klick auf einen Body = dieser Body bleibt der Kameraanker; Zoom arbeitet
relativ zu einem expliziten lokalen Scope statt ueber einen impliziten
Root-/Weltanker-Blend.

Erledigt:

- neuer reiner `OrbitCameraScope`-Helper bestimmt den sichtbaren Scope
  fuer `BLACK_HOLE`/Root, `STAR`, `PLANET` und `MOON`
- `OrbitZoomModel` ist jetzt rein scope-relativ; `target_view_scale`
  ist exakt `scope_fit_scale * zoom_factor`
- die P16.1-Korrektur fuehrt fuer verschachtelte `wide`-Views wieder
  einen weichen Focus->Root-Anchor-Blend ein, ohne die scope-relative
  Scale-Semantik selbst anzutasten
- der Folgefix zieht diese Stabilisierung jetzt von `wide` auf eine
  sichtbarkeitsbasierte Root-Lock-Semantik hoch: `wide / fit / detail`
  bleiben reine Zoommodi; der Kameraanker folgt dem Root immer dann,
  wenn das BH im aktuellen Bildmassstab sinnvoll sichtbar ist
- ein kurzlebiger world-space-Follow-Regressionpfad im
  `OrbitCameraController` ist wieder entfernt; der Kameraanker folgt
  jetzt direkt dem berechneten Fokus-/Wide-Anker statt zeitlich
  hinterherzulaufen
- der sichtbare Fokus-Closeup folgt jetzt dem geglaetteten aktuellen
  View-Scale statt direkt dem rohen Zielzoom; Nahdetail und
  Fokus-Footprint wachsen dadurch waehrend der Zoom-Interpolation
  weicher mit
- der High-Zoom-Detailpfad traegt jetzt einen verlaengerten Tail ueber
  das fruehere `~1500%`-Plateau hinaus, damit `10000%` wieder sichtbar
  naeher an Planeten, Monde und Sterne heranrueckt; Wheel-Zoom nutzt
  dafuer feinere `1.12x`-Schritte
- Fokuswechsel resetten bewusst auf `fit` (`zoom_factor = 1.0`) und
  loeschen manuelles Pan
- Root-/BH-Overview ist jetzt nur noch explizit ueber Root-Fokus bzw.
  `Home` erreichbar
- HUD-Zoomlabels wurden von `world / fit / focus` auf
  `wide / fit / detail` umgestellt
- HUD-Frame-Labels unterscheiden jetzt zwischen `root-overview`,
  `root-lock` und `focus-lock`; kleine Hysterese verhindert Flackern im
  Uebergangsband
- neue Tests fuer `OrbitCameraScope`; Zoom- und Controller-Tests auf
  die neue Scope-Semantik umgestellt
- Controller-Regressionstests pinnen jetzt zusaetzlich die
  sichtbarkeitsbasierte Umschalt-Stetigkeit nahe `root_lock_phase = 0.5`
  sowie die Pan-Unabhaengigkeit des Lock-Zustands
- Controller-Regressionstests pinnen jetzt zusaetzlich dynamische
  No-Drift-Faelle fuer schnelle Fokus- und Root-Bewegung
- die fruehere P14.1-Invariante "gleiche Zoomzahl = gleicher
  Welt-Massstab" wurde bewusst endgueltig aufgegeben

Offen / spaeter:

- kurze manuelle Editor-Pruefung der neuen Scope-Zoom-Haptik in
  `starter_world` und `sample_system`
- spaeter optional feineres Scope-Tuning pro Body-Kind, falls Sterne,
  Planeten oder Monde im Playtest noch zu eng oder zu weit geframet
  wirken

## Prioritaet 17 - Baseline / Snapshot / Generator sauberziehen - erledigt

Ziel:
Die rote Test-Baseline, der offensichtliche planetare Render-Hot-Path
und die naechste kleine Content-Basis sollten vor weiterem Survey- oder
Content-Ausbau wieder sauber und reproduzierbar sein.

Erledigt:

- `run_tests.bat` funktioniert jetzt wieder direkt aus PowerShell/CMD;
  der direkte Headless-Aufruf und der Batch-Entry laufen beide gruen
- der Kamera-Uebergang nahe `root_lock_phase ~= 0.5` wurde fuer den
  Anker-Blend geglaettet; die bestehende
  `test_visibility_transition_is_continuous`-Regression bleibt gruen
- `OrbitBodyVisual` cached jetzt die 1x1-Fallback-Texturen modulweit und
  dedupliziert identische Theme-Applies ueber eine stabile Signatur
- der Renderer liest planetare Themes jetzt bevorzugt aus einem
  read-only `DerivedSnapshotCache` statt pro Frame blind
  `EnvironmentService.describe_body(...)` fuer jeden Body neu
  aufzufalten
- der Snapshot invalidiert bewusst nur auf `TimeService.sim_tick`,
  `LocalBubbleManager.focus_changed` und `WorldLoader.world_loaded`
- HUD und Debug-Overlay weisen die aktuelle Thermal-Vereinfachung jetzt
  explizit ueber `Primary source: ...` aus
- legitime Cross-Root-Pfade (`INACTIVE_NO_LCA`) loggen nicht mehr als
  Fehler
- `generated_system` haengt jetzt als deterministische Welt am
  bestehenden `WorldLoader`-Pfad; keine Sonder-Registry, keine neue
  Simulationswahrheit
- die Doku trennt jetzt wieder sauber zwischen genau zwei
  projekt-eigenen Sim-Autoloads und plugin-provided Addon-Autoloads

## Prioritaet 18 - Large-World Pilot / Dirty Tracking - erledigt

Ziel:
Den ersten grossen Mehr-Root-Slice bauen, ohne in Chunk-/Sektorlogik
abzugleiten, und gleichzeitig die offensichtlichen O(N)-Hotpaths vor
dem Content-Ausbau entschlacken.

Erledigt:

- `OrbitService` emittiert jetzt explizit `bodies_updated(ids, reason)`
  fuer geaenderte Runtime-Bodies
- `BubbleActivationSet` rebuilt im steady-state nicht mehr blind den
  ganzen geladenen Slice, sondern reagiert auf dirty markierte IDs /
  Teilbaeume
- `DerivedSnapshotCache` fuehrt jetzt ein explizites Interest-Set und
  refreshes bei verdrahtetem `OrbitService` nur dirty-abhaengige
  Bodies; `sim_tick` bleibt der Fallback
- neue Large-World-Datenmodelle unter `src/sim/world/`:
  `GalaxyDef`, `RootSystemManifest`, `RootStarManifest`,
  `RootSystemGenerator`, `PilotGalaxyWorld`
- `WorldLoader` kann jetzt Galaxy-Katalog und gezielte Root-
  Materialisierung fuer `pilot_galaxy`
- `GalaxyStreamingController` materialisiert focus-/zoomgetrieben
  maximal einen Nachbar-Root zusaetzlich
- `GalaxyProxyRenderer` zeigt entfernte BH-/Stern-Proxies in
  Galaxy-Koordinaten
- `orbit_testbed.gd` unterstuetzt jetzt `pilot_galaxy` als 3-Root-
  Pilotwelt (1 Hero-Root, 2 generierte Roots)
- neue Tests decken Dirty-/Interest-Hotpaths, deterministische
  Root-Materialisierung und Proxy<->Detail-Handoff fuer Position und
  Velocity ab

## Prioritaet 19 - Streaming-Stabilitaet / Delta-Materialisierung - erledigt

Ziel:
Den 3-Root-Pilot aus dem ersten Architektur-Slice von einem harten
Root-Swap auf einen ruhigeren kontinuierlichen Streaming-Pfad ziehen,
ohne das Projekt in Sektor-/Chunk-Logik umzubauen.

Erledigt:

- `GalaxyStreamingController.update(delta_s, zoom_factor)` arbeitet
  jetzt zeitbasiert statt framebasiert
- Neighbor-Streaming nutzt jetzt Hysterese
  (`enter <= 0.55`, `exit >= 0.65`) plus `1.5 s` Keepalive
- `prewarm` nutzt eine eigene billige Shell
  (`enter <= 0.90`, `exit >= 1.00`)
- `WorldLoader.materialize_galaxy_roots(...)` materialisiert jetzt
  delta-basiert und behaelt unveraenderte residente Root-Slices samt
  `BodyState` / `current_mode`
- `BubbleActivationSet` behandelt Registry-Churn jetzt ueber
  `topology_dirty` statt ueber pauschalen Full-Rebuild
- neue Tests decken Hysterese, Keepalive, Fokus-Ping-Pong,
  Delta-Materialisierung, Cache-Bereinigung und einen test-only
  30-Root-Stresspfad ab

## Prioritaet 20 - Playtest-Diagnostik / Boundary-Hardening - erledigt

Ziel:
Bevor der 3-Root-Pilot gefuehlt im Editor beurteilt wird, sollten die
letzten kleinen Boundary-/Stress-Luecken headless geschlossen und der
Runtime-Pfad mit einer brauchbaren Streaming-Diagnose ausgeruestet
werden.

Erledigt:

- `GalaxyStreamingController` liefert jetzt einen read-only
  Debug-Snapshot mit Fokus-/Resident-/Neighbor-/Prewarm-Zustand,
  Keepalive-Restzeit und letztem Zoom-Faktor
- derselbe Controller fuehrt jetzt einen kleinen Ringbuffer der letzten
  Streaming-Ereignisse (`focus_changed`, `neighbor_enter`,
  `keepalive_started`, `keepalive_expired`, `neighbor_exit`,
  `prewarm_enter`, `prewarm_exit`)
- das `F3`-Debug-Overlay zeigt diesen Streaming-Snapshot im
  Large-World-Modus direkt mit an
- neue Tests pinnen den `prewarm`-Boundary-Contract fuer
  `0.89 / 0.90 / 0.91 / 1.00`
- ein neuer Paritaetstest sichert, dass uebernommene Pilot-Manifeste im
  Stress-Helper ueber dieselbe `WorldLoader.build_defs_for_root_manifest(...)`-
  Pipeline dieselbe Def-Signatur liefern
- der 30-Root-Stresstest leitet seinen Fokus-/Interest-Root jetzt voll
  aus Manifest-/Registry-Daten ab statt aus Magic-Strings

## Prioritaet 21 - Pilot-Playtest-Gate - erledigt

Ziel:
Den headless-gruenen 3-Root-Pilot als echte Runtime-/UX-Integration
gegen die neuen Streaming-Diagnosepfade pruefen, bevor die Root-Anzahl
hochgezogen wird.

Erledigt:

- der 3-Root-Pfad wurde gegen Startup, Hysterese, Prewarm, Keepalive,
  Proxy-/Detail-Handoff, Fokus-Ping-Pong und `NUMERIC_LOCAL`-Stabilitaet
  als Gate durchgespielt
- der Ringbuffer-/Overlay-Pfad war dafuer die explizite
  Diagnosegrundlage
- Ergebnis: `pilot_galaxy` liest ruhig genug, um kontrolliert auf einen
  produktiven 10-Root-Slice hochzuziehen

## Prioritaet 22 - Produktiver 10-Root-Scale-up - erledigt

Ziel:
Den validierten 3-Root-Pilot nicht aufzuweiten, sondern als Referenz
stehenzulassen und die naechste Root-Stufe als eigene produktive Welt zu
shippen.

Erledigt:

- neue produktive Galaxy `scaleup_galaxy_10` als separater Named-World-
  Pfad
- `pilot_galaxy` bleibt unveraendert der 3-Root-Referenzslice
- sieben Zusatz-Roots laufen jetzt ueber einen produktiven Shared-
  Helper in `src/sim/world/`; `StressGalaxyFactory` ist nur noch Wrapper
- `WorldLoader` und `orbit_testbed.gd` kennen jetzt
  `scaleup_galaxy_10`, ohne den Default von `starter_world` zu aendern
- `OrbitViewRenderer` schneidet Cross-Root-Detailvisuals schon vor
  `compose_view_position_m()` ab, damit residenter Neighbor-Churn kein
  Warning-Spam mehr im Detail-Layer erzeugt
- `GalaxyStreamingController` faellt jetzt bei fehlenden Galaxy-
  Defaults robust auf `root_ids()[0]` als primaeren Fokus zurueck
- neue Tests pinnen die 10-Root-Welt, Produkt-/Stress-Paritaet der
  sieben Zusatz-Roots, den Renderer-Kurzschluss fuer `pilot_galaxy` und
  `scaleup_galaxy_10` sowie den Fokus-Fallback

## Prioritaet 23 - Produktiver 30-Root-Scale-up - erledigt

Ziel:
Den produktiven Large-World-Pfad nach dem 10-Root-Slice kontrolliert auf
30 Roots hochziehen, ohne neue Streaming-Regeln, neue Proxy-Typen oder
eine zweite Produkt-/Stress-Logik einzufuehren.

Erledigt:

- neue produktive Galaxy `scaleup_galaxy_30` als separater Named-World-
  Pfad
- neuer produktiver `ScaleupGalaxyCatalogFactory` als einziger
  Catalog-Builder fuer `scaleup_galaxy_10`, `scaleup_galaxy_30` und den
  test-only Stresspfad
- deterministischer Spacing-Guard mit radialem Auto-Relax nur fuer
  generierte Zusatz-Roots und hartem Fehler nach `16` Versuchen
- `WorldLoader` und `orbit_testbed.gd` kennen jetzt
  `scaleup_galaxy_30`, ohne den Default von `starter_world` zu aendern
- neue Tests pinnen die 10-Root-Content-Signatur, die 30-Root-
  Produkt-/Stress-Paritaet, den Spacing-Guard inklusive Forced-
  Collision- und Hard-Fail-Pfad sowie explizit versteckte Cross-Root-
  Orbit-/Trail-Visuals

## Prioritaet 23.1 - Streaming-/Diagnose-Qualitaet haerten - erledigt

Ziel:
Vor dem naechsten groesseren 30-Root-Playtest die auffaelligen
Review-Funde im Runtime-/Diagnosepfad entfernen, ohne die bestehende
Large-World-Architektur umzubauen.

Erledigt:

- `WorldLoader` fuehrt vorbereitete Root-Slices jetzt nur noch in genau
  einem cache-scopegebundenen Loader-Cache pro aktiver Welt/Galaxy
- `GalaxyStreamingController.prewarm` fuellt nur noch diesen
  Loader-Cache und haelt keine zweite Root-Def-Kopie mehr
- das `F3`-Debug-Overlay liest bei verdrahtetem
  `DerivedSnapshotCache` strikt snapshot-only; Cache-Miss bleibt
  bewusst `n/a` statt live `ThermalService.describe_body(...)`
- neue Tests pinnen den loader-scoped Prewarm-Cache und den
  snapshot-only-Overlay-Contract
- `test_orbit_body_visual.gd` gibt erzeugte Visual-Nodes wieder frei,
  damit die Rendering-Suite keine offensichtlichen Node-Leaks mehr
  akkumuliert

## Prioritaet 24 - Root-Overview-LOD und Large-World-Performance im Editor validieren

Ziel:
Den neuen Performance-Block als echte Runtime-/Feel-Integration gegen
`scaleup_galaxy_30` pruefen, bevor weitere Root-Anzahl, planetare
Proxies oder neue Layout-/Polish-Bloecke angegangen werden.

Konkreter Arbeitsblock:

- `scaleup_galaxy_30` im Editor / Testbed manuell durchzoomen
- dieselbe Szene gezielt in drei Zustaenden vergleichen:
  `F3 aus + ROOT_OVERVIEW`, `F3 an + ROOT_OVERVIEW`,
  `Detailansicht`
- bestaetigen, dass die ruhige 10-/30-Root-Streaming-Haptik erhalten
  bleibt:
  Neighbor-/Prewarm-Wechsel, Keepalive, Fokus-Ping-Pong und
  Root-Wechsel ueber mehrere `shade_*`-Kandidaten
- dabei jetzt explizit den neuen Overview-Contract pruefen:
  im `ROOT_OVERVIEW` bleiben nur BH plus direkte Sterne sichtbar;
  planetare Detailwolken, planetare Orbitlinien und planetare Trails
  verschwinden
- dabei zusaetzlich gegenpruefen, dass generierte Root-Systeme
  im Detailblick wirklich auf derselben `obsidian`-Baseline lesen:
  gleiche BH-Stern-Skalierung, vergleichbarer System-Footprint und kein
  sichtbarer Sprung zwischen `obsidian` und `shade_*`
- dabei speziell bestaetigen, dass die jetzt normalisierte planetare
  Generator-Skala keine scheinbar BH-nahen Planetenausreisser oder
  rootweit kollidierenden Orbitbilder mehr erzeugt
- das bestehende `F3`-Overlay mit Streaming-Block mitlaufen lassen und
  darauf achten, dass es im `ROOT_OVERVIEW` jetzt wirklich als
  kompakte Summary statt als Volltabelle liest
- dabei explizit pruefen, dass `F3` den Hotpath nicht mehr selbst
  verfremdet:
  Thermal-/Environment-Werte nur aus Snapshot, Cache-Miss sichtbar als
  `n/a`, keine spuerbare Overlay-Chatterei
- die neue Proxy-Tier-Hysterese gegenpruefen:
  BH-only in weiter Fernsicht, Stern-Proxies erst in naehere Stufe,
  kein Flackern beim Pendeln an der Sichtbarkeitsgrenze
- bestaetigen, dass der root-aware Renderer-Kurzschluss auch in der
  30-Root-Welt keine sichtbaren Cross-Root-Detailleichen hinterlaesst
- kurzen Profil-/Playtest fuer einen Detail-Root plus Proxies in der
  30-Root-Welt machen und dabei besonders auf Vorher/Nachher-FPS bzw.
  Frame-Zeit im `ROOT_OVERVIEW` achten

Erfolgskriterium:

- `scaleup_galaxy_30` liest sich weiterhin als kontinuierlicher Fokus-/
  Scale-Pfad und nicht wie Root-Chunks oder versteckte Sektoren
- der neue `ROOT_OVERVIEW` ist visuell klarer:
  BH + direkte Sterne statt planetarer Chaoswolke
- `F3` ist im Overview jetzt diagnostisch nuetzlich, ohne die Szene
  selbst merklich schwer zu machen
- die neue screen-stabile Proxy-Groesse und das Proxy-Tiering machen
  entfernte BH-/Sternsysteme klar genug sichtbar, ohne den
  Root-Ueberblick zu ueberladen
- danach entscheiden, ob der naechste Block eher ein weiterer
  View-/Performance-LOD-Pass (z. B. Orbitgeometrie/Trails weiter
  trimmen) oder planetare Proxy-/Derived-Folgearbeit wird

## Danach - Weitere planetare Umweltableitung

Nach dem ersten Guardrail-Block ist der naechste groessere Simulations-
Schritt wieder die planetare Ableitung:

- additive Mehrquellenstrahlung fuer Mehrstern-Faelle als naechster
  echter `ThermalService`-Block
- Wasser-/Volatile-Logik als naechster Fundamentblock fuer globale
  planetare Oekosystem-Typen
- weitere Atmosphaerenfaktoren jenseits des additiven `greenhouse_delta_k`
- spaeter Jahresmittel-/Stabilitaetslogik statt nur momentaner
  Bandklassifikation
- spaeter weitere Umweltgroessen / Strahlung / Atmosphaerenklassen

Zielbild fuer diesen Strang:

- weg von nur momentanen Drei-Band-Temperaturen
- hin zu glaubwuerdigen planetaren Gesamtzustaenden wie Eiswelt,
  trockene Welt, saisonal habitabler Planet oder greenhouse-getriebene
  Heisswelt mit spaeterer Volatile-/Stabilitaetsableitung

## Kleiner moeglicher View-Folgeblock

- spaeter `DESERT` erst dann einfuehren, wenn die Sim eine bessere
  Ariditaets-/Wassergrundlage liefert
- den neuen galaktischen Screen-Backdrop im Editor gezielt
  gegenpruefen: bleiben HUD, Orbit-Linien, Trails und Body-Silhouetten
  in `starter_world` und `sample_system` auch bei Zoom/Pan/Fokuswechseln
  sauber lesbar, ohne dass helle Nebelzonen die Szene ueberladen
- dabei auch bestaetigen, dass der Backdrop wirklich rein screen-fixed
  liest und nicht wie ein versehentlich mitwandernder View-/Root-Layer
- falls spaeter neue Artefakte am Backdrop auftauchen, zuerst den
  vorhandenen Debug-Pfad mit `control`, `viewport`, `render`, `bake`,
  `composition` und den Resize-/Sync-Zaehlern nutzen, statt sofort
  wieder einen per-frame-Follow-/Parallaxe-Fix zu versuchen
- die neuen Archetypen-Referenzen im Editor gezielt gegenpruefen:
  lesen `temperate_reference.png`, `frozen_reference.png` und
  `hot_scorched_reference.png` im Nahzoom wirklich als "Bild fuehrt,
  Shader veredelt", ohne dass gebackene Rims oder alte Pattern wieder
  zu dominant werden
- den neuen Stern-Hybrid im Editor gegenpruefen:
  liest `star_reference.png` in Fern- und Nahansicht wirklich als
  dieselbe Sonne, waehrend Halo, Randaktivitaet und die alte
  `star_detailmap.png` nur noch veredeln statt die sichtbare
  Solaroberflaeche wieder zu uebermalen
- bei `TEMPERATE_OCEAN` und `FROZEN` jetzt speziell gegenpruefen, ob der
  reduzierte Glow-/Overlay-Pfad und die entfernten Shader-Wolken den
  gewuenschten Schritt "mehr Originalbild, weniger Kunst-Layer"
  tatsaechlich sauber treffen
- im selben Playtest jetzt gezielt schauen, ob der neue einheitliche
  Referenz-Layer fuer `TEMPERATE_OCEAN` und `FROZEN` Fern- und
  Nahansicht wirklich als denselben Planeten lesen laesst und die
  Rotation dabei im neuen verzerrungsfreien disc-preserving Pfad klar
  genug sichtbar bleibt
- dabei speziell pruefen, ob die neue rotationsgekoppelte
  Planet-Referenz fuer `TEMPERATE_OCEAN`, `FROZEN` und
  `HOT_SCORCHED` in Bewegung natuerlich genug liest oder ob der
  jeweilige Archetyp noch eigene Rotation-/Blend-Tunings braucht
- als naechsten moeglichen Quality-Folgeblock die reicheren
  Referenzbilder weiter aufspalten:
  z. B. spaeter getrennte Surface-/Cloud-/Night-Lights-Masks fuer
  `TEMPERATE_OCEAN` statt einer einzigen zusammengefalteten Referenz
- danach entscheiden, ob auch `BARREN` einen eigenen planetaren
  Hybridpfad bekommen soll oder bewusst als letzter klar
  shader-first-Archetyp stehenbleibt
- falls spaeter ein BH-zentrierter oder root-aware Spezialhintergrund
  gewuenscht ist, ihn als separaten View-Pass planen statt den neuen
  dekorativen Screen-Backdrop still semantisch aufzuladen
- spaeter Moon-spezifische Verfeinerungen, wenn die gemeinsamen
  Klima-Archetypen allein noch nicht genug Charakter tragen
- spaeter optional noch feineres Texture-/Theme-Caching im Renderer,
  falls die Body-Zahl deutlich waechst
- spaeter optional kleine reine Feel-Tuning-Paesse fuer
  Scope-Radius-/Margin-Werte, falls der neue Kamera-Slice im Playtest
  noch Body-Kind-spezifisch Feinschliff braucht

## Offene Folgeaufgabe - NUMERIC_LOCAL Tuning / staerkere Policies

- spaeter numerische Tuning-Arbeit jenseits des aktuellen
  `Cap+Warn`-Best-Effort-Pfads, falls hoehere `time_scale` praktisch
  wichtig werden
- falls Bodies nach dem neuen Exit-Budget ueber lange Strecken
  numerisch kleben bleiben, gezielt ueber strengere Rejoin-Strategien
  oder ein explizites analytisches Re-Seeding nachdenken statt ueber
  blinde Rueck-Snaps
- moegliche spaetere strengere Overspeed-Policies oder weitere
  High-Speed-Regeln im `OrbitService`
- Topologie-Helfer sind jetzt zentralisiert; spaetere Folgearbeit liegt
  eher in weiteren Derived-/Planeten-Systemen als in erneutem
  Architektur-Grundaufriss

## Danach - Generator ausbauen und Survey vorbereiten

- `generated_system` ist jetzt als erster deterministischer
  Showcase-Seed im Loader vorhanden
- der neue per-root-Generator treibt bereits `pilot_galaxy`; als
  naechster Generator-Block geht es nach dem Pilot-Playtest um mehr
  Seeds, mehr Stern-/Root-Varianten und spaeter mehr Galaxy-Layouts
  statt nur eines festen Beispiels
- erst auf dieser Basis eine read-only Survey-/Notebook-/Scanner-UX
  planen
- auch diese spaetere Survey-Schicht bleibt reiner Viewer ueber
  bestehender Sim-Wahrheit und fuehrt keine neue autoritative
  Gameplay-Schicht ein

## Spaeter - BH-Star-Ellipsen und weitere Root-Welt-Politur

- `sample_system` bleibt bewusst klein und sauber als kompakte
  Referenzwelt
- `starter_world` ist jetzt bereits groesser und asymmetrischer, kann
  spaeter aber weiter ausgebaut oder durch eine noch groessere
  Referenzwelt ergaenzt werden
- die BH-gebundenen Sternorbits muessen langfristig nicht auf perfekten
  Kreisen bleiben; elliptische BH-Sternbahnen sind der naechste
  naheliegende Welt-/Content-Folgeblock

## Kleiner naechster UX-Folgeblock

- falls die HUD-Sprache trotz P13.1 weiter unklar wirkt, kann spaeter
  ein kleinerer Layout-/Dichte-Pass folgen
- dabei gilt bewusst: neue HUD-Zeilen brauchen kuenftig eine kurze
  Begruendung gegen unnoetige Anzeige-Dichte

## Bewusst nicht jetzt

- kein fotorealistischer Texture-/Asset-Pass fuer Planeten
- qualitative Umweltklassen in P8 nur als Text, keine Farben/Badges
- auch P9 zeigt Greenhouse-/Surface-Werte nur als Text, keine
  renderer-seitige Visualisierung
- keine neue Gameplay-/Schiffs-/Fraktionsschicht
- keine Survey-/Scanner-Schicht, die neue Simulationswahrheit einfuehrt
- keine ueberhastete Generator-Spielerei ohne sauberes Weltmodell
- kein `DESERT`-Archetyp ohne staerkere Wasser-/Ariditaetsbasis
- keine Ausweitung der Autoload-Liste
