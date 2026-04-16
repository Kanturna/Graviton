# Atraxis — Architektur

Dieses Dokument beschreibt das Fundament. Es ist bewusst kurz und
normativ. Wenn du etwas hinzufügst, das hier widerspricht, halte zuerst
an und frage.

## Leitidee

> Daten und Simulationszustand sind die Wahrheit.
> Nodes, Transforms und Render-Koordinaten sind immer abgeleitet.

Konsequenz: kein `Node.position` als Simulationsquelle. Kein
versteckter Zustand in Szenen. Keine globale Physik-Engine für Orbits.

## Schichten und Abhängigkeitsrichtung

```
scenes/     (dünn, nur Projektion)
   │
   ▼
src/runtime/       LocalBubbleManager, später Bubble-Logik
   │
   ▼
src/sim/           UniverseRegistry, OrbitService, BodyDef/State, OrbitProfile
   │
   ▼
src/core/          TimeService, UnitSystem, OrbitMath, IdRegistry
```

Abhängigkeiten zeigen streng nach unten. `core/` kennt weder
`sim/` noch `runtime/` noch `scenes/`. `sim/` hängt nur von `core/`
ab. `runtime/` hängt von `sim/` und `core/` ab.

## Wer ist autoritativ wofür

| Thema                        | Autoritative Quelle                              | Schreibrecht       |
|------------------------------|--------------------------------------------------|--------------------|
| Simulationszeit              | `TimeService` (Autoload)                         | nur TimeService    |
| Bekannte Bodies & Topologie  | `UniverseRegistry` (Autoload)                    | nur Registry-API   |
| Parent-Frame-Position/-Velo  | `BodyState`                                      | nur `OrbitService` |
| Orbit-Modus pro Body         | `BodyState.current_mode`                         | nur `OrbitService` |
| Fokus / View                 | `LocalBubbleManager` (Node)                      | nur Bubble-API     |

Niemals autoritativ:
`Node.position`, `Node3D.transform`, Welt- oder View-Koordinaten,
Visuals im Testbed, Debug-Overlay-Anzeigen.

## Autoloads — ADR

**Entscheidung:** Genau zwei Autoloads — `TimeService` und
`UniverseRegistry`. Alles andere ist regulärer Szenengraph.

**Gründe:**
- `TimeService` treibt den gesamten Tick; ohne Zeit keine Simulation.
- `UniverseRegistry` muss szenenübergreifend persistent sein (Bubble
  wechselt, Universum nicht).
- Jeder weitere Autoload erhöht globale Kopplung, erschwert Tests.

**Nicht Autoload (bewusste Entscheidung):**
- `OrbitService` und `LocalBubbleManager` werden in der Testbed-Szene
  als Kind-Nodes instanziiert und per `configure()` explizit verdrahtet.
- Vorteil: explizite Abhängigkeiten, testbar, lokal auswechselbar.

Eine Erweiterung der Autoload-Liste braucht einen neuen ADR-Abschnitt
hier.

## UniverseRegistry-Schlankheit — ADR

**Entscheidung:** Die Registry hält ausschließlich Defs, States, IDs,
Update-Order und Signale. Keine Simulationslogik, keine Koordinaten-
berechnung, keine Mathematik.

**Grund:** Jeder Extra-Zweck in der Registry zieht Verantwortlichkeit
aus ihrem eigentlichen Zuhause und macht sie zum heimlichen
Alles-Singleton. Das ist genau der "Architekturwuchs", den wir
vermeiden.

Wenn du überlegst, der Registry Funktionalität hinzuzufügen, prüfe:

- Positions-/Velocity-Logik → gehört in `OrbitService`.
- Welt-/Render-Koordinaten → gehört in `LocalBubbleManager`.
- Zeit-Fortschritt → gehört in `TimeService`.
- Mathematik → gehört in `core/math/`.

## Daten-first

- `BodyDef` und `OrbitProfile` sind `Resource`-Klassen (typisiert,
  inspektable). Ihre **Instanzen** werden im Foundation aber aus
  `data/sample_system.gd` (Factory) erzeugt, nicht aus `.tres`.
  Grund: diff-freundlich, reviewbar, KI-lesbar.
- `BodyState` ist `RefCounted` — reiner Laufzeitzustand, nicht
  serialisiert, nicht als Asset.

## Composition Root

Die Verdrahtung passiert pro Szene in deren Root-Script:

```
_ready():
    OrbitService.configure(UniverseRegistry, TimeService)
    OrbitService.recompute_all_at_time(TimeService.sim_time_s)  # initialer konsistenter Zustand
    LocalBubbleManager.configure(UniverseRegistry)
    LocalBubbleManager.set_focus(...)
    DebugOverlay.configure(UniverseRegistry, TimeService, LocalBubbleManager)
```

`recompute_all_at_time` ist kein Tick — es emittiert kein Signal, treibt
keine Zeit vorwärts. Es stellt nur sicher, dass alle `BodyState`s vor dem
ersten `_process`-Frame konsistent befüllt sind.

Kein impliziter `get_node(^"/root/...")`-Griff aus tiefen Skripten.

## Bubble-Verantwortung — ADR

**Entscheidung:** `LocalBubbleManager` ist reine Ableitungsschicht.
Er speichert keinen eigenen Körperzustand, keinen World-Space-Cache,
kein Aktiv-Set.

**Präzisionsstrategie:** Fokus-relative Komposition via LCA (Lowest
Common Ancestor). Parent-Frame-Ketten werden als drei separate
GDScript-`float`-Variablen (IEEE-754 double) akkumuliert, nicht als
`Vector3` (float32). Das verhindert Katastrophen-Kanzellation bei
AU-Distanzen (~18 km Fehler in naiver float32-Subtraktion).

**Fehlerpfad kein LCA:** `Vector3.INF` + `push_error`. Kein stilles
`ZERO` — semantisch falsch lokalisierte Objekte sollen sichtbar sein.

**Render-Skalierung:** Ausschließlich in `to_render_units(view_m)`.
Kein anderer Code ruft `RENDER_SCALE_M_PER_UNIT` direkt an.
