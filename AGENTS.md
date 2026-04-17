# Graviton Agent Guide

Dieses Repository soll fuer Menschen und KI-Agenten mit moeglichst wenig
Prompt-Kontext verstaendlich bleiben.

## Lies das zuerst

1. `docs/STATUS.md`
2. `docs/NEXT_STEPS.md`
3. `docs/DECISIONS.md`
4. `docs/ARCHITEKTUR.md`

Wenn sich Dokumente widersprechen, gilt diese Reihenfolge:

`STATUS.md` > `NEXT_STEPS.md` > `DECISIONS.md` > historische Detaildokumente

## Projektprinzipien

- Daten und Simulationszustand sind die Wahrheit.
- View- und Szene-Code ist nur Projektion, nie Simulationsquelle.
- Schichten bleiben strikt: `core/` -> `sim/` -> `runtime/` -> `scenes/`
- Neue Features duerfen die Simulationsarchitektur nicht durch
  pragmatische View-Abkuerzungen aushoehlen.

## Arbeitsweise fuer Agenten

- Vor einer groesseren Aenderung: erst `STATUS.md` und `NEXT_STEPS.md`
  lesen, damit der aktuelle Fokus klar ist.
- Bei Architekturfragen: `ARCHITEKTUR.md` ist normativ.
- Alte Dokumente wie `HANDOFF.md` oder `AI_KONTEXT.md` koennen
  historische Formulierungen enthalten. Nutze sie als Hintergrund, aber
  nicht als hoechste Wahrheit, wenn `STATUS.md` neuer ist.

## Dokumentationspflege

Nach jeder relevanten Repo-Aenderung:

- `docs/STATUS.md` aktualisieren:
  Was wurde geaendert? Warum? Was ist der aktuelle sichtbare Effekt?
- `docs/NEXT_STEPS.md` aktualisieren:
  Was ist jetzt der naechste sinnvolle Arbeitsblock?
- `docs/DECISIONS.md` aktualisieren:
  Nur wenn eine echte Entscheidung oder Richtungsfestlegung getroffen wurde.

## Nicht tun

- Keine Simulationslogik in `scenes/` oder `src/tools/` verstecken.
- Keine neue globale Wahrheit ausser den bewusst definierten Autoloads.
- Keine "schnellen" Workarounds einbauen, die spaeter die Architektur
  unklar machen.
