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
scenes/     (duenn, nur Projektion + Composition Root)
   |
   v
src/runtime/       LocalBubbleManager, BubbleActivationSet
   |
   v
src/sim/           UniverseRegistry, WorldLoader, OrbitService, LocalOrbitIntegrator,
                   ThermalService,
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
| Fokus / View                | `LocalBubbleManager` (Node)   | nur Bubble-API     |
| Aktiv-Set                   | `BubbleActivationSet` (Node)  | nur Activation-API |

Niemals autoritativ:
`Node.position`, `Node3D.transform`, Welt- oder View-Koordinaten,
Visuals im Testbed, Debug-Overlay-Anzeigen.

## Autoloads - ADR

**Entscheidung:** Genau zwei Autoloads - `TimeService` und
`UniverseRegistry`. Alles andere ist regulaerer Szenengraph.

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
Das folgende Snippet beschreibt den aktuellen Composition-Root-Stand
nach Schritt 4. Der aktuelle Code in
`scenes/testbeds/orbit_testbed.gd` nutzt bereits einen expliziten
`WorldLoader`, ein verdrahtetes `BubbleActivationSet` und den gelebten
`request_numeric_local_candidates(...)`-Pfad im Runtime-Flow.

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
    DebugOverlay.configure(
        UniverseRegistry,
        TimeService,
        LocalBubbleManager,
        BubbleActivationSet,
        ThermalService
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

**Rebuild-Strategie:** Explizit pro Frame aus dem Testbed plus
Auto-Rebuild bei `focus_changed`. Bewusste Uebergangsloesung fuer
kleines N.

**Klassifikation:** Drei explizite Zustaende - `ACTIVE`,
`INACTIVE_DISTANT`, `INACTIVE_NO_LCA`. Kein stilles "inaktiv ist
inaktiv".

**Aktueller Stand:** Implementiert als read-only Runtime-Service in
`src/runtime/local_bubble/bubble_activation_set.gd`. `classify(id)`
liest den Zustand des letzten `rebuild()`, und `get_active_ids()`
folgt der topologischen Registry-Reihenfolge (Parent vor Kind).

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

**Fehlerpfad kein LCA:** `Vector3.INF` plus `push_error`. Kein stilles
`ZERO` - semantisch falsch lokalisierte Objekte sollen sichtbar sein.

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
`gravity_acceleration_mps2()` und `step_velocity_verlet()`. Liest und
schreibt kein `BodyState`. Kein Autoload.

**Aktueller Stand:** Implementiert als minimaler Parent-Only-Integrator
in `src/sim/orbit/local_orbit_integrator.gd`. Kein Substepping, kein
High-Speed-Guardrail, keine N-Body-Kraefte.

## ThermalService - ADR

**Entscheidung:** `ThermalService` ist ein eigener read-only
Derived-Service im `sim/`-Layer.

**Grund:** Insolation ist weder View-Ableitung (`runtime/`) noch
autoritative Sim-Wahrheit (`BodyState`). Sie ist eine abgeleitete Groesse
aus bestehender Foundation-Wahrheit und sollte deshalb als eigener,
leicht testbarer Service neben `OrbitService` leben.

**Verantwortung:** On-demand-Reads auf `BodyDef.luminosity_w`,
`BodyDef.albedo`, `BodyState.position_parent_frame_m` und
Parent-Topologie. Kein Cache, kein Tick-Hook, keine `BodyState`-
Mutation.

**Quellenregel:** Quelle ist der naechste Ancestor mit
`luminosity_w > 0.0`. Die Suche startet beim Parent, nicht beim Body
selbst. `luminosity_w == 0.0` wird pragmatisch als "keine Quelle"
behandelt und blockiert die Suche nicht.

**Aktueller Stand:** `ThermalService` liefert jetzt on-demand
Insolation, global gemittelten absorbierten Fluss und einfache
Gleichgewichtstemperatur. Das `/4`-Redistribution-Modell ist bewusst
als Fast-Rotator-Annahme dokumentiert; Atmosphaeren-, Greenhouse- und
Mehrquellen-Modelle bleiben Folgearbeit.

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

**Uebergangs-Logging:** Beim Austritt (`NUMERIC_LOCAL` ->
`KEPLER_APPROX`) ruft `OrbitService` `push_warning` auf, damit
Diskontinuitaeten sichtbar bleiben.

**Eintritts-Seeding:** Beim Eintritt in `NUMERIC_LOCAL` seedet
`OrbitService` Position und Velocity aus der analytischen Kepler-Loesung
am aktuellen `t_s`. Velocity wird per zentraler finite Differenz mit
`VELOCITY_SEED_EPSILON_S = 1.0` berechnet.

**Bekannte Rest-Limitation:** Der Wish-Pfad entsteht aktuell in
`_process()`, der eigentliche Sim-Tick in `_physics_process()`. Dieser
Ein-Frame-Versatz bleibt fuer den minimalen Slice bewusst stehen und
wird spaeter ueber Guardrails / Substepping adressiert.

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
