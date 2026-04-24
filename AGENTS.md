# Graviton Agent Guide

Dieses Repository soll fuer Menschen, Codex und Claude Code mit
moeglichst wenig Prompt-Kontext verstaendlich bleiben.

## Lies das zuerst

1. `docs/STATUS.md`
2. `docs/NEXT_STEPS.md`
3. `docs/DECISIONS.md`
4. `docs/ARCHITEKTUR.md`
5. `README.md`

Wenn sich Dokumente widersprechen, gilt:

- `docs/ARCHITEKTUR.md` ist normativ fuer Architekturregeln,
  Schichten, Autoritaeten und Autoloads.
- `docs/STATUS.md` beschreibt den aktuellen Repo-Zustand.
- `docs/NEXT_STEPS.md` beschreibt den naechsten Arbeitsblock.
- `docs/DECISIONS.md` haelt Richtungsentscheidungen fest.
- Historische Dokumente wie `docs/HANDOFF.md`,
  `docs/AI_KONTEXT.md` oder `docs/GODOT_UMSETZUNGSPLAN.md` sind nur
  Hintergrund.

## Agentenrollen

- Codex ist primaerer Planungs- und Umsetzungsagent.
- Claude Code ist primaer Review-/Evaluationsinstanz. Wenn Claude Code
  implementiert, gelten dieselben Repo-Regeln.
- Der Nutzer ist Entscheider und Commit-Freigeber.
- Kein Agent erweitert still den Scope, deutet Architekturregeln um oder
  startet neue Grossbaustellen.

## Projektprinzipien

- Daten und Simulationszustand sind die Wahrheit.
- View-, Tool- und Szene-Code ist Projektion, nie Simulationsquelle.
- Schichten bleiben strikt: `core/` -> `sim/` -> `runtime/` -> `scenes/`.
- `src/tools/` ist Hilfs-/Debug-/Rendering-Code und keine
  Simulationsschicht.
- Neue Features duerfen die Simulationsarchitektur nicht durch
  pragmatische View-Abkuerzungen aushoehlen.
- Projektname ist `Graviton`; neue Dateien sollen keine alten
  `Atraxis`-Altlasten einfuehren.

## Startprotokoll

Vor nicht trivialen Aenderungen:

- `git status --short` pruefen.
- `AGENTS.md` und die kanonischen Dokumente in der Reihenfolge oben
  lesen.
- Den aktiven Fokus aus `docs/NEXT_STEPS.md` identifizieren.
- Bestehende uncommitted Aenderungen nicht ueberschreiben oder
  zuruecksetzen.
- Kurz nennen:
  Ziel, Annahmen, betroffene Schichten (`core`, `sim`, `runtime`,
  `scenes`, `tools`, `docs`), Risiken und Validierungspfad.
- Bei Architektur-, Layer- oder Autoritaetsfragen zusaetzlich
  `docs/ARCHITEKTUR.md` und relevante Eintraege in
  `docs/DECISIONS.md` pruefen. Wenn ein Plan widerspricht: vor Code
  stoppen.

## Arbeitsweise

- Kleine saubere Slices bevorzugen, keine breiten Rewrites.
- Neue Arbeit am aktuellen Fokus aus `docs/NEXT_STEPS.md` ausrichten.
- Keine Simulationslogik in `scenes/` oder `src/tools/` verstecken.
- Keine zweite Wahrheit fuer Werte einfuehren, die bereits aus einem
  Service, Snapshot oder Body-State kommen.
- Debug-/Perf-Instrumentation darf die Schichten nicht umdrehen:
  `sim/` darf nicht von `src/tools/`, `scenes/` oder View-Code
  abhaengen. Sim-Code exponiert hoechstens read-only Counter, Signale
  oder Snapshots; Sampling und Dumping leben ausserhalb von `sim/`.
- Wenn ein Bugfix festfaehrt: Diagnose statt blindes Patchen
  (Reproduktion, wahrscheinlichste Ursache, kleinster Fix).

## Tooling und Sprache

- Lokale Shell ist Windows/PowerShell. Fuer normale Repo-Arbeit
  PowerShell oder CMD verwenden, nicht Bash/MSYS.
- Bevorzugter Testpfad ist `run_tests.bat`.
- `run_tests.bat` nutzt `GODOT_BIN`, falls gesetzt, sonst
  `godot_console.exe` aus `PATH`.
- Doku und Antworten sind Deutsch, Code-Identifier Englisch,
  Commit-Messages Englisch. Bestehende ASCII-Schreibweise wie
  `fuer`, `Aenderung`, `Schichten` beibehalten.

## Validierung

Nach Codeaenderungen:

- Relevante gezielte Tests ausfuehren.
- Wenn der Slice headless sinnvoll pruefbar ist, `run_tests.bat`
  verwenden.
- Wenn ein Editor-/Playtest-Gate noetig ist, den Pfad explizit nennen
  und soweit realistisch validieren.
- Keine Testergebnisse, Repo-Fakten oder ausgefuehrten Schritte
  erfinden.
- Wenn nicht validiert wurde, praezise sagen warum.

## Dokumentationspflege

Nach jeder relevanten Repo-Aenderung:

- `docs/STATUS.md` aktualisieren:
  Was wurde geaendert? Warum? Was ist der aktuelle sichtbare Effekt?
- `docs/NEXT_STEPS.md` aktualisieren:
  Was ist jetzt der naechste sinnvolle Arbeitsblock oder welches Gate
  bleibt offen?
- `docs/DECISIONS.md` aktualisieren:
  Nur wenn eine echte Entscheidung oder Richtungsfestlegung getroffen
  wurde.
- `docs/ARCHITEKTUR.md` aktualisieren:
  Wenn Schichtregeln, Autoritaeten, Service-Verantwortungen oder
  Autoload-Regeln betroffen sind.
- Wenn Code geaendert wurde und keine Doku geaendert wurde, am Ende
  begruenden warum keine Doku-Aenderung noetig war.

## Review-Uebergabe

Nach einer Implementierung kurz liefern:

- Ziel des Slices
- geaenderte Dateien
- Architekturannahmen
- Tests / Validierung
- offene Risiken
- konkrete Punkte, die Claude Code kritisch pruefen soll

Claude Code soll besonders pruefen:

- Schichtverletzungen
- versteckte Simulationswahrheit in View-/Tool-/Szenencode
- Doku-Drift zwischen Code, `ARCHITEKTUR.md`, `STATUS.md`,
  `NEXT_STEPS.md` und `DECISIONS.md`
- fehlende Tests oder ungetestete Hotpaths
- zu grosse Scope-Ausweitung

## Abschluss / Commit-Workflow

Ein Agent darf nicht still committen, pushen oder PRs oeffnen, ausser
der Nutzer fordert es ausdruecklich.

Nach jeder Codeaenderung am Ende nennen:

- `git status --short`
- geaenderte Dateien
- Tests / Validierung
- Doku-Sync oder Grund fuer bewusste Nicht-Doku
- bekannte Risiken
- Commit-Vorschlag mit Titel und Beschreibung

Commit-Titel bevorzugt im Conventional-Commit-Stil:

```text
feat(scope): ...
fix(scope): ...
perf(scope): ...
docs(scope): ...
test(scope): ...
refactor(scope): ...
```

Commit-Vorschlag-Format:

```text
Commit-Vorschlag:
type(scope): kurzer titel

Beschreibung:
- wichtigste Aenderung
- Validierung
- Doku-Folge oder bewusste Nicht-Doku
```

Danach fragen, ob Titel und Beschreibung so verwendet werden sollen
oder angepasst werden.

## Nicht tun

- Keine Simulationslogik in `scenes/` oder `src/tools/` verstecken.
- Keine neue globale Wahrheit ausser den bewusst definierten Autoloads.
- Keine Registry-Gottklasse bauen.
- Keine neuen Autoloads ohne ADR in `docs/ARCHITEKTUR.md`.
- Keine "schnellen" Workarounds einbauen, die spaeter die Architektur
  unklar machen.
- Keine Force-Pushes, destruktiven Git-Operationen, Loeschungen von
  Doku oder `.tscn`-Umkonfigurationen ohne ausdrueckliche Freigabe.
