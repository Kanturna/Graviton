# Graviton - Decisions

## 2026-04-23 - Planetare Zustandsbasis landet als eigener Jahres-Layer vor jeder Life-Simulation

Der naechste planetare Simulationsschritt wird nicht als direkte
Life-/Biosphaerenlogik gebaut. Stattdessen bekommt `Graviton` zuerst
einen eigenen read-only Jahres-/Weltcharakter-Layer neben der
bisherigen momentanen Thermal-/Environment-Aussage.

Konsequenz:

- `EnvironmentService` bleibt die Antwort auf den **aktuellen**
  Zustand eines planetaren Bodies
- `PlanetaryStateService` beschreibt den **Charakter ueber das Jahr**
  und fuehrt dafuer eigene Achsen wie `Volatiles`, `Buffering`,
  `Seasonality`, `Stability` und `Thermal Extremity` ein
- die neuen Achsen bleiben bewusst chemie-agnostisch; sie sollen spaeter
  unterschiedliche Biochemie- oder Life-Pfade tragen koennen, statt
  frueh einen Earth-first-Pfad einzubetonieren
- fuer sampled-year-Analysen wird kein Langzeit-State in
  `BodyState`, `TimeService` oder `OrbitService` aufgebaut;
  Jahresprofile entstehen read-only ueber einen analytischen
  `PlanetaryYearSampler`
- die dafuer benoetigte Thermal-/Atmosphere-Math wird als pure
  Helper-Schicht extrahiert, damit Live-Pfad und Jahres-Sampler
  dieselbe Math teilen und nicht still auseinanderdriften
- annualisierte sampled-year-Profile werden pro Body lazy gecacht,
  weil sie in v1 nur von statischen `BodyDef`-/Orbit-Daten abhaengen;
  `DerivedSnapshotCache` bleibt darueber nur die View-/HUD-Glue-Schicht
- HUD und Root-Inspector duerfen die neue `World:`-Lesart direkt
  anzeigen, ohne daraus schon eine versteckte Life-Aussage zu machen
  oder Simulationswahrheit in die View zu verschieben

## 2026-04-22 - Survey-UX startet als residenter Root-Inspector vor einem globalen Galaxy-Atlas

Die erste Survey-/Navigationsoberflaeche fuer Large Worlds startet nicht
als globale Liste oder Suchansicht ueber alle Systeme. Stattdessen kommt
zuerst ein fokussierter Inspector fuer genau den aktuell residenten
Fokus-Root.

Konsequenz:

- V1 der Survey-UX ist ein `RootInspectorOverlay` fuer den aktuell
  ausgewaehlten BH-/Root
- das Panel oeffnet nur bei expliziten Root-Klicks
  (BH-Proxy oder BH-Body), nicht bei `Home`, `Tab`, `Backspace` oder
  passiven Residency-Wechseln
- das Panel zeigt nur residente Daten
  `BLACK_HOLE -> STAR -> PLANET -> MOON`; es gibt noch keine
  nichtresidenten Root-Summaries
- der Inspector bleibt rein view-seitig:
  Daten kommen aus `UniverseRegistry`, `UniverseTopology` und
  `DerivedSnapshotCache`; Fokuswechsel laufen weiter ueber
  `orbit_testbed.gd` als einzige Autoritaet
- der `ROOT_OVERVIEW`-Performance-Contract bleibt fokus-only, bekommt
  aber einen expliziten Ausnahmefall:
  waehrend der Inspector fuer den aktuellen Fokus-Root offen ist, darf
  das Testbed wieder root-lokales Planet-/Moon-Interest aktivieren,
  damit Planetentypen und Climate-Badges sofort sichtbar bleiben
- ein globaler Galaxy-Atlas ueber leichte Root-Summaries ist damit
  ausdruecklich ein Folgeblock, nicht Teil dieser ersten Inspector-Stufe

## 2026-04-22 - 100-Root-Scale-up bleibt ein Catalog-/Proxy-Schritt statt ein Residency-Rewrite

Der Schritt von 30 auf 100 Roots wird nicht ueber mehr geladene
Detailslices, weitere Neighbor-Shells oder einen neuen Spatial-Index
erreicht. Stattdessen bleibt die bestehende Large-World-Invariante
erhalten: ein Fokus-Root ist resident, maximal ein Neighbor-Root kommt
zusaetzlich dazu. Die Skalierung passiert ueber billigere Catalog- und
Proxy-Arbeit.

Konsequenz:

- `scaleup_galaxy_100` ist nur eine weitere produktive Named-Galaxy
  ueber denselben `ScaleupGalaxyCatalogFactory`
- `scaleup_galaxy_10`, `scaleup_galaxy_30` und `scaleup_galaxy_100`
  werden alle ueber feste Content-Signaturen gegen Drift gepinnt
- `GalaxyDef` haelt einen lazy Neighbor-Order-Cache pro Fokus-Root,
  damit `GalaxyStreamingController` seine Neighbor-/Prewarm-Auswahl
  nicht mehr frameweise ueber neue Vollsortierungen zieht
- `GalaxyProxyRenderer` spart 100-Root-Fernsicht ueber
  Viewport-Culling plus bestehendes BH-only-/Stern-Proxy-Tiering aus,
  statt ueber mehr Streaming-Komplexitaet
- Sichtbarkeit und Residency bleiben dabei bewusst getrennt:
  ein residenter Neighbor darf off-screen und damit ungezeichnet sein
- wenn ein groesserer Catalog spaeter Probleme macht, wird zuerst an
  Proxy-/Cache-/Budget-Pfaden gearbeitet, nicht das Resident-Limit
  aufgeweicht

## 2026-04-22 - `ROOT_OVERVIEW` bleibt ein View-LOD fuer BH plus direkte Sterne

Der Large-World-Root-Overview soll nicht mehr dieselbe komplette
Detailszene nur kleiner darstellen. Stattdessen bleibt er bewusst ein
eigener View-LOD mit klarer Lesbarkeit und deutlich geringerer
per-frame-Arbeit.

Konsequenz:

- im `ROOT_OVERVIEW` bleiben nur das Fokus-BH und seine direkten
  `STAR`-Kinder sichtbar
- Planeten, Monde, ihre Orbitlinien und ihre Trails gehoeren erst in
  naehere Ansichten; sie werden im Overview vor der
  `compose_view_position_m()`-Pipeline frueh ausgesiebt
- die rootweite Derived-Last wird dafuer nicht in
  `DerivedSnapshotCache` selbst geloest, sondern im Caller
  `orbit_testbed.gd` ueber ein view-abhaengiges Interest-Set
- `ROOT_OVERVIEW` bleibt in diesem Block bewusst root-focus-only; ein
  kuenftiger Leaf->Overview-UX-Pfad muss zuerst auf den Parent-Root
  umschalten
- der Proxy-Layer folgt derselben Lesbarkeitsidee:
  entfernte Roots sind BH-only, Stern-Proxies kommen erst oberhalb
  einer hysteretischen Sichtbarkeitsgrenze dazu
- die Streaming-Semantik selbst bleibt dabei unberuehrt; der Block ist
  bewusst View-LOD und keine Residency-/Bubble-Entscheidung

## 2026-04-22 - Generierte Root-Systeme nehmen `obsidian` als Skalenstandard

Die ersten Large-World-Playtests haben gezeigt, dass nicht nur die
Proxy-Icons, sondern auch die innere Root-System-Skalierung zwischen
`obsidian` und generierten Roots visuell vergleichbar bleiben muss.
Darum nehmen generierte Root-Systeme jetzt bewusst `obsidian` /
`starter_world` als Standard fuer BH-Stern-Lanes und Root-Footprint.

Konsequenz:

- `onyx`, `umbra` und `shade_*` nutzen jetzt denselben
  `system_extent_m`-Baselinewert wie `obsidian`
- generierte Roots nutzen jetzt dieselbe Standard-Sternanzahl und
  dieselben BH-Stern-Orbit-Radien/-Perioden wie die `obsidian`-Vorlage
- der planetare Generator nutzt fuer generierte Roots jetzt ebenfalls
  eine `obsidian`-artige lokale Orbit-Skala statt alter
  AU-/Luminositaets-basierter Fernbahnen
- Variation bleibt weiter in Sternmassen, Leuchtkraeften, Phasen,
  Rotationen und Planetensystemen, nicht mehr in einer still kleineren
  Root-System-Skala

## 2026-04-22 - `NUMERIC_LOCAL` verlaesst den numerischen Pfad nur noch ueber budgetierten Rejoin

Der Rueckwechsel `NUMERIC_LOCAL -> KEPLER_APPROX` bleibt weiter eine
explizite OrbitService-Entscheidung, darf aber nicht mehr blind auf die
analytische Loesung snappen, wenn der aktuelle numerische Zustand zu
weit davon entfernt ist.

Konsequenz:

- `OrbitService` prueft beim Exit jetzt relative Rejoin-Budgets fuer
  Positions- und Velocity-Delta gegen die analytische Kepler-Loesung
- liegt der Delta ueber Budget, bleibt der Body autoritativ in
  `NUMERIC_LOCAL` und wird im selben Tick numerisch weiterintegriert
- `ThermalService` und darauf aufbauende Derived-Services sehen dadurch
  keinen stillen analytischen Rueck-Snap mehr aus dem Exit-Pfad
- Exit-Block-Warnings werden dedupliziert; ein neuer Wish oder ein
  erfolgreicher Exit setzt den Warning-Zustand wieder zurueck

## 2026-04-20 - Produktive Scale-up-Galaxien laufen ueber genau einen Catalog-Builder mit Spacing-Guard

Nach `pilot_galaxy` und `scaleup_galaxy_10` wird der 30-Root-Schritt
nicht als dritter Sonderpfad gebaut. Stattdessen laufen alle
produktiven Scale-up-Galaxien sowie der test-only Stresspfad jetzt ueber
einen einzigen produktiven `ScaleupGalaxyCatalogFactory`.

Konsequenz:

- `scaleup_galaxy_10` und `scaleup_galaxy_30` sind duenne Wrapper ueber
  denselben produktiven Catalog-Builder
- `StressGalaxyFactory` ist nur noch Test-Wrapper ueber denselben
  Produktpfad und darf keine eigene Zusatz-Root-Logik mehr tragen
- produktive Large-World-Layouts koennen dadurch ueber feste
  Content-Signaturen gegen Drift gepinnt werden
- der Catalog-Builder fuehrt den ersten produktiven Spacing-Guard:
  `distance >= 3.0 * (extent_a + extent_b)`
- nur generierte Zusatz-Roots duerfen fuer diese Regel radial nach
  aussen relaxed werden; Pilot-/Hero-Roots bleiben positionsstabil
- Seed, Winkel und Detail-Content eines Zusatz-Roots bleiben dabei
  erhalten; nur `galaxy_position_m` darf sich aendern
- bei Nicht-Konvergenz nach `16` Relax-Versuchen bricht der Builder
  explizit mit Fehler ab; es gibt keinen stillen Overlap und keinen
  zufaelligen Fallback

## 2026-04-20 - Der 3-Root-Pilot bleibt Referenzslice; der 10-Root-Scale-up kommt als eigene Named-Galaxy

Der validierte 3-Root-Pilot wird nicht still auf 10 Roots erweitert.
Stattdessen bleibt `pilot_galaxy` exakt der kleine Referenzslice, und
der erste produktive Scale-up kommt als separate Named-Galaxy
`scaleup_galaxy_10`.

Konsequenz:

- `pilot_galaxy` bleibt genau `obsidian + onyx + umbra`
- `scaleup_galaxy_10` startet bewusst als `1 Hero + 9 generierte Roots`
- die sieben Zusatz-Roots kommen aus einem produktiven Helper unter
  `src/sim/world/`; Testcode darf diesen Pfad konsumieren, aber der
  Produktpfad zeigt nie in `src/tests/`
- `StressGalaxyFactory` ist damit nur noch Wrapper ueber dieselbe
  produktive Zusatz-Root-Logik
- Cross-Root-Detailvisuals werden fuer residente Neighbor-Roots im
  Renderer vor der Bubble-Lokalisierung abgeschnitten, statt die
  same-root Bubble-Semantik selbst zu verbiegen

## 2026-04-20 - Large-World-Streaming bleibt ein hysteretischer Shell-Pfad mit Delta-Materialisierung

Der 3-Root-Pilot bleibt bewusst ein kontinuierlicher Fokus-/Scale-Pfad
und wird nicht ueber harte Root-Swaps oder sektorartige Besitzlogik
weitergezogen.

Konsequenz:

- `GalaxyStreamingController` arbeitet jetzt zeitbasiert ueber
  `update(delta_s, zoom_factor)`
- Neighbor-Residency nutzt getrennte Enter-/Exit-Schwellen plus
  `1.5 s` Keepalive statt sofortigem Load/Unload an einer harten Kante
- `prewarm` bleibt billig und nutzt eine eigene Shell ohne Keepalive
- `WorldLoader.materialize_galaxy_roots(...)` behaelt unveraenderte
  residente Roots in der Registry und vergleicht sie ueber eine
  kanonische `defs_signature`
- `BubbleActivationSet` behandelt Registry-Churn nur noch als
  `topology_dirty`; Fokuswechsel bleiben der Full-Rebuild-Fall

## 2026-04-19 - Grosse Multi-Root-Welten bleiben ein Proxy-/Streaming-Pfad statt Bubble- oder Sektor-Rewrite

Der neue Large-World-Slice wird bewusst nicht als Erweiterung des
`LocalBubbleManager` auf mehrere Roots gebaut. Die bestehende Bubble-
Semantik bleibt same-root und fokusrelativ korrekt. Die Cross-Root-
Uebersicht entsteht stattdessen als paralleler Galaxy-Space-
Proxy-Layer.

Konsequenz:

- `GalaxyDef` / `RootSystemManifest` beschreiben den grossen
  Weltkatalog ausserhalb des aktiven Detail-Slices
- `GalaxyStreamingController` materialisiert nur den relevanten
  Root-Slice in `UniverseRegistry`
- `GalaxyProxyRenderer` zeigt entfernte Roots rein view-seitig
- die Architektur bewegt sich damit bewusst in Richtung eines
  kontinuierlichen Fokus-/Scale-Pfads und nicht in Richtung
  "Sektoren 2.0"

## 2026-04-19 - Runtime-Hotpaths fuer Bubble- und Derived-Daten werden dirty-/interest-getrieben statt Full-Scan

Vor dem Multi-Root-Content-Ausbau wurden die beiden offensichtlichen
O(N)-Hotpaths bewusst aus dem "alles jedes Tick"-Modell gezogen.

Konsequenz:

- `OrbitService` emittiert jetzt `bodies_updated(ids, reason)` als
  kleine Dirty-Schiene fuer Runtime-Konsumenten
- `BubbleActivationSet` rebuilt same-root Bodies nur noch fuer dirty
  IDs / Teilbaeume bzw. bei Fokus-/World-Wechsel voll
- `DerivedSnapshotCache` fuehrt ein explizites Interest-Set und
  refreshed bei verdrahtetem Orbit-Dirty nur abhaengige interessierte
  Bodies
- `TimeService.sim_tick` bleibt nur der konservative Fallback, wenn
  kein Dirty-Signal verfuegbar ist

## 2026-04-19 - Der erste Large-World-Milestone startet bewusst als 3-Root-Pilot

Das Ziel "spaeter 30 Roots" bleibt erhalten, wird aber nicht als erster
Sprint umgesetzt. Die Architektur und Streaming-Haptik werden zuerst an
einem kleinen, absichtlich kontrollierten Slice validiert.

Konsequenz:

- `pilot_galaxy` besteht aus genau drei Roots:
  `obsidian` als Hero-Root plus `onyx` und `umbra` als generierte Roots
- der Loader startet defaultmaessig mit genau einem residenten
  Detail-Root
- beim Herauszoomen darf maximal ein Nachbar-Root zusaetzlich resident
  werden
- Skalierung auf 10 oder 30 Roots ist ausdruecklich ein Folgeblock nach
  Pilot-Playtest und Profiling

## 2026-04-19 - Projekt-Autoload-ADR bleibt bei genau zwei projekt-eigenen Autoloads; Addon-Autoloads werden separat dokumentiert

`project.godot` listet aktuell zusaetzlich
`AntialiasedLine2DTexture` und `PhantomCameraManager` als Autoloads.
Diese Eintraege stammen aus Addons und duerfen die bestehende ADR
"genau zwei Sim-Autoloads" nicht still verwischen.

Konsequenz:

- `TimeService` und `UniverseRegistry` bleiben die einzigen
  projekt-eigenen Sim-Autoloads
- Addon-Autoloads werden explizit als plugin-provided Ausnahme
  dokumentiert statt heimlich als neue globale Wahrheit mitzulesen
- weder `AntialiasedLine2DTexture` noch `PhantomCameraManager` zaehlen
  als Erweiterung der Simulationsarchitektur

## 2026-04-19 - Thermal-/Environment-Snapshots invalidieren weiter explizit, jetzt aber dirty-/interest-getrieben

Der Renderer und das HUD brauchen dieselben Derived-Daten fuer
Environment-/Thermal-Anzeige und planetare Themes. Diese Glue-Schicht
wird bewusst nicht als neuer per-frame-Recompute versteckt.

Konsequenz:

- `DerivedSnapshotCache` fuehrt jetzt ein explizites Interest-Set
- bei verdrahtetem `OrbitService.bodies_updated(...)` rebuilt der Cache
  nur dirty-abhaengige interessierte Bodies
- `TimeService.sim_tick`, `LocalBubbleManager.focus_changed` und
  `WorldLoader.world_loaded` bleiben als explizite Invalidierungsfaelle
  bzw. Fallback erhalten
- `_process()` konsumiert nur den letzten Snapshot
- `ThermalService` und `EnvironmentService` bleiben on-demand/read-only;
  der Cache fuehrt keine neue Simulationswahrheit ein

## 2026-04-19 - `INACTIVE_NO_LCA` ist in Multi-Root-Faellen kein Fehler

Cross-Root-Nichtlokalisierbarkeit ist im Bubble-/Activation-Modell ein
vorgesehener Zustand und kein Architekturbruch.

Konsequenz:

- Bodies ohne gemeinsamen Root mit dem Fokus bleiben sichtbar als
  `Vector3.INF` / `INACTIVE_NO_LCA`
- Logging fuer diesen Pfad laeuft auf Warning-/Debug-Niveau statt als
  `push_error`
- Multi-Root-Testwelten duerfen diesen Pfad regelmaessig ausloesen,
  ohne die Fehlerdiagnose zu verwischen

## 2026-04-19 - Der deterministische Generator kommt vor einer Survey-UX

Bevor eine Survey-/Discovery-Schicht ueber Weltvergleiche gebaut wird,
braucht das Projekt mehr als nur die handgebauten Referenzwelten.

Konsequenz:

- `generated_system` haengt jetzt als deterministische Welt am
  bestehenden `WorldLoader`-Pfad
- Generator-Output nutzt dieselbe `BodyDef`-/`OrbitProfile`-/
  Registry-Topologie wie die Handwelten
- eine spaetere Survey-/Notebook-/Scanner-Schicht bleibt read-only
  Viewer ueber bestehender Sim-Wahrheit und fuehrt keine neue
  autoritative Gameplay-Schicht ein

## 2026-04-19 - Der neue galaktische Backdrop bleibt bewusst screen-fixed und dekorativ

Die neuen Referenzbilder legen einen reicheren, lebendigeren
Weltraumhintergrund nahe. Fuer den aktuellen Pass wird dieser Look aber
bewusst **nicht** an Fokus, Root oder die Position des schwarzen Lochs
gekoppelt. Der Hintergrund bleibt ein rein dekorativer Screen-Space-
Layer im bestehenden `CanvasLayer`.

Konsequenz:

- `space_backdrop.gd` wird als duenne Host-Schicht fuer einen
  shadergetriebenen Hybrid-Look genutzt
- die grossskalige Backdrop-Komposition wird bewusst an die erste
  gueltige Viewport-Groesse gebunden; spaetere Editor-/Window-Resizes
  duerfen die Dust-/Nebelfelder nicht neu remappen
- der Look darf ein breites galaktisches Staubband, dunklere Dust-Lanes,
  farbige Nebel-Akzente und ein dichteres Sternfeld tragen
- es gibt in diesem Slice bewusst **keinen** BH-zentrierten Wirbel und
  keinen impliziten Spezialfall fuer `obsidian`
- Zoom, Pan und Fokuswechsel veraendern die Hintergrundkomposition
  nicht; der Backdrop wandert nicht mit der Bubble oder dem Root mit
- falls spaeter ein root-aware oder BH-zentrierter Spezialeffekt
  gewuenscht ist, gehoert dieser in einen eigenen separaten View-Pass
  statt als stiller Ausbau des dekorativen Backdrops

## 2026-04-19 - Die Sonne wird im Hybridpfad jetzt explizit color-led statt weiter nur detailmap-getrieben

Der bisherige Stern-Hybrid nutzte `sun.png` nur indirekt ueber die
abgeleitete Graustufen-`star_detailmap.png`. Das war fuer die
Closeup-Struktur brauchbar, liess die sichtbare Sonnenoberflaeche aber
weiter staerker wie einen prozeduralen Stern mit etwas Bildsignal lesen
statt wie dieselbe solar referenzierte Sonne ueber alle Zoomstufen.

Konsequenz:

- zusaetzlich zur bestehenden `star_detailmap.png` wird jetzt eine
  farbige `star_reference.png` aus `sun.png` abgeleitet
- diese `star_reference.png` fuehrt im `body_star.gdshader` ab jetzt die
  sichtbare Solaroberflaeche
- die prozeduralen Sternlayer bleiben erhalten, werden unter aktiver
  Referenz aber amplitude-seitig bewusst etwas gedimmt
- die alte `star_detailmap.png` bleibt ebenfalls erhalten, liest jetzt
  aber nur noch als sekundere Strukturquelle statt als alleinige
  Bildbruecke
- die Sonne bekommt damit denselben Grundsatz wie die planetaren
  Hybride: Bild fuehrt, Shader veredelt

## 2026-04-19 - Root-Stabilitaet ist sichtbarkeitsbasiert, nicht mehr `wide`- oder lag-basiert

Der erste P16.1-Fix hat den Root-/BH-Anker nur fuer verschachtelte
`wide`-Views weich zurueckgebracht. Das war besser als die rein
fokuszentrierte Variante, blieb aber semantisch zu eng: sobald das BH
bei anderen Zoomstufen ebenfalls sinnvoll sichtbar war, wirkte es weiter
unnatuerlich, wenn der Fokuskoerper eingefroren blieb und alles andere
scheinbar um ihn kreiste.

Konsequenz:

- `wide / fit / detail` bleiben reine Zoom-/Massstabsmodi
- der Kameraanker wird separat ueber die aktuelle Root-Sichtbarkeit im
  Screen-Space entschieden
- solange das BH im aktuellen Bildmassstab sinnvoll sichtbar ist, bleibt
  es der stabile Bildanker (`root-lock`)
- erst wenn der Root faktisch nicht mehr sinnvoll im Bild liegt, faellt
  die Kamera auf lokalen Fokus-Lock zurueck (`focus-lock`)
- expliziter Root-Fokus (`Home`) wird im HUD separat als
  `root-overview` gekennzeichnet
- Manual Pan bleibt ein rein additiver View-Offset und darf den
  Lock-Zustand nicht beeinflussen

## 2026-04-19 - Kamera folgt dem berechneten Framing-Anker direkt, nicht ueber separaten World-Space-Lag

Ein kurzer Follow-Experimentpfad im `OrbitCameraController` hat eine
eigene geglaettete Kamera-World-Position eingefuehrt. Das loeste das
urspruengliche Fernblick-Problem nicht, weil es nur zeitliches
Nachziehen auf die bereits fokus-relative Bubble-Projektion addierte:
bei hoher Sim-Speed driftete der Fokus sichtbar aus der Mitte, und auch
der `wide`-Root-/BH-Anker konnte hinterherhaengen.

Konsequenz:

- es gibt keinen separaten kameraeigenen World-Space-Tracking-State mehr
- `fit/detail` folgen dem Fokuskoerper exakt; sichtbare Drift ist dort
  ein Bug und kein Trade-off
- `wide` nutzt weiter den dokumentierten weichen Focus->Root-/BH-Blend,
  aber ohne zeitliches Anchor-Lag
- weiche Bewegung bleibt auf Zoom-/Scale-Smoothing begrenzt; die
  Ankerposition selbst wird nicht mehr als eigener Low-Pass gefiltert

## 2026-04-19 - P16.1 bringt den Root-/BH-Anker fuer verschachtelte `wide`-Views weich zurueck

Der erste P16-Slice hat Kamera und Scope-Scale voll fokuszentriert
gezogen. Das war fuer lokale Scopes konsistent, fuehrte in grossen
BH-Systemen aber dazu, dass der Fernblick um den aktuellen Subfokus zu
kreisen schien, weil Bubble und Kamera beide strikt fokusgebunden
waren. P16.1 korrigiert das bewusst nur im Kameraanker:

- `fit` und `detail` bleiben strikt fokuszentriert
- nur `wide` auf verschachtelten Stern-/Planeten-/Mondfoki blendet den
  Kameraanker wieder weich vom Fokus zum Root-/BH-Mittelpunkt
- der Bubble-Frame bleibt fokus-relativ; der Fix lebt ausdruecklich
  nicht in `LocalBubbleManager`
- die P16-Scope-Scale-Semantik bleibt unangetastet; nur der
  Blickanker wird wieder weich stabilisiert

## 2026-04-19 - Der bestaetigte Moon-Pilot wird selektiv auf drei Planet-Archetypen erweitert; Sterne bleiben auf dem Hybrid-Detailpfad

Der Moon-Hybrid wurde im Playtest sichtbar bestaetigt: die Referenz
liest dort jetzt wie gewuenscht im Zentrum, waehrend Licht und Rand
weiter shaderseitig kontrolliert bleiben. Statt nach dieser Bestaetigung
direkt auf direkte Planetensprites umzuschwenken, erweitert P14.7 den
Hybridpfad gezielt nur auf die Archetypen, die bereits von den neuen
Bildreferenzen klar profitieren.

Konsequenz:

- `TEMPERATE_OCEAN`, `FROZEN` und `HOT_SCORCHED` bekommen eigene aus
  `Terran1.png`, `Ice1.png` und `Lava1.png` abgeleitete
  Referenz-Maps innerhalb des bestehenden `body_sphere.gdshader`
- `BARREN` bleibt vorerst bewusst shader-first; der Mond bleibt ein
  eigener Sonderpfad mit `moon_reference.png`
- die planetaren Referenzen werden nicht nur geblendet, sondern an die
  bestehende Body-Rotation gekoppelt; sie bleiben also Teil derselben
  Projektion statt statischer Disc-Aufkleber
- die neuen Planet-Referenzen sampeln enger als der Mondpilot, damit
  gebackene Beauty-Raender weniger in die Runtime leaken
- der Stern bleibt ebenfalls hybrid: `sun.png` wird weiter nur ueber die
  abgeleitete `star_detailmap.png` eingebracht; im Follow-up wird deren
  Einfluss aber etwas staerker gewichtet statt einen direkten
  Solar-Fotoskin einzuziehen

## 2026-04-19 - `TEMPERATE_OCEAN` und `FROZEN` werden im Hybridpfad bewusst reference-led statt weiter mit generischen Wolken-/Glow-Layern verziert

Der erste planetare Hybrid-Expand war technisch korrekt, las fuer
`TEMPERATE_OCEAN` und `FROZEN` aber noch zu sehr wie "starkes Bild plus
alter Planeten-Look darueber": die Bildfarben waren zu weit in Richtung
Theme-Tint zusammengedrueckt, die generischen Shader-Wolken lagen
zusaetzlich ueber einer ohnehin wolkigen Referenz, und der grosse blaue
Planet-Glow wirkte vor allem bei `Terran`/`Ice` staerker als das
eigentliche Bild.

Konsequenz:

- fuer `TEMPERATE_OCEAN` und `FROZEN` werden die Referenz-Maps jetzt
  farbtreuer aus den Quellbildern abgeleitet
- im Shader wird fuer diese Archetypen die native Referenzfarbe
  deutlich staerker bevorzugt als im Moon-/Hot-Pfad
- zusaetzliche generische Shader-Wolken werden fuer diese beiden
  Archetypen unterdrueckt
- der grosse atmosphaerische Overlay-/Glow-Pfad wird fuer diese beiden
  Archetypen stark reduziert; `HOT_SCORCHED` bleibt hiervon bewusst
  ausgenommen
- der kurz getestete portrait-stabile Closeup-Sonderpfad wurde im
  naechsten Follow-up wieder verworfen, weil er zwar die Nahansicht
  schoen hielt, aber Fern- und Nahansicht als verschiedene Sprites lesen
  liess und die sichtbare Rotation praktisch entfernte
- ein weiterer kurzer Versuch, `TEMPERATE_OCEAN` und `FROZEN` dann auf
  denselben HOT-artigen rotationsgekoppelten Pfad zu ziehen, hat die
  sichtbare Verzerrungszone des Einzelbild-Mappings nicht geloest
- stattdessen nutzen `TEMPERATE_OCEAN` und `FROZEN` jetzt denselben
  voll aktiven, zoomstabilen disc-preserving Referenz-Layer ueber alle
  Zoomstufen: damit bleibt die Bildtreue hoch, der Zoom-Bruch
  verschwindet, die sichtbare Verzerrung geht weg und Rotation bleibt
  trotzdem vorhanden

## 2026-04-19 - Der erste Planet-Asset-Pilot startet bewusst moon-only als Hybrid statt als direkter Sprite-Ersatz

Die neuen hochaufgeloesten Planeten-/Mondbilder legen einen moeglichen
Asset-getriebenen Quality-Sprung nahe. Fuer den ersten konkreten
Variant-2-Test wird aber bewusst **kein** direkter Beauty-Sprite-Pfad
fuer alle Bodies eingefuehrt. Stattdessen bekommt nur der `MOON`-Pfad
einen ersten hybriden Surface-Pilot:

- der Mond bleibt im bestehenden `body_sphere.gdshader`
- Licht, Terminator, Rim und die bestehende Rotationssemantik bleiben
  shaderseitig autoritativ
- eine aus `planet25.png` abgeleitete `moon_reference.png` wird nur als
  zusaetzliche innere Surface-/Krater-Referenz in denselben Shader
  eingeblendet
- die Referenzmap wird vorab radial entlichtet und am Rand nach innen
  kontrahiert, damit nicht der komplette Beauty-Render mit seinem
  gebackenen Halo direkt in die Runtime wandert

Konsequenz:

- der erste Asset-Pilot bleibt klar Projektion und kein neuer
  planetarer Wahrheitscontainer
- Planeten allgemein bleiben zunaechst weiter shader-first
- ob spaeter weitere Archetypen einen analogen Hybridpfad bekommen,
  wird erst nach visueller Pilotbewertung entschieden

## 2026-04-19 - Der Moon-Hybrid fuehrt die Referenz im Zentrum; Shaderarbeit sitzt an Rand und Terminator

Der erste Moon-Hybridpilot hat die Referenzmap technisch korrekt
gebunden, visuell aber noch zu sehr wie "alter Mondshader plus etwas
Texture darueber" gelesen. Das Follow-up zieht die Rollen deshalb
bewusst klarer auseinander:

- die Referenzmap fuehrt jetzt die sichtbare Mondoberflaeche deutlich
  staerker im Scheibenzentrum
- der alte prozedurale Mond-Look wird unter aktiver Referenz staerker
  amplitude-seitig gedimmt
- die zusaetzlichen Moon-Overlay-Krater werden bei aktiver Referenz
  ganz unterdrueckt
- die shaderseitige Lichtlogik konzentriert sich fuer diesen Pfad jetzt
  staerker auf Seiten, Terminator und Rim statt die Referenz flach ueber
  die ganze Disc zu uebermalen

Konsequenz:

- der Moon-Hybrid ist jetzt bewusst `center-led / edge-lit`
- der Sprite-/Reference-Anteil bleibt in der Mitte lesbar
- die Schattierungslogik bleibt trotzdem shaderseitig kontrolliert und
  kompatibel mit Rotation, Glow und der bestehenden Projektion

## 2026-04-19 - P14.6b macht die Stern-Detailmap statisch, zentriert und dominant im Closeup

P14.6 hat bewusst einen Hybridpfad aus prozeduralem Sternshader und
abgeleiteter Detailmap eingefuehrt. Der erste Lauf zeigte aber zwei
gekoppelte Probleme: die Detailmap war nicht sauber auf die
Sternscheibe zentriert und sie lief mit eigener `TIME`-Translation
gegen die animierte P14.5/P14.6-Prozeduralbasis. P14.6b zieht diesen
Pfad deshalb explizit gerade:

- die abgeleitete `star_detailmap.png` wird als disc-zentrierte innere
  Strukturmap erzeugt; aeussere Protuberanzen aus der Referenz werden
  bewusst abgeschnitten
- der Shader sampelt die Detailmap statisch und ohne Rotation oder
  Translation fest im Sternzentrum
- im Stern-Closeup darf nur noch eine Oberflaechenlogik dominant lesen:
  die sichtbare Detailmap fuehrt, waehrend Granulation, Activity,
  Filamente und Meso-Layer nur amplitude-seitig gedimmt als animierter
  Unterbau erhalten bleiben
- das statische Macro-Feld bleibt bewusst auf `100%`, ebenso Rim/Edge;
  nur die konkurrierenden Mid-/Fine-Layer werden ueber einen
  `smoothstep`-gated `lerp` reduziert

## 2026-04-19 - P14.6 gibt Sterne bewusst einen eigenen Fokus-Closeup-Mode

P14.6 baut auf P14.5 auf, loest dessen verbleibende Schwaeche aber
nicht durch weiteres generisches `df_t`-Tuning. Stattdessen bekommt der
fokussierte Stern bewusst einen eigenen Closeup-Mode mit kontrolliert
groesserem Footprint, hybrider Detailmap-Unterstuetzung und begrenzter
echter Randaktivitaet. Nicht-fokussierte Sterne bleiben bewusst auf
P14.5-Niveau.

Konsequenz:

- der aktuelle scope-relative Zoom bleibt die feste Basis; P14.6 nutzt
  `focus_closeup_ratio` nur noch sternspezifisch ueber eine eigene
  `star_closeup_phase`
- P14.6 lockert die fruehere Restriktion "kein Footprint-Wachstum" nur
  fuer den fokussierten Stern und nur konservativ (`1.0 -> 1.5`)
- der Sternshader wird bewusst hybrid:
  prozedurale P14.5-Basis plus abgeleitete `star_detailmap.png` als
  Strukturquelle fuer Faculae und Sunspot-/Channel-Komplexe
- die neue Detailquelle wird ueber ein Repo-Skript reproduzierbar aus
  `sun.png` abgeleitet; P14.6 fuehrt also kein stilles einmaliges
  Lookdev-Binary ohne Herkunft ein
- auch P14.6 haelt die P14.3-Rundheits-Invariante aufrecht: neue
  Detailmap- und Closeup-Layer modulieren nur `col`, nie `alpha`
- echte aussen sichtbare Randaktivitaet ist jetzt bewusst erlaubt, aber
  nur fuer den fokussierten Stern und nur in einem kleinen zusaetzlichen
  Radius

## 2026-04-19 - Kamera-Zoom ist ab P16 scope-relativ statt weltanker-hybrid

P16 beendet bewusst die P14.1-/P14.2-Semantik aus Weltanker und
`world -> fit -> focus`-Hybridzoom. Die Kamera wird wieder direkt an
dem Mental Model ausgerichtet: angeklickter Body = Kameraanker;
sichtbarer Kontext = expliziter lokaler Scope dieses Fokus. Der fruehere
Root-/Weltanker-Blend war kein Interpolationsdetail, sondern eine
strukturelle Fehlsemantik fuer fokus-relative Bubble-Koordinaten.

Konsequenz:

- `100%` bedeutet ab jetzt `fit current focus scope`
- `< 100%` ist `wide` innerhalb desselben Fokus-Scopes,
  `> 100%` ist `detail` innerhalb desselben Fokus-Scopes
- `Home` bzw. expliziter Root-/BH-Fokus ist der einzige globale
  Overview-Pfad; Rauszoomen auf Stern-/Planeten-/Mondfokus darf nicht
  mehr implizit Richtung Root ziehen
- die P14.1-Invariante "gleiche Zoomzahl = gleicher Welt-Massstab"
  wird endgueltig aufgegeben; Zoom-Prozente sind ab jetzt per Scope,
  nicht fokusuebergreifend global zu lesen
- `OrbitCameraScope` bestimmt den lokalen Sichtkontext per Body-Kind;
  `OrbitCameraController` benutzt keinen separaten Weltanker mehr
- das HUD benennt die neue Semantik ehrlich als
  `wide / fit / detail`

## 2026-04-19 - Architektur-Cleanup bleibt helper-/controller-basiert statt neue globale Services einzuziehen

Der Aufraeum-Pass fuer Topologie, Test-Setups und View-Logik wurde
bewusst ohne Architekturbruch umgesetzt. Neue globale Wahrheit oder neue
Autoloads wurden ausdruecklich nicht eingefuehrt.

Konsequenz:

- Topologie lebt jetzt in einem read-only `UniverseTopology`-Helper
  ueber `UniverseRegistry`, nicht in einer erweiterten Registry-API und
  nicht in einem neuen Singleton
- wiederkehrende Named-World-Test-Setups laufen ueber den
  test-only `SimTestHarness`; Produktivcode bekommt daraus keine neue
  Runtime-Abhaengigkeit
- die fruehere Testbed-Kameralogik sitzt jetzt in einem eigenen
  `OrbitCameraController`; `orbit_testbed.gd` bleibt Composition Root
  statt View-Gottklasse
- HUD-Textformatierung ist bewusst in `OrbitHudFormatter` getrennt,
  damit View-State und Player-Texte nicht weiter im Testbed vermischt
  bleiben
- `OrbitViewRenderer` bleibt `Node2D`-Fassade; reine Regeln fuer
  Camera-Scope, Orbit-Geometrie und Emphasis wurden in kleine Helper
  ausgelagert statt den Renderer durch ein Plugin oder einen grossen
  Rewrite zu ersetzen

## 2026-04-19 - P14.5 vertieft Sterne ueber mehrskalige Surface-Hierarchie statt ueber Assets

P14.5 baut auf P14.4 auf und adressiert die verbleibende Schwaeche des
Sternlooks als Materialtiefe-Problem, nicht als weiteres Halo- oder
Kamera-Problem. Der Sternshader bekommt deshalb eine feste
Frequenzleiter aus statischem Macro-Feld, neuer Meso-Breakup-Ebene,
bestehender Activity, bestehender feiner Granulation und dunklen
Filament-/Channel-Layern. Die neue Tiefe bleibt vollstaendig
shader-only; es werden bewusst keine Textur-Assets importiert.

Konsequenz:

- das Macro-Feld bleibt explizit statisch und traegt keine globale
  Sternbewegung; `TIME` bleibt auf langsamere mittlere und feine
  Aktivitaetslagen begrenzt
- die Layer-Komposition ist festgezogen:
  Macro und Granulation modulieren multiplikativ, Meso und Activity
  additiv, Channels schneiden danach dunkler ein, Rim/Edge bleiben
  zuletzt
- auch P14.5 haelt die P14.3-Rundheits-Invariante aufrecht: neue
  Surface-Layer modulieren nur `col`, nie `alpha`
- P14.5 bleibt bewusst ein Surface-Depth-Pass; Halo, Kamera,
  Orbit-Komposition, Body-Size und Planetpfade bleiben unangetastet
- Stern-Typisierung / Spektralklassen bleiben weiterhin ein spaeterer
  separater Pass

## 2026-04-19 - P14.4 zieht Sterne bewusst in Richtung NASA-naher aktiver Sonnenoberflaeche

P14.4 baut auf P14.3 auf, ersetzt ihn aber nicht. Die runde
Alpha-Silhouette des Sternshaders bleibt explizit unberuehrt; neue
Solar-Activity moduliert nur Farbe und Helligkeit, niemals `alpha`.
Der Stern-Look wird ueber neue Star-Uniforms in Richtung aktiverer
Photosphaere mit helleren aktiven Regionen, dunkleren Filament-/
Channel-Zonen und staerkerem heissen Innenrand nachgeschaerft. Der
fruehere Ring-Glow wird bewusst subtiler gemacht, nachdem die visuelle
Energie zuerst shaderseitig in Rim und Oberflaeche aufgebaut wurde.

Konsequenz:

- P14.4 ist bewusst ein Material-/Surface-Pass, kein Kamera-, Orbit-,
  Body-Size- oder Planet-Pass
- neue Sternaktivitaet bleibt innerhalb der bestehenden Sternscheibe;
  echte aussen sichtbare Prominenzen werden bewusst vertagt, damit der
  sichtbare Stern-Footprint stabil bleibt
- `OrbitBodyVisual` setzt erstmals explizite Star-Uniforms, aber nur im
  `STAR`-Pfad; Planet-/Mond-Pfade bleiben unberuehrt
- die in P13 physikalisch gesetzte M-Dwarf-Rolle von `gamma` bleibt
  weiter sim-seitig gueltig; visuell bleibt `gamma` in P14.4 bewusst
  Teil derselben Sonnenfamilie, bis ein spaeterer
  Star-Typisierungs-Pass diese Ebene wieder sichtbar auffaechert

## 2026-04-19 - P14.3: Star-Polish als gemeinsame solare Familie

Sterne werden als runde, warmfarbige Sonnen mit sichtbarer Photosphaere
und weichem Corona-Halo lesbar gemacht. Der Haupt-Shader-Fix ist die
Entkopplung der Alpha-Silhouette vom zeitgetriebenen Warp - die innere
Animation (Limb, Farbe, Rim) bleibt erhalten, nur die Aussenkante ist
jetzt ein sauberer Kreis. Palette und Granulations-Amplitude werden rein
an Zahlenwerten nachgetuned; die bestehende Granulations-Morphologie
(hexagonale 3-Richtungs-Zellen, Domain-Warp, asymmetrische Lanes
`bright*0.60 - dark*1.35`) bleibt unveraendert. Der Corona-Halo wird
durch einen 5-stufigen weichen Ringgradient (Aussenradius 25 px) ersetzt,
ohne den sichtbaren Stern-Footprint zu vergroessern.

Konsequenz:

- alle Sterne teilen in P14.3 bewusst denselben Sun-Look
- die in P13 physikalisch eingefuehrte M-Dwarf-Parametrisierung fuer
  `gamma` (reduzierte Masse und Luminositaet) bleibt voll gueltig und
  wirksam fuer Thermal-/Environment-Ableitung; die visuelle Entkopplung
  davon in P14.3 ist eine bewusste Vertagung auf einen spaeteren
  Star-Typisierungs-Pass (z. B. via `BodyDef.luminosity_w` oder explizite
  Spektralklasse), kein Versehen
- P14.3 fasst weder Kamera noch Body-Size noch Sim-Schicht noch
  Planet-Archetypen an
- keine neuen Uniforms, keine Star-Tuning-Zentralisierung in
  `OrbitBodyVisual` - der aktuelle `STAR`-Pfad in `_make_sphere_material`
  haette dafuer nichts zu zentralisieren und wuerde versehentlich
  Planet-/Mond-Parameter mitziehen

## 2026-04-19 - P14.2 nutzt bewusst Hybrid-Zoom: `world -> fit -> focus`

P14.2 ersetzt die reine P14.1-Semantik "gleiche Zoomzahl = gleicher
Welt-Massstab" durch ein bewusstes Hybridmodell, weil der globale
Rauszoom gut funktionierte, der lokale Nahzoom auf fokussierte Systeme
und Planeten aber spielerisch zu schwach wurde.

Konsequenz:

- `0.5% .. 100%` bilden jetzt explizit `world -> fit current focus` ab
- der `world`-Abschnitt ist nicht nur ein Scale-Blend; der Kameraanker
  interpoliert dort bewusst von Root-/Weltanker zu Fokusanker
- `100%` bedeutet wieder exakt `fit current focus`
- oberhalb von `100%` ist Zoom bewusst wieder lokaler Closeup relativ
  zum aktuellen Fokus
- gleiche Zoomzahlen oberhalb von `100%` sind damit nicht mehr
  fokusuebergreifend als gleicher Welt-Massstab interpretierbar
- das HUD macht diese Semantik explizit sichtbar ueber
  `Zoom ... world`, `Zoom 100% fit` und `Zoom ... focus`

## 2026-04-19 - Der globale Weltanker bleibt, aber nur fuer den Fernblick

P14.2 verwirft nicht den Weltanker aus P14.1, sondern grenzt ihn klarer
ein.

Konsequenz:

- der beim Load gecachte Root-Overview-Radius bleibt der Anker fuer den
  guten globalen Rauszoom
- der Zoombereich bleibt bei `0.5%` bis `10000%`
- `Backspace` bleibt der explizite `fit current focus`-Reset
- Renderer-Nahdetail und Fokus-Emphasis bleiben weiter fokus-relativ
  ueber `focus_closeup_ratio`
- P14.2 ist bewusst kein Render-/Body-Size-Pass; Sprite-Groesse,
  `detail_factor` und P14-Klima-Archetypen bleiben unangetastet

## 2026-04-18 - Planet-/Mond-Visuals bleiben Projektion bestehender Sim-/Derived-Daten

Der neue Klima-Archetypen-Pass in P14 fuehrt bewusst keine neue
Simulationswahrheit ein. Planet- und Mond-Looks bleiben reine Projektion
aus bereits vorhandenen `BodyDef`- und Umwelt-/Atmosphaeren-Daten.

Konsequenz:

- der Archetypen-Resolver lebt im Rendering-Layer, nicht in `sim/`
- `PLANET` und `MOON` teilen sich denselben Klima-Resolver, damit HUD
  und Darstellung semantisch zusammenbleiben
- `FROZEN`, `HOT_SCORCHED` und `BARREN` gelten als direkt sim-gestuetzte
  Visual-Familien
- `TEMPERATE_OCEAN` ist bewusst als stilisierte Interpretation markiert,
  weil Wasserinventar, Land/Ozean-Verhaeltnis und Wolkenphysik noch
  nicht simuliert werden
- `DESERT` wird ausdruecklich auf einen spaeteren Pass mit staerkerer
  Ariditaets-/Wasserbasis verschoben

## 2026-04-18 - HUD-Sprache trennt bewusst `Environment`, `Climate` und `Bands`

Die spielerische HUD-Sprache fuer planetare Umweltwerte wird bewusst
strenger getrennt als die internen Enum-Namen.

Konsequenz:

- `Environment` bezeichnet die momentane Habitability-Aussage ueber die
  drei festen Breitenbaender
- `Climate` bezeichnet im HUD aktuell nur den Welttyp /
  `ecosystem_type`, nicht eine vollstaendige spaetere Klimasimulation
- `Bands` zeigt die rohen zonalen Temperaturwerte und ist die implizite
  Begruendung fuer das Urteil
- neue HUD-Zeilen brauchen ab jetzt eine kurze Begruendung gegen
  unnoetige Anzeige-Dichte; P13.1 fuegt bewusst keine neue Zeile hinzu,
  sondern schaerft nur bestehende

## 2026-04-18 - `MARGINAL` bleibt intern, wird player-facing aber zu `HARSH`

Das interne Enum-Symbol `Class.MARGINAL` bleibt aus
Kompatibilitaetsgruenden stabil, wird fuer Spieler aber bewusst als
`HARSH` dargestellt.

Konsequenz:

- `MARGINAL` wird im Code nicht umbenannt; bestehende Tests, Logs und
  Datenmodelle bleiben kompatibel
- `HARSH` wird als Spielerwort verwendet, weil `MARGINAL`
  alltagssprachlich zu sehr nach "knapp drin" klingt
- `HABITABLE` und `HOSTILE` bleiben unveraendert, weil ihre
  Alltagssemantik bereits zur Systemsemantik passt
- View-/HUD-Code muss fuer Spielertexte immer ueber
  `EnvironmentService.to_string_class()` und
  `EnvironmentService.to_string_ecosystem()` laufen

## 2026-04-18 - `gamma` wird in P13 bewusst als kompaktes Red-Dwarf-System neu parametrisiert

Der nachtraegliche `gamma_iv`-Hotfix aus dem ersten Sichtbarkeits-Follow-up
wird bewusst nicht konserviert. Stattdessen wird das gesamte `gamma`-System
neu aufgesetzt, damit ein habitabler Kandidat innerhalb einer lokalen
Stabilitaetsgrenze statt als root-skaliger Ausreisserorbit entsteht.

Konsequenz:

- `gamma` ist nicht mehr der fruehere P12B-Stern mit hoher
  Luminositaet, sondern ein bewusst kompakter Red-Dwarf-artiger Stern
- `gamma_iv` bleibt der eine sichtbare habitabele Kandidat der
  `starter_world`, jetzt aber in einem lokal plausiblen kompakten Orbit
- die P12B-Asymmetrie bleibt erhalten; `gamma` bleibt das reichste
  Sternsystem, bekommt aber eine schaerfere thematische Rolle

## 2026-04-18 - Renderer bleibt Wahrheitsspiegel fuer Systemskalen

Outlier-Orbits in der `starter_world` werden nicht durch spezielle
Zoom-/Fokusregeln versteckt. Wenn ein Sternfokus gequetscht wirkt, ist
das primaer ein Content-/Skalenproblem und kein Anlass fuer eine
Renderer-Sonderbehandlung.

Konsequenz:

- `OrbitViewRenderer` bleibt unveraendert, wenn ein Content-Ausreisser
  die Systemgroesse dominiert
- lokale habitabele Kandidaten muessen ueber sauberes Welt-/Stern-
  Tuning entstehen, nicht ueber Zoom-Maskierung
- neue Content-Tunes in `starter_world` brauchen bei Bedarf explizite
  lokale Stabilitaets- oder Skalen-Guardrails statt stiller View-Hacks

## 2026-04-18 - `starter_world` bekommt genau einen sichtbaren habitablen Kandidaten

Nach P12A wird `starter_world` bewusst nicht flaechig auf Habitability
retuned, bekommt aber genau einen explizit sichtbaren Kandidaten
(`gamma_iv`), damit der Default-Testbed-Start nicht nur extreme
`HOT`-/`FROZEN`-Faelle zeigt.

Konsequenz:

- `sample_system` bleibt weiter der kanonische kleine habitable
  Showcase
- `starter_world` bleibt insgesamt ein asymmetrischer BH-Sandkasten und
  wird nicht breit auf „freundliche“ Planeten umgebaut
- einzelne gezielte Content-Tunes fuer Sichtbarkeit sind erlaubt, wenn
  sie explizit gepinnt und getestet werden

## 2026-04-18 - P12A bewertet momentane Umweltzonen, keine Jahresmittel

Die erste zonenbewusste Umweltklassifikation in P12A bewertet bewusst
nur den **aktuellen** Orbit-/Saisonzustand eines planetaren Bodies.

Konsequenz:

- `AtmosphereService` und `EnvironmentService` mitteln in P12A nicht
  ueber das Jahr
- `environment_class` und `ecosystem_type` duerfen deshalb bei Tilt und
  exzentrischen Bahnen sichtbar ueber das Orbitaljahr oszillieren
- Jahresmittel, Stabilitaetsmetriken oder UI-Hysterese gehoeren in
  einen spaeteren expliziten Folgeblock

## 2026-04-18 - `sample_system` bleibt der habitable Showcase; `starter_world` bleibt thermisch extrem

P12A fuehrt bewusst keinen Habitability-Retune der kompakten
Mehrstern-Referenzwelt `starter_world` durch. Der sichtbare habitable
Showcase bleibt stattdessen `sample_system`.

Konsequenz:

- `sample_system.planet_a` bleibt der kanonische Earth-like /
  habitable Fokus-Body
- `starter_world` bleibt in P12A der asymmetrische Content-Sandkasten
  und darf thermisch weiter extrem oder unfreundlich wirken
- neue Umweltfeatures werden damit zunaechst an einer kleinen,
  kontrollierten Referenzwelt sichtbar statt ueber Welt-Content-Tuning

## 2026-04-18 - Umwelt-Roadmap zielt auf planetare Oekosystem-Typen

Die weitere planetare Umweltableitung soll nicht bei globalen
Temperatur- und Habitability-Skalarwerten stehen bleiben, sondern
schrittweise in Richtung globaler planetarer Oekosystem-Typen fuehren.

Konsequenz:

- breiten- und saisonabhaengige Thermalgeometrie ist nur ein
  Zwischenschritt
- weitere Atmosphaeren- und Wasser-/Volatile-Faktoren sind die
  naechsten sinnvollen Fundamentbloeke
- detailreiche Laender-/Biome- oder Oberflaechenmodelle sind dafuer
  ausdruecklich nicht sofort Voraussetzung

## 2026-04-18 - `sample_system` bleibt klein; reichere BH-Systeme gehoeren in `starter_world` oder eine spaetere grosse Referenzwelt

Die aktuelle kleine Referenzwelt `sample_system` bleibt bewusst kompakt
und sauber. Ein deutlich groesseres, asymmetrischeres
Schwarzes-Loch-Mehrsternsystem soll stattdessen ueber `starter_world`
oder eine spaetere groessere Referenzwelt entstehen.

Konsequenz:

- mehr Sterne unter `obsidian` sind ausdruecklich gewuenscht
- einzelne Sterne duerfen deutlich unterschiedlich viele Planeten tragen
- die heutigen perfekten Kreisbahnen der Sterne um das schwarze Loch
  sind keine langfristige Zielvorgabe; elliptischere und insgesamt
  weniger symmetrische Sternsysteme bleiben eine bewusste Ausbauoption

## 2026-04-18 - P12B bleibt beim BH-Weltausbau bewusst content-only

Der erste groessere Ausbau der BH-Referenzwelt erweitert bewusst nur die
Inhaltsmenge und Asymmetrie von `starter_world`, ohne neue Orbit-
Mechanik einzuziehen.

Konsequenz:

- BH-Sterne bleiben in P12B kreisfoermige `AUTHORED_ORBIT`
- elliptische BH-Sternbahnen sind fuer diesen Slice ausdruecklich
  deferiert
- ein spaeterer Schritt darf Root-Star-Ellipsen nur als eigenen
  expliziten Mechanik-/Weltentscheid einfuehren, nicht still als
  Weltpflege-Nebenprodukt

## 2026-04-18 - Saisonale Strahlungsgeometrie bleibt im `ThermalService`

Die P11-Saisongeometrie erweitert bewusst den bestehenden
`ThermalService` statt einen separaten Saison-Service einzuziehen.

Konsequenz:

- `ThermalService` bleibt die Heimat quantitativer Strahlungs- und
  Thermalwerte
- `EnvironmentService` bleibt in P11 unveraendert qualitativ
- `source_dir_hat` ist fuer die saisonale Geometrie explizit als
  normierter Vektor von Body -> Quelle festgezogen
- latitudenbewusste Thermalgeometrie und skalare Umweltklassifikation
  koennen spaeter bewusst wieder zusammengefuehrt werden, ohne heute die
  Domain-Grenzen aufzubrechen

## 2026-04-18 - `axial_tilt_rad` allein reicht nicht fuer Jahreszeiten

P11 fuehrt bewusst das neue Datenfeld
`BodyDef.north_pole_orbit_frame_azimuth_rad` ein.

Konsequenz:

- `axial_tilt_rad` beschreibt weiter nur den Kippwinkel relativ zur
  Orbit-Ebene
- die neue Azimut-Angabe fixiert zusaetzlich die Nordpol-Projektion im
  lokalen Orbit-Frame
- erst beide Felder zusammen definieren eine zeitabhaengige
  Spinachsen-Orientierung fuer tilt-getriebene Jahreszeiten

## 2026-04-18 - Anti-Thrashing bleibt im `OrbitService`, nicht im `BubbleActivationSet`

Der erste `NUMERIC_LOCAL`-Stabilitaets-Guardrail lebt bewusst im
`OrbitService`.

Konsequenz:

- `BubbleActivationSet` bleibt rein geometrische Aktivierungslogik ohne
  Hysterese
- der bekannte `_process()`/`_physics_process()`-Versatz wird ueber eine
  kleine Missing-Request-Grace im `OrbitService` abgefedert
- es gibt in P10 keine neue Wunsch-/Stability-Zwischenschicht und keine
  `BodyState`-Erweiterung

## 2026-04-18 - Overspeed-Policy fuer `NUMERIC_LOCAL` ist `Cap+Warn`

Bei zu grossem numerischem `dt` bleibt der Body im `NUMERIC_LOCAL`-
Pfad. `OrbitService` capped nur die Substep-Anzahl und warnt mit
Dedup-Logik beim Eintritt in den gecappten Zustand.

Konsequenz:

- kein harter Kepler-Fallback als Teil des ersten Guardrail-Blocks
- das Warning ist bewusst Best-Effort-Diagnose, kein Stabilitaetsbeweis
- wer dauerhaft gecappte Bodies vermeiden will, muss `time_scale` oder
  Guardrail-Parameter anpassen

## 2026-04-18 - Greenhouse lebt in einem eigenen `AtmosphereService`

Die P9-Greenhouse-Schicht erweitert bewusst weder `ThermalService` noch
`EnvironmentService`, sondern lebt als eigener read-only Derived-Service
im `sim/`-Layer.

Konsequenz:

- `ThermalService` bleibt bei nackter Strahlungsbasis
  (`F`, absorbierter Fluss, `T_eq`)
- `AtmosphereService` modelliert nur additive
  Oberflaechenerwaermung (`greenhouse_delta_k`)
- `EnvironmentService` bleibt qualitativ und interpretiert die
  abgeleitete Temperaturbasis nur

## 2026-04-18 - `EnvironmentService.configure(...)` wechselt bewusst auf `AtmosphereService`

Der zweite Parameter von `EnvironmentService.configure(...)` wechselt
bewusst von `ThermalService` auf `AtmosphereService`.

Konsequenz:

- Umweltklassifikation basiert ab P9 auf `surface_temperature_k`,
  nicht mehr direkt auf `T_eq`
- der P8-Pfad (Klassifikation auf Basis von `T_eq`) ist bewusst
  obsolet
- es gibt keinen Fallback-Parallelpfad fuer beide Service-Typen
- Composition Roots und Tests muessen explizit auf den neuen
  Atmosphaerenpfad umverdrahtet werden

## 2026-04-17 - Naechste Kernphase ist World Model + Loader + Bubble Foundations

Die naechste groessere Projektphase priorisiert nicht weitere Visual-
Politur oder fruehes Gameplay, sondern das Fundament fuer spaetere
Welt-/Systemsimulation.

Gemeinter Arbeitsblock:

- `LocalBubbleManager` wird von der aktuellen einfachen Fokus-
  Subtraktion in Richtung des dokumentierten Step-2-Zielbilds
  (LCA-/praezisionsbewusste Bubble) weiterentwickelt.
- Das Laden einer Welt wird aus dem Testbed in eine explizite
  Loader-/World-Schicht gezogen.
- `BodyDef` wird additiv um fehlende statische Welt-/Physikfelder
  erweitert (z. B. Rotation, Achsneigung, Luminositaet, Albedo).

Konsequenz:

- Mehrere Root-Systeme / mehrere schwarze Loecher werden als echte
  spaetere Zielrichtung ernst genommen.
- Planetare Zustaende und prozedurale Welterzeugung bekommen damit ein
  tragfaehiges Daten- und Frame-Fundament.
- Weitere groeessere Visual-Paesse, Gameplay-Features oder Content-
  Systeme sind gegenueber diesem Fundament aktuell nachrangig.

Praezisierung:

- In der Ausfuehrungsreihenfolge hat der Bubble-/Frame-Schritt Vorrang,
  weil er den groessten aktuellen Architektur-Vision-Gap schliesst.
- Die Erweiterung von `BodyDef` ist weiterhin wichtig, aber additiv und
  kann parallel oder direkt im Anschluss folgen.

## 2026-04-17 - Sim und View bleiben strikt getrennt

Die Architektur von `Graviton` bleibt wichtiger als ein schneller
visueller Port aus `Atraxis`.

Konsequenz:

- Simulationswahrheit bleibt in `core/`, `sim/` und `runtime/`
- Praesentation darf stark verbessert werden
- View-Code bekommt keine autoritativen Simulationsabkuerzungen

## 2026-04-17 - 2D-Praesentation statt altes 3D-Minimal-Testbed

Das fruehere minimalistische 3D-Testbed wird nicht weiter ausgebaut.
Stattdessen nutzt `Graviton` jetzt eine stilisierte 2D-Orbit-Ansicht,
weil sie den bisherigen `Atraxis`-Look deutlich besser trifft.

Konsequenz:

- 3D-Rendering-Node-Strukturen wurden aus dem aktiven Testbed entfernt
- Orbit-Ringe, Trails, Glow-Body-Visuals und HUD sind Teil der neuen
  Standardansicht
- Die Simulationsmathematik darf weiterhin `Vector3` nutzen

## 2026-04-17 - `Vector3` in der Sim ist kein 3D-Altlastproblem

`Vector3` und 3D-Orbitparameter in `OrbitMath`, `OrbitService`,
`BodyState` oder `OrbitProfile` gelten aktuell als legitime Simulations-
 und Frame-Mathematik, nicht als View-Altlast.

Konsequenz:

- Nicht blind alles auf `Vector2` umstellen
- Erst unterscheiden zwischen Sim-Mathematik und Praesentationscode

## 2026-04-17 - Zoom-Frame berechnet nur Fokus + direkte Kinder

`get_focus_frame` in `OrbitViewRenderer` beschraenkt die Radius-Berechnung
auf den Fokus-Koerper selbst und seine direkten Kinder. Vorfahren und
Enkel-Koerper aus `related_ids` werden fuer den Zoom-Frame uebersprungen.

Konsequenz:

- BH-Fokus: zeigt beide Sterne (direkte Kinder von obsidian) vollstaendig
- Stern-Fokus: zeigt das Planetensystem des Sterns (~5-10 RU Rahmen)
- Planet-Fokus: zeigt den Planeten und seine Monde
- Mond-Fokus: enger Rahmen um den Mond; Planet und Stern sind durch
  den Mindest-Radius von 8 RU sichtbar, setzen aber den Zoom nicht

Hintergrund: In Step-1 (Identity-Bubble, Weltkoordinaten) fuehren
Vorfahren-Koerper im Zoom-Rahmen zu System-weiter Aufloesung, da ihre
Distanz vom Fokus in absoluten Koordinaten gross ist.

## 2026-04-17 - Repo braucht kanonische Kurz-Dokumente

Damit kuenftige Agenten nicht jedes Mal denselben Kontext aus Prompts
rekonstruieren muessen, gibt es drei kurze kanonische Dateien:

- `docs/STATUS.md`
- `docs/NEXT_STEPS.md`
- `docs/DECISIONS.md`

Ergaenzt durch `AGENTS.md` im Repo-Root.

## 2026-04-17 - Planetare Zustaende und Systemgenerator sind spaetere Sim-Ziele

`Graviton` soll spaeter nicht nur feste Testsysteme zeigen, sondern auch
prozedural erzeugte Mehrkoerper-Systeme mit planetaren Zustaenden tragen.

Geplante Richtung:

- Generator entscheidet spaeter probabilistisch ueber:
  - Anzahl schwarzer Loecher / Root-Systeme
  - Anzahl Sterne pro Root-System
  - Anzahl Planeten pro Stern
  - Wahrscheinlichkeit fuer Monde
  - Orbit-Parameter wie Achsen, Exzentrizitaeten und Ausrichtungen
- Nicht jeder Planet soll automatisch "fruchtbar" oder bewohnbar sein.
- Planetare Zustaende wie Temperatur, Bewohnbarkeit oder andere
  Umweltfaktoren sollen aus Simulationsparametern ableitbar werden.

Wichtige Einordnung:

- Die jetzt sichtbaren Toy-Ellipsen im `StarterWorld` sind dafuer ein
  frueher visueller Vorlaeufer, aber noch kein Planetenzustands-System.
- Jahreszeiten sollen spaeter nicht nur ueber Bahnellipsen gedacht
  werden; fuer erdaehnliche Welten ist Achsneigung langfristig die
  wichtigere Simulationsgrundlage.
