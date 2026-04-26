# Graviton - Architektur

Dieses Dokument beschreibt das Fundament. Es ist bewusst kurz und
normativ. Wenn du etwas hinzufuegst, das hier widerspricht, halte zuerst
an und frage.

## Leitidee

> Daten und Simulationszustand sind die Wahrheit.
> Nodes, Transforms und Render-Koordinaten sind immer abgeleitet.

Konsequenz: kein `Node.position` als Simulationsquelle. Kein
versteckter Zustand in Szenen. Keine globale Physik-Engine fuer Orbits.

## Schichten und Abhaengigkeitsrichtung

```text
scenes/     (duenn, nur Projektion + Composition Root,
             z. B. OrbitViewRenderer + GalaxyProxyRenderer)
   |
   v
src/runtime/       LocalBubbleManager, BubbleActivationSet,
                   DerivedSnapshotCache, AsteroidSnapshotCache,
                   GalaxyStreamingController
   |
   v
src/sim/           UniverseRegistry, WorldLoader, OrbitService, LocalOrbitIntegrator,
                   ThermalService, AtmosphereService, EnvironmentService,
                   PlanetaryYearSampler, PlanetaryStateService,
                   LifePotentialService, ProtoBiosphereSimulationService,
                   BiosphereScaleService, NativeSpeciesService,
                   GeneticSpeciesService, LifeEcologyService,
                   LifePopulationEstimateService,
                   AsteroidSimulationService/AsteroidState,
                   GalaxyDef/RootSystemManifest/RootSystemGenerator,
                   BodyDef/State, OrbitProfile, OrbitMode
   |
   v
src/core/          TimeService, UnitSystem, OrbitMath, IdRegistry
```

Abhaengigkeiten zeigen streng nach unten. `core/` kennt weder `sim/`
noch `runtime/` noch `scenes/`. `sim/` haengt nur von `core/` ab.
`runtime/` haengt von `sim/` und `core/` ab.

## Wer ist autoritativ wofuer

| Thema                        | Autoritative Quelle           | Schreibrecht       |
|-----------------------------|-------------------------------|--------------------|
| Simulationszeit             | `TimeService` (Autoload)      | nur TimeService    |
| Bekannte Bodies & Topologie | `UniverseRegistry` (Autoload) | nur Registry-API   |
| Parent-Frame-Position/-Velo | `BodyState`                   | nur `OrbitService` |
| Orbit-Modus pro Body        | `BodyState.current_mode`      | nur `OrbitService` |
| Asteroiden-Minor-Bodies     | `AsteroidState`               | nur `AsteroidSimulationService` |
| Residenter Galaxy-Slice     | `GalaxyStreamingController`   | nur Streaming-API  |
| Fokus / View                | `LocalBubbleManager` (Node)   | nur Bubble-API     |
| Aktiv-Set                   | `BubbleActivationSet` (Node)  | nur Activation-API |

Niemals autoritativ:
`Node.position`, `Node3D.transform`, Welt- oder View-Koordinaten,
Visuals im Testbed, Debug-Overlay-Anzeigen,
`GalaxyStreamingController.get_debug_snapshot()`.

## Diagnose / Perf-Probes - ADR

**Entscheidung:** Diagnose- und Performance-Sampling lebt ausserhalb
der autoritativen Sim-Schicht. `sim/`-Services duerfen read-only
Counter oder Snapshots exponieren, aber keine `scenes/`- oder
`src/tools/`-Skripte laden.

**Aktueller Stand:** `OrbitService.get_perf_counter_snapshot()`
liefert kumulative Diagnosezaehler fuer `NUMERIC_LOCAL`,
Substeps, Cap-Hits und Sim-Ticks. `orbit_testbed.gd` sampelt diese
Werte in `PerfProbe` und uebersetzt kumulative Service-Counter dort in
per-frame Diagnose-Counter. Der `P`-Hotkey schreibt die bestehende
CSV-Zeitreihe und zusaetzlich einen JSON-Sidecar mit punktuellen
On-Demand-Snapshots fuer Szene, Fokus, Registry, Kamera, Aktiv-Set,
Derived-Cache, Renderer, Streaming, UI und Service-Counter.
Stage-Zeiten fuer Asteroiden- und Render-Hotpaths werden ebenfalls im
Composition Root gemessen (`asteroid_advance_us`,
`asteroid_snapshot_refresh_us`, `asteroid_renderer_sync_us`,
`orbit_renderer_sync_us`). Der OrbitService exponiert zusaetzlich den
letzten reinen Orbit-Step als read-only `orbit_step_core_us`, damit
Physics-Zeit in `P`-Dumps nicht mit Asteroiden- oder View-Arbeit
verwechselt wird. `TimeService` exponiert analog den letzten Tick-Emit
und den kumulativen `tick_emit_total_us` als read-only Diagnosewerte;
das Testbed bildet daraus die per-frame Spalte
`time_tick_emit_total_us`, ohne Frame-Reset-Logik in `core/` zu
verlagern. `DerivedSnapshotCache` exponiert als `runtime/`-Cache
read-only Refresh-Timer (`last_refresh_us`, `refresh_total_us`) sowie
den bestehenden `refresh_throttled_count`; `orbit_testbed.gd` schreibt
daraus die per-frame Diagnose `derived_snapshot_refresh_total_us`.
`sim/`-Services bleiben dabei frei von `PerfProbe`-Abhaengigkeiten und
exponieren hoechstens read-only Counter wie `free_drift_count`.

**Konsequenz:** `PerfProbe` ist CSV-/Playtest-Diagnostik, keine
Simulationswahrheit. Der JSON-Sidecar ist ebenfalls nur Diagnoseausgabe
und wird erst beim expliziten Dump gebaut, nicht pro Frame. Neue
Messpunkte duerfen die Schichten nicht umdrehen: autoritative Schichten
stellen hoechstens read-only Werte bereit; Sampling, Ringbuffer,
Dumping und Hotkey-Bedienung bleiben im Composition Root oder in
`src/tools/`.

## Autoloads - ADR

**Entscheidung:** Genau zwei projekt-eigene Autoloads -
`TimeService` und `UniverseRegistry`. Alles andere ist regulaerer
Szenengraph.

**Gruende:**
- `TimeService` treibt den gesamten Tick; ohne Zeit keine Simulation.
- `UniverseRegistry` muss szenenuebergreifend persistent sein (Bubble
  wechselt, Universum nicht).
- Jeder weitere Autoload erhoeht globale Kopplung und erschwert Tests.

**Nicht Autoload (bewusste Entscheidung):**
- `WorldLoader`, `OrbitService` und `LocalBubbleManager` werden in der
  Testbed-Szene als Kind-Nodes instanziiert und per `configure()` oder
  explizitem Methodenaufruf verdrahtet.
- Vorteil: explizite Abhaengigkeiten, testbar, lokal auswechselbar.

**Explizite Ausnahme:** `project.godot` kann plugin-provided
Addon-Autoloads enthalten (aktuell `AntialiasedLine2DTexture` und
`PhantomCameraManager`). Diese zaehlen nicht als Projekt-/Sim-Autoloads
und fuehren keine neue Simulationswahrheit ein.

Eine Erweiterung der Autoload-Liste braucht einen neuen ADR-Abschnitt
hier.

## UniverseRegistry-Schlankheit - ADR

**Entscheidung:** Die Registry haelt ausschliesslich Defs, States, IDs,
Update-Order und Signale. Keine Simulationslogik, keine
Koordinatenberechnung, keine Mathematik.

**Grund:** Jeder Extra-Zweck in der Registry zieht Verantwortlichkeit
aus ihrem eigentlichen Zuhause und macht sie zum heimlichen
Alles-Singleton. Das ist genau der Architekturwuchs, den wir vermeiden.

Wenn du ueberlegst, der Registry Funktionalitaet hinzuzufuegen, pruefe:

- Positions-/Velocity-Logik -> gehoert in `OrbitService`
- Welt-/Render-Koordinaten -> gehoert in `LocalBubbleManager`
- Zeit-Fortschritt -> gehoert in `TimeService`
- Mathematik -> gehoert in `core/math/`

## Daten-first

- `BodyDef` und `OrbitProfile` sind `Resource`-Klassen. Ihre Instanzen
  werden im Foundation aber aus `data/*.gd`-Factories erzeugt, nicht aus
  `.tres`.
- `BodyState` ist `RefCounted` - reiner Laufzeitzustand, nicht
  serialisiert, nicht als Asset.

## Composition Root

Hinweis:
Das folgende Snippet ist bewusst schematisch fuer den Single-World-Pfad.
Der aktuelle Code in `scenes/testbeds/orbit_testbed.gd` verdrahtet
zusaetzlich `OrbitReadoutService`, `NativeSpeciesService`,
`GeneticSpeciesService`, `LifeEcologyService`,
`LifePopulationEstimateService`, `RootInspectorOverlay` und
`PlanetBadgeOverlay`; im Large-World-Pfad
laedt dieselbe Szene ueber `load_named_galaxy(...)` und den
`GalaxyStreamingController`. Der im Repo eingecheckte Szenen-Override startet
derzeit mit `scaleup_galaxy_100`.

Die Verdrahtung passiert pro Szene in deren Root-Script:

```gdscript
_ready():
    WorldLoader.load_named_world(&"starter_world", UniverseRegistry)
    OrbitService.configure(UniverseRegistry, TimeService)
    OrbitService.recompute_all_at_time(TimeService.sim_time_s)
    LocalBubbleManager.configure(UniverseRegistry)
    LocalBubbleManager.set_focus(...)
    BubbleActivationSet.configure(UniverseRegistry, LocalBubbleManager)
    BubbleActivationSet.rebuild()
    OrbitService.request_numeric_local_candidates(
        BubbleActivationSet.get_active_ids()
    )
    OrbitService.recompute_all_at_time(TimeService.sim_time_s)
    ThermalService.configure(UniverseRegistry)
    AtmosphereService.configure(UniverseRegistry, ThermalService)
    EnvironmentService.configure(UniverseRegistry, AtmosphereService)
    PlanetaryYearSampler.configure(UniverseRegistry)
    PlanetaryStateService.configure(
        UniverseRegistry,
        ThermalService,
        AtmosphereService,
        PlanetaryYearSampler
    )
    LifePotentialService.configure(
        UniverseRegistry,
        PlanetaryStateService,
        EnvironmentService
    )
    ProtoBiosphereSimulationService.configure(
        UniverseRegistry,
        TimeService,
        WorldLoader
    )
    ProtoBiosphereSimulationService.initialize_for_named_world(...)
    BiosphereScaleService.configure(
        UniverseRegistry,
        PlanetaryStateService,
        LifePotentialService,
        ProtoBiosphereSimulationService
    )
    NativeSpeciesService.configure(
        UniverseRegistry,
        PlanetaryStateService,
        LifePotentialService,
        BiosphereScaleService
    )
    GeneticSpeciesService.configure(
        UniverseRegistry,
        PlanetaryStateService,
        LifePotentialService,
        BiosphereScaleService,
        NativeSpeciesService
    )
    LifeEcologyService.configure(
        UniverseRegistry,
        BiosphereScaleService,
        GeneticSpeciesService
    )
    LifePopulationEstimateService.configure(
        UniverseRegistry,
        BiosphereScaleService,
        LifeEcologyService
    )
    OrbitReadoutService.configure(UniverseRegistry)
    DerivedSnapshotCache.configure(
        UniverseRegistry,
        TimeService,
        LocalBubbleManager,
        WorldLoader,
        ThermalService,
        EnvironmentService,
        OrbitService,
        PlanetaryStateService,
        LifePotentialService,
        ProtoBiosphereSimulationService,
        BiosphereScaleService,
        OrbitReadoutService,
        NativeSpeciesService,
        GeneticSpeciesService,
        LifeEcologyService,
        LifePopulationEstimateService
    )
    OrbitViewRenderer.set_derived_snapshot_cache(DerivedSnapshotCache)
    OrbitService.bodies_updated.connect(
        BubbleActivationSet.mark_ids_dirty
    )
    DebugOverlay.configure(
        UniverseRegistry,
        TimeService,
        LocalBubbleManager,
        BubbleActivationSet,
        ThermalService,
        DerivedSnapshotCache,
        Backdrop,
        GalaxyStreamingController
    )

_process():
    BubbleActivationSet.rebuild()
    OrbitService.request_numeric_local_candidates(
        BubbleActivationSet.get_active_ids()
    )
    ...
```

`recompute_all_at_time` ist kein Tick - es emittiert kein Signal und
treibt keine Zeit vorwaerts. Es stellt nur sicher, dass alle
`BodyState`s vor dem ersten `_process`-Frame konsistent befuellt sind.

`DerivedSnapshotCache` ist ausdruecklich read-only Glue zwischen
`sim/` und View. Wenn ein `OrbitService` mit
`bodies_updated(...)` verdrahtet ist, rebuilt der Cache nur dirty-
abhaengige interessierte Bodies; ohne dieses Signal bleibt
`TimeService.sim_tick` der konservative Fallback. Im Frame-Loop werden
nur bereits berechnete Snapshots konsumiert.
Nach `PlanetaryStateService`, `LifePotentialService`,
`ProtoBiosphereSimulationService`, `BiosphereScaleService`,
`NativeSpeciesService`, `GeneticSpeciesService` und
`LifeEcologyService` sowie `LifePopulationEstimateService` fuehrt der
Cache damit jetzt mehrere read-only Desc-Familien fuer dieselben
Interessens-Bodies, ohne neue Simulationswahrheit in `runtime/`
aufzubauen. Der proto-biosphere-Desc bleibt dabei internes
Substrat/Debug, waehrend `biosphere_scale_desc` die player-facing
`Life:`-Wahrheit fuer HUD und Inspector liefert. `life_ecology_desc`
ist nur qualitative oekologische Praesenz; der darin enthaltene
`population_index` ist kein Census und keine absolute Biomasse dieses
Lifeforms. `population_estimate_desc` liest diesen bereits
kalibrierten Index nur als grobe Order-of-Magnitude-Range und fuehrt
keinen `PopulationState`, keine Settlement-Wahrheit und keine
dynamische Population ein.
Auch Diagnosepfade wie `DebugOverlay` duerfen bei verdrahtetem
`DerivedSnapshotCache` nicht live auf
`ThermalService.describe_body(...)` zurueckfallen; Cache-Miss bleibt
sichtbar als `n/a`.

Jahresprofile fuer planetare Bodies werden bewusst nicht ueber
temporale Mutation der Live-Registry erzeugt. `PlanetaryYearSampler`
arbeitet analytisch und read-only auf `BodyDef`-/Orbitdaten und darf
weder `BodyState` noch `TimeService` noch
`OrbitService.recompute_all_at_time(...)` fuer Analysezwecke verwenden.

Die v1b-Proto-Biosphaere folgt demselben Grundsatz: sie mutiert nicht
frameweise fuer jeden Body, sondern berechnet den aktuellen
Background-State lazy aus stabilen Seed-/Drift-Parametern und
`TimeService.sim_time_s`. Offscreen-/All-Roots-Pfade duerfen dafuer
dieselben Pure-Helper wie die residenten Live-Pfade nutzen, aber keine
zweite Temp-Registry oder duplizierte Planetary-/Life-Math aufbauen.

`Life v2` folgt derselben Architekturdisziplin: `BiosphereScaleService`
fuehrt bandweise Carrying Capacity und Biomasse als read-only
Derived-Layer ein, nutzt dafuer aber direkt den bestehenden
Proto-Progress (`biomass_fraction = progress^2`) statt ein zweites
Zeitmodell zu erfinden. Die chemistry-aware Track-Praeferenzen leben
dafuer gebuendelt in `LifeTrackLookup`, damit `LifePotentialService`
und `BiosphereScaleService` dieselbe Lookup-Wahrheit teilen.

Fuer grosse Multi-Root-Welten bleibt dieselbe Schichtung erhalten:

- `WorldLoader` laedt zunaechst nur einen leichten `GalaxyDef`-Katalog
  plus den aktuell residenten Detail-Slice in die Registry
- `WorldLoader` materialisiert Galaxy-Slices delta-basiert:
  unveraenderte residente Roots bleiben samt `BodyState` erhalten
- vorbereitete Root-Slices leben dabei in genau einem
  cache-scopegebundenen Loader-Cache pro aktiver Welt/Galaxy; `prewarm`
  fuellt nur diesen Loader-Cache und fuehrt keine zweite Def-Haltung im
  `GalaxyStreamingController` ein
- `GalaxyStreamingController.update(delta_s, zoom_factor)` entscheidet
  focus-/zoomgetrieben ueber Resident-/Prewarm-Shells, Hysterese und
  Keepalive
- `GalaxyStreamingController.get_debug_snapshot()` bleibt ausdruecklich
  read-only Diagnoseflaeche fuer `F3`/Playtest und fuehrt keine neue
  Runtime-Autoritaet ein
- `GalaxyProxyRenderer` zeigt nichtresidente Roots als reine
  View-Proxies im Galaxy-Space
- `LocalBubbleManager` und `BubbleActivationSet` bleiben bewusst
  same-root im Detail-Slice; die Cross-Root-Uebersicht ist ein
  paralleler Projektionpfad, keine Bubble-Umschreibung

Kein impliziter `get_node("/root/...")`-Griff aus tiefen Skripten.

## BubbleActivationSet - ADR

**Entscheidung:** `BubbleActivationSet` ist eine eigene Klasse, kein Teil
von `LocalBubbleManager`.

**Grund:** `LocalBubbleManager` ist View-Ableitung (Koordinaten,
Render-Skalierung). `BubbleActivationSet` ist Relevanzklassifikation
(geometrische Naehe zum Fokus). Beides in eine Klasse zu legen, waere
eine Gottklasse.

**Verantwortung:** Liest `registry.get_update_order()` und
`bubble.compose_view_position_m()`. Schreibt nichts. Kein Autoload.
Die Klasse darf ihr eigenes letztes Klassifikationsergebnis lesen, um
eine rein geometrische Enter-/Exit-Hysterese am Aktivierungsrand zu
bilden; das ist keine Simulations- oder Orbit-Regime-Wahrheit.

**Rebuild-Strategie:** Die Szene darf `rebuild()` weiter pro Frame
aufrufen, aber der Dienst scannt nicht mehr blind alles neu. Same-root-
Bodies werden nur bei Fokus-/World-Wechsel voll neu klassifiziert;
normale Tick-Arbeit laeuft inkrementell ueber explizit dirty markierte
IDs bzw. betroffene Teilbaeume.

**Klassifikation:** Drei explizite Zustaende - `ACTIVE`,
`INACTIVE_DISTANT`, `INACTIVE_NO_LCA`. Kein stilles "inaktiv ist
inaktiv". Inaktive Bodies werden bei
`distance <= activation_radius_m` aktiv. Bereits aktive Bodies bleiben
bis `distance <= activation_radius_m * activation_radius_exit_ratio`
aktiv, damit der reine Relevanz-Wish an der Distanzschwelle nicht
flackert.

**Dirty-Quelle:** `OrbitService.bodies_updated(...)` markiert geaenderte
Bodies ueber den Composition Root dirty; Registry-Churn setzt nur
`topology_dirty` und rebuilt danach denselben Fokus-root-Slice neu;
`focus_changed` bleibt der Full-Rebuild-Fall des lokalen Slices.

**Aktueller Stand:** Implementiert als read-only Runtime-Service in
`src/runtime/local_bubble/bubble_activation_set.gd`. `classify(id)`
liest den Zustand des letzten `rebuild()`, und `get_active_ids()`
folgt der topologischen Registry-Reihenfolge (Parent vor Kind). Das
Activation-Set bleibt ein Wish-Signal fuer den Composition Root:
`OrbitService` entscheidet weiter allein ueber Eligibility,
`BodyState.current_mode`, Grace und budgetierten Rejoin.

## Bubble-Verantwortung - ADR

**Entscheidung:** `LocalBubbleManager` ist reine Ableitungsschicht.
Er speichert keinen eigenen Koerperzustand, keinen World-Space-Cache und
kein Aktiv-Set.

**Zielbild fuer Schritt 2:** Fokus-relative Komposition via LCA (Lowest
Common Ancestor). Parent-Frame-Ketten werden als drei separate
GDScript-`float`-Variablen (IEEE-754 double) akkumuliert, nicht als
`Vector3` (float32). Das verhindert Katastrophen-Kanzellation bei
AU-Distanzen.

**Aktueller Stand:** `LocalBubbleManager` nutzt jetzt die
praezisionsbewusste Step-2-LCA-Komposition fuer
`compose_view_position_m()`. Bodies ohne gemeinsamen Root mit dem Fokus
liefern bewusst `Vector3.INF`. Die root-lokale Debug-Hilfe heisst
`compose_root_local_position_m()` und ist nicht fuer den Render-Pfad
gedacht.

**Kein-LCA-Pfad:** `Vector3.INF` plus Warning-/Debug-Logging. Kein
stilles `ZERO` - semantisch falsch lokalisierte Objekte sollen sichtbar
sein, aber legitime Cross-Root-Faelle sind kein Fehler.

**Render-Skalierung:** Ausschliesslich in `to_render_units(view_m)`.
Kein anderer Code ruft `RENDER_SCALE_M_PER_UNIT` direkt an.

## LocalOrbitIntegrator - ADR

**Entscheidung:** `LocalOrbitIntegrator` ist eine eigene Klasse, kein
Teil von `OrbitService`.

**Grund:** Die Integrationslogik (z. B. Velocity Verlet,
Gravitationsbeschleunigung) ist reine, zustandslose Mathematik - analog
zu `OrbitMath.kepler_position`. Sie in `OrbitService` einzubetten,
wuerde den Service zu einer monolithischen Klasse machen.

**Verantwortung:** Statische pure Funktionen wie
`gravity_acceleration_mps2()`, `step_velocity_verlet()` und
`step_velocity_verlet_substepped()`. Liest und schreibt kein
`BodyState`. Kein Autoload.

**Aktueller Stand:** Implementiert als Parent-Only-Integrator in
`src/sim/orbit/local_orbit_integrator.gd`, inklusive reiner
Substep-Hilfe fuer grosse numerische `dt`. Weiterhin keine N-Body-
Kraefte und keine Service-Verantwortung.

## ThermalService - ADR

**Entscheidung:** `ThermalService` ist ein eigener read-only
Derived-Service im `sim/`-Layer.

**Grund:** Insolation ist weder View-Ableitung (`runtime/`) noch
autoritative Sim-Wahrheit (`BodyState`). Sie ist eine abgeleitete Groesse
aus bestehender Foundation-Wahrheit und sollte deshalb als eigener,
leicht testbarer Service neben `OrbitService` leben.

**Verantwortung:** On-demand-Reads auf `BodyDef.luminosity_w`,
`BodyDef.albedo`, `BodyDef.axial_tilt_rad`,
`BodyDef.north_pole_orbit_frame_azimuth_rad`,
`BodyState.position_parent_frame_m` und Parent-Topologie. Kein Cache,
kein Tick-Hook, keine `BodyState`-Mutation.

**Quellenregel:** Quelle ist der naechste Ancestor mit
`luminosity_w > 0.0`. Die Suche startet beim Parent, nicht beim Body
selbst. `luminosity_w == 0.0` wird pragmatisch als "keine Quelle"
behandelt und blockiert die Suche nicht.

**Aktueller Stand:** `ThermalService` liefert jetzt on-demand
Insolation, global gemittelten absorbierten Fluss, nackte
Gleichgewichtstemperatur sowie saisonale Geometrie
(`subsolar_latitude_rad`, tagesgemittelte TOA-Insolation fuer
ausgewaehlte Breiten). Das `/4`-Redistribution-Modell ist bewusst als
Fast-Rotator-Annahme dokumentiert; Atmosphaeren-, Greenhouse- und
Mehrquellen-Modelle leben bewusst ausserhalb dieses Services. Bis ein
spaeterer Mehrquellen-Block existiert, muessen HUD/Debug diese
Vereinfachung explizit als `Primary source: ...` sichtbar machen.

## AtmosphereService - ADR

**Entscheidung:** `AtmosphereService` ist ein eigener read-only
Derived-Service im `sim/`-Layer.

**Grund:** Greenhouse ist eine eigene Domane zwischen nackter
Strahlungsphysik und qualitativer Umweltklassifikation. Weder
`ThermalService` noch `EnvironmentService` sollen dadurch zu
Sammelklassen werden.

**Verantwortung:** On-demand-Reads auf `BodyDef.greenhouse_delta_k` plus
`ThermalService.describe_body(id)`. Kein Cache, kein Tick-Hook, keine
`BodyState`-Mutation.

**Aktueller Stand:** `AtmosphereService` liefert jetzt ein minimales,
datengetriebenes Toy-Greenhouse-Modell:
`surface_temperature_k = equilibrium_temperature_k + greenhouse_delta_k`.
Keine Chemie, kein Druckmodell, keine Anti-Greenhouse-Kuehlung.

## EnvironmentService - ADR

**Entscheidung:** `EnvironmentService` ist ein eigener read-only
Derived-Service im `sim/`-Layer und erweitert weder `ThermalService`
noch `AtmosphereService`.

**Grund:** `ThermalService` bleibt bei quantitativen Thermalwerten
(`F`, absorbierter Fluss, `T_eq`). `EnvironmentService` macht daraus
eine qualitative Interpretation (`HABITABLE` / `MARGINAL` /
`HOSTILE`) und verhindert so, dass `ThermalService` zur Sammelklasse
fuer jede umweltnahe Aussage wird.

**Verantwortung:** On-demand-Klassifikation fuer `PLANET` und `MOON`
auf Basis von `surface_temperature_k`. Kein Cache, kein Tick-Hook,
keine `BodyState`-Mutation.

**API-Break in P9:** `EnvironmentService.configure(...)` wechselt
bewusst von `configure(registry, thermal_service)` auf
`configure(registry, atmosphere_service)`. Der P8-Pfad auf Basis von
`T_eq` bleibt nicht parallel erhalten.

## DerivedSnapshotCache - ADR

**Entscheidung:** `DerivedSnapshotCache` ist ein kleiner read-only
Runtime-Helfer zwischen `sim/`-Services und View-Code.

**Grund:** HUD und Renderer brauchen dieselben Derived-Daten, aber diese
Schnittstelle soll nicht wieder still in `_process()` rekursiv
`ThermalService.describe_body(...)` und
`EnvironmentService.describe_body(...)` fuer jeden Frame aufrollen.

**Verantwortung:** Speichert nur den letzten Snapshot pro Body und fuer
den aktuellen Fokus. Kein eigener Sim-Zustand, keine neue Wahrheit,
keine `BodyState`-Mutation.

**Invalidierung / Interesse:** Der Cache fuehrt ein explizites
Interest-Set (Fokus plus angeforderte Bodies) und refreshes nur diese
Bodies. Wenn ein `OrbitService` mit `bodies_updated(...)` verdrahtet
ist, folgt die Invalidierung den dirty IDs plus Ancestor-Kette. Ohne
diesen Hook bleibt `TimeService.sim_tick` der konservative Fallback.

**Wichtig:** Keine stillen Rebuilds im Frame-Loop; `_process()`
konsumiert nur den letzten Snapshot.

## Minor Bodies / Asteroiden - ADR

**Entscheidung:** Asteroiden v1 sind Minor Bodies in einem eigenen
`src/sim/asteroids/`-Slice. Sie sind keine normalen
`UniverseRegistry`-Bodies, bekommen kein dynamisches
`BodyDef.parent_id`-Reparenting und schreiben niemals Major-Body-
`BodyState`.

**Grund:** Asteroiden sollen viele kleine, chaotisch wirkende Koerper
sein, ohne die bestehende Parent-/Child-Topologie der grossen
Himmelskoerper zu zerlegen. Die Major-Body-Simulation bleibt die
Quelle fuer `BLACK_HOLE`, `STAR`, `PLANET` und `MOON`; Asteroiden
lesen diese Zustande nur als read-only Kontext. Als v1.2-Attraktoren
gelten `BLACK_HOLE`, `STAR`, `PLANET` und `MOON` nur innerhalb
expliziter Einflussradien; es gibt keine globale Root-Dauerschwerkraft.

**State und Autoritaet:** `AsteroidDef.spawn_origin_id` beschreibt das
deterministische Stern-Spawnzentrum. `AsteroidState.anchor_id`
beschreibt dagegen den Rechen-Frame und ist seit v1.1 stabil der
`root_id`. Position und Velocity liegen als double-Felder im Root-
Frame. Nur `AsteroidSimulationService` darf diesen State schreiben.
Asteroiden haben einen eigenen ID-Raum ausserhalb `IdRegistry`;
`BodyType.Kind.ASTEROID` bleibt fuer spaetere benannte Grossasteroiden
reserviert.

**Frame-Politik v1.1:** v1.1 fuehrt kein `FrameDef` ein und nutzt den
Root als stabilen Asteroiden-Anchor. Damit entfaellt bewusst der
urspruengliche lokale Anchor-Praezisionsvorteil aus v1; die double-
Komponenten im Root-Frame sind fuer v1.1 ausreichend. Anchor-Switching
zu naeheren Major-Body-Frames, Stetigkeitsgarantien beim Switch und
eine moegliche Vereinheitlichung mit einem spaeteren Frame-Modell sind
Folge-Slices.

**Lifecycle v1:** In Single-World-Szenen werden Asteroiden fuer die
geladenen Root-IDs gespawnt. In Large-World-Szenen folgt der
Asteroiden-Slice bewusst nur dem aktuellen Fokus-Root, nicht allen
residenten oder vorgewaermten Neighbor-Roots. Neighbor-Residency bleibt
Streaming-/Registry-Zustand fuer Major Bodies; sie erweitert in v1
nicht automatisch die aktive Minor-Body-Physik. Fokus-Root-Wechsel
loeschen bereits erzeugte Asteroiden aber nicht mehr: nicht aktive
Root-Asteroiden werden im `AsteroidSimulationService` geparkt, aus dem
Snapshot ausgeblendet und nicht weiter integriert, bis dieser Root
wieder aktiver Asteroiden-Root ist. Dadurch bleibt der aktive
Large-World-Pfad bei 24 Asteroiden pro Fokus-Root, ohne deterministisch
neu zu spawnen.

**Physik v1.2:** Restricted Gravity mit Freiflug. `BLACK_HOLE`, `STAR`,
`PLANET` und `MOON` ziehen Asteroiden nur innerhalb expliziter
Einflussradien an. Schwarze Loecher sind keine Mandatory-Attraktoren
und bekommen in v1.2 keinen Consume-/Kill-Radius; sie lenken schnelle
Flybys nur innerhalb ihres lokalen Root-Einflussfelds. Die BH-
Gravitation nutzt fuer Asteroiden ein `sim/asteroids`-internes
`effective_mu`, das aus direkten authored Sternkindern des Roots
gefittet wird (`4*pi^2*r^3/T^2`, log-linear ueber `r`,
`BH_FLYBY_GRAVITY_FACTOR = 0.45`). Dieses `effective_mu` ist keine neue
globale Physikwahrheit: `BodyDef.mass_kg` bleibt die einzige Major-
Body-Wahrheit, und `OrbitService`, `ThermalService`,
`PlanetaryStateService` sowie alle nicht-Asteroiden-Services verwenden
weiter `UnitSystem.mu_from_mass(BodyDef.mass_kg)`. Der
Asteroiden-`effective_mu`-Pfad darf nicht ueber Registry, Runtime-
Snapshots oder View-Code als globale Masse sichtbar werden. Ausserhalb
aktiver Felder driftet ein
Asteroid linear mit unveraenderter Velocity weiter. Es gibt keine
globale Dauerschwerkraft, keinen Re-Spawn/Belt-Replenishment in v1.2
und keinen Consume-/Kill-Radius fuer Schwarze Loecher. Die fruehere
Out-of-Bounds-Deaktivierung wird durch eine harte Numerik-Grenze
ersetzt:
`ASTEROID_FAR_RETIRE_RADIUS_M = 1.0e16`. Initiale Velocities enthalten
bewusst schnelle Flyby-Anteile, damit BH-Felder Asteroiden eher
ablenken als als kleine Kreisbahn-Polygone einfangen. Sehr langsame
Asteroiden koennen physikalisch gebunden werden; eine explizite
BH-Capture-/Escape-Policy bleibt ein Folge-Slice. Asteroiden ziehen
nichts an. Es gibt keine Asteroid-Asteroid-Gravitation, keine
Asteroid-Kollisionen, keine Impacts, kein Merge/Split und keine
Life-Folgen.

**Attractor-Auswahl:** Pro aktivem Root baut `AsteroidSimulationService`
einen sim-internen Influence-Zone-Index. Eintraege enthalten nur
abgeleitete read-only Werte (`id`, `kind`, Enter-/Exit-Radius und das
asteroid-Restricted-Gravity-`mu_m3ps2`). Fuer `BLACK_HOLE` darf dieses
`mu_m3ps2` vom Major-Body-`mass_kg` abweichen; fuer
`STAR`/`PLANET`/`MOON` bleibt es exakt `UnitSystem.mu_from_mass`.
Asteroiden pruefen diesen kompakten Index; Bodies suchen nicht nach
Asteroiden. Pro Tick wird ein fixes Attractor-Set fuer alle Substeps
genutzt, capped auf sechs Eintraege. Kandidaten muessen im Root des
Asteroiden liegen, `BLACK_HOLE`/`STAR`/`PLANET`/`MOON` sein und
innerhalb ihres Einflussradius liegen. Bereits aktive Attraktoren
nutzen einen Exit-Radius mit Faktor `1.15`; optionale Quellen werden
nur ersetzt, wenn ein neuer Kandidat den schwaechsten aktuellen
Attraktor mindestens um Faktor `1.25` uebertrifft. Leere
Attractor-Sets werden jeden Tick gegen den Index geprueft, aktive Sets
duerfen weiter ueber ein kurzes Refresh-Fenster wiederverwendet werden.
Die konkreten Major-Body-Positionen der ausgewaehlten Attraktoren
werden trotzdem in jedem Tick neu gelesen.

**Runtime/View:** `AsteroidSnapshotCache` lebt getrennt von
`DerivedSnapshotCache` in `runtime/derived/` und ist read-only Glue fuer
Renderer. Er exponiert Root-Frame-Komponenten plus abgeleitete
View-Positionen, ohne Sim-State zu schreiben. `AsteroidFieldRenderer`
rendert Punkte und kurze Trails aus Snapshots. Trail-History ist ein
reiner Renderer-Ringbuffer aus stabilen Samples und keine Simulations-
oder Snapshot-Wahrheit; die Reprojektion nutzt pro Frame einen
Anchor-View-Cache, damit pro unique `anchor_id` nur eine
`compose_view_position_m`-Komposition anfaellt. Trails duerfen bei
Fokuswechseln innerhalb desselben Roots erhalten bleiben, muessen bei
Root-/World-Wechsel und Despawn aber geloescht werden.

## Large-World Proxy-Layer - ADR

**Entscheidung:** Cross-Root-Uebersicht fuer grosse Galaxien lebt in
einem separaten Proxy-/Streaming-Pfad statt als Erweiterung des
`LocalBubbleManager` oder als Sektorsystem.

**Grund:** Die bestehende Bubble-Lokalisierung bleibt same-root und
fokusrelativ korrekt. Mehrere Root-Systeme gleichzeitig in denselben
Bubble-Frame zu pressen, wuerde diese Semantik aufweichen und fuehrte
leicht zu "Sektoren 2.0"-Komplexitaet.

**Konsequenz:**

- `GalaxyDef` / `RootSystemManifest` beschreiben die Galaxy-Metadaten
- `GalaxyStreamingController` materialisiert nur den relevanten
  Detail-Slice in `UniverseRegistry`
- `GalaxyProxyRenderer` zeigt entfernte BH-/Stern-Proxies ausserhalb
  dieses Detail-Slices
- Proxy und Detail teilen dieselben analytischen Orbit-Parameter, damit
  Materialisierung und Rueckfall positions- und velocity-stetig bleiben

## Regime-Wechsel-Modell - ADR

**Entscheidung:** Der Wechsel zwischen `KEPLER_APPROX` und
`NUMERIC_LOCAL` wird durch die Szene (Composition Root) ausgeloest, nicht
durch `OrbitService` oder `BubbleActivationSet` selbst.

**Grund:** `OrbitService` (`sim/`) kennt `BubbleActivationSet`
(`runtime/`) nicht - die Layering-Regel verbietet diese
Rueckwaertsabhaengigkeit. `BubbleActivationSet` schreibt kein
`BodyState`; seine Verantwortung ist Klassifikation. Die Szene sieht
beide Schichten und bridged sie explizit.

**API:** `OrbitService.request_numeric_local_candidates(ids)` -
Kandidaten-Angebot von der Szene. `OrbitService` filtert intern auf
Eligibility und ersetzt das Wunsch-Set bei jedem Aufruf vollstaendig.

**Eligibility:** `AUTHORED_ORBIT`-Bodies wechseln nie zu
`NUMERIC_LOCAL`. Root-Bodies wechseln nie. Nur `KEPLER_APPROX` ist
eligible.

**Uebergangs-Logging:** Beim erfolgreichen Austritt (`NUMERIC_LOCAL` ->
`KEPLER_APPROX`) aktualisiert `OrbitService` den read-only
Perf-Counter, loggt aber keine Warning. Wenn der Rejoin am Budget
scheitert, wird dieser blocked Exit explizit per Warning sichtbar
gemacht.

**Eintritts-Seeding:** Beim Eintritt in `NUMERIC_LOCAL` seedet
`OrbitService` Position und Velocity aus der analytischen Kepler-Loesung
am aktuellen `t_s`. Velocity wird per zentraler finite Differenz mit
`VELOCITY_SEED_EPSILON_S = 1.0` berechnet.

**P10-Guardrail-Stand:** Der Wish-Pfad entsteht weiter in `_process()`,
der eigentliche Sim-Tick in `_physics_process()`. Dieser
Ein-Frame-Versatz bleibt bewusst bestehen, wird aber im `OrbitService`
ueber eine kleine Missing-Request-Grace abgefedert. Separat darf
`BubbleActivationSet` eine rein geometrische Enter-/Exit-Hysterese fuer
das Aktiv-Set nutzen; sie schreibt keinen Sim-State und entscheidet
keinen Orbit-Modus. Der Rueckwechsel auf `KEPLER_APPROX` erfolgt nur
ueber den budgetierten Rejoin im `OrbitService`; liegt der numerische
Zustand zu weit von der analytischen Loesung entfernt, bleibt der Body
autoritativ `NUMERIC_LOCAL`.

**Overspeed-Policy:** `OrbitService` integriert `NUMERIC_LOCAL` jetzt
per Substepping bis zu einem festen Budget und nutzt darueber hinaus
`Cap+Warn`. Das ist bewusst Best-Effort und kein Garant fuer beliebig
hohe `time_scale`.

**Tick-Completion-Signal:** `OrbitService.step_completed(dt_s, t_s)`
feuert bei jedem `_on_sim_tick` genau einmal und bedingungslos nach dem
Orbit-Step. Es ist nicht an die `bodies_updated`-Empty-Guard gekoppelt.
`bodies_updated(ids, reason)` bleibt ein Dirty-/Interest-Signal;
`step_completed` ist das explizite Completion-Signal fuer abgeleitete
Services wie `AsteroidSimulationService`.

## Frame-Modell - ADR (vorlaeufig)

**Entscheidung (Schritte 1-4):** Ein Body fungiert als Referenzrahmen
fuer seine Kinder. Die `parent_id`-Hierarchie in `BodyDef`/`BodyState`
definiert den Frame-Graphen. Es existiert kein separates `FrameDef`.

**Grund:** In der aktuellen Phase bestehen Frames ausschliesslich aus
Himmelskoerpern. Ein separates `FrameDef` wuerde eine
Abstraktionsebene einfuehren, die erst noetig wird, wenn Frames ohne
Massebeitrag benoetigt werden.

**Vorlaeufig - bewusst offene Fragen:**
- Brauchen wir spaeter Frames ohne klassischen Himmelskoerper?
- Wie werden Docking/Attachment/Surface-Frames modelliert?
- Ist `Body == Frame` dauerhaft richtig oder nur eine Phasenentscheidung?
- Wie wird Reparenting gehandhabt?

Wenn eine dieser Fragen beantwortet werden muss, neuen ADR-Abschnitt
erstellen statt diesen still zu erweitern.

## Kontrollierbare Bodies - Design-Gate

`BodyType.Kind.CONTROLLED` ist strukturell vorbereitet, aber semantisch
noch nicht festgelegt. Bewusst offene Fragen fuer den spaeteren
Designschritt vor einer CONTROLLED-/Schub-Schicht:

- Hat ein `CONTROLLED`-Body immer ein `OrbitProfile`?
- Ist ein `CONTROLLED`-Body automatisch `NUMERIC_LOCAL`-eligible?
- Wo lebt die forces-/command-API - in `OrbitService` oder in einem
  neuen Layer?
- Wer darf `parent_id` eines `CONTROLLED`-Bodies aendern
  (z. B. beim Andocken)?

Bis dahin gilt: `CONTROLLED` ist nur ein Typ-Tag, keine
Verhaltensgarantie.
