# Graviton — Umsetzungsplan

Dieses Dokument ist die lebende Roadmap. Es zeigt, was abgeschlossen ist,
was als nächstes kommt, und was bewusst noch nicht entschieden ist.

## Foundation-Schritte (Architektur-Dokumentation)

| Schritt | Inhalt | Code-Stand |
|---|---|---|
| 1 | TimeService, UnitSystem, OrbitMath, BodyDef/State, UniverseRegistry, OrbitService (AUTHORED_ORBIT + KEPLER_APPROX), StarterWorld, 2D-Testbed, Tests | **implementiert** |
| 2 | LocalBubbleManager (LCA, double-präzise), `compose_view_position_m` fokus-relativ | dokumentiert, Identity-Stub aktiv |
| 3 | BubbleActivationSet (ACTIVE / INACTIVE_DISTANT / INACTIVE_NO_LCA), `rebuild()`, `describe()` | dokumentiert, nicht implementiert |
| 4 | LocalOrbitIntegrator (Velocity Verlet), NUMERIC_LOCAL-Regime, Regime-Wechsel-Logging | dokumentiert, nicht implementiert |

## Design-Gate vor Schritt 5

Vor der ersten Mechanik-Implementierung steht ein expliziter Designschritt.
Die folgenden Fragen müssen beantwortet sein, bevor Code geschrieben wird:

1. **BodyType:** Welchen Typ braucht ein steuerbares Objekt? Welche Invarianten trägt der Typ?
2. **Motion Authority:** Wer darf die Position eines CONTROLLED-Bodies schreiben?
   Erweitert OrbitService, oder entsteht ein neuer Layer?
3. **Forces-API:** Wo lebt der Mechanismus, mit dem Schub in die Integration einfließt?
   Wie wird er aufgerufen, von wem, mit welcher Lebensdauer?
4. **Parent-Zugehörigkeit:** Wer darf `parent_id` eines CONTROLLED-Bodies ändern
   (z. B. beim Andocken)? Wie wird das durch OrbitService abgebildet?

Erst wenn diese Fragen explizit beantwortet sind, beginnt Schritt 5.

## Bewusste Nicht-Ziele (diese Phase)

- Kein Multiplayer / keine Server-Architektur
- Keine prozedurale Welt-Generierung
- Keine N-Body-Gravitation (nur Parent-Gravitation)
- Kein Save/Load des Integrator-Zustands
- Keine Oberflächen-/Lande-Mechanik
- Keine Transit-/Clusterlogik
