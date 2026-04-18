# Graviton - Next Steps

Stand: 2026-04-18

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

## Prioritaet 1 - Foundation Phase A: Step 2 Bubble / Frame-Modell - erledigt

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

## Danach - Weitere planetare Umweltableitung

Nach dem ersten Guardrail-Block ist der naechste groessere Simulations-
Schritt wieder die planetare Ableitung:

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
- spaeter Moon-spezifische Verfeinerungen, wenn die gemeinsamen
  Klima-Archetypen allein noch nicht genug Charakter tragen
- spaeter optional Theme-Caching im Renderer, falls die Body-Zahl
  deutlich waechst

## Offene Folgeaufgabe - NUMERIC_LOCAL Tuning / staerkere Policies

- spaeter numerische Tuning-Arbeit jenseits des aktuellen
  `Cap+Warn`-Best-Effort-Pfads, falls hoehere `time_scale` praktisch
  wichtig werden
- moegliche spaetere strengere Overspeed-Policies oder weitere
  High-Speed-Regeln im `OrbitService`
- spaeter Topologie-Helfer sinnvoll zentralisieren, wenn die
  Activation-/Mehrwurzel-Pfade stabil sind

## Spaeter - Prozedurale Systeme

- Generator-Konzept fuer Root-Systeme, Sterne, Planeten und Monde
- Zufallsbereiche fuer Orbitachsen, Exzentrizitaeten und Orientierungen
- deterministische Seeds / reproduzierbare Welten

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
- keine ueberhastete Generator-Spielerei ohne sauberes Weltmodell
- keine Ausweitung der Autoload-Liste
