# Graviton - Status

Stand: 2026-04-25

## Kurzfassung

`Graviton` hat aktuell eine saubere Foundation-Architektur fuer eine
Weltraum-/Systemsimulation und eine erste stilisierte 2D-
Praesentationsschicht.

Darauf sitzt jetzt zusaetzlich ein lokaler statischer Website-Prototyp
unter `website/`: ein deutscher Onepager ohne Build-System, ohne
Deployment und ohne JavaScript. Die Bildflaechen sind bewusst als
`Platzhalter - Aufnahme ausstehend` markiert, weil noch keine lokalen
Website-Screenshots als Projektbelege vorliegen. Die Seite trennt
sichtbar vorhandene Readouts von geplanten Gates und nennt
ausdruecklich, dass kein fertiges Gameplay, keine lebenden dynamischen
Populationen, keine Settlement-/Economy-/Quest-Systeme und keine
Veroeffentlichung behauptet werden.

Darauf sitzt jetzt zusaetzlich `Asteroiden v1` als sichtbare
Minor-Body-Simulation:
Asteroiden leben in einem eigenen `sim/asteroids/`-Slice mit eigenem
`AsteroidState`, stabilem `anchor_id`, eigenem ID-Raum und
Restricted-Gravity-Integrator. `STAR`, `PLANET` und `MOON` ziehen
Asteroiden an; `BLACK_HOLE` bleibt in v1 Root-/Kontextkoerper, aber
kein Asteroiden-Attractor. Asteroiden schreiben nie
Major-Body-`BodyState` und wirken nicht aufeinander. Die Szene bridged
`OrbitService.step_completed(dt_s, t_s)` explizit in den
Asteroid-Service; Single-World- und Large-World-Residency spawnen
deterministisch pro Root. View-seitig projiziert ein separater
`AsteroidSnapshotCache` read-only in Bubble-View-Koordinaten, waehrend
`AsteroidFieldRenderer` Punkte und kurze Trails als reine Renderer-
History zeichnet. Impacts, Merge/Split, Life-Folgen,
Asteroid-Asteroid-Kollisionen, Anchor-Switching und Fokusnavigation auf
Asteroiden bleiben bewusst Folge-Slices.
Ein direkter Qualitaets-Follow-up reduziert den zuvor zu sauberen
Kreisbahn-Eindruck: Initiale Asteroiden-Velocities enthalten jetzt
deterministischen radialen Drift und einen kleinen Anteil retrograder
Starts, statt fast perfekte Tangenten um den Anchor zu sein. Zusammen
mit dem Entfernen von `BLACK_HOLE` aus dem v1-Attractor-Set sollen die
Steinchen im Root-/Sternfokus eher wie fliegendes Geroell statt wie
kleine gezeichnete Mondorbits lesen.
Ein direkter Performance-Follow-up cached im Asteroid-Service
relative Major-Body-Zustaende pro `(anchor_id, body_id)` innerhalb
eines Asteroiden-Ticks. Damit werden identische Topologie-/Frame-
Aufloesungen nicht mehr fuer jeden Asteroid erneut berechnet, waehrend
Attractor-Auswahl und Restricted-Gravity-Ergebnis unveraendert bleiben.
Ein zweiter Follow-up reduziert den sichtbaren Trail-Hotpath:
Asteroid-Trails werden jetzt kuerzer gehalten und pro Asteroid als
eine Polyline statt als viele einzelne Liniensegmente gezeichnet.
Zusaetzliche Perf-Probe-Spalten `asteroid_visible_count`,
`asteroid_trail_count` und `asteroid_trail_point_count` machen diesen
Renderpfad im naechsten `P`-Dump direkt messbar.
Der danach gemessene Sternfokus-Einbruch kam von Large-World-
Residency: waehrend im lokalen Fokus nur 24 Asteroiden sichtbar waren,
wurden durch einen residenten Neighbor-Root 48 Asteroiden simuliert.
Der Testbed-Composition-Root bridged Asteroiden in Large-Worlds deshalb
jetzt nur noch fuer den aktuellen Fokus-Root; Single-Worlds behalten
weiter ihre geladenen Roots. Beim Fokuswechsel wird ausserdem die reine
Renderer-Trail-History geleert, damit keine alten Root-Overview-Linien
in den lokalen Sternfokus hineinragen.
Der folgende Dump zeigte danach noch einen Sternfokus-Engpass durch
Sim-Catchup: bei 6 FPS holte Godot bis zu acht Asteroiden-Ticks pro
Renderframe nach. Der Restricted-Gravity-Integrator nutzt deshalb im
normalen Asteroidenpfad jetzt flache `PackedFloat64Array`-Attractor-
Daten statt Dictionary-Entries im inneren Loop, und die teure
Attractor-Set-Auswahl wird ueber ein kurzes Refresh-Fenster
wiederverwendet. Die Positionen der gewaehlten Major-Body-Attraktoren
werden weiter pro Tick neu gelesen.
Der naechste Editor-Dump lag damit im Alpha-Fokus wieder bei grob
43-65 FPS; der Restpfad war nun klar Render-LOD statt Asteroiden-
Physik. `OrbitViewRenderer` baut Orbitlinien deshalb mit weniger
Stuetzwerten und cullt Bodies, Orbitlinien und Trails gegen den
aktuellen Screen-Ausschnitt mit Margin. Neue PerfProbe-Spalten
`body_screen_culled_count` und `orbit_screen_culled_line_count` zeigen
im naechsten Dump, ob lokale Sternsystem-Foki weiterhin offscreen
Sibling-Systeme zeichnen.
Der anschliessende `P`-Dump zeigte: lokaler Focus-lock cullt nun
korrekt auf wenige Bodies/Orbitlinien, aber Root-lock/wide und
Sternfokus-Badges blieben teuer. `OrbitViewRenderer` kompaktet deshalb
jetzt auch im Root-lock den View-Zweig: direkte Geschwistersterne
bleiben als Kontext sichtbar, deren Planet-/Mond-Zweige, Trails und
Orbitlinien werden ausgeblendet; der Fokuszweig bleibt sichtbar.
`PlanetBadgeOverlay` zeigt planetennahe `LIFE`-Badges ausserdem nur
noch in echten Planet-/Mond-Detailfoki und scannt im Stern-/Root-lock
keine Badge-Kandidaten. Der neue Counter
`root_lock_hidden_body_count` macht diesen LOD-Pfad im naechsten
`P`-Dump messbar.
Der danach verglichene `P`-Dump bestaetigte den offenen rechten
`RootInspectorOverlay` als groessten verbliebenen Hotpath im lokalen
Sternfokus: bei geschlossenem Inspector lag der Alpha-Fokus nahe 60-70
FPS, bei offenem Inspector fielen `render_objects`, `draw_calls` und
Primitive deutlich hoeher aus, obwohl `visible_badges = 0` und
`attractor_checks = 0` waren. Deshalb rendert der Inspector seine
sichtbaren Rows jetzt als je ein konsolidiertes `RootInspectorRow`-
Control mit eigenem `_draw()`-Pfad, statt pro Row verschachtelte
Panel-/Margin-/Label-/Chip-/Button-Untercontrols zu erzeugen. Das
Inspector-Modell, die deferred Fokus-Signale und der explizite
Life-Chip-Hit-Test bleiben erhalten; nur die View-Materialisierung
wurde reduziert.
Der naechste Dump war dann mit geschlossenem Inspector weiter im
Sternfokus langsam. Die Zeitreihe zeigte keinen Zusammenhang mit der
Asteroiden-Physik: Frames mit `attractor_checks = 0` und Frames mit
`432` Checks lagen bei praktisch gleicher FPS. Der harte
Render-Objekt-Sprung trat stattdessen beim Reinzoomen in den
Fokus-Stern auf, sobald `body_star_closeup_phase_max` den
Closeup-Schwellenbereich erreichte. `OrbitBodyVisual` zeichnet deshalb
die sternspezifischen Closeup-Spicules/Prominence-Arcs nicht mehr als
CPU-Canvas-Linien; die Sternoberflaeche und der Closeup-Eindruck
bleiben ueber den bestehenden `body_star.gdshader`-Pfad erhalten.

Darauf sitzt jetzt zusaetzlich ein erster grosser Large-World-Pfad:
ein validierter 3-Root-Pilot plus separate produktive 10-, 30- und
100-Root-Galaxien mit Proxy-Layer, Streaming, deterministischem
Catalog-Builder und inkrementellen Runtime-Hotpath-Fixes fuer Bubble-,
Derived- und Proxy-/Neighbor-Arbeit. Darauf sitzt jetzt zusaetzlich
ein erster fokussierter Survey-UX-Slice als Root-Inspector fuer
residente BH-Systeme sowie eine erste read-only `Planetary State
Foundation` fuer laengerfristige Weltprofile von Planeten und Monden.
Darauf sitzt jetzt zusaetzlich `Life Potential v1a` als kleiner
read-only Life-Layer mit benannten Chemiepfaden auf Basis dieser
Jahresachsen. Darauf sitzt jetzt zusaetzlich `Root Inspector v2.1` als
kleiner UX-/Navigationsschritt: die rechte Liste ist kompakter, zeigt
`World:` nur noch focused-row-only und springt bei Row-Klicks jetzt
sofort auf den gewaehlten Body. Der Live-Klickpfad des Inspectors wurde
danach zusaetzlich gegen Reentrancy gehaertet: Row-Buttons routen ihren
Fokuswunsch jetzt deferred und der Overlay-Rebuild gibt alte Row-Nodes
nur noch per `queue_free()` frei, damit Snapshot-Refresh den gerade
geklickten Button nicht mehr mitten im `pressed`-Signal zerstoert.
Da der Inspector unter laufender Sim regelmaessig rebuilt, feuern die
Rows jetzt ausserdem bewusst schon auf Mouse-Down statt erst auf
Mouse-Up; sonst konnte eine Row zwischen Press und Release bereits
ersetzt sein und der Live-Klick ging still verloren. Darauf sitzt jetzt
zusaetzlich `Life Potential v1b` als erste persistente
Proto-Biosphaeren-Schicht:
`Life Potential` bleibt der read-only Chemiepfad-Layer,
`Life` beschreibt jetzt zusaetzlich den aktuellen
Proto-Biosphaerenstand (`STERILE`, `PREBIOTIC`, `MICROBIAL`).
Darauf sitzt jetzt zusaetzlich `Life v2` als quantitativer
Biosphaeren-Layer:
`ProtoBiosphereSimulationService` bleibt das interne deterministische
Seed-/Progress-Substrat, waehrend ein neuer read-only
`BiosphereScaleService` daraus bandweise Carrying Capacity, Biomasse und
neue player-facing `Life`-Stages
(`COMPLEX_MULTICELLULAR`, `COMPLEX_ECOSYSTEM`) ableitet.
Darauf sitzt jetzt zusaetzlich `Time UX v1` als kleiner reiner
Control-/HUD-Schritt:
die normale HUD-Sprache zeigt lesbare Zeitraten statt roher
`x...`-Multiplikatoren, der Preset-Flow und der Slider-Bereich sind
bewusst getrennt und das HUD macht die bestehende Life-Cadence als
`Bio tick ~ ...` direkt sichtbar.
Darauf sitzt jetzt zusaetzlich `Orbit Readout v1` als kleiner reiner
Readout-/HUD-Schritt:
die bestehende Runtime-Zeile rendert `T+` jetzt adaptiv statt stumpf in
Tagen und das Fokus-HUD macht `Day:` und `Year:` fuer den aktuell
fokussierten Body explizit sichtbar.
Darauf sitzt jetzt zusaetzlich `Native Species Foundation v1` als
kleiner read-only Species-Layer:
aus `World + Life Potential + Life v2` wird erstmals ein konkreter
nativer Species-Archetyp pro `PLANET`/`MOON` abgeleitet; das Fokus-HUD
zeigt dafuer jetzt optional `Species:` im bestehenden CAPS-Stil.
Darauf sitzt jetzt zusaetzlich `Survey UX v2` als reiner
Readout-/HUD-Block:
das linke Fokuspanel ist jetzt standardmaessig `Summary` statt
datenreich, der rechte Root-Inspector liest wieder klar als Navigator
und planetennahe `LIFE`-Badges machen biologische Aktivitaet in
Detailansichten direkt am Body scanbar, ohne schon echte Population zu
behaupten.
Darauf sitzt jetzt zusaetzlich `Planet Summary v1` als kleiner
Summary-HUD-Slice:
fokussierte `PLANET`-/`MOON`-Bodies zeigen im Summary-Modus jetzt eine
zweizeilige Hauptaussage aus `Environment`/`Climate` plus
`Life`/`Density`/`Species`, waehrend die bisherigen separaten
Environment-, Life-, Species- und Density-Zeilen in diesem Modus
bewusst verschwinden. `Details` bleibt der Expertenmodus fuer Track,
Biomass, World, Life Potential und Rohwerte.
Darauf sitzt jetzt zusaetzlich Stage 1 von `Survey Color v1`:
der rechte Root-Inspector rendert Rows nicht mehr als einen langen
Button-String, sondern als strukturierte `PanelContainer`-Rows mit
Name-, Kind-, Environment-, Climate-, Life- und Note-Elementen. Farben
kommen enum-basiert ueber einen reinen View-Helper und ergaenzen die
weiterhin sichtbaren Textlabels; Environment und Climate sind getrennte
Chips, Planeten-/Mondnamen lesen fetter, Sterne waermer und Schwarze
Loecher kuehler.
Stage 2 von `Survey Color v1 + Life Detail Panel v1` ist ebenfalls
umgesetzt:
Inspector-Life-Chips und planetennahe `LIFE`-Badges koennen jetzt ein
read-only `LifeDetailPanel` oeffnen. Das Panel reusst fuer bestehende
Readouts ausschliesslich `OrbitHudFormatter.format_*`, zeigt noch keine
Populationen oder generierten Kreaturenbilder und fuehrt damit keine
neue Simulationswahrheit ein.
Ein direkter Follow-up hat dabei die planetennahen Badge-Hitboxen
gehaertet: frei platzierte Badge-Buttons setzen ihre sichtbare
Control-Groesse jetzt explizit auf die gemessene Badge-Groesse, damit
der kleine `LIFE ...`-Text im Editor wirklich klickbar ist.
Der anschliessende Praxis-Fix macht zusaetzlich die sichtbaren
Badge-Textzeilen selbst zu transparenten Buttons, damit Klicks direkt
auf `LIFE MICROBIAL` oder die zweite Zeile wie `SPARSE` sicher im
Life-Detail-Pfad landen.
Darauf sitzt jetzt zusaetzlich `Genetic Lifeform Foundation v1` als
kleiner read-only Lifeform-/Trait-Layer vor echter Population:
`GeneticSpeciesService` baut auf `NativeSpeciesService` auf, erzeugt
deterministische Native-Forms-Profile mit stabilen `trait_loci` und
textuellen Visual-Profilen und fuellt damit im `LifeDetailPanel` die
bisherigen `Native forms`-/`Visual profile`-Platzhalter. Es gibt weiter
keine Populationszahlen, keine Kriege, keine Katastrophen, keine
Zivilisationen und keine generierten Kreaturenbilder.
Ein direkter Follow-up haertet dabei den `MICROBIAL`-Pfad ohne
Native-Species-Basis: Track/Thermik fallen jetzt nicht mehr auf die
Default-Species-Werte zurueck. Das Panel bleibt ausserdem kompakter,
weil `Abundance` nur noch in `Native forms`/`Dominant form` mitlaeuft
und keine eigene Datenblatt-Zeile mehr bekommt.
Darauf sitzt jetzt zusaetzlich `Lifeform Pressure v1`:
Lifeform-Profile tragen einen qualitativen `SelectionPressureClass`-
Wert direkt auf dem Profil, ohne daraus ein neues Gen oder eine
Population zu machen. `COMPLEX_ECOSYSTEM`-Welten mit `DIVERSE`
Richness koennen jetzt mehrere dominante Lebensformen zeigen; die
`Native forms`-Zeile liest darum `ROLE ABUNDANCE/PRESSURE`, waehrend
`Dominant form` bei mehreren dominanten Profilen plural als
`Dominant forms` rendert. Es gibt weiter keine Populationszahlen, keine
zeitliche Evolution, keine Kriege, keine Katastrophen und keine neuen
redundanten Niche-/Competition-/VisualPattern-Enums.
Darauf sitzt jetzt zusaetzlich `Life Ecology Foundation v1`:
`LifeEcologyService` leitet read-only aus `BiosphereScaleService` und
`GeneticSpeciesService` eine qualitative `PopulationClass` pro
stabiler Lifeform ab. `Population:` im `LifeDetailPanel` zeigt damit
jetzt spielbare Praesenz wie `FLOURISHING`, `STABLE` oder `SPARSE`,
aber in `Population:` selbst keine Counts, Kriege, Katastrophen,
Zivilisationen oder Settlement-Zahlen. Der neue `population_index` ist nur ein
normalisierter Praesenz-Hook fuer spaetere echte Count-Slices und kein
Census.
Darauf sitzt jetzt zusaetzlich `Population Estimates v1`:
`LifePopulationEstimateService` leitet read-only aus
`BiosphereScaleService` und `LifeEcologyService` grobe
Order-of-Magnitude-Ranges pro Lifeform ab. Das `LifeDetailPanel` zeigt
dadurch eine neue `Estimate:`-Zeile wie `~10M-100M`, ohne daraus einen
echten `PopulationState`, Census, Settlement-State oder dynamische
Population zu machen. Rollen-, Pressure- und Abundance-Effekte werden
nicht doppelt gezaehlt, weil der Service direkt auf dem bereits
kalibrierten `population_index` aufsetzt.
Ein anschliessender Root-Overview-Performance-Fix macht den
`GalaxyProxyRenderer` dirty-getrieben: der 100-Root-Proxy-Pfad queued
nicht mehr jedes Render-Frame pauschal ein Redraw, sondern nur noch bei
Kamera-/Canvas-, Viewport- oder Fokus-/Resident-Aenderungen. Sichtbare
Stern-Proxies sind bewusst keine Sim-Zeit-Quelle fuer Redraws mehr,
damit ein stabiler Root-Overview nicht periodisch die gesamte
Proxy-Projektion neu aufbaut.
Ein direkter Folgefix deckelt denselben Stern-Proxy-Pfad auf maximal
acht Root-Systeme pro Redraw. Die Auswahl bevorzugt groessere
projizierte Root-Systeme und nutzt Screennaehe nur als Tie-Breaker;
uebrige sichtbare Roots fallen weiterhin auf BH-only-Proxies zurueck.
Neue `PerfProbe`-Spalten wie `galaxy_proxy_star_proxies`,
`galaxy_proxy_star_proxy_roots`,
`galaxy_proxy_star_proxy_capped_roots`,
`galaxy_proxy_recomputes` und `galaxy_proxy_redraw_requests` machen den
Pfad im CSV-Dump direkt beobachtbar.
Der anschliessende Re-Dump zeigte den Rest-Ruckler weiterhin, aber mit
`galaxy_proxy_visible_roots = 0` und `galaxy_proxy_draw_entries = 0`;
damit war der sichtbare 254-Draw-Call-Zustand nicht mehr den
Galaxy-Proxies zuzuordnen. Eine 24-Sample-Linien-LOD reduzierte zwar
die Primitive, aber nicht die Draw-Calls ausreichend. Deshalb blendet
`OrbitViewRenderer` direkte `AntialiasedLine2D`-Stern-Orbits im
`root-overview` jetzt komplett aus; die direkten Sterne bleiben
sichtbar und der Detailmodus stellt die Orbitlinien wieder her.
Neue `PerfProbe`-Spalten `orbit_visible_line_count`,
`orbit_root_overview_line_count` und `orbit_visible_point_count`
machen diesen Pfad messbar.
Der naechste Dump zeigte den Rest-Ruckler erneut mit
`orbit_* = 0`, `galaxy_proxy_* = 0` und `visible_badges = 0`, aber
weiterem Sprung von `draw_calls 51 -> 250` genau bei
`body_visual_draws = 5` und `body_overlay_draws = 4`. Ein kurz
getesteter Body-Visual-LOD-Schnitt fuer Fokus-BH und direkte Sterne
wurde danach bewusst wieder zurueckgenommen, weil der spaetere
Before-/After-Dump den rechten Inspector als eigentlichen Restpfad
bestaetigte und der Body-LOD-Versuch visuelle Regressionen riskierte.
Ein direkter Diagnose-Follow-up erweitert denselben Messpfad, ohne
Rendering- oder Simulationslogik weiter umzubauen:
`GalaxyProxyRenderer` sampelt jetzt Signatur-Aenderungsgruende wie
`focus_root_view`, `canvas_basis`, `canvas_origin`,
`resident_roots`, leere Proxy-Recomputes und cached Entry Counts.
`OrbitViewRenderer` sampelt zusaetzlich sichtbare Body-Anzahl sowie
Detail-/Star-Closeup-/Effective-Scale-Maxima. Damit soll der naechste
`P`-Dump den verbliebenen Fokus-Ruckler klarer zwischen Kamera-/Canvas-
Invalidierung, leerer Proxy-Arbeit und Body-Visual-Skalierung trennen.
Der direkte Before-/After-Dump plus Nutzerbeobachtung bestaetigten
danach den eigentlichen Restpfad: nicht der BH-Fokus selbst, sondern der
automatisch aufploppende rechte `RootInspectorOverlay` machte den
Root-Overview schwer. Der Inspector oeffnet deshalb jetzt nicht mehr
automatisch bei BH-/Root- oder Proxy-Klicks; diese Klicks fokussieren
nur noch. Der explizite Inspector-Pfad ist jetzt `I` als Toggle fuer
den aktuellen Fokus-Root. Neue `PerfProbe`-Spalten
`root_inspector_open`, `root_inspector_row_count` und
`root_inspector_model_apply_count` machen diesen UI-Zustand im Dump
direkt sichtbar.
Ein anschliessender gezielter Inspector-Perf-Slice reduziert den
gemessenen offenen Inspector-Zustand direkt:
im `ROOT_OVERVIEW` und beim direkten Root-/BH-Fokus rendert der rechte
Inspector jetzt nur noch Root plus direkte Sterne als kompakten
Navigator, waehrend Summary-Zahlen weiter aus dem vollen Modell kommen.
Im lokalen Sternfokus rendert derselbe Inspector jetzt nur den
fokussierten Stern detailliert mit dessen Planeten-/Mond-Unterbaum;
andere Sterne bleiben reine Navigationszeilen. Im Planet-/Mondfokus
bleibt entsprechend nur der Fokuspfad plus Fokus-Unterbaum
materialisiert. Neue `PerfProbe`-Spalten
`root_inspector_full_row_count` und
`root_inspector_compact_root_overview` sowie
`root_inspector_compact_focus_branch` trennen sichtbare Row-Kosten von
der vollen Modellgroesse und vom aktiven Kompaktmodus.
Ein anschliessender Diagnose-Slice erweitert den `P`-Dump ohne neue
Dauerlast: neben der bisherigen CSV-Zeitreihe schreibt `orbit_testbed`
jetzt einen gleichnamigen JSON-Sidecar mit punktuellen On-Demand-
Snapshots fuer Szene, Zeit, Fokus, Registry, Kamera, Aktiv-Set,
Derived-Cache, Renderer, Proxy, Streaming, UI-Panels, Backdrop und
Service-Counter. Der Sidecar wird nur beim Tastendruck gebaut und ist
Diagnoseausgabe, keine Simulationswahrheit. Ein direkter Bugfix macht
die JSON-Safe-Konvertierung fuer `StringName`-/`NodePath`-Werte und
`StringName`-Dictionary-Keys runtime-sicher, damit der `P`-Dump im
Editor nicht am Sidecar-Schreiben scheitert.
Ein direkter Follow-up adressiert den danach sichtbaren Fokus-Ruckler
bei deaktiviertem VSync: `TimeService` merkt das letzte autoritative
Sim-dt, `LocalBubbleManager` kann daraus rein view-seitig eine
zwischen Physics-Ticks interpolierte Position komponieren und
`OrbitViewRenderer` nutzt Godots Physics-Interpolation-Fraction fuer
Kamera-/Fokus-Readouts und Body-Positionen. `BodyState` bleibt dabei
unveraendert; Trails bleiben bewusst tick-basiert, damit unlocked FPS
nicht hunderte Trailpunkte pro Sekunde erzeugt.
Ein weiterer kleiner Hotpath-Fix laesst den `GalaxyProxyRenderer` jetzt
nur im echten `root-overview` aktiv und pickbar. Lokale
Sonnen-/Planeten-/Mond-Foki muessen beim Reinzoomen dadurch nicht mehr
parallel den 100-Root-Proxy-Pfad pruefen oder redrawen. Zusaetzlich
schreibt `OrbitViewRenderer.set_world_scale(...)` Orbit-/Trail-
Line-Widths nur noch, wenn sich der Scale wirklich geaendert hat.
Ein weiterer Follow-up adressiert den gemeldeten FPS-Einbruch mit
offenem rechtem Root-Inspector und sichtbaren Life-Badges:
`RootInspectorOverlay` baut seine Row-Nodes bei identischem
Inspector-Modell nicht mehr neu auf und exponiert dafuer einen
`model_apply_count` im Debug-Snapshot. `OrbitViewRenderer` schreibt
Trail-Line-Punkte nur noch bei echter History-Aenderung, statt jedes
Render-Frame ein neues `PackedVector2Array` zu setzen. Das
`PlanetBadgeOverlay` liest Body-Sichtbarkeit, Screen-Center und
projizierten Radius jetzt ueber einen gemeinsamen Renderer-Metrics-Call
statt ueber drei separate Transform-Abfragen pro Body.
Ein weiterer kleiner Fokuswechsel-Fix verhindert einen sichtbaren
Einzel-Frame-Scale-Pop beim Klick von stark gezoomten Foki auf Sterne:
`OrbitCameraController` setzt das Renderer-Closeup-Ratio jetzt direkt
auf den neuen Ziel-Fokus, bevor der naechste Render-Sync mit altem
Detail-/Closeup-Wert laufen kann. Kamera-Smoothing bleibt erhalten;
Sim-Zeit, Orbit-Zustand und Body-Groessen bleiben unveraendert.
`Performance Closure v2` schliesst den naechsten Render-Hotpath:
Trail-History wird jetzt ueber `TimeService.sim_tick` statt ueber den
Renderloop fortgeschrieben; `_sync_visual_positions()` positioniert nur
noch Bodies, Orbits und Trail-Lines. `UniverseRegistry` bietet dafuer
additiv `get_update_order_ref()` als trusted read-only Hotpath-Iteration,
waehrend `get_update_order()` weiter die defensive Kopie liefert.
Sterne queueen ihren CPU-gezeichneten Halo nicht mehr per `_process()`
jedes Frame neu; die Sternscheibe bleibt ueber den bestehenden
`body_star.gdshader`/`TIME`-Pfad animiert. Bewusst akzeptiert: Trails
sind in v2 sim-tick-proportional und koennen bei hohem `time_scale`
eckiger wirken.
Darauf sitzt jetzt zusaetzlich `View Bookmarks v1` als kleiner
session-only QoL-Slice:
`Ctrl+1..5` speichert den aktuellen Fokus samt Zoom-Faktor und
manuellem Pan, `1..5` stellt denselben View-State wieder her. Der
Bookmark-State lebt nur im Testbed-Composition-Root, wird bei
World-Scope-Wechsel geloescht und ignoriert stale Body-IDs sauber;
es gibt kein Savegame, keine Streaming-Sonderlogik und keine neue
Simulationswahrheit.
Ein direkt danach eingeschobener Focus-/Badge-Performance-Follow-up
reduziert weiteren View-Churn: planetennahe `LIFE`-Badges cachen ihre
Text-/Layout-Messung bei stabilen Zeilen und bewegen nur noch ihre
Position pro Refresh, waehrend `OrbitBodyVisual` winzige
Detail-/Star-Closeup-Jitter unterhalb einer kleinen Schwelle nicht mehr
als neuen Shader-/Redraw-State schreibt. `OrbitViewRenderer` vermeidet
zusaetzlich unveraenderte Scale-/Visibility-Property-Writes im
per-frame Sync. Die Sim-Wahrheit und der OrbitService bleiben davon
unberuehrt.
Ein weiterer kleiner Badge-Performance-Slice drosselt danach den
teuren Candidate-Pfad:
`PlanetBadgeOverlay.refresh()` scannt und sortiert planetare Badge-
Kandidaten nicht mehr jedes Render-Frame, sondern rebuildet die
Candidate-Liste nur noch dirty/periodisch. Bereits sichtbare Badges
ziehen ihre Screen-Position weiter pro Frame nach, damit die View nicht
stottert. Der Debug-Snapshot exponiert dafuer
`badge_candidate_rebuild_count`; `badge_text_apply_count` bleibt die
separate Text-/Layout-Messung.
Ein weiterer Fokus-/Pan-Follow-up schliesst danach die verbliebene
Frame-Order-Kante: `orbit_testbed.gd` wendet Kamera, Zoom und
Manual-Pan jetzt vor dem expliziten Renderer-Sync an, damit
Body-Scale, Detail-LOD und Overlays im selben Frame den aktuellen
Kamera-State lesen. Sofortige Fokus-/Bookmark-Restores duerfen den
Renderer-Same-Frame-Guard gezielt uebersteuern, damit deferred
UI-Klicks keinen alten Visual-State bis zum naechsten Frame behalten.
Auch dieser Fix bleibt reine View-/Scene-Synchronisierung.
Der kleine Folge-Slice pinnt diese Reihenfolge jetzt enger:
Kamera-Frame, LOD-/Frame-Kontext, Renderer-Sync, danach Large-World-
Streaming. Derselbe Immediate-Pfad gilt fuer Fokuswechsel und
Bookmark-Restore. Erfolgreiche `NUMERIC_LOCAL -> KEPLER_APPROX`-Exits
zaehlen weiterhin in den Perf-Countern, loggen aber nicht mehr als
Warning; nur blocked Exits und Substep-Caps bleiben Warnpfade.
Ein begleitender Workflow-/Repo-Hygiene-Slice haertet jetzt den
Agentenvertrag:
`AGENTS.md` beschreibt Startprotokoll, Validierung,
Doku-Sync, Review-Uebergabe und Commit-Vorschlagspflicht explizit,
`CLAUDE.md` verweist Claude Code auf die Reviewer-Rolle, lokale
Claude-State-Dateien werden nicht mehr geteilt und `run_tests.bat`
nutzt `GODOT_BIN` statt eines fest verdrahteten lokalen Godot-Pfads.
Ein direkter Architektur-Hygiene-Follow-up entkoppelt danach
`OrbitService` von `PerfProbe`: der Sim-Service exponiert nur noch
read-only Perf-Counter-Snapshots, waehrend `orbit_testbed.gd` diese
Werte in die bestehenden `PerfProbe`-Spalten sampelt. Damit zeigt keine
Abhaengigkeit mehr aus `src/sim/` nach `src/tools/debug/`.
Der naechste Hygiene-Follow-up legalisiert die bereits vorhandene
`BubbleActivationSet`-Exit-Hysterese als rein geometrische read-only
Relevanzklassifikation: sie stabilisiert nur das Aktiv-Set-Wish am
Distanzrand, waehrend `OrbitService` alleiniger Autor fuer
`BodyState.current_mode`, Grace und Rejoin-Budget bleibt.

Die Simulationsbasis bleibt getrennt von der Darstellung:

- `src/core/` -> Zeit, Einheiten, IDs, Mathematik
- `src/sim/` -> autoritative Simulationsdaten und Orbit-Update
- `src/runtime/` -> fokus-relative Ableitung / Bubble
- `scenes/` und `src/tools/rendering/` -> View und Projektion

## Was aktuell umgesetzt ist

### Simulation / Architektur

- Foundation-Schritt 1 ist implementiert (OrbitService `AUTHORED_ORBIT` +
  `KEPLER_APPROX`, StarterWorld).
- `LocalBubbleManager` nutzt jetzt die dokumentierte Step-2-
  Bubble-Komposition via LCA statt der frueheren einfachen
  Fokus-Subtraktion.
- `WorldLoader` laedt benannte Welten jetzt explizit im `sim/`-Layer;
  `orbit_testbed.gd` laedt nicht mehr direkt `StarterWorld`.
- `WorldLoader` exponiert jetzt `starter_world`, `sample_system` und
  `generated_system`; die Generator-Welt laeuft bewusst ueber dieselbe
  Vorvalidierung und Registry-Transaktion wie die handgebauten Welten.
- `BodyDef` enthaelt jetzt erste statische Weltmodell-Felder fuer
  Rotation, Achsneigung, deren saisonale Orbit-Frame-Orientierung,
  Leuchtkraft und Albedo.
- `BubbleActivationSet` klassifiziert Bodies jetzt read-only relativ
  zum aktuellen Fokus in `ACTIVE`, `INACTIVE_DISTANT` und
  `INACTIVE_NO_LCA`; eine rein geometrische Enter-/Exit-Hysterese
  stabilisiert dabei nur das Aktiv-Set-Wish am Distanzrand.
- `OrbitService` bridged das aktuelle Aktiv-Set jetzt explizit in den
  Sim-Layer und schaltet eligible `KEPLER_APPROX`-Bodies minimal auf
  `NUMERIC_LOCAL`.
- `LocalOrbitIntegrator` ist als pure Parent-Only-Mathematik via
  Velocity Verlet implementiert und hat jetzt einen reinen
  Substep-Helper fuer grosse numerische `dt`.
- `OrbitService` haertet den numerischen Pfad jetzt mit
  OrbitService-seitiger Missing-Request-Grace, Substepping sowie
  `Cap+Warn`-Dedup gegen dt-Spitzen und Wish-Rand-Thrashing.
- `OrbitService` budgetiert jetzt auch den Rueckwechsel
  `NUMERIC_LOCAL -> KEPLER_APPROX`: uebergrosse Rejoin-Deltas blockieren
  den Snap, halten den Body autoritativ im numerischen Regime und
  integrieren im selben Tick weiter. Erfolgreiche Rueckwechsel sind
  Counter-only; nur blocked Exits warnen weiter.
- `ThermalService` liefert jetzt on-demand minimale Insolation,
  global gemittelten absorbierten Fluss und einfache
  Gleichgewichtstemperatur aus `luminosity_w`, `albedo`, Parent-Kette
  und aktuellem `BodyState`.
- `ThermalService` nutzt jetzt zusaetzlich `axial_tilt_rad` und
  `north_pole_orbit_frame_azimuth_rad` fuer saisonale Geometrie und
  liefert on-demand subsolare Breite sowie tagesgemittelte TOA-
  Insolation fuer ausgewaehlte Breiten.
- `AtmosphereService` legt jetzt on-demand ein minimales,
  datengetriebenes Greenhouse-Modell (`greenhouse_delta_k`) auf
  `T_eq`, liefert daraus `surface_temperature_k` und meldet jetzt
  zusaetzlich bandbewusste Oberflaechentemperaturen fuer `-60deg`,
  `Eq` und `+60deg`.
- `EnvironmentService` klassifiziert `PLANET`- und `MOON`-Bodies jetzt
  read-only zonenbewusst ueber drei feste Breitenbaender als
  `HABITABLE`, `MARGINAL` oder `HOSTILE` und leitet zusaetzlich erste
  planetare Oekosystem-Typen (`FROZEN`, `TEMPERATE`, `SEASONAL`,
  `HOT`) ab.
- `BodyDef` enthaelt jetzt zusaetzlich zwei erste chemie-agnostische
  Weltmodellachsen fuer spaetere Welt-/Life-Folgepfade:
  `volatile_inventory_ratio` und `climate_buffer_factor`.
- `ThermalService` und `AtmosphereService` exponieren jetzt zusaetzlich
  pure Helper fuer radiative, saisonale und latitudinale
  Temperaturauswertung, damit dieselbe Math sowohl im Live-Pfad als
  auch in spaeterer Jahresanalyse verwendet wird.
- `PlanetaryYearSampler` wertet planetare und lunare Jahresprofile jetzt
  analytisch und read-only ueber `AUTHORED_ORBIT` bzw. `KEPLER_APPROX`
  aus, ohne `BodyState`, `TimeService` oder
  `OrbitService.recompute_all_at_time(...)` fuer Analysezwecke
  anzufassen.
- `PlanetaryStateService` liegt jetzt als eigener read-only
  Derived-Service neben `EnvironmentService`:
  `Environment` bleibt die Aussage fuer den aktuellen Zustand, `World`
  beschreibt den Charakter ueber das Jahr.
- `LifePotentialService` liegt jetzt als weiterer read-only
  Derived-Service neben `PlanetaryStateService`:
  `Life Potential` beschreibt fuer `PLANET`- und `MOON`-Bodies noch
  keine Biosphaere, sondern nur den aktuell dominanten Chemiepfad
  (`WATER_CARBON`, `SULFUR_REACTIVE`, `CRYOGENIC_SOLVENT`) samt
  Potenzialklasse (`NONE`, `LOW`, `MEDIUM`, `HIGH`).
- `PlanetaryYearSampler`, `PlanetaryStateService` und
  `LifePotentialService` exponieren jetzt zusaetzlich registry-freie
  Pure-Helper; dieselbe Jahres-, World- und Life-Math laeuft damit
  sowohl fuer residente Bodies als auch fuer Galaxy-/Manifest-Defs,
  ohne Temp-Registry oder Math-Duplikation.
- `ProtoBiosphereSimulationService` fuehrt jetzt den ersten
  persistenten Life-Layer ausserhalb von `BodyState` ein:
  gespeichert werden nur stabile Seed-/Drift-Parameter pro
  `PLANET`/`MOON`, waehrend aktueller `Life`-Fortschritt, Stage und
  dominanter Track lazy aus `sim_time_s` berechnet werden.
- `LifeTrackLookup` buendelt jetzt die chemistry-aware
  Track-Praeferenzmatrix fuer `WATER_CARBON`, `SULFUR_REACTIVE` und
  `CRYOGENIC_SOLVENT` an genau einer Stelle; `LifePotentialService` und
  `BiosphereScaleService` konsumieren dieselben Lookups und
  Tie-Break-Regeln statt still zu driften.
- Diese v1b-Proto-Biosphaere ist bewusst deterministisch und
  monoton-konvergent:
  `progress = clamp(seed + delta * ticks_elapsed, 0, 1)`.
  Es gibt in diesem Block also noch keine emergenten Dynamiken, sondern
  einen ehrlichen Background-State-Pfad fuer sichtbaren biologischen
  Fortschritt ueber Sim-Zeit.
- Die Seed-/Drift-Kalibrierung ist jetzt fest:
  `HIGH -> 0.50 / +0.03`,
  `MEDIUM -> 0.30 / +0.01`,
  `LOW -> 0.10 / -0.01`,
  `NONE -> 0.00 / -0.03`.
  Dadurch startet `HIGH` bewusst noch nicht als `MICROBIAL`, sondern
  erreicht den Cap erst nach vier Bio-Ticks a zehn Tagen.
- `ProtoBiosphereSimulationService` initialisiert bei Named Worlds und
  Galaxy-Catalogs jetzt Background-State fuer alle `PLANET`-/`MOON`-
  Bodies, auch wenn ein Root nie resident wird; resident und offscreen
  lesen bei gleichem `sim_time_s` denselben `Life`-Zustand.
- `BiosphereScaleService` fuehrt jetzt den naechsten quantitativen
  Life-Layer ein:
  pro Track und pro festem Band (`south`, `equator`, `north`) werden
  `carrying_capacity` und `biomass` read-only berechnet.
- Die bandweise Carrying Capacity liest dieselben chemistry-aware
  Track-Lookups wie `LifePotentialService`, nutzt aber die bandweisen
  Jahres-Mitteltemperaturen als lokale Thermal-Gates und die globalen
  `World`-Achsen fuer Volatiles, Buffer, Stability und Seasonality.
- Biomasse fuehrt bewusst **kein** zweites Zeitmodell ein:
  `BiosphereScaleService` nutzt direkt den bestehenden
  Proto-Progress aus `ProtoBiosphereSimulationService` und leitet daraus
  `biomass_fraction = progress^2` ab.
- Die neue player-facing `Life:`-Aussage kommt ab jetzt aus
  `BiosphereScaleService`, nicht mehr direkt aus dem Proto-Substrat.
  Die sichtbaren Stages sind jetzt:
  `STERILE`, `PREBIOTIC`, `MICROBIAL`,
  `COMPLEX_MULTICELLULAR`, `COMPLEX_ECOSYSTEM`.
- Der alte Proto-Desc-Pfad bleibt parallel erhalten fuer interne Tests
  und Debug; `Life v2` fuehrt also bewusst eine neue Snapshot-Familie
  ein, statt den v1b-Substratpfad semantisch umzudeuten.
- Die aktuelle v2-Kalibrierung ist dabei bewusst bandstrenger als die
  frueheren groben Anchor-Annahmen:
  `sample_system.planet_a` traegt faktisch nur aequatoriale
  `WATER_CARBON`-Biomasse und endet mit den jetzigen Band-Gates deshalb
  bei `COMPLEX_MULTICELLULAR`, nicht bei `COMPLEX_ECOSYSTEM`.
  `starter_world.gamma_iv` kalibriert auf
  `COMPLEX_MULTICELLULAR`, `starter_world.gamma_iii` dagegen auf
  `COMPLEX_ECOSYSTEM`.
- `PlanetaryStateService` cached seine annualisierten sampled-year-
  Profile pro Body jetzt lazy, weil diese in v1 nur von statischen
  `BodyDef`-/Orbit-Daten abhaengen; `DerivedSnapshotCache` cached davon
  nur noch die UI-konsumierbaren Desc-Copies.
- `OrbitTimeScaleController` authored Zeitpresets jetzt bewusst als
  lesbare Sim-Zeitraten statt als rohen Multiplikator-Teppich:
  `10 s/s`, `1 min/s`, `10 min/s`, `30 min/s`, `1 h/s`, `6 h/s`,
  `1 d/s`, `7 d/s`.
- Der produktive Default liegt jetzt bei `1 h/s`; der regulaere
  Preset-Flow startet bei `10 s/s`, waehrend der Slider davon getrennt
  weiter bis `1 s/s` als bewussten Feinmodus herunterreichen darf.
- `OrbitHudFormatter` rendert die normale Scale-Zeile jetzt als
  `Rate: ...   Preset ...   Zoom ...` statt als `Speed x...`; rohe
  Multiplikatoren sind damit keine primaere User-Sprache mehr.
- Das Fokus-HUD zeigt jetzt zusaetzlich eine kompakte
  `Cadence: Bio tick ~ ...`-Zeile.
  Diese liest direkt aus
  `ProtoBiosphereSimulationService.BIO_TICK_STEP_S / time_scale` und
  macht damit die Simulationsgeschwindigkeit erstmals im Kontext der
  bereits existierenden Life-/Biosphaeren-Dynamik sichtbar.
- `OrbitPeriodHelper` buendelt jetzt die bestehende
  `AUTHORED_ORBIT`-/`KEPLER_APPROX`-Periodenlogik fuer
  `PlanetaryYearSampler` und den neuen Orbit-Readout an genau einer
  Stelle; es gibt dafuer keine zweite Kepler-Periodenformel.
- `OrbitReadoutService` liegt jetzt als weiterer kleiner read-only
  Service im `sim/orbit/`-Layer:
  `rotation_period_s` wird direkt aus `BodyDef` gelesen,
  `orbital_period_s` aus dem bestehenden Orbitmodell abgeleitet.
- `DerivedSnapshotCache` fuehrt jetzt zusaetzlich
  `orbit_readout_desc` als weitere read-only Desc-Familie; das
  Fokus-HUD liest `Day:` und `Year:` dadurch ueber denselben
  Snapshot-Pfad wie `Environment`, `World`, `Life` und `Biomass`.
- Die bestehende Runtime-Zeile bleibt strukturell
  `T+ ...   steps ...   FPS ...`, rendert den `T+`-Wert jetzt aber
  adaptiv als `s`, `min`, `h`, `d` oder `y` statt immer nur in Tagen.
- Das Fokus-HUD zeigt jetzt zusaetzlich optionale `Day:`- und
  `Year:`-Zeilen fuer Bodies mit Rotations- bzw. Orbitbasis.
  `Year:` bleibt dabei bewusst der einheitliche User-Label fuer die
  Parent-Orbitperiode, auch bei Monden und BH-Sternen.
- `NativeSpeciesService` landet jetzt als weiterer kleiner read-only
  Derived-Service im `sim/life/`-Layer zwischen `Life v2` und spaeterer
  Population:
  pro `PLANET`/`MOON` wird genau ein dominanter nativer
  Species-Archetyp aus `Life Potential`, `Life v2` und der dominanten
  Band-Thermik abgeleitet.
- Species starten bewusst erst ab
  `BiosphereScaleService.Stage.COMPLEX_MULTICELLULAR`;
  `MICROBIAL`, `PREBIOTIC` und `STERILE` bleiben weiter ohne konkrete
  Species-Aussage.
- `BiosphereScaleService` exponiert dafuer jetzt zusaetzlich
  `dominant_band_id` und `dominant_band_thermal_class`, damit
  `NativeSpeciesService` keine zweite Band- oder Thermal-Wahrheit
  erfinden muss.
- Die neue Species-Aussage bleibt in v1 klein und streng regelbasiert:
  `complexity`, `richness`, `habitat`, `metabolism` und `mobility`
  werden als feste Klassen ausgegeben; es gibt noch keine
  Species-Listen, keine Oekologie und keine Populationen.
- `OrbitHudFormatter` fuehrt jetzt zusaetzlich eine kleine gemeinsame
  Survey-Sprache fuer `Summary`-HUD, Root-Inspector und planetennahe
  Badges:
  kurze Life-Stages (`COMPLEX`, `ECOSYSTEM`), kurze Species-Texte
  (`PHOTO`, `CHEMO`, `SULFUR`, `CRYO`) und eine qualitative
  `Density:`-Lesart (`SPARSE`, `THRIVING`, `ABUNDANT`), die bewusst nur
  an die bestehende `Life v2`-Stage gekoppelt ist.
- Das linke Fokus-HUD des `orbit_testbed` hat jetzt zwei explizite
  Modi:
  `Summary` als Default und `Details` als Expertenmodus.
  `Summary` zeigt fuer `PLANET`/`MOON` jetzt zwei kompakte
  Hauptaussage-Zeilen:
  `Summary: <Environment> / <Climate>` und
  `Life: <Stage>   Density: <...>   Species: <...>`.
  Die frueheren separaten `Environment`-, `Life`-, `Species`- und
  `Density`-Zeilen sind dort bewusst ausgeblendet; `Cycle`, `T+`,
  `Rate` und `Cadence` bleiben erhalten.
  `Details` zeigt weiter die tieferen Analysewerte (`Environment`,
  `Bands`, `World`, `Life`, `Biomass`, `Species`, `Life Potential`,
  `Season / Primary source`, `Rotation`, `Orbit`).
- Der Root-Inspector liest jetzt wieder klar navigator-first:
  nicht-fokussierte `PLANET`-/`MOON`-Rows sind kompakte Einzeiler aus
  `name`, `kind`, Environment-Badge, Life-Badge und `note`;
  `World`, `Biomass`, `Life Potential` und `Species` verschwinden dort
  bewusst.
  Nur die fokussierte Planet-/Moon-Row darf optional eine zweite
  kompakte `Species: <short> / <density>`-Zeile tragen, und auch nur
  bei echter Species-Basis.
- `PlanetBadgeOverlay` landet als neuer view-only Overlay-Pfad zwischen
  Welt und HUD:
  ausserhalb des `ROOT_OVERVIEW` duerfen sichtbare `PLANET`-/`MOON`-
  Bodies mit ausreichender projected size kleine zweizeilige
  `LIFE ...`-Badges tragen.
  Der Pfad bleibt bewusst einfach:
  kein Overlap-Handling, kein neuer visible-body-specific
  Interest-Hydration-Pfad, maximal 24 Badges, Badge-Readouts nur ueber
  den bereits bestehenden per-root-Interest-Pfad.
- `species_richness_class` basiert bewusst auf dem dominanten
  `carrying_capacity_index` statt auf Biomasse; damit bleiben
  Evolutionsfortschritt (`complexity`) und Nischenbreite (`richness`)
  zwei getrennte Achsen.
- `mobility_class` koppelt bewusst nicht direkt an Biomasse, sondern an
  `complexity + richness`; `EARLY_MACRO` bleibt in v1 auf
  `SESSILE`/`COLONIAL` begrenzt, `MOTILE` wird erst fuer
  `DIVERSE_MACRO + DIVERSE` freigeschaltet.
- `DerivedSnapshotCache` fuehrt dafuer jetzt zusaetzlich
  `native_species_desc` als weitere read-only Desc-Familie ein.
- Das Fokus-HUD zeigt jetzt fuer Bodies mit Species-Basis zusaetzlich
  eine kompakte Zeile
  `Species: <COMPLEXITY> / <METABOLISM> / <HABITAT> / <MOBILITY>`.
  `Root Inspector` bleibt dabei bewusst unveraendert kompakt.
- `LifePotentialService` bewertet diese World-Achsen bewusst nur ueber
  die fuenf Jahresklassen
  `Thermal Extremity`, `Volatiles`, `Buffering`, `Stability` und
  `Seasonality`; `Environment` bleibt dabei bewusst eine separate
  "jetzt"-Aussage und geht nicht als gewichtete Kernachse in den
  Life-Score ein.
- Die aktuelle v1a-Kalibrierung ist dabei fuer kalte Welten bewusst
  etwas schaerfer als der urspruengliche Plantext:
  `WATER_CARBON` wird auf `COLD` aktiv zurueckgedraengt, waehrend
  `CRYOGENIC_SOLVENT` sowohl `FROZEN` als auch `COLD` als starke
  Thermikbasis liest; das verhindert kaltes Water-/Earth-Rauschen auf
  Bodies wie `gamma_iii`.
- Die annuale `World`-Lesart arbeitet jetzt ueber fuenf explizite
  Klassenachsen:
  `Volatiles`, `Buffering`, `Seasonality`, `Stability` und
  `Thermal Extremity`.
- Handgebaute Referenzwelten und der generierte Root-System-Pfad
  wurden fuer diese neuen Achsen bewusst backfilled:
  `sample_system`, `starter_world` und generierte `shade_*`-Planeten
  tragen jetzt explizite oder deterministisch korrelierte
  Reservoir-/Buffer-Werte statt impliziter Defaults.
- Neue Sim-/Thermal-Regressionen pinnen jetzt explizit, dass ein
  blocked `NUMERIC_LOCAL`-Exit numerisch weiterintegriert und
  `ThermalService` dabei keinen stillen analytischen Rueck-Snap sieht.
- `DerivedSnapshotCache` verteilt jetzt read-only den letzten
  Thermal-/Environment-Snapshot an HUD und Renderer, fuehrt jetzt aber
  ein explizites Interest-Set und invalidiert bei verdrahtetem
  `OrbitService` nur dirty-abhaengige interessierte Bodies; ohne diesen
  Hook bleibt `TimeService.sim_tick` der Fallback.
- `DerivedSnapshotCache` fuehrt jetzt zusaetzlich `biosphere_desc` als
  weitere read-only Desc-Familie; HUD und Inspector lesen damit
  `Life` aus demselben Snapshot-Pfad wie `Environment`, `World` und
  `Life Potential`.
- `DerivedSnapshotCache` fuehrt jetzt zusaetzlich
  `biosphere_scale_desc` als weitere read-only Desc-Familie;
  der alte `biosphere_desc`-Pfad bleibt fuer das Proto-Substrat
  erhalten, waehrend HUD und Inspector ihr player-facing `Life:` jetzt
  aus `biosphere_scale_desc` lesen.
- Das `F3`-Debug-Overlay konsumiert bei verdrahtetem
  `DerivedSnapshotCache` denselben read-only Snapshot jetzt strikt
  snapshot-only; Cache-Misses bleiben sichtbar als `n/a`, statt im
  Frame-Loop live `ThermalService.describe_body(...)` nachzuziehen.
- `OrbitService` emittiert jetzt explizit `bodies_updated(ids, reason)`
  fuer geaenderte Runtime-Bodies und nutzt fuer `AUTHORED_ORBIT`-
  Velocities denselben zentralen Finite-Difference-Pfad wie der neue
  Proxy-Layer.
- `BubbleActivationSet` scannt im steady-state nicht mehr jedes Frame
  den ganzen geladenen Slice: same-root Bodies werden jetzt ueber dirty
  markierte IDs / Teilbaeume inkrementell reklassifiziert; Fokus- und
  World-Wechsel forcieren weiter den Full-Rebuild des aktuellen
  Detail-Slices.
- Registry-Churn in `BubbleActivationSet` laeuft jetzt separat ueber
  `topology_dirty`: `body_registered` / `body_unregistered` bereinigen
  entfernte Cache-IDs und reklassifizieren danach nur den aktuellen
  Fokus-root-Slice statt denselben Full-Rebuild-Pfad wie Fokuswechsel zu
  nutzen.
- `src/sim/world/` traegt jetzt erste Large-World-Datenmodelle:
  `GalaxyDef`, `RootSystemManifest`, `RootStarManifest`,
  `RootSystemGenerator` und `PilotGalaxyWorld`.
- `WorldLoader` kann jetzt neben flachen Named Worlds auch einen
  leichten `GalaxyDef`-Katalog fuer `pilot_galaxy` laden und gezielt
  einzelne Root-Slices materialisieren.
- `WorldLoader.materialize_galaxy_roots(...)` arbeitet fuer
  Galaxy-Welten jetzt delta-basiert statt ueber `clear()+reload`:
  unveraenderte residente Roots bleiben in der Registry, behalten ihre
  `BodyState`s und werden ueber eine kanonische `defs_signature`
  verglichen.
- Der erste Large-World-Content-Milestone ist jetzt eine kleine
  3-Root-Pilotgalaxie:
  `obsidian` als Hero-Root plus zwei deterministisch generierte
  Nachbar-Roots `onyx` und `umbra`.
- Darauf baut jetzt zusaetzlich eine zweite produktive Large-World-
  Galaxy `scaleup_galaxy_10` auf:
  `pilot_galaxy` bleibt unveraendert als 3-Root-Referenzslice erhalten,
  waehrend `scaleup_galaxy_10` denselben Hero-Root plus sieben weitere
  deterministisch generierte Zusatz-Roots traegt.
- Darauf baut jetzt zusaetzlich eine dritte produktive Large-World-
  Galaxy `scaleup_galaxy_30` auf:
  `obsidian`, `onyx` und `umbra` bleiben erhalten, dazu kommen
  `shade_01 .. shade_27` als deterministische Zusatz-Roots.
- Darauf baut jetzt zusaetzlich eine vierte produktive Large-World-
  Galaxy `scaleup_galaxy_100` auf:
  `obsidian`, `onyx`, `umbra` plus `shade_01 .. shade_97`.
- `scaleup_galaxy_10`, `scaleup_galaxy_30` und der test-only
  Stresspfad laufen jetzt ueber genau einen produktiven
  `ScaleupGalaxyCatalogFactory`-Builder in `src/sim/world/`;
  `StressGalaxyFactory` ist dadurch nur noch duennes Test-Wrapper-
  Stueck ueber denselben Produktpfad.
- `GalaxyDef` haelt jetzt zusaetzlich einen lazy Neighbor-Order-Cache
  pro Fokus-Root; `GalaxyStreamingController` zieht seine
  Neighbor-/Prewarm-Kandidaten dadurch nicht mehr frameweise ueber eine
  neue Vollsortierung des ganzen Catalogs.
- Generierte Root-Systeme sind jetzt bewusst auf den
  `obsidian`-/`starter_world`-Rootstandard normalisiert:
  dieselbe Sternanzahl, dieselben BH-Stern-Orbit-Lanes und derselbe
  `system_extent_m`-Baseline-Footprint statt kleinerer eigener
  Generator-Skalen.
- Der planetare Generator nutzt fuer generierte Roots jetzt ebenfalls
  wieder eine `obsidian`-artige lokale Orbit-Skala statt alter
  AU-/Luminositaets-basierter Fernbahnen; dadurch haengen Planeten in
  Root-Overviews nicht mehr scheinbar am schwarzen Loch oder schneiden
  rootweit sichtbar durch fremde Sternsysteme.
- Der produktive Catalog-Builder fuehrt jetzt zusaetzlich einen
  deterministischen Spacing-Guard ein:
  alle Root-Paare muessen mindestens
  `3.0 * (extent_a + extent_b)` Abstand halten; nur generierte
  Zusatz-Roots duerfen dafuer radial nach aussen relaxed werden.
- Der Relax-Schritt ist dabei bewusst extentskaliert statt magisch:
  `2.0 * max(candidate_extent, conflicting_extent)` entspricht grob
  einem System-Durchmesser und behaelt Seed, Winkel und Detail-Content
  des Zusatz-Roots bei.
- Nach `MAX_RELAX_ATTEMPTS = 16` bricht der produktive Builder
  explizit mit Fehler ab; es gibt keinen stillen Overlap und keinen
  zufaelligen Fallback.
- `GalaxyStreamingController` nutzt jetzt ein zeitbasiertes
  `update(delta_s, zoom_factor)` mit Hysterese:
  ein Nachbar-Root kommt erst unter `0.55` hinein, faellt erst ab
  `0.65` wieder heraus und bleibt dazwischen ueber `1.5 s` Keepalive
  resident; `prewarm` arbeitet separat mit `0.90 -> 1.00`.
- `GalaxyStreamingController` exponiert jetzt zusaetzlich einen
  read-only Debug-Snapshot fuer den Playtest:
  Fokus-Root, Resident-/Neighbor-/Prewarm-IDs, Keepalive-Restzeit,
  letzter Zoom-Faktor und ein kleiner Ringbuffer der juengsten
  Streaming-Ereignisse werden rein diagnostisch mitgefuehrt.
- `WorldLoader` fuehrt vorbereitete Root-Slices jetzt bewusst nur noch
  in genau einem cache-scopegebundenen Loader-Cache pro aktiver
  Welt/Galaxy; `GalaxyStreamingController.prewarm` fuellt nur noch
  diesen Loader-Cache und haelt keine zweite Root-Def-Kopie mehr.
- Topologie-Helfer sind jetzt in einem read-only
  `UniverseTopology`-Helper ueber `UniverseRegistry` gebuendelt statt
  parallel in Bubble-, Renderer- und Testbed-Code verteilt.
- Die wiederkehrenden Named-World-Test-Setups laufen jetzt ueber einen
  gemeinsamen `SimTestHarness` mit festem Build-/Teardown-Pfad statt
  ueber kopierte Boilerplate in mehreren Suites.
- Bodies aus einem anderen Root als der aktuelle Fokus liefern bewusst
  `Vector3.INF` und werden im Renderer nicht lokalisiert.
- `GalaxyStreamingController` faellt jetzt auch produktiv sauber ueber
  `focus_root_id -> default_resident_root_ids[0] -> root_ids()[0]`
  auf einen primaeren Fokus-Root zurueck, falls ein Galaxy-Catalog
  keine expliziten Defaults setzt.
- `OrbitViewRenderer` schneidet Cross-Root-Detailvisuals jetzt bereits
  vor `compose_view_position_m()` root-aware ab; dadurch bleiben
  Detail-Layer und Logs auch mit residentem Neighbor-Root ruhig, ohne
  die same-root Bubble-Semantik anzufassen.
- Derselbe `OrbitViewRenderer` behandelt `ROOT_OVERVIEW` jetzt als
  expliziten View-LOD statt als "Detailszene in klein":
  sichtbar bleiben nur BH plus direkte Sterne des Fokus-Roots; Planeten,
  Monde, ihre Orbitlinien und ihre Trails werden vor der
  View-Positionspipeline frueh ausgesiebt.
- `orbit_testbed.gd` koppelt den View-LOD jetzt bewusst an das
  `DerivedSnapshotCache`-Interest-Set:
  im `ROOT_OVERVIEW` bleibt Derived-Interesse fokus-only, waehrend
  Detailansichten weiter ihr root-lokales Planet-/Moon-Interest
  behalten.
- Large-World-Testbeds haben jetzt rechts angedockt einen ersten
  `RootInspectorOverlay`:
  der explizite `I`-Toggle oeffnet fuer den aktuell residenten
  Fokus-Root ein read-only Hierarchiepanel
  `BLACK_HOLE -> STAR -> PLANET -> MOON`.
- Der neue `RootInspectorModelBuilder` baut diese Hierarchie rein
  view-seitig aus `UniverseRegistry`, `UniverseTopology` und
  `DerivedSnapshotCache`; V1 fuehrt noch keinen globalen Atlas und keine
  nichtresidenten Root-Summaries ein.
- `OrbitHudFormatter` stellt jetzt zusaetzlich kleine wiederverwendbare
  Inspector-Badges fuer Environment-/Climate-Texte bereit, statt die
  Mapping-Logik in Overlay und HUD zu duplizieren.
- `orbit_testbed.gd` bleibt die einzige Controller-Stelle fuer den
  Inspector:
  der `I`-Toggle oeffnet ihn, normale Root-Klicks, Fokuswechsel oder
  passive Residency-Wechsel nicht.
- Der `ROOT_OVERVIEW`-Performance-Contract bleibt ausserhalb des
  offenen Inspectors unveraendert fokus-only.
  Als dokumentierter Ausnahmefall darf ein offener Inspector fuer genau
  den aktuell inspizierten Fokus-Root wieder root-lokales
  Planet-/Moon-Interest aktivieren, damit Planetentypen und Climate-
  Badges sofort sichtbar bleiben.
- Der Fokus-HUD und der Root-Inspector zeigen fuer `PLANET`- und
  `MOON`-Bodies jetzt zusaetzlich eine kompakte `World:`-Zeile aus den
  neuen planetaren Zustandsachsen, ohne daraus schon eine versteckte
  Life- oder Biosphaeren-Aussage abzuleiten.
- Der Fokus-HUD und der Root-Inspector zeigen fuer `PLANET`- und
  `MOON`-Bodies jetzt zusaetzlich getrennt `Life:` und
  `Life Potential:`:
  derselbe Planet kann damit gleichzeitig als
  `Environment` = jetzt, `World` = Jahrescharakter,
  `Life` = Proto-Biosphaerenstand und
  `Life Potential` = dominanter Chemiepfad lesbar werden.
- Der Fokus-HUD zeigt jetzt zusaetzlich eine quantitative
  `Biomass:`-Zeile; `Life:` ist damit nicht mehr nur der alte
  Proto-Stage-Text, sondern die player-facing Kurzfassung des neuen
  quantitativen Biosphaeren-Layers.
- Der rechte Root-Inspector liest sich jetzt bewusster als Navigator:
  `BLACK_HOLE`- und `STAR`-Rows bleiben schlanke Einzeiler ohne
  unnoetiges `n/a`-Badge, nicht fokussierte `PLANET`-/`MOON`-Rows
  zeigen nur noch `Life: ...`, und `World:` erscheint dort nur
  noch fuer die aktuell fokussierte Zeile.
- Klicks auf Root-Inspector-Zeilen bleiben im bestehenden
  `orbit_testbed.gd`-Fokuspfad, loesen jetzt aber bewusst einen
  sofortigen Fokus-/Center-/Fit-Sprung ueber `_set_focus(..., true, true)`
  aus, statt nur den normalen Fokuswechsel zu markieren.
- `GalaxyProxyRenderer` arbeitet jetzt auch view-seitig mit Tiering:
  entfernte Roots sind erst BH-only-Proxies; Stern-Proxies kommen erst
  oberhalb einer projizierten Root-Groesse mit eigener 96/80-px-
  Hysterese dazu.
- Derselbe `GalaxyProxyRenderer` cullt off-screen Roots jetzt schon vor
  BH-/Stern-Draws ueber einen konservativen Viewport-Envelop und fuehrt
  dafuer explizite Debug-Counts fuer sichtbare und gecullte Roots.
- `OrbitViewRenderer`, `GalaxyProxyRenderer` und `DebugOverlay`
  exponieren jetzt kleine read-only Debug-Snapshots/Counter, damit
  Compose-/Trail-Arbeit, Proxy-Tiering und Overlay-Refreshes in Tests
  strukturell statt nur ueber FPS-Gefuehl gepinnt werden koennen.
- Neue Tests pinnen jetzt zusaetzlich den Root-Inspector ueber drei
  Ebenen:
  Formatter-/Badge-Regressionen, ModelBuilder-/Overlay-Hierarchie und
  die Testbed-Controller-Regeln fuer explizites Oeffnen,
  Interest-Override und Reset bei Welt-Wechsel.
- Dieselbe Overlay-/Inspector-Suite pinnt jetzt zusaetzlich die neue
  Navigator-Verdichtung mechanisch:
  `STAR` bleibt einzeilig, nicht fokussierte `PLANET`-/`MOON`-Rows
  zeigen `Life:` ohne `World:`, fokussierte Rows zeigen beide
  Zeilen und behalten die Reihenfolge `Life:` vor `World:`.
- Neue Tests pinnen jetzt zusaetzlich den neuen Life-Layer ueber vier
  Ebenen:
  `LifePotentialService`-Anchor- und Tie-Break-Regressionen,
  `ProtoBiosphereSimulationService`-Seed-/Drift- und
  All-Roots-Regressionen, `DerivedSnapshotCache`-Glue,
  HUD-/Formatter-Ausgabe und die Root-Inspector-Life-Zeile.
- `INACTIVE_NO_LCA` bleibt fuer legitime Cross-Root-Faelle sichtbar,
  loggt aber jetzt als Warning statt als Fehler.
- `TimeService` und `UniverseRegistry` bleiben die einzigen
  projekt-eigenen Sim-Autoloads; die in `project.godot` sichtbaren
  Addon-Autoloads `AntialiasedLine2DTexture` und
  `PhantomCameraManager` sind plugin-provided und nicht Teil dieser
  Simulations-ADR.
- `OrbitService` schreibt autoritativ die `BodyState`-Positionsdaten.
- Die Sim-Mathematik nutzt weiter `Vector3`, auch wenn die aktuelle
  Praesentation 2D ist. Das ist bewusst und kein Fehler.
- Die Headless-Testbasis ist weiter reproduzierbar: `run_tests.bat`
  laeuft nach `Population Estimates v1` mit `7960`
  erfolgreichen Assertions bei `0` Failures.

### Aktuelle Praesentation

- Das fruehere minimalistische 3D-Testbed wurde durch eine stilisierte
  2D-Orbit-Ansicht ersetzt.
- Der bildschirmfeste Testbed-Hintergrund liest jetzt nicht mehr nur als
  ein paar Sternpunkte, sondern als shadergetriebener galaktischer
  Hybrid-Look: tiefer Navy-/Charcoal-Basisraum, breites diagonales
  Staub-/Milchstrassenband, dunklere Dust-Lanes, sparsame farbige
  Nebel-Akzente und ein dichteres mehrstufiges Sternfeld.
- Dieser neue Backdrop bleibt bewusst rein dekorativ im
  `CanvasLayer`: kein Fokus-/Root-Follow, kein BH-zentrierter Wirbel,
  keine neue Simulationswahrheit.
- Die grossskalige Staub-/Nebel-Komposition wird dabei bewusst aus der
  ersten gueltigen Viewport-Groesse abgeleitet und anschliessend ueber
  einen Bake-Pfad stabil gehalten; spaetere Resize-, Zoom- oder
  Pan-Vorgaenge verteilen den Nebel dadurch nicht mehr sichtbar um.
- Der Backdrop wird dafuer nicht mehr live auf dem Haupt-Canvas-Pfad
  geshadert, sondern ueber `SubViewport` + `TextureRect` als gebackene
  Textur dargestellt. Das beseitigt den gemeldeten Flicker-/Britzel-
  Effekt beim Bewegen und Zoomen und haelt den laufenden Frame-Pfad
  schlanker.
- Ein kurz getesteter Kamera-Kopplungsversuch fuer den Backdrop wurde
  bewusst wieder verworfen: er fuehrte zu sichtbarem Stern-/Nebel-
  Britzeln bei `WASD`/Zoom sowie zu unnoetigem per-frame-Churn und FPS-
  Verlust.
- Das Debug-Overlay zeigt jetzt optional live die Backdrop-Werte
  `control`, `viewport`, `render`, `bake`, `composition` sowie
  Resize-/Sync-Zaehler an, damit kuenftige Viewport-/Sampling-
  Regressionen schnell eingegrenzt werden koennen.
- Im Large-World-Modus zeigt dasselbe `F3`-Overlay jetzt zusaetzlich
  einen kompakten Streaming-Block:
  aktueller Fokus-/Resident-/Prewarm-Zustand plus die letzten
  Streaming-Ereignisse aus dem Controller-Ringbuffer.
- Dasselbe `F3`-Overlay ist jetzt fuer Large-World-Playtests bewusst
  billiger:
  Text-Rebuilds laufen nur noch mit 5 Hz, Fast-Path-Invalidierungen bei
  Fokus-/Residency-/Streaming-Wechseln bleiben sofort, und im
  `ROOT_OVERVIEW` ersetzt eine kompakte Summary die fruehere
  Volltabelle.
- Dieselbe `F3`-Diagnose liest Thermal-/Environment-Werte dabei nicht
  mehr still live nach; bei Snapshot-Luecken zeigt sie bewusst `n/a`
  statt den Frame-Pfad mit verstecktem Derived-Workload zu verfremden.
- Bodies werden jetzt als 2D-Visuals mit Glow, Orbit-Linien und Trails
  dargestellt.
- In Large-World-`ROOT_OVERVIEW` ist dieser View-Pfad jetzt bewusst
  lesbarer und leichter:
  BH plus direkte Sterne bleiben sichtbar, planetare Detailwolken
  verschwinden, und pausierte Trails werden beim Zurueckkehren ohne
  sichtbares Brueckensegment wieder aufgenommen.
- Planet-/Mond-Themes werden nicht mehr blind pro Frame komplett neu
  angewendet: der Renderer konsumiert jetzt den letzten Derived-
  Snapshot, und identische Theme-Applies sind materialseitig
  idempotent.
- Es gibt ein HUD fuer Fokus, Sim-Zeit, Zeitskala und Status.
- Die normale Environment-Zeile zeigt fuer unterstuetzte Fokus-Bodies
  jetzt die Habitability-Aussage plus `Climate: ...` als Welttyp.
- Das normale HUD zeigt fuer unterstuetzte Fokus-Bodies jetzt
  zusaetzlich eine `Bands:`-Zeile mit den rohen bandbewussten
  Temperaturen fuer `-60deg`, `Eq` und `+60deg`.
- Das normale HUD zeigt fuer Bodies mit saisonaler Basis jetzt
  zusaetzlich eine kleine `Season: subsolar ...`-Zeile.
- Dieselbe HUD-Zeile weist jetzt zusaetzlich die aktuelle
  Thermal-Vereinfachung explizit als `Primary source: <star_id>` aus,
  statt Mehrstern-Faelle still wie Einquellenfaelle aussehen zu lassen.
- Das HUD zeigt zusaetzlich FPS und die aktuelle Speed-Preset-Stufe.
- Die Sim-Speed kann ueber einen logarithmischen HUD-Slider geregelt
  werden.
- Die HUD-Speed-/Preset-/Slider-Logik lebt jetzt in einem eigenen
  `OrbitTimeScaleController` statt weiter direkt im Testbed-Script.
- Hohe Speedstufen erzeugen keinen Tick-Sturm pro Frame mehr;
  `time_scale` skaliert das simulierte `dt` pro Physics-Frame.
- Die Fokusansicht bewegt und zoomt weich auf den relevanten Ausschnitt.
- Die Kamera nutzt jetzt ein bewusst scope-relatives Zoommodell:
  `fit`, `wide` und `detail` bleiben weiter reine Massstabsmodi, aber
  der Kameraanker wird jetzt sichtbarkeitsbasiert bestimmt: sobald der
  Root-/BH-Mittelpunkt im aktuellen Massstab sinnvoll im Bild sein kann,
  verankert sich die Ansicht wieder weich am Root; erst wenn der Root
  faktisch ausser Reichweite liegt, faellt die Kamera auf lokalen
  Fokus-Lock zurueck.
- `100%` bedeutet im Testbed jetzt explizit `fit current focus scope`;
  `Backspace` springt auf genau diesen Scope-Fit zurueck.
- Der Zoombereich bleibt bei `0.5%` bis `10000%`; unter `100%` wird nur
  innerhalb des aktuellen Fokus-Scopes weiter herausgezoomt (`wide`),
  aber Root-Stabilitaet haengt nicht mehr nur an `wide`: auch in `fit`
  oder moderatem Zoom bleibt das BH stabil, solange es im aktuellen
  Bildausschnitt sinnvoll sichtbar ist; oberhalb davon bleibt Zoom ein
  lokaler Detail-Zoom (`detail`) relativ zu demselben Fokus.
- Ein kurzlebiger world-space-Follow im `OrbitCameraController` wurde
  wieder entfernt: `fit/detail` halten den Fokus auch bei hoher
  Sim-Speed exakt, und der sichtbarkeitsbasierte Root-Lock stabilisiert
  den Root-/BH-Anker ohne sichtbares Kamera-Nachziehen.
- Der sichtbare Fokus-Closeup folgt jetzt dem geglaetteten aktuellen
  Kamera-Scale statt direkt dem rohen Zielzoom; dadurch springen
  Nahdetail und Body-Footprint beim Wheel-Zoom nicht mehr sofort auf den
  Endwert.
- Der lokale Detail-Zoom saettigt ausserdem nicht mehr schon grob bei
  `~1500%`: die Closeup-Kurve traegt jetzt einen weichen High-Zoom-Tail,
  damit `1500% -> 10000%` weiter sichtbar mehr Naehe bringt; der
  Wheel-Zoom nutzt dafuer zusaetzlich feinere `1.12x`-Schritte statt
  `1.20x`.
- Das HUD macht die Zoom-Semantik jetzt explizit sichtbar:
  `Zoom ... wide`, `Zoom 100% fit` und `Zoom ... detail`.
- Das HUD trennt jetzt explizit zwischen expliziter Root-Uebersicht und
  implizitem Kamera-Lock: `root-overview` fuer echten Root-Fokus,
  `root-lock` fuer sichtbarkeitsbasierten Root-Anker und `focus-lock`
  fuer lokalen Fokus-Lock; kleine Hysterese verhindert Label-Flackern im
  Uebergangsband.
- Explizite Root-/BH-Overview gibt es weiter ueber Root-Fokus bzw.
  `Home`; `wide` auf einem Stern-, Planeten- oder Mondfokus darf den
  Kameraanker aber wieder weich Richtung Root/BH ziehen, damit grosse
  BH-Systeme im Fernblick nicht um den Subfokus kreisen.
- Fokuswechsel resetten bewusst auf den neuen Scope-Fit und loeschen
  manuelles Pan, damit unterschiedlich grosse Systeme nicht denselben
  Detailzoom mitschleppen.
- Das Testbed unterstuetzt Camera-Panning, klickbaren Fokus und
  staerkere Zeitskalen.
- Die Kameralogik lebt jetzt nicht mehr direkt im Testbed-Script,
  sondern in einem eigenen `OrbitCameraController`; HUD-Strings sind in
  `OrbitHudFormatter` gebuendelt, und `OrbitViewRenderer` nutzt jetzt
  reine Helper fuer Camera-Scope-, Orbit-Geometrie- und
  Emphasis-Regeln.
- Die service-lokalen `KEY_*`-Konstanten fuer Thermal-/Atmosphaeren-/
  Environment-Dictionaries werden jetzt auch producer-seitig intern
  durchgezogen statt nur in den wichtigsten Runtime-Konsumenten.
- Das Testbed kann jetzt explizit zwischen `starter_world` und
  `sample_system` als Referenzwelten umgeschaltet werden.
- Das Testbed unterstuetzt jetzt zusaetzlich `pilot_galaxy` als grossen
  Weltmodus: ein Root bleibt detailliert materialisiert, entfernte
  Roots erscheinen als eigene BH-/Stern-Proxies im Galaxy-Space, und
  beim Herauszoomen darf genau ein Nachbar-Root zusaetzlich resident
  werden.
- Das Testbed unterstuetzt jetzt zusaetzlich auch
  `scaleup_galaxy_10` als zweite produktive Large-World-Welt.
- Das Testbed unterstuetzt jetzt zusaetzlich auch
  `scaleup_galaxy_30` als dritte produktive Large-World-Welt.
- Das Testbed unterstuetzt jetzt zusaetzlich auch
  `scaleup_galaxy_100` als vierte produktive Large-World-Welt.
- Der im Repo eingecheckte Szenen-Override von
  `scenes/testbeds/orbit_testbed.tscn`
  startet aktuell mit `initial_world_id = "scaleup_galaxy_100"`;
  `starter_world`, `sample_system` und die anderen Weltpfade bleiben
  ueber denselben `initial_world_id`-Pfad explizit umschaltbar.
- Dieser Large-World-Pfad entlaedt den bestehenden Fokus-Root dabei
  nicht mehr bei jedem Neighbor-Wechsel: Delta-Materialisierung und
  Streaming-Keepalive halten unveraenderte Root-Slices stabil resident,
  inklusive `NUMERIC_LOCAL`-/Trail-/Derived-Kontext des Fokus-Roots.
- Der neue `GalaxyProxyRenderer` bleibt bewusst reine Projektion:
  Proxy-Sterne animieren mit denselben authored Orbit-Parametern wie
  der Detail-Slice, damit Proxy->Detail-Handoffs ohne sichtbaren
  Positions- oder Velocity-Sprung moeglich bleiben.
- Root-Proxies halten ihre sichtbare Bildschirmgroesse jetzt bewusst
  gegen den Kamera-Scale: entfernte BH-Roots schrumpfen beim
  Herauszoomen nicht mehr zu Fast-Pixeln zusammen, sondern lesen sich
  ueber dieselbe BH-Grundform und grob denselben Footprint wie
  `obsidian`; auch Proxy-Sterne und ihre Verbindungslinien bleiben
  screen-stabil sichtbar.
- `starter_world` ist jetzt als groessere asymmetrische BH-
  Referenzwelt ausgebaut: vier Sterne unter `obsidian`, ungleich grosse
  Planetensysteme und bewusst keine neue Spiegel-Symmetrie.
- Die Toy-Orbitwerte der `starter_world` bleiben so getunt, dass Monde
  sichtbar schneller als Planeten und Planeten sichtbar schneller als
  ihre Sterne um `obsidian` kreisen; die BH-Sterne bleiben dabei in
  diesem Slice bewusst kreisfoermige `AUTHORED_ORBIT`.
- `starter_world` enthaelt jetzt mit `gamma` bewusst ein kompakteres
  Red-Dwarf-artiges Sternsystem; `gamma_iv` ist darin der erste lokal
  plausible sichtbare habitabele Kandidat statt eines root-skaligen
  Ausreisserorbits.
- Die player-facing HUD-Sprache wurde bewusst geschaerft:
  `Class.MARGINAL` bleibt intern stabil, wird fuer Spieler aber als
  `HARSH` angezeigt; `Eco` heisst jetzt `Climate`, und die
  Temperaturzeile heisst `Bands`.
- `PLANET`- und `MOON`-Bodies leiten jetzt zusaetzlich
  shaderbasierte Klima-Archetypen aus der bestehenden Umweltbeschreibung
  ab: `TEMPERATE_OCEAN`, `FROZEN`, `HOT_SCORCHED` und `BARREN`.
- Der neue Klima-Look bleibt bewusst projektionstreu:
  `FROZEN`, `HOT_SCORCHED` und `BARREN` lesen sich direkt aus den
  momentanen Umweltzustaenden; `TEMPERATE_OCEAN` ist dagegen eine
  explizit stilisierte, semi-realistische Interpretation ohne
  simuliertes Wasserinventar oder echte Wolkenphysik.
- Monde laufen jetzt durch denselben Klima-Resolver wie Planeten,
  bleiben aber ueber gedimmte Theme-Intensitaeten sichtbar als Monde
  lesbar statt wie kleine Vollplaneten zu wirken.
- Sterne lesen sich jetzt als runde, warme Sonnen mit deutlich
  aktiverer, NASA-naher Photosphaere: die P14.3-Rundheits-Invariante
  bleibt erhalten (`alpha` haengt weiter nur an `t`), aber der Shader
  traegt jetzt zusaetzlich eine zweite Solar-Activity-Ebene mit
  helleren aktiven Regionen und dunkleren Filament-/Channel-Zonen.
- Der Stern-Look ist jetzt ueber explizite Star-Uniforms lesbarer
  getuned (`star_core_color`, `activity_strength`, `filament_strength`,
  `rim_hotness`, `edge_activity_strength` etc.), aber weiterhin nur im
  `STAR`-Pfad und ohne neue Simulationswahrheit.
- Die sichtbare Energie sitzt jetzt staerker im shaderseitigen heissen
  Innenrand und in der Oberflaechenaktivitaet; der fruehere Ring-Glow in
  `_draw_star_glow()` wurde bewusst subtiler gemacht, damit Sterne
  weniger nach konzentrischen Glow-Scheiben und mehr nach aktiven Sonnen
  lesen. Alle Sterne teilen weiter bewusst denselben Sun-Look;
  Spektralklassen-/Typ-Unterscheidung ist explizit vertagt.
- P14.5 vertieft den Stern-Look jetzt zusaetzlich ueber eine
  mehrskalige Surface-Hierarchie: ein statisches grobes Macro-Feld,
  eine neue Meso-Breakup-Zwischenskala, die bestehende Activity-Ebene,
  feine Granulation und dunkle Channel-Layer arbeiten jetzt als feste
  Frequenzleiter zusammen statt nur als guter Einzel-Pattern-Shader.
- Die neue Tiefe bleibt bewusst shader-only und entsteht nur ueber
  Farb-/Luminanzmodulation: Macro-Feld wirkt multiplikativ, Meso- und
  Activity-Faculae additiv, Channels schneiden zuletzt dunkler ein;
  `alpha` bleibt weiter unangetastet und der sichtbare Stern-Footprint
  waechst nicht.
- Der Sternshader traegt dafuer jetzt eigene kleine Noise-/FBM-Helfer
  sowie neue Star-Uniforms fuer Macro-/Meso-Staerke und
  Oberflaechenkontrast (`macro_surface_strength`,
  `meso_breakup_strength`, `granulation_contrast`,
  `channel_contrast`, `hotspot_contrast`), die ausschliesslich im
  `STAR`-Pfad von `OrbitBodyVisual` gesetzt werden.
- P14.6 fuehrt jetzt zusaetzlich einen sternspezifischen Closeup-Mode
  ein: nur der aktuell fokussierte Stern bekommt ueber
  `star_closeup_phase` kontrolliert mehr Footprint, mehr aktive
  Oberflaechencluster und begrenzte solare Randaktivitaet; nicht-
  fokussierte Sterne bleiben optisch auf P14.5-Niveau.
- Der Sternshader ist damit bewusst hybrid geworden: die P14.5-
  Prozeduralbasis bleibt erhalten, wird aber im Fokusstern ueber eine
  abgeleitete `star_detailmap.png` um eine zusaetzliche Strukturquelle
  fuer helle Faculae und dunklere Sunspot-/Channel-Komplexe erweitert -
  weiterhin ohne direkte Foto-Skin und ohne Alpha-Silhouetten-Aenderung.
- Die neue Detailmap kommt reproduzierbar ueber ein kleines
  Ableitungsskript aus der Referenzdatei `sun.png` in den Repo-Workflow;
  P14.6 fuehrt dafuer ein eigenes Rendering-Asset und eine kurze
  Asset-Notiz ein, statt die Detailquelle nur lokal implizit zu halten.
- P14.6b zieht diese Detailmap jetzt bewusst wieder auf eine
  disc-zentrierte, statische Closeup-Schicht zurecht: die abgeleitete
  `star_detailmap.png` wird neu zentriert, aeussere Protuberanzen werden
  aus der Map abgeschnitten, und der Shader sampelt die Bildstruktur
  ohne `TIME`-Translation fest im Sternzentrum.
- Im Stern-Closeup darf damit nur noch eine Oberflaechenlogik dominieren:
  die sichtbare Detailmap fuehrt die Surface-Lesbarkeit, waehrend
  Granulation, Activity, Filament- und Meso-Layer nur amplitude-seitig
  gedimmt als animierter Unterbau erhalten bleiben; das statische
  Macro-Feld sowie Rim/Edge bleiben unveraendert voll aktiv.
- Ein neuer erster Variant-2-Pilot fuehrt jetzt fuer `MOON`-Bodies einen
  hybriden Surface-Pfad ein: der Mond bleibt weiter im
  `body_sphere.gdshader`, nutzt dort aber zusaetzlich eine aus
  `planet25.png` abgeleitete `moon_reference.png` als kontrollierte
  Oberflaechen-Referenz fuer Farbe und Kraterdetail.
- Dieser Mond-Pilot ersetzt bewusst nicht den Shader durch ein direktes
  Beauty-Sprite: Licht, Terminator, Rim und Rotation bleiben weiter
  shaderseitig; die Referenzmap wird nur innerhalb der bestehenden
  Projektion mitbenutzt.
- Die neue Mond-Referenz wird ueber ein eigenes kleines
  Ableitungsskript reproduzierbar aus der Nutzerreferenz in eine
  hybridfreundliche innere Surface-Map ueberfuehrt: alpha-zentriert,
  radial leicht entlichtet, im Rand nach innen kontrahiert und fuer
  innere Kraterdetails nachgeschaerft.
- Der Moon-Hybrid wurde im Follow-up jetzt klarer auf
  `center-led / edge-lit` gezogen: die Referenz fuehrt staerker im
  Scheibenzentrum, der alte prozedurale Mond-Look wird unter aktiver
  Referenz deutlicher gedimmt, und die frueheren Moon-Overlay-Krater
  werden dann bewusst ganz unterdrueckt.
- Die shaderseitige Lichtarbeit sitzt fuer diesen Mondpfad jetzt
  sichtbar staerker an Seiten, Terminator und Rim statt weiter als
  flaechige Vollabdunklung ueber der ganzen Mondscheibe zu lesen.
- Nach visueller Bestaetigung des Mondpiloten traegt derselbe
  Variant-2-Hybridpfad jetzt auch drei planetare Klima-Archetypen:
  `TEMPERATE_OCEAN`, `FROZEN` und `HOT_SCORCHED` nutzen zusaetzlich aus
  `Terran1.png`, `Ice1.png` und `Lava1.png` abgeleitete
  Referenz-Maps (`temperate_reference.png`, `frozen_reference.png`,
  `hot_scorched_reference.png`) innerhalb des bestehenden
  `body_sphere.gdshader`.
- Diese planetaren Referenzen ersetzen weiter keine Planetensprites:
  Licht, Terminator, Rim und die bestehende Rotationssemantik bleiben
  shaderseitig autoritativ; neu ist aber, dass der Referenz-Layer fuer
  Planeten jetzt an dieselbe Rotationslogik gekoppelt wird, statt nur
  statisch auf der sichtbaren Disc zu kleben.
- Die planetaren Archetypen sampeln ihre Referenz ausserdem etwas enger
  als der Mondpilot, damit weniger vom gebackenen Beauty-Rand und mehr
  von der inneren Oberflaechenlesbarkeit in den Runtime-Pfad gelangt.
- Ein weiteres Follow-up zieht `TEMPERATE_OCEAN` und `FROZEN` jetzt
  sichtbar naeher an ihre Originalbilder: die zugehoerigen
  Referenz-Maps werden farbtreuer aus `Terran1.png` und `Ice1.png`
  abgeleitet, die nativen Referenzfarben werden im Shader deutlich
  staerker bevorzugt, zusaetzliche Shader-Wolken werden fuer diese
  beiden Archetypen unterdrueckt, und der fruehere grosse blaue
  Planet-Glow wird stark reduziert.
- Ein weiteres Korrektur-Follow-up vereinheitlicht `TEMPERATE_OCEAN`
  und `FROZEN` jetzt wieder ueber alle Zoomstufen auf denselben
  Referenz-Layer: Fern- und Nahansicht lesen damit nicht mehr als zwei
  unterschiedliche Sprites, und die sichtbare Rotation bleibt fuer diese
  beiden Archetypen erhalten.
- Technisch nutzt dieser Korrekturpfad fuer `TEMPERATE_OCEAN` und
  `FROZEN` jetzt einen voll aktiven, zoomstabilen disc-preserving
  Referenz-Layer statt des kurz getesteten HOT-artigen
  rotationsgekoppelten Pfads und statt des portrait-stabilen
  Closeup-Sondermappings; damit verschwinden der alte Zoom-Bruch und die
  sichtbare Verzerrungszone, ohne die neue Bildtreue wieder aufzugeben.
- `HOT_SCORCHED` bleibt in diesem Follow-up bewusst praktisch
  unveraendert, weil dieser Archetyp visuell bereits die gewuenschte
  Lesbarkeit erreicht hatte.
- Der Sternpfad nutzt jetzt zusaetzlich eine aus `sun.png` abgeleitete
  farbige `star_reference.png` als sichtbare Solaroberflaeche innerhalb
  des bestehenden `body_star.gdshader`.
- Diese neue Stern-Referenz ersetzt bewusst keinen Runtime-Sprite:
  Halo, Randaktivitaet, Closeup-Verhalten und die restliche
  Oberflaechenbewegung bleiben weiter shaderseitig kontrolliert; neu ist
  nur, dass die Sonnenoberflaeche jetzt sichtbar bildgefuehrt ist statt
  nur ueber die alte Graustufen-Detailmap zu lesen.
- Die bestehende `star_detailmap.png` bleibt erhalten, liest jetzt aber
  nur noch als zweite Strukturquelle ueber der farbigen
  `star_reference.png`, waehrend die prozeduralen Sternlayer etwas
  gedimmt unter diesem Bild-Layer weiterlaufen.

## Ziel dieser Praesentationsschicht

- `Graviton` soll nicht wie ein technisches Roh-Testbed wirken.
- Der Look darf stilisiert und attraktiv sein.
- Die View soll trotzdem nur Projektion bleiben und keine neue Wahrheit
  ueber Bodies, Positionen oder Zeit einfuehren.

## Wichtige zuletzt geaenderte Dateien

- `website/index.html`
- `website/styles.css`
- `website/assets/README.md`
- `src/core/math/orbit_math.gd`
- `src/tests/orbit/test_orbit.gd`
- `src/sim/world/world_loader.gd`
- `src/tests/sim/test_world_loader.gd`
- `src/sim/world/deterministic_world_generator.gd`
- `src/tests/sim/test_deterministic_world_generator.gd`
- `src/sim/bodies/body_def.gd`
- `data/sample_system.gd`
- `src/tests/sim/test_body_def_world_model.gd`
- `src/runtime/local_bubble/bubble_activation_set.gd`
- `src/runtime/streaming/galaxy_streaming_controller.gd`
- `src/runtime/streaming/galaxy_proxy_math.gd`
- `src/tests/runtime/test_bubble_activation_set.gd`
- `src/tests/runtime/test_large_world_streaming.gd`
- `src/sim/orbit/orbit_service.gd`
- `src/sim/orbit/local_orbit_integrator.gd`
- `src/tests/orbit/test_local_orbit_integrator.gd`
- `src/tests/sim/test_orbit_service_numeric_local.gd`
- `data/starter_world.gd`
- `src/tests/sim/test_starter_world.gd`
- `src/sim/thermal/thermal_service.gd`
- `src/tests/sim/test_thermal_service.gd`
- `src/sim/atmosphere/atmosphere_service.gd`
- `src/tests/sim/test_atmosphere_service.gd`
- `src/sim/environment/environment_service.gd`
- `src/sim/life/life_potential_service.gd`
- `src/sim/life/life_track_lookup.gd`
- `src/sim/life/biosphere_scale_service.gd`
- `src/sim/life/native_species_service.gd`
- `src/sim/life/genetic_species_service.gd`
- `src/sim/life/life_ecology_service.gd`
- `src/tests/sim/test_environment_service.gd`
- `src/tests/sim/test_life_potential_service.gd`
- `src/tests/sim/test_biosphere_scale_service.gd`
- `src/tests/sim/test_native_species_service.gd`
- `src/tests/sim/test_genetic_species_service.gd`
- `src/tests/sim/test_life_ecology_service.gd`
- `docs/SIMULATIONSREGELN.md`
- `docs/STARTER_WORLD.md`
- `docs/ARCHITEKTUR.md`
- `docs/NEXT_STEPS.md`
- `docs/DECISIONS.md`
- `src/runtime/local_bubble/local_bubble_manager.gd`
- `src/tests/runtime/test_local_bubble_step2.gd`
- `src/tools/rendering/orbit_view_renderer.gd`
- `src/tools/rendering/orbit_time_scale_controller.gd`
- `src/tools/rendering/planet_badge_overlay.gd`
- `src/tools/ui/root_inspector_overlay.gd`
- `src/tools/ui/life_detail_panel.gd`
- `src/tools/ui/survey_visual_theme.gd`
- `src/sim/topology/universe_topology.gd`
- `src/tests/sim/test_universe_topology.gd`
- `src/tests/helpers/sim_test_harness.gd`
- `src/tests/sim/test_sim_test_harness.gd`
- `src/tools/rendering/orbit_zoom_model.gd`
- `src/tools/rendering/orbit_camera_controller.gd`
- `src/tools/rendering/orbit_hud_formatter.gd`
- `src/tools/rendering/orbit_camera_scope.gd`
- `src/tools/rendering/orbit_emphasis_rules.gd`
- `src/tools/rendering/orbit_orbit_geometry.gd`
- `src/tests/rendering/test_orbit_camera_controller.gd`
- `src/tests/rendering/test_orbit_camera_scope.gd`
- `scenes/testbeds/orbit_testbed.gd`
- `scenes/testbeds/orbit_testbed.tscn`
- `src/tools/rendering/orbit_body_visual.gd`
- `src/tools/rendering/orbit_emphasis_rules.gd`
- `src/tools/rendering/planet_visual_theme.gd`
- `src/tools/rendering/planet_visual_profile.gd`
- `src/tools/rendering/shaders/body_sphere.gdshader`
- `src/tools/rendering/shaders/body_star.gdshader`
- `src/tools/rendering/assets/README.md`
- `src/tools/rendering/assets/star_detailmap.png`
- `src/tools/rendering/assets/star_reference.png`
- `src/tools/rendering/assets/moon_reference.png`
- `src/tools/rendering/assets/temperate_reference.png`
- `src/tools/rendering/assets/frozen_reference.png`
- `src/tools/rendering/assets/hot_scorched_reference.png`
- `src/tools/rendering/scripts/derive_star_detailmap.py`
- `src/tools/rendering/scripts/derive_star_reference_map.py`
- `src/tools/rendering/scripts/derive_planet_reference_map.py`
- `src/tests/rendering/test_orbit_body_visual.gd`
- `src/tests/rendering/test_orbit_emphasis_rules.gd`
- `src/tests/rendering/test_planet_visual_profile.gd`
- `src/tests/rendering/test_orbit_view_renderer.gd`
- `src/tests/rendering/test_orbit_time_scale_controller.gd`
- `src/tests/rendering/test_orbit_zoom_model.gd`
- `src/tests/rendering/test_root_inspector_overlay.gd`
- `src/tests/rendering/test_life_detail_panel.gd`
- `src/tests/rendering/test_planet_badge_overlay.gd`
- `src/tests/rendering/test_survey_visual_theme.gd`
- `src/tests/rendering/test_space_backdrop.gd`
- `src/tools/rendering/space_backdrop.gd`
- `src/tools/rendering/shaders/space_backdrop.gdshader`
- `src/tools/debug/debug_overlay.gd`
- `src/runtime/derived/derived_snapshot_cache.gd`
- `src/tests/runtime/test_derived_snapshot_cache.gd`
- `src/sim/world/galaxy_def.gd`
- `src/sim/world/root_system_manifest.gd`
- `src/sim/world/root_star_manifest.gd`
- `src/sim/world/root_system_generator.gd`
- `src/sim/world/pilot_galaxy_world.gd`
- `src/sim/world/generated_scaleup_root_factory.gd`
- `src/sim/world/scaleup_galaxy_world.gd`
- `src/tools/rendering/galaxy_proxy_renderer.gd`
- `src/tests/rendering/test_debug_overlay.gd`
- `src/tests/rendering/test_orbit_hud_formatter.gd`
- `src/tests/scenes/test_orbit_testbed_hud_modes.gd`
- `src/tests/scenes/test_orbit_testbed_root_inspector.gd`
- `src/sim/orbit/orbit_period_helper.gd`
- `src/sim/orbit/orbit_readout_service.gd`
- `src/tests/sim/test_orbit_readout_service.gd`
- `AGENTS.md`
- `CLAUDE.md`
- `.gitignore`
- `run_tests.bat`

## Bekannte offene Punkte

- Schritte 1-4 sind jetzt minimal implementiert; der erste
  `NUMERIC_LOCAL`-Guardrail-Block umfasst jetzt Missing-Request-Grace,
  Substep-`Cap+Warn` und budgetierten Exit-Rejoin. Offene Folgearbeit
  im Regime-Fundament ist damit eher spaeteres Tuning der Budgets /
  Langlauf-Policy als ein fehlender Guardrail-Block.
- `LocalBubbleManager` liefert jetzt die dokumentierte LCA-/
  praezisionsbewusste Bubble-Komposition fuer same-root-Faelle.
- `BubbleActivationSet` ist jetzt implementiert, wird im Testbed pro
  Frame aufgerufen, macht im steady-state aber keinen Full-Scan mehr
  und wird jetzt read-only inklusive geometrischer Exit-Hysterese als
  Wish-Quelle fuer `OrbitService.request_numeric_local_candidates(...)`
  genutzt.
- Das Projekt ist topologisch offen fuer mehrere Root-Systeme und hat
  jetzt eine explizite Loader-, Aktivierungs- und erste
  Stabilitaetsschicht fuer hohe `time_scale` im numerischen Pfad.
- `BodyDef` traegt jetzt erste statische Weltmodell-Felder, und daraus
  werden mittlerweile saisonale Thermalgeometrie, additive
  Greenhouse-Erwaermung, bandbewusste Oberflaechentemperaturen und eine
  erste zonale Umweltklassifikation abgeleitet -
  weiterhin aber noch keine Atmosphaerenchemie, kein Druckmodell und
  keine Wasser-/Volatile-Logik.
- Die zonale `EnvironmentService`-Klassifikation in P12A ist bewusst
  **momentan**: sie mittelt nicht ueber Jahreszyklen und kann bei Tilt
  oder exzentrischen Bahnen sichtbar ueber das Orbitaljahr
  oszillieren.
- Die Thermal-/Environment-Kette bleibt vorerst bewusst
  `primary-source only`; additive Mehrquellenstrahlung fuer
  Mehrstern-Faelle ist noch nicht implementiert.
- `sample_system` ist jetzt der explizite habitable Showcase fuer die
  neue zonale Umweltkette; `starter_world` bleibt weitgehend der
  thermisch extreme Mehrstern-Sandkasten, traegt jetzt aber bewusst
  genau einen sichtbaren habitablen Kandidaten in einem kompakt
  neu skalierten `gamma`-System.
- `generated_system` ist aktuell ein fixer deterministischer
  Showcase-Seed ohne Seed-Auswahl, Survey-Notebook oder Scanner-UX.
- Die zugrunde liegende zonale Umweltlogik blieb in P13.1 unveraendert;
  nur die HUD-Sprache trennt jetzt klarer zwischen Habitability-Urteil
  (`Environment`), Welttyp (`Climate`) und Rohdaten (`Bands`).
- Der Klima-Archetypen-Pass bleibt weiter bewusst shader-first in seiner
  Autoritaet, ist aber jetzt nicht mehr voll texturfrei: `MOON`,
  `TEMPERATE_OCEAN`, `FROZEN` und `HOT_SCORCHED` duerfen selektive
  Hybrid-Referenzen nutzen; `DESERT` wurde weiterhin ausdruecklich
  nicht eingefuehrt, weil dafuer noch keine staerkere Sim-Basis fuer
  Ariditaet oder Wasserverteilung existiert.
- Der neue Hybrid-Reference-Pfad deckt jetzt bewusst `MOON` plus die
  drei Klima-Archetypen `TEMPERATE_OCEAN`, `FROZEN` und
  `HOT_SCORCHED` ab, bleibt aber weiterhin ein selektiver View-Pfad und
  keine generelle Umstellung aller Planeten auf direkte
  Beauty-Sprites; `BARREN` bleibt vorerst shader-first.
- Der Zoom ist jetzt bewusst per Fokus-Scope statt globalem Weltanker
  definiert; gleiche Zoomzahlen sind damit nicht mehr
  fokusuebergreifend als gleicher Welt-Massstab interpretierbar.
- Expliziter globaler Ueberblick ist weiter primaer Root-/BH-Fokus bzw.
  `Home`; verschachtelte Foki koennen den Root-/BH-Mittelpunkt jetzt
  wieder weich stabilisieren, sobald dieser im aktuellen Bildmassstab
  sinnvoll sichtbar ist, ohne die P16-Scope-Scale-Semantik aufzugeben.
- Die dokumentierte P16.1-Kameralogik ist jetzt auch controller- und
  testseitig wieder konsistent: kein separater Kamera-World-State, kein
  zeitliches Nachlaufen des Fokus-/Root-Ankers, und Manual Pan bleibt
  ein rein additiver View-Offset ohne Einfluss auf den Lock-Modus.
- Renderer-Nahdetail bleibt weiterhin getrennt fokus-relativ, damit die
  P14-Archetypen bei gleicher lokaler Naehe dieselben Detail-Schwellen
  behalten.
- Der Wish-Pfad fuer `NUMERIC_LOCAL` bleibt bewusst um einen Frame
  gegenueber `sim_tick` versetzt (`_process()` vs. `_physics_process()`),
  wird jetzt aber im `OrbitService` ueber einen Grace-Tick abgefedert.
- `Cap+Warn` ist bewusst nur eine Best-Effort-Policy: bei dauerhaft
  gecappten Bodies kann weiter langsame Energie- und Bahndrift
  auftreten, auch wenn der Body im numerischen Regime bleibt.
- Die Runtime-/View-Architektur ist jetzt deutlich besser getrennt,
  aber `orbit_testbed.gd` bleibt trotz Controller-/HUD-Split noch
  ein relativ dichter Composition-Root fuer Input und Zeitskala.
- Der neue Snapshot-/Theme-Cache reduziert den offensichtlichen
  per-frame-Derived-Workload jetzt deutlich staerker ueber
  Interest-/Dirty-Tracking, ist aber noch nicht durch einen laengeren
  visuellen Idle-/Playtest im neuen 30-Root-Produktpfad profiliert.
- `test_orbit_body_visual.gd` gibt seine erzeugten Visual-Nodes jetzt
  wieder explizit frei; im aktuellen `main`-Runner taucht damit kein
  separater neuer Headless-Exit-Leak-Befund mehr auf.
- `pilot_galaxy` bleibt bewusst exakt der kleine 3-Root-Referenzslice;
  `scaleup_galaxy_10` und `scaleup_galaxy_30` sind jetzt die
  produktiven Folgepfade.
  Noch offen ist damit primaer der echte Editor-/Feel-Playtest der
  30-Root-Welt statt weiterer Loader-/Catalog-Grundlagenarbeit.
- Der Large-World-Content ist damit nicht nur builder-seitig vereinheitlicht,
  sondern auch root-seitig besser vergleichbar:
  `onyx`, `umbra` und `shade_*` lesen jetzt als Varianten desselben
  `obsidian`-Standards statt als still kleiner skalierte BH-Systeme.
- Der neue Streaming-Pfad ist jetzt headless-seitig auch auf
  Hysterese, Keepalive, Delta-Materialisierung, Proxy-/Detail-Handoff
  und einen test-only 30-Root-Stress abgesichert; zusaetzlich pinnen
  neue Tests jetzt den `prewarm`-Boundary-Contract
  (`0.89 / 0.90 / 0.91 / 1.00`), die 10-Root-Content-Signatur, die
  30-Root-Produkt-/Stress-Paritaet, den Spacing-Guard inklusive
  Forced-Collision-/Hard-Fail-Pfad und den Debug-Ringbuffer.
- Offene Restarbeit liegt damit noch klarer im echten Editor-/Playtest
  als in weiterer Grundarchitektur.
- Die Large-World-Produktreihe ist jetzt auch testseitig durchgaengig
  gepinnt:
  `scaleup_galaxy_10`, `scaleup_galaxy_30` und `scaleup_galaxy_100`
  haben feste kanonische Content-Signaturen; `scaleup_galaxy_100` ist
  zusaetzlich auf Produkt-/Stress-Paritaet, Spacing, lazy Neighbor-
  Cache und bounded Streaming abgesichert.
- Der neue galaktische Backdrop ist bewusst screen-fixed und
  dekorativ; ein spaeterer root-aware oder BH-zentrierter Spezialeffekt
  waere ein eigener View-Pass und kein stilles Follow-up dieses
  Hintergrunds.
- Der gemeldete Backdrop-Flicker war ein Render-/Sampling-Problem des
  frueheren live geshaderten Hintergrundpfads, nicht der
  Simulationsdaten oder Orbitlogik; der aktuelle Bake-Pfad ist der
  bewusst beibehaltene Endzustand dieses Fixes.
- Die neuen `KEY_*`-Konstanten stabilisieren jetzt die wichtigsten
  Service-/HUD-Schnittstellen; ein spaeterer Test-only-Aufraeumpass
  koennte verbleibende rohe String-Key-Zugriffe in aelteren Suites
  noch weiter vereinheitlichen.
- `phantom_camera` ist im Projekt vorhanden, wird aber in der aktuellen
  Runtime noch nicht aktiv genutzt.
- Die Praesentation ist fuer das aktuelle Testbed gut genug; der
  groesste Engpass liegt momentan nicht mehr im Look, sondern im
  Welt-/Frame- und Regime-Fundament.
- Orbit-Linienpunkte fuer KEPLER-Orbits werden gleichmaessig in M
  (mittlere Anomalie) gesampelt - bei den aktuellen Toy-Ellipsen meist
  okay, aber nicht physikalisch gleichmaessig verteilt.

## Was als naechstes wahrscheinlich sinnvoll ist

- zuerst kein neuer Simulationslayer, sondern das in
  `docs/NEXT_STEPS.md` beschriebene Acceptance-Bundle:
  Lifeform Pressure, Life Ecology, Genetic Lifeforms,
  Survey-Color-/Life-Detail-Panel, Planet Summary, Survey UX,
  Native Species, Orbit Readout, Time UX, View Bookmarks und die
  aktuellen Performance-/Focus-Smoothing-Gates gemeinsam im Editor
  validieren
- die Headless-Basis ist dabei bereits sichtbar:
  `./run_tests.bat` lief nach `Population Estimates v1` mit `7960`
  Passed und `0` Failed; gezielte Tests decken unter anderem
  HUD-Modi, Root-Inspector-Testbed-Regeln, Root-Inspector-
  Model-Caching, Planet-Badge-Text-/Candidate-Caching,
  Perf-Snapshot-JSON-Konvertierung, Life-Detail-Panel,
  Genetic-/Pressure-/Life-Ecology-/Population-Estimate-Ableitung und
  `scaleup_galaxy_100`-Streaming ab
- diese Tests ersetzen das offene Editor-Gate nicht:
  `sample_system.planet_a`, `starter_world.gamma_iv`,
  `starter_world.alpha_iii`, `starter_world.gamma_iii` und mindestens
  ein Detailplanet in `scaleup_galaxy_100` muessen im Fokus-HUD,
  Inspector, Life-Detail-Panel und Badge-Pfad wirklich gelesen werden
- dabei im Summary-/Details-Flow pruefen:
  `Environment` bleibt "jetzt", `World` bleibt "ueber das Jahr",
  `Life` bleibt quantitative Biosphaerenstufe, `Biomass` bleibt Menge,
  `Life Potential` bleibt dominanter Chemiepfad, `Population:` bleibt
  qualitativ und `Estimate:` bleibt grobe Magnitude ohne echten Census,
  Kriege, Katastrophen, Zivilisationen oder Settlement-Zahlen
- denselben Acceptance-Run mit den offenen Large-World-/Performance-
  Gates koppeln:
  `scaleup_galaxy_30` und `scaleup_galaxy_100` mit offenem Inspector im
  `ROOT_OVERVIEW` pruefen, inklusive `model_apply_count`,
  `badge_text_apply_count`, `badge_candidate_rebuild_count`,
  Proxy-Culling, Focus-Smoothing, View-Bookmarks und unlocked-FPS-Haptik
- wenn dieses Bundle sauber ist, danach als naechsten Life-Slice
  `Population Dynamics v1` oder `Evolution Competition v1` planen:
  zeitliche Entwicklung und Konkurrenz sollen erst auf den jetzt
  vorhandenen Estimate-Ranges aufsetzen, nicht im Panel erfunden werden
- falls der Playtest stattdessen zeigt, dass
  `has_primary_source_only_basis` fuer Mehrstern-Faelle zu stoerend
  wird, zuerst einen expliziten `Mehrquellenstrahlung`-Block vorziehen
- den produktiven Large-World-Pfad weiter nur ueber Proxy-/Perf-Trim
  oder planetare Derived-Folgearbeit ausbauen, nicht ueber noch mehr
  Root-Anzahl ohne echten Editor-/Feel-Playtest
- fuer den lokalen Website-Prototyp erst nach einem echten lokalen
  Screenshot-Capture die Platzhalter in `website/` ersetzen; keine
  externen Bilder, Stock-Weltraumbilder, Addon-Icons oder Rendering-
  Referenztexturen als Projektbeleg verwenden
- Headless-Basis nach `Population Estimates v1`:
  `./run_tests.bat` laeuft gruen mit `7960` Passed, `0` Failed;
  der reale Lauf meldet am Prozessende aber weiter generische
  `ObjectDB instances leaked`- und
  `resources still in use`-Hinweise
