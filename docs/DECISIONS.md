# Graviton - Decisions

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
