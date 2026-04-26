#!/usr/bin/env python3
"""Analyze Graviton PerfProbe CSV/JSON dump pairs.

The script intentionally reads finished dump artifacts only. It does not
connect to Godot and does not know simulation state beyond the JSON sidecar.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable


APP_NAME = "Graviton"
CSV_GLOB = "perf_probe_*.csv"
INCLUSIVE_EXPLAIN_US = "time_tick_emit_total_us"
FALLBACK_EXPLAIN_US = (
    "orbit_step_core_total_us",
    "asteroid_advance_total_us",
    "derived_snapshot_refresh_total_us",
)
COMPONENT_US = (
    "time_tick_emit_total_us",
    "orbit_step_core_total_us",
    "asteroid_advance_total_us",
    "derived_snapshot_refresh_total_us",
)


@dataclass(frozen=True)
class DumpPair:
    csv_path: Path
    json_path: Path
    modified_time: float


@dataclass
class ScenarioRows:
    scenario: str
    dumps: list[DumpPair]
    physics_ms: list[float]
    explained_ms: list[float]
    residual_ms: list[float]
    components_ms_by_name: dict[str, list[float]]
    explainable_rows: int
    explained_sources: set[str]


def main() -> int:
    args = _parse_args()
    dump_dir = Path(args.dump_dir) if args.dump_dir else default_dump_dir()
    pairs = discover_dump_pairs(dump_dir)
    if args.limit > 0:
        pairs = pairs[: args.limit]
    if not pairs:
        print(f"No paired {CSV_GLOB}/.json dumps found under {dump_dir}")
        return 1

    scenarios = group_pairs_by_scenario(pairs)
    print(f"PerfProbe analysis: {len(pairs)} dump pair(s), {len(scenarios)} scenario(s)")
    print(f"Dump dir: {dump_dir}")
    print(
        "Note: component *_total_us columns can be nested; explained_ms uses "
        f"{INCLUSIVE_EXPLAIN_US} when present to avoid double counting."
    )
    for scenario_rows in sorted(scenarios.values(), key=_latest_modified_time, reverse=True):
        print_scenario(scenario_rows)
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyze latest Graviton perf_probe_*.csv/.json pairs."
    )
    parser.add_argument(
        "--dump-dir",
        default="",
        help="Directory containing perf_probe_*.csv/.json pairs. Defaults to Godot user data.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=8,
        help="Newest dump pairs to include. Use 0 for all pairs. Default: 8.",
    )
    return parser.parse_args()


def default_dump_dir() -> Path:
    appdata = os.environ.get("APPDATA", "")
    if appdata:
        return Path(appdata) / "Godot" / "app_userdata" / APP_NAME

    home = Path.home()
    candidates = [
        home / "AppData" / "Roaming" / "Godot" / "app_userdata" / APP_NAME,
        home / "Library" / "Application Support" / "Godot" / "app_userdata" / APP_NAME,
        home / ".local" / "share" / "godot" / "app_userdata" / APP_NAME,
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[-1]


def discover_dump_pairs(dump_dir: Path) -> list[DumpPair]:
    if not dump_dir.exists():
        return []
    pairs: list[DumpPair] = []
    for csv_path in dump_dir.glob(CSV_GLOB):
        json_path = csv_path.with_suffix(".json")
        if not json_path.exists():
            continue
        modified_time = max(csv_path.stat().st_mtime, json_path.stat().st_mtime)
        pairs.append(DumpPair(csv_path=csv_path, json_path=json_path, modified_time=modified_time))
    pairs.sort(key=lambda pair: pair.modified_time, reverse=True)
    return pairs


def group_pairs_by_scenario(pairs: Iterable[DumpPair]) -> dict[str, ScenarioRows]:
    scenarios: dict[str, ScenarioRows] = {}
    for pair in pairs:
        sidecar = read_json(pair.json_path)
        scenario = scenario_label(sidecar, pair.csv_path)
        rows, fieldnames = read_csv_rows(pair.csv_path)
        explained_source = explain_source(fieldnames)
        bucket = scenarios.get(scenario)
        if bucket is None:
            bucket = ScenarioRows(
                scenario=scenario,
                dumps=[],
                physics_ms=[],
                explained_ms=[],
                residual_ms=[],
                components_ms_by_name={name: [] for name in COMPONENT_US},
                explainable_rows=0,
                explained_sources=set(),
            )
            scenarios[scenario] = bucket
        bucket.dumps.append(pair)
        bucket.explained_sources.add(explained_source)
        if explained_source != "none":
            bucket.explainable_rows += len(rows)
        for row in rows:
            physics_ms = float_value(row.get("physics_ms", "0"))
            explained_ms = explained_physics_ms(row, fieldnames)
            bucket.physics_ms.append(physics_ms)
            bucket.explained_ms.append(explained_ms)
            bucket.residual_ms.append(physics_ms - explained_ms)
            for component in COMPONENT_US:
                if component in fieldnames:
                    bucket.components_ms_by_name[component].append(us_to_ms(float_value(row.get(component, "0"))))
    return scenarios


def read_json(path: Path) -> dict:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
            return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def read_csv_rows(path: Path) -> tuple[list[dict[str, str]], set[str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = [dict(row) for row in reader]
        return rows, set(reader.fieldnames or [])


def scenario_label(sidecar: dict, csv_path: Path) -> str:
    scene = dict_value(sidecar.get("scene"))
    focus = dict_value(sidecar.get("focus"))
    camera = dict_value(sidecar.get("camera"))
    ui = dict_value(sidecar.get("ui"))
    root_inspector = dict_value(ui.get("root_inspector"))

    world = str(scene.get("active_world_scope_id") or scene.get("initial_world_id") or "?")
    focus_id = str(focus.get("id") or "?")
    focus_kind = str(focus.get("kind") or "?")
    frame = str(camera.get("frame_label") or scene.get("last_frame_label") or "?")
    inspector_open = bool(root_inspector.get("is_open", False))
    if world == "?" and focus_id == "?":
        return csv_path.stem
    inspector = "open" if inspector_open else "closed"
    return f"world={world} focus={focus_id}({focus_kind}) frame={frame} inspector={inspector}"


def dict_value(value) -> dict:
    return value if isinstance(value, dict) else {}


def explain_source(fieldnames: set[str]) -> str:
    if INCLUSIVE_EXPLAIN_US in fieldnames:
        return INCLUSIVE_EXPLAIN_US
    for column in FALLBACK_EXPLAIN_US:
        if column in fieldnames:
            return "fallback_stage_sum"
    return "none"


def explained_physics_ms(row: dict[str, str], fieldnames: set[str]) -> float:
    if INCLUSIVE_EXPLAIN_US in fieldnames:
        return us_to_ms(float_value(row.get(INCLUSIVE_EXPLAIN_US, "0")))
    return sum(
        us_to_ms(float_value(row.get(column, "0")))
        for column in FALLBACK_EXPLAIN_US
        if column in fieldnames
    )


def us_to_ms(value: float) -> float:
    return value / 1000.0


def float_value(value: str | None) -> float:
    if value is None or value == "":
        return 0.0
    try:
        return float(value)
    except ValueError:
        return 0.0


def print_scenario(rows: ScenarioRows) -> None:
    physics = stats(rows.physics_ms)
    explained = stats(rows.explained_ms)
    residual = stats(rows.residual_ms)
    coverage = 0.0
    physics_sum = sum(rows.physics_ms)
    if physics_sum > 0.0:
        coverage = sum(rows.explained_ms) / physics_sum * 100.0

    latest = max(rows.dumps, key=lambda pair: pair.modified_time)
    latest_time = datetime.fromtimestamp(latest.modified_time).isoformat(timespec="seconds")
    source_label = ",".join(sorted(rows.explained_sources))
    print("")
    print(rows.scenario)
    print(
        f"  dumps={len(rows.dumps)} rows={len(rows.physics_ms)} "
        f"explainable_rows={rows.explainable_rows} "
        f"latest={latest.csv_path.name} modified={latest_time}"
    )
    print(
        "  physics_ms      "
        f"p50={physics['p50']:.3f} p95={physics['p95']:.3f} max={physics['max']:.3f}"
    )
    print(
        f"  explained_ms    source={source_label} "
        f"p50={explained['p50']:.3f} p95={explained['p95']:.3f} "
        f"max={explained['max']:.3f} coverage={coverage:.1f}%"
    )
    print(
        "  residual_ms     "
        f"p50={residual['p50']:.3f} p95={residual['p95']:.3f} max={residual['max']:.3f}"
    )
    component_parts: list[str] = []
    for name, values in rows.components_ms_by_name.items():
        if not values:
            continue
        component_parts.append(f"{name} p95={stats(values)['p95']:.3f}")
    if component_parts:
        print("  component p95   " + "; ".join(component_parts))


def stats(values: list[float]) -> dict[str, float]:
    if not values:
        return {"p50": 0.0, "p95": 0.0, "max": 0.0}
    return {
        "p50": percentile(values, 50.0),
        "p95": percentile(values, 95.0),
        "max": max(values),
    }


def percentile(values: list[float], percentile_value: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    rank = max(1, math.ceil(percentile_value / 100.0 * len(ordered)))
    return ordered[min(rank - 1, len(ordered) - 1)]


def _latest_modified_time(rows: ScenarioRows) -> float:
    return max(pair.modified_time for pair in rows.dumps)


if __name__ == "__main__":
    raise SystemExit(main())
