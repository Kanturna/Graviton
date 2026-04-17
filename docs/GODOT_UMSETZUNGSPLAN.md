# Graviton - Umsetzungsplan

Dieses Dokument ist die lebende Roadmap. Es zeigt, was abgeschlossen
ist, was als naechstes kommt, und was bewusst noch nicht entschieden
ist.

## Foundation-Schritte (Architektur-Dokumentation)

| Schritt | Inhalt | Code-Stand |
|---|---|---|
| 1 | TimeService, UnitSystem, OrbitMath, BodyDef/State, UniverseRegistry, OrbitService (AUTHORED_ORBIT + KEPLER_APPROX), StarterWorld, 2D-Testbed, Tests | **implementiert** |
| 2 | LocalBubbleManager (LCA, double-praezise), `compose_view_position_m` fokus-relativ | **implementiert** |
| 3 | BubbleActivationSet (ACTIVE / INACTIVE_DISTANT / INACTIVE_NO_LCA), `rebuild()`, `describe()` | **implementiert** |
| 4 | LocalOrbitIntegrator (Velocity Verlet), NUMERIC_LOCAL-Regime, Regime-Wechsel-Logging | **implementiert (minimal)** |
| 5 | ThermalService (on-demand Insolation, naechster leuchtender Ancestor, `describe_body()`) | **implementiert (minimal)** |

## Ergaenzender Foundation-Block

- `WorldLoader` / explizite Weltwahl: **implementiert**
  - `src/sim/world/world_loader.gd`
  - `orbit_testbed.gd` laedt Welten jetzt explizit ueber
    `initial_world_id`
  - benannte Referenzwelten: `starter_world`, `sample_system`

## Naechster Fokus

- planetare Zustandsableitung auf Basis der jetzt vorhandenen
  Weltmodell-Felder ueber reine Insolation hinaus
- spaeter Stabilitaets-Guardrails fuer `NUMERIC_LOCAL`
  (Substepping / High-Speed-Limits / Anti-Thrashing)

## Design-Gate vor CONTROLLED-/Schub-Schicht

Vor einer spaeteren Mechanik-Implementierung fuer steuerbare Bodies
steht ein expliziter Designschritt. Die folgenden Fragen muessen
beantwortet sein, bevor Code geschrieben wird:

1. Welchen `BodyType` braucht ein steuerbares Objekt?
2. Wer darf die Position eines `CONTROLLED`-Bodies schreiben?
3. Wo lebt die Forces-API fuer Schub?
4. Wer darf `parent_id` eines `CONTROLLED`-Bodies aendern?

Erst wenn diese Fragen explizit beantwortet sind, beginnt Schritt 5.

## Bewusste Nicht-Ziele dieser Phase

- kein Multiplayer / keine Server-Architektur
- keine prozedurale Welt-Generierung
- keine N-Body-Gravitation
- kein Save/Load des Integrator-Zustands
- keine Oberflaechen-/Lande-Mechanik
- keine Transit-/Clusterlogik
