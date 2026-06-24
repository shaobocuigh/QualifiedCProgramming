#!/usr/bin/env python3
"""Concurrent runner for grouped refinement VC goals.

Spawns one Codex agent per prepared proof group in parallel, then merges
per-group reports. Group partitioning and per-group work directory setup live
in ``prepare_agent_concurrent.py``; each agent sees all goals in its group at
once and follows the vc-checking proof-pattern notes when present.
"""

from __future__ import annotations

import argparse
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from agent_runner import (
    WORKER_MODE_COQC_ONLY,
    WORKER_EXECUTION_MODES,
    build_group_prompt,
    check_codex,
    normalize_worker_execution_mode,
    run_codex_agent,
    suppress_worker_rocq_mcp_config,
    worker_mode_uses_rocq_mcp,
)
from manual_goal_utils import block_has_admitted, lemma_by_name, load_manifest, parse_manual_file
from prepare_agent_concurrent import (
    DEFAULT_CHUNK_SIZE,
    GROUPS_MANIFEST_NAME,
    effective_use_rocq_mcp,
    load_groups_manifest,
    prepare_groups,
)
from apply_partial_proof_packet import apply_partial_proof_packet
from proof_reuse_index import apply_reuse

DEFAULT_TIMEOUT_PER_GOAL = 600  # 10 minutes per assigned goal
DEFAULT_MAX_PARALLEL = 6
REUSE_INDEX_MANIFEST_KEYS = ("proof_reuse_index", "reuse_index")
REUSE_CHECKPOINT_MANIFEST_KEYS = (
    "previous_vc_proving_checkpoint",
    "vc_proving_round_checkpoint",
    "reuse_checkpoint",
)
PARTIAL_PROOF_PACKET_MANIFEST_KEYS = (
    "previous_partial_proof_packet",
    "partial_proof_packet",
)


# ---------------------------------------------------------------------------
# Proof report helpers
# ---------------------------------------------------------------------------

def _find_report_entry(goal_name: str, proof_report: list[dict]) -> dict | None:
    """Find the proof_report.json entry matching a goal name."""
    for entry in proof_report:
        if str(entry.get("goal", "")) == goal_name:
            return entry
    return None


def _quick_status(goal_name: str, proof_report: list[dict]) -> dict:
    """Quick status from proof_report.json (not authoritative — validate_and_merge.py validates).

    Returns {"goal": name, "status": ..., "report": ...}
    """
    entry = _find_report_entry(goal_name, proof_report)
    if entry:
        result = {"goal": goal_name, "status": str(entry.get("status", "unknown"))}
        if entry.get("report"):
            result["report"] = str(entry["report"])
        return result
    return {"goal": goal_name, "status": "no_report"}


def _load_proof_report(work_dir: Path) -> list[dict]:
    """Load proof_report.json from work dir, or empty list if missing."""
    report_path = work_dir / "proof_report.json"
    if not report_path.exists():
        return []
    try:
        data = json.loads(report_path.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except (json.JSONDecodeError, ValueError):
        return []


def _load_strategy_report(work_dir: Path) -> dict | None:
    """Load proof_strategy_report.json from a group work dir, or None if missing."""
    path = work_dir / "proof_strategy_report.json"
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else None
    except (json.JSONDecodeError, ValueError):
        return None


def _merge_proof_reports(group_work_dirs: list[Path], dest: Path) -> list[dict]:
    """Merge per-group proof_report.json files into one at *dest*.

    Returns the merged list. The merged file has the same format as a single
    worker's proof_report.json, so validate_and_merge.py can read it directly
    from the concurrent pipeline output.
    """
    merged: list[dict] = []
    for work_dir in group_work_dirs:
        merged.extend(_load_proof_report(work_dir))
    dest.write_text(json.dumps(merged, indent=2), encoding="utf-8")
    return merged


def _merge_strategy_reports(group_work_dirs: list[Path], dest: Path) -> list[dict]:
    """Merge per-group proof_strategy_report.json files into one at *dest*.

    Returns a list of group strategy reports (each tagged with its group index).
    """
    merged: list[dict] = []
    for i, work_dir in enumerate(group_work_dirs):
        report = _load_strategy_report(work_dir)
        if report is not None:
            merged.append({"group": i, "work_dir": str(work_dir), **report})
    dest.write_text(json.dumps(merged, indent=2), encoding="utf-8")
    return merged


def _manifest_reuse_index(manifest: dict) -> Path | None:
    for key in REUSE_INDEX_MANIFEST_KEYS:
        raw = manifest.get(key)
        if raw:
            return Path(str(raw)).expanduser().resolve()
    return None


def _manifest_reuse_checkpoint(manifest: dict) -> Path | None:
    for key in REUSE_CHECKPOINT_MANIFEST_KEYS:
        raw = manifest.get(key)
        if raw:
            return Path(str(raw)).expanduser().resolve()
    return None


def _manifest_partial_proof_packet(manifest: dict) -> Path | None:
    for key in PARTIAL_PROOF_PACKET_MANIFEST_KEYS:
        raw = manifest.get(key)
        if raw:
            return Path(str(raw)).expanduser().resolve()
    return None


def _reuse_report_entries(manifest: dict | None) -> list[dict]:
    if not manifest:
        return []
    prepass = manifest.get("proof_reuse_prepass")
    source = "proof_reuse_prepass"
    if not isinstance(prepass, dict):
        prepass = manifest.get("partial_proof_packet_prepass")
        source = "partial_proof_packet_prepass"
    if not isinstance(prepass, dict):
        return []
    entries: list[dict] = []
    for item in prepass.get("applied", []):
        if not isinstance(item, dict) or not item.get("lemma_name"):
            continue
        if item.get("status") != "reused_compile_checked":
            continue
        reused_from = item.get("reused_from", {})
        reused_source = reused_from.get("source_manual") if isinstance(reused_from, dict) else None
        entries.append({
            "goal": str(item["lemma_name"]),
            "status": "solved",
            "source": source,
            "report": f"reused proof block from {reused_source}" if reused_source else "reused proof block",
        })
    return entries


def _admitted_target_names(manual_file: Path, candidate_names: list[str]) -> list[str]:
    _prelude, lemmas = parse_manual_file(manual_file.read_text(encoding="utf-8"))
    by_name = lemma_by_name(lemmas)
    remaining: list[str] = []
    for name in candidate_names:
        lemma = by_name.get(name)
        if lemma is not None and block_has_admitted(str(lemma["block"])):
            remaining.append(name)
    return remaining


def apply_reuse_prepass(
    manifest_path: Path,
    lib_file: Path,
    reuse_index_path: Path | None = None,
    *,
    reuse_checkpoint_path: Path | None = None,
    partial_proof_packet_path: Path | None = None,
    checkpoint_reuse_policy: str = "exact_or_pattern",
    frozen_prefix_end_line: int | None = None,
    compile_check: bool = True,
) -> dict | None:
    """Apply checkpoint/packet or reuse-index prepass before worker preparation."""
    manifest = load_manifest(manifest_path)
    reuse_checkpoint_path = reuse_checkpoint_path or _manifest_reuse_checkpoint(manifest)
    partial_proof_packet_path = partial_proof_packet_path or _manifest_partial_proof_packet(manifest)
    if checkpoint_reuse_policy != "disabled" and (
        reuse_checkpoint_path is not None or partial_proof_packet_path is not None
    ):
        report = apply_partial_proof_packet(
            manifest_path=manifest_path,
            lib_file=lib_file,
            checkpoint_path=reuse_checkpoint_path,
            packet_path=partial_proof_packet_path,
            frozen_prefix_end_line=frozen_prefix_end_line,
            reuse_policy=checkpoint_reuse_policy,
            compile_check=compile_check,
        )
        if report.get("kind") == "partial_proof_packet_pattern_reference_report":
            print(
                "Partial proof packet pattern reference: "
                f"{report.get('matched_goal_count', 0)} similar goal(s)"
            )
        else:
            print(
                "Partial proof packet prepass: "
                f"{len(report.get('reused_goal_names', []))} reused, "
                f"{len(report.get('remaining_goal_names', []))} remaining"
            )
        return report

    reuse_index_path = reuse_index_path or _manifest_reuse_index(manifest)
    if reuse_index_path is None:
        return None
    if not compile_check:
        report = {
            "kind": "vc_proof_reuse_apply_report",
            "status": "direct_reuse_disabled_without_compile_check",
            "reuse_index": str(reuse_index_path),
            "compile_check": False,
            "applied_count": 0,
            "applied": [],
            "reused_goal_names": [],
            "remaining_goal_names": [
                str(entry["name"]) for entry in manifest.get("lemmas", [])
                if isinstance(entry, dict) and entry.get("name") is not None
            ],
            "informal_reuse_note": (
                "Direct reuse from reuse_index is disabled when compile_check is false; "
                "run with compile_check enabled or use a checkpoint partial proof packet "
                "as proof-pattern reference."
            ),
        }
        manifest["proof_reuse_prepass"] = report
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        print("Proof reuse prepass skipped: direct reuse requires compile check")
        return report
    reuse_index = json.loads(reuse_index_path.read_text(encoding="utf-8"))
    base_work_dir = Path(str(manifest["work_dir"])).resolve()
    output = base_work_dir / "proof_reuse_candidate_proof_manual.v"
    report_output = base_work_dir / "proof_reuse_apply_report.json"
    report = apply_reuse(
        manifest_path,
        reuse_index,
        output=output,
        report_output=report_output,
        lib_file=str(lib_file),
        frozen_prefix_end_line=frozen_prefix_end_line,
        compile_check=compile_check,
    )

    target_names = [
        str(entry["name"]) for entry in manifest.get("lemmas", [])
        if isinstance(entry, dict) and entry.get("name") is not None
    ]
    remaining = _admitted_target_names(output, target_names)
    applied = [
        item for item in report.get("applied", [])
        if isinstance(item, dict) and item.get("status") == "reused_compile_checked"
    ]

    manifest.setdefault("source_lemma_order", manifest.get("lemma_order", target_names))
    manifest["proof_reuse_prepass"] = {
        "reuse_index": str(reuse_index_path),
        "candidate_manual": str(output),
        "report": str(report_output),
        "compile_check": compile_check,
        "applied_count": len(applied),
        "applied": applied,
        "reused_goal_names": [
            str(item["lemma_name"]) for item in applied
            if isinstance(item, dict) and item.get("lemma_name")
        ],
        "remaining_goal_names": remaining,
        "status": "applied" if applied else "no_reusable_goals",
    }
    if applied:
        remaining_set = set(remaining)
        manifest["source_file"] = str(output)
        manifest["lemmas"] = [
            entry for entry in manifest.get("lemmas", [])
            if isinstance(entry, dict) and str(entry.get("name")) in remaining_set
        ]
        manifest["lemma_order"] = remaining
        manifest["target_lemma_order"] = remaining
        manifest["goal_count"] = len(remaining)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(
        "Proof reuse prepass: "
        f"{len(manifest['proof_reuse_prepass']['reused_goal_names'])} reused, "
        f"{len(remaining)} remaining"
    )
    return manifest["proof_reuse_prepass"]


def _scheduled_group_indices(group_manifests: list[dict], indices: list[int]) -> list[int]:
    """Run harder groups first so slow proof search starts earlier."""
    return sorted(
        indices,
        key=lambda idx: (
            float(group_manifests[idx].get("estimated_difficulty_score", 0.0) or 0.0),
            len(group_manifests[idx].get("goals", [])),
            -idx,
        ),
        reverse=True,
    )


# ---------------------------------------------------------------------------
# Run agents
# ---------------------------------------------------------------------------

def run_agents(
    group_manifests: list[dict],
    max_parallel: int = DEFAULT_MAX_PARALLEL,
    timeout: int | None = None,
    timeout_per_goal: int = DEFAULT_TIMEOUT_PER_GOAL,
    only_groups: list[int] | None = None,
    use_rocq_mcp: bool = False,
) -> dict[int, int]:
    """Spawn one Codex agent per prepared group in parallel.

    Parameters
    ----------
    only_groups : list[int] | None
        If provided, only spawn agents for these group indices. Default is
        all groups.

    Returns a dict mapping group_idx -> exit_code.
    """
    agent_results: dict[int, int] = {}

    if only_groups is None:
        target_indices = list(range(len(group_manifests)))
    else:
        target_indices = sorted(set(only_groups))
        for idx in target_indices:
            if not (0 <= idx < len(group_manifests)):
                raise SystemExit(
                    f"Invalid group index {idx}: must be in 0..{len(group_manifests) - 1}"
                )

    target_indices = _scheduled_group_indices(group_manifests, target_indices)
    if not target_indices:
        print("\n=== No worker groups to solve ===")
        return agent_results

    codex = check_codex()

    def _run_group(group_idx: int) -> tuple[int, int]:
        gm = group_manifests[group_idx]
        work_dir = Path(gm["work_dir"])
        goal_files = [Path(str(e["split_rocq_file"])).name for e in gm["goals"]]
        worker_execution_mode = normalize_worker_execution_mode(
            gm.get("worker_execution_mode"),
            use_rocq_mcp=gm.get("use_rocq_mcp", True),
        )
        group_use_rocq_mcp = worker_mode_uses_rocq_mcp(worker_execution_mode)
        if not group_use_rocq_mcp:
            suppress_worker_rocq_mcp_config(work_dir)
        worker_manual_raw = gm.get("worker_manual_file")
        worker_helper_raw = gm.get("worker_helper_scratch_lib_file")
        worker_manual = Path(str(worker_manual_raw)).name if worker_manual_raw else None
        worker_helper_scratch_lib = None
        if worker_helper_raw:
            worker_helper_path = Path(str(worker_helper_raw))
            try:
                worker_helper_scratch_lib = str(worker_helper_path.resolve().relative_to(work_dir.resolve()))
            except ValueError:
                worker_helper_scratch_lib = worker_helper_path.name
        proof_group_id = str(gm.get("proof_group_id", f"group_{group_idx:02d}"))
        prompt = build_group_prompt(
            goal_files,
            worker_manual,
            worker_helper_scratch_lib,
            proof_group_id,
            use_rocq_mcp=group_use_rocq_mcp,
        )
        if timeout is not None:
            agent_timeout = timeout
        else:
            agent_timeout = timeout_per_goal * len(gm["goals"])
        exit_code = run_codex_agent(
            work_dir,
            prompt,
            agent_timeout,
            codex=codex,
            use_rocq_mcp=group_use_rocq_mcp,
        )
        return group_idx, exit_code

    if only_groups is None:
        print(f"\n=== Solving all {len(target_indices)} group(s) (max_parallel={max_parallel}) ===")
    else:
        print(f"\n=== Solving groups {target_indices} (max_parallel={max_parallel}) ===")
    with ThreadPoolExecutor(max_workers=max_parallel) as pool:
        futures = {
            pool.submit(_run_group, i): i
            for i in target_indices
        }
        for future in as_completed(futures):
            group_idx, exit_code = future.result()
            agent_results[group_idx] = exit_code
            status = "OK" if exit_code == 0 else f"FAIL (exit {exit_code})"
            print(f"  Group {group_idx}: {status}")

    return agent_results


# ---------------------------------------------------------------------------
# Finalize (merge reports and summarize)
# ---------------------------------------------------------------------------

def finalize(
    group_manifests: list[dict],
    base_work_dir: Path,
    manifest_path: Path | None = None,
) -> dict:
    """Merge per-group reports and print a summary.

    Returns ``{"status_counts": ..., "groups": ...}``.
    """
    group_work_dirs = [Path(gm["work_dir"]) for gm in group_manifests]
    merged_report_path = base_work_dir / "proof_report.json"
    merged_report = _merge_proof_reports(group_work_dirs, merged_report_path)
    manifest = load_manifest(manifest_path) if manifest_path is not None and manifest_path.is_file() else None
    reuse_entries = _reuse_report_entries(manifest)
    if reuse_entries:
        merged_report = reuse_entries + merged_report
        merged_report_path.write_text(json.dumps(merged_report, indent=2), encoding="utf-8")
    print(f"Merged proof_report.json written to {merged_report_path}")

    merged_strategy_path = base_work_dir / "proof_strategy_report.json"
    merged_strategies = _merge_strategy_reports(group_work_dirs, merged_strategy_path)
    print(f"Merged proof_strategy_report.json written to {merged_strategy_path}"
          f" ({len(merged_strategies)} group(s) reported)")

    print("\n=== Agent Reports (from proof_report.json) ===")
    summary: dict[str, list[dict]] = {}
    status_counts: dict[str, int] = {}

    for i, gm in enumerate(group_manifests):
        group_results = []
        for entry in gm["goals"]:
            name = str(entry["name"])
            result = _quick_status(name, merged_report)
            group_results.append(result)
            s = result["status"]
            status_counts[s] = status_counts.get(s, 0) + 1

        summary[f"group_{i}"] = group_results

        print(f"\n  Group {i}:")
        for r in group_results:
            status_str = r["status"]
            if r.get("report"):
                status_str += f" — {r['report']}"
            print(f"    {r['goal']}: {status_str}")

    if reuse_entries:
        summary["proof_reuse_prepass"] = reuse_entries
        print("\n  Proof reuse prepass:")
        for r in reuse_entries:
            s = r["status"]
            status_counts[s] = status_counts.get(s, 0) + 1
            print(f"    {r['goal']}: {s} — {r.get('report', 'reused proof block')}")

    print(f"\n=== Quick Summary (agent-reported, not yet validated) ===")
    for s, count in sorted(status_counts.items()):
        print(f"  {s}: {count}")
    print(f"  total: {sum(status_counts.values())}")
    print(f"\nRun validate_and_merge.py for authoritative validation.")

    summary_path = base_work_dir / "concurrent_summary.json"
    summary_path.write_text(json.dumps({
        "status_counts": status_counts,
        "groups": summary,
    }, indent=2), encoding="utf-8")

    return {"status_counts": status_counts, "groups": summary}


# ---------------------------------------------------------------------------
# Full pipeline (default: prepare + run + finalize)
# ---------------------------------------------------------------------------

def run_concurrent(
    manifest_path: Path,
    lib_file: Path,
    max_parallel: int = DEFAULT_MAX_PARALLEL,
    chunk_size: int = DEFAULT_CHUNK_SIZE,
    timeout: int | None = None,
    timeout_per_goal: int = DEFAULT_TIMEOUT_PER_GOAL,
    use_rocq_mcp: bool = True,
    worker_execution_mode: str | None = None,
    group_plan_path: Path | None = None,
    task_local_logical_module: str | None = None,
    reuse_index_path: Path | None = None,
    reuse_checkpoint_path: Path | None = None,
    partial_proof_packet_path: Path | None = None,
    checkpoint_reuse_policy: str = "exact_or_pattern",
    reuse_frozen_prefix_end_line: int | None = None,
    reuse_compile_check: bool = True,
) -> dict:
    """Run the full prepare + agents + finalize pipeline.

    Convenience wrapper. For more control, call ``prepare_groups``,
    ``run_agents``, and ``finalize`` separately.
    """
    manifest = load_manifest(manifest_path)
    base_work_dir = Path(str(manifest["work_dir"])).resolve()
    apply_reuse_prepass(
        manifest_path=manifest_path,
        lib_file=lib_file,
        reuse_index_path=reuse_index_path,
        reuse_checkpoint_path=reuse_checkpoint_path,
        partial_proof_packet_path=partial_proof_packet_path,
        checkpoint_reuse_policy=checkpoint_reuse_policy,
        frozen_prefix_end_line=reuse_frozen_prefix_end_line,
        compile_check=reuse_compile_check,
    )

    group_manifests = prepare_groups(
        manifest_path=manifest_path,
        lib_file=lib_file,
        chunk_size=chunk_size,
        use_rocq_mcp=use_rocq_mcp,
        worker_execution_mode=worker_execution_mode,
        group_plan_path=group_plan_path,
        task_local_logical_module=task_local_logical_module,
    )
    run_agents(
        group_manifests=group_manifests,
        max_parallel=max_parallel,
        timeout=timeout,
        timeout_per_goal=timeout_per_goal,
        use_rocq_mcp=use_rocq_mcp,
    )
    return finalize(group_manifests, base_work_dir, manifest_path=manifest_path)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Adaptive concurrent runner for refinement VC goals. "
                    "By default runs prepare + agents + finalize. Use --skip-prepare "
                    "to load groups_manifest.json from a prior prepare_agent_concurrent.py "
                    "run and skip straight to the agent run + finalize."
    )
    parser.add_argument("manifest", help="Path to manifest.json (after split_manual_goals.py)")
    parser.add_argument("task_local_scratch_lib", nargs="?", default=None,
                        help="Path to task_local_scratch_lib. Required unless --skip-prepare is set.")
    parser.add_argument("--max-parallel", type=int, default=DEFAULT_MAX_PARALLEL,
                        help=f"Max concurrent agents (default: {DEFAULT_MAX_PARALLEL})")
    parser.add_argument("--chunk-size", type=int, default=DEFAULT_CHUNK_SIZE,
                        help=f"Fallback goal group size (default: {DEFAULT_CHUNK_SIZE})")
    parser.add_argument("--group-plan", default=None,
                        help="JSON proof group plan produced by vc-checking. Ignored with "
                             "--skip-prepare.")
    parser.add_argument("--task-local-module", default=None,
                        help="Explicit canonical logical module that maps to "
                             "task_local_scratch_lib during prepare. Ignored with "
                             "--skip-prepare.")
    parser.add_argument("--worker-execution-mode", default=None,
                        choices=sorted(WORKER_EXECUTION_MODES),
                        help="Explicit worker tooling mode. Overrides --no-rocq-mcp "
                             "and the manifest worker_execution_mode, during prepare "
                             "or a --skip-prepare resume (the Windows guard still "
                             "forces coqc/coqtop).")
    parser.add_argument("--reuse-index", default=None,
                        help="Optional proof reuse index JSON. If omitted, manifest "
                             "proof_reuse_index/reuse_index is used when present.")
    parser.add_argument("--reuse-checkpoint", default=None,
                        help="Optional vc_proving_round_checkpoint.json. If omitted, "
                             "manifest previous_vc_proving_checkpoint/reuse_checkpoint "
                             "is used when present.")
    parser.add_argument("--partial-proof-packet", default=None,
                        help="Optional partial_proof_packet.json. Normally resolved "
                             "through --reuse-checkpoint.")
    parser.add_argument("--checkpoint-reuse-policy", default="exact_or_pattern",
                        choices=[
                            "exact",
                            "extended_candidate",
                            "exact_or_pattern",
                            "pattern_reference",
                            "disabled",
                        ],
                        help="Policy for applying checkpoint partial proof packets.")
    parser.add_argument("--reuse-lib-frozen-prefix-end-line", type=int, default=None,
                        help="Frozen prefix end line for proof reuse context hashing.")
    parser.add_argument("--no-reuse-compile-check", action="store_true",
                        help="Do not direct-reuse proof scripts. Checkpoint packets are "
                             "downgraded to proof-pattern references, and reuse_index "
                             "direct reuse is skipped.")
    parser.add_argument("--timeout", type=int, default=None,
                        help="Per-group timeout in seconds. If unset, computed as "
                             "--timeout-per-goal * group size.")
    parser.add_argument("--timeout-per-goal", type=int, default=DEFAULT_TIMEOUT_PER_GOAL,
                        help=f"Used when --timeout is unset to compute per-group timeout "
                             f"(default: {DEFAULT_TIMEOUT_PER_GOAL}s).")
    parser.add_argument("--skip-prepare", action="store_true",
                        help="Skip preparation; load groups_manifest.json written by a "
                             "prior prepare_agent_concurrent.py run, spawn agents, and finalize.")
    parser.add_argument("--skip-finalize", action="store_true",
                        help="Skip report merge and summary.")
    parser.add_argument("--use-rocq-mcp", action="store_true",
                        help="Opt in to rocq-mcp config. Do not use on Windows proof runs.")
    parser.add_argument("--no-rocq-mcp", action="store_true",
                        help="Deprecated no-op: coqc/coqtop mode is the default.")
    parser.add_argument("--groups", type=int, nargs="+", default=None, metavar="IDX",
                        help="Only run agents for these group indices (0-based). "
                             "Default: all groups. Useful with --skip-prepare for "
                             "selective re-runs (e.g. --groups 2 to redo just group 2).")
    args = parser.parse_args()

    manifest_path = Path(args.manifest).expanduser().resolve()
    manifest = load_manifest(manifest_path)
    base_work_dir = Path(str(manifest["work_dir"])).resolve()

    # --- Prepare phase ---
    if args.skip_prepare:
        group_manifests = load_groups_manifest(base_work_dir)
        # Resolve each group's worker tooling mode with the same precedence as
        # prepare: an explicit --worker-execution-mode wins, else the group's
        # recorded worker_execution_mode. The previous code ignored both and
        # recomputed from --use-rocq-mcp (a store_true defaulting to False), so a
        # bare --skip-prepare silently rewrote every prepared rocq_mcp group to
        # coqc_only (and renamed each worker .codex/config.toml), discarding a mode
        # prepare deliberately recorded. Downgrade to coqc_only only for a real
        # reason: the Windows guard (effective_use_rocq_mcp -> False on nt, which
        # wins over everything since rocq-mcp is unavailable there), or an explicit
        # --no-rocq-mcp when no --worker-execution-mode overrides it (mirrors
        # prepare, where --worker-execution-mode overrides --no-rocq-mcp).
        explicit_mode = args.worker_execution_mode
        for gm in group_manifests:
            mode = normalize_worker_execution_mode(
                explicit_mode or gm.get("worker_execution_mode"),
                use_rocq_mcp=gm.get("use_rocq_mcp", True),
            )
            wants_rocq_mcp = worker_mode_uses_rocq_mcp(mode)
            if not effective_use_rocq_mcp(wants_rocq_mcp) or (
                args.no_rocq_mcp and explicit_mode is None
            ):
                gm["worker_execution_mode"] = WORKER_MODE_COQC_ONLY
                gm["use_rocq_mcp"] = False
            elif explicit_mode is not None:
                gm["worker_execution_mode"] = mode
                gm["use_rocq_mcp"] = wants_rocq_mcp
        print(f"Loaded {len(group_manifests)} group manifest(s) from "
              f"{base_work_dir / GROUPS_MANIFEST_NAME}")
    else:
        if args.task_local_scratch_lib is None:
            raise SystemExit("task_local_scratch_lib is required for the prepare phase")
        lib_file = Path(args.task_local_scratch_lib).expanduser().resolve()
        if not lib_file.is_file():
            raise SystemExit(f"task_local_scratch_lib file not found: {lib_file}")
        apply_reuse_prepass(
            manifest_path=manifest_path,
            lib_file=lib_file,
            reuse_index_path=Path(args.reuse_index).expanduser().resolve()
            if args.reuse_index else None,
            reuse_checkpoint_path=Path(args.reuse_checkpoint).expanduser().resolve()
            if args.reuse_checkpoint else None,
            partial_proof_packet_path=Path(args.partial_proof_packet).expanduser().resolve()
            if args.partial_proof_packet else None,
            checkpoint_reuse_policy=args.checkpoint_reuse_policy,
            frozen_prefix_end_line=args.reuse_lib_frozen_prefix_end_line,
            compile_check=not args.no_reuse_compile_check,
        )
        group_manifests = prepare_groups(
            manifest_path=manifest_path,
            lib_file=lib_file,
            chunk_size=args.chunk_size,
            use_rocq_mcp=not args.no_rocq_mcp,
            worker_execution_mode=args.worker_execution_mode,
            group_plan_path=Path(args.group_plan).expanduser() if args.group_plan else None,
            task_local_logical_module=args.task_local_module,
        )

    # --- Agent run phase ---
    agent_results = run_agents(
        group_manifests=group_manifests,
        max_parallel=args.max_parallel,
        timeout=args.timeout,
        timeout_per_goal=args.timeout_per_goal,
        only_groups=args.groups,
        use_rocq_mcp=effective_use_rocq_mcp(args.use_rocq_mcp and not args.no_rocq_mcp),
    )
    any_agent_failed = any(code != 0 for code in agent_results.values())

    # --- Finalize phase ---
    if args.skip_finalize:
        print("\n--skip-finalize: skipping copy-back and merge.")
        return 1 if any_agent_failed else 0

    if args.groups is not None:
        print(
            "\n--groups was set, so this is a partial run. Skipping finalize to avoid "
            "mixing stale and fresh per-group reports.\n"
            "Re-run without --groups (or with --skip-prepare and no --groups) to finalize "
            "once all groups are up to date."
        )
        return 1 if any_agent_failed else 0

    result = finalize(group_manifests, base_work_dir, manifest_path=manifest_path)
    counts = result["status_counts"]
    if any_agent_failed:
        return 1
    if counts.get("solved", 0) == sum(counts.values()):
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
