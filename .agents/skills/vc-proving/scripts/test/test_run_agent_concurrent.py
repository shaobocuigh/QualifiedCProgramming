#!/usr/bin/env python3
"""Tests for run_agent_concurrent.py — adaptive concurrent runner."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from unittest.mock import patch

import pytest

from prepare_agent_concurrent import (
    GROUPS_MANIFEST_NAME,
    load_groups_manifest,
    prepare_groups,
)
from agent_runner import (
    WORKER_MODE_COQC_ONLY,
    build_group_prompt as _build_group_prompt,
    normalize_worker_execution_mode,
    run_codex_agent,
)
from run_agent_concurrent import (
    _find_report_entry,
    _load_proof_report,
    _load_strategy_report,
    _merge_proof_reports,
    _merge_strategy_reports,
    _quick_status,
    _scheduled_group_indices,
    apply_reuse_prepass,
    finalize,
    run_agents,
    run_concurrent,
)
from proof_reuse_index import build_index


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture()
def workspace(tmp_path):
    """Set up a minimal workspace with _CoqProject, lib, source, and split goals."""
    (tmp_path / "_CoqProject").write_text("-Q . MyLib\n", encoding="utf-8")

    lib = tmp_path / "foo_rel_lib.v"
    lib.write_text("Definition foo := 1.\n", encoding="utf-8")

    goals_dir = tmp_path / "goals"
    goals_dir.mkdir()
    names = [
        "proof_of_foo_entail_wit_1",
        "proof_of_foo_entail_wit_2",
        "proof_of_foo_return_wit_1",
    ]
    src = tmp_path / "foo_manual.v"
    src.write_text(
        "Require Import MyLib.\n\n"
        + "\n\n".join(
            f"Lemma {name} : True.\nProof. Admitted."
            for name in names
        )
        + "\n",
        encoding="utf-8",
    )
    lemmas = []
    for i, name in enumerate(names, 1):
        f = goals_dir / f"goal_{i:02d}__{name}.v"
        f.write_text(
            f"Require Import MyLib.\nLemma {name} : True.\nProof. Admitted.\n",
            encoding="utf-8",
        )
        lemmas.append({
            "index": i,
            "name": name,
            "split_rocq_file": str(f),
            "statement_header": f"Lemma {name} : True.",
            "original_start_line": i * 10,
            "original_end_line": i * 10 + 5,
        })

    work_dir = tmp_path / "work"
    work_dir.mkdir()

    manifest = {
        "source_file": str(src),
        "work_dir": str(work_dir),
        "goal_count": len(lemmas),
        "lemma_order": [e["name"] for e in lemmas],
        "lemmas": lemmas,
    }
    manifest_path = work_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    return {
        "tmp_path": tmp_path,
        "lib": lib,
        "src": src,
        "goals_dir": goals_dir,
        "work_dir": work_dir,
        "manifest_path": manifest_path,
        "manifest": manifest,
        "lemmas": lemmas,
        "names": names,
    }


# ---------------------------------------------------------------------------
# Prompt building
# ---------------------------------------------------------------------------

class TestBuildGroupPrompt:
    def test_lists_all_goals(self):
        prompt = _build_group_prompt(
            ["goal_01__a.v", "goal_02__b.v"],
            "foo_manual.v",
            "worker_helper_scratch_lib.v",
            "shape_a",
        )
        assert "goal_01__a.v" in prompt
        assert "goal_02__b.v" in prompt
        assert "attempt" not in prompt.lower()
        assert "proof_report.json" in prompt
        assert "proof_strategy_report.json" in prompt
        assert "shape_a" in prompt
        assert "foo_manual.v" in prompt
        assert "worker_helper_scratch_lib.v" in prompt
        assert "manual only" not in prompt.lower()
        assert "compile-only dependencies" in prompt

    def test_mcp_prompt_mentions_coqc_fallback(self):
        prompt = _build_group_prompt(["goal_01__a.v"], use_rocq_mcp=True)
        assert "rocq-mcp" in prompt
        assert "coqc/coqtop" in prompt
        assert "request_user_input is not supported in exec mode" in prompt

    def test_no_mcp_prompt_is_coqc_only(self):
        prompt = _build_group_prompt(["goal_01__a.v"], use_rocq_mcp=False)
        assert "rocq-mcp is disabled" in prompt
        assert "coqc/coqtop" in prompt


class TestWorkerExecutionMode:
    def test_legacy_string_false_maps_to_coqc_only(self):
        assert normalize_worker_execution_mode(use_rocq_mcp="false") == WORKER_MODE_COQC_ONLY


class TestScheduling:
    def test_harder_groups_run_first(self):
        group_manifests = [
            {"goals": [{"name": "easy"}], "estimated_difficulty_score": 1.0},
            {"goals": [{"name": "hard"}], "estimated_difficulty_score": 10.0},
            {"goals": [{"name": "medium"}], "estimated_difficulty_score": 5.0},
        ]
        assert _scheduled_group_indices(group_manifests, [0, 1, 2]) == [1, 2, 0]

    @patch("run_agent_concurrent.check_codex")
    def test_no_groups_skips_codex_lookup(self, mock_check):
        assert run_agents([], max_parallel=2, timeout=60) == {}
        assert mock_check.call_count == 0


class _DummyProcess:
    pid = 12345
    returncode = 0

    def wait(self, timeout=None):
        return 0


class TestRunCodexAgentCommand:
    @patch("agent_runner.subprocess.Popen", return_value=_DummyProcess())
    def test_passes_worker_local_rocq_mcp_config_as_cli_overrides(self, mock_popen, tmp_path):
        config_dir = tmp_path / ".codex"
        config_dir.mkdir()
        (config_dir / "config.toml").write_text(
            '[mcp_servers.rocq-mcp]\n'
            'command = "/usr/local/bin/rocq-mcp"\n'
            f'cwd = "{tmp_path}"\n'
            'startup_timeout_sec = 20\n'
            'tool_timeout_sec = 120\n',
            encoding="utf-8",
        )

        result = run_codex_agent(
            tmp_path,
            "prompt",
            60,
            codex="/usr/bin/codex",
            use_rocq_mcp=True,
        )

        assert result == 0
        cmd = mock_popen.call_args[0][0]
        assert 'mcp_servers.rocq-mcp.command="/usr/local/bin/rocq-mcp"' in cmd
        assert f'mcp_servers.rocq-mcp.cwd="{tmp_path}"' in cmd
        assert "mcp_servers.rocq-mcp.startup_timeout_sec=20" in cmd
        assert "mcp_servers.rocq-mcp.tool_timeout_sec=120" in cmd

    @patch("agent_runner.subprocess.Popen", return_value=_DummyProcess())
    def test_no_rocq_mcp_suppresses_worker_local_config(self, mock_popen, tmp_path):
        config_dir = tmp_path / ".codex"
        config_dir.mkdir()
        (config_dir / "config.toml").write_text(
            '[mcp_servers.rocq-mcp]\n'
            'command = "/usr/local/bin/rocq-mcp"\n'
            f'cwd = "{tmp_path}"\n',
            encoding="utf-8",
        )

        result = run_codex_agent(
            tmp_path,
            "prompt",
            60,
            codex="/usr/bin/codex",
            use_rocq_mcp=False,
        )

        assert result == 0
        cmd = mock_popen.call_args[0][0]
        assert not any("mcp_servers.rocq-mcp" in part for part in cmd)
        assert not (config_dir / "config.toml").exists()
        assert (config_dir / "config.toml.disabled-by-coqc-only").exists()

    @patch("agent_runner.subprocess.Popen", return_value=_DummyProcess())
    def test_worker_execution_mode_overrides_legacy_use_rocq_mcp(self, mock_popen, tmp_path):
        config_dir = tmp_path / ".codex"
        config_dir.mkdir()
        (config_dir / "config.toml").write_text(
            '[mcp_servers.rocq-mcp]\n'
            'command = "/usr/local/bin/rocq-mcp"\n'
            f'cwd = "{tmp_path}"\n',
            encoding="utf-8",
        )

        result = run_codex_agent(
            tmp_path,
            "prompt",
            60,
            codex="/usr/bin/codex",
            use_rocq_mcp=True,
            worker_execution_mode=WORKER_MODE_COQC_ONLY,
        )

        assert result == 0
        cmd = mock_popen.call_args[0][0]
        assert not any("mcp_servers.rocq-mcp" in part for part in cmd)
        assert not (config_dir / "config.toml").exists()
        assert (config_dir / "config.toml.disabled-by-coqc-only").exists()


# ---------------------------------------------------------------------------
# Goal classification helpers
# ---------------------------------------------------------------------------

class TestQuickStatus:
    def test_solved(self):
        report = [{"goal": "foo", "status": "solved"}]
        result = _quick_status("foo", report)
        assert result["status"] == "solved"

    def test_admitted_with_report(self):
        report = [{"goal": "foo", "status": "admitted", "report": "tactic failed"}]
        result = _quick_status("foo", report)
        assert result["status"] == "admitted"
        assert result["report"] == "tactic failed"

    def test_no_report_entry(self):
        result = _quick_status("foo", [])
        assert result["status"] == "no_report"

    def test_find_report_entry(self):
        report = [
            {"goal": "bar", "status": "solved"},
            {"goal": "foo", "status": "admitted", "report": "failed"},
        ]
        entry = _find_report_entry("foo", report)
        assert entry is not None
        assert entry["status"] == "admitted"

    def test_find_report_entry_missing(self):
        assert _find_report_entry("baz", [{"goal": "foo", "status": "solved"}]) is None


# ---------------------------------------------------------------------------
# Proof report loading and merging
# ---------------------------------------------------------------------------

class TestLoadProofReport:
    def test_valid_report(self, tmp_path):
        report = [{"goal": "foo", "status": "solved"}]
        (tmp_path / "proof_report.json").write_text(json.dumps(report))
        assert _load_proof_report(tmp_path) == report

    def test_missing_report(self, tmp_path):
        assert _load_proof_report(tmp_path) == []

    def test_invalid_json(self, tmp_path):
        (tmp_path / "proof_report.json").write_text("not json")
        assert _load_proof_report(tmp_path) == []

    def test_non_array(self, tmp_path):
        (tmp_path / "proof_report.json").write_text('{"goal": "foo"}')
        assert _load_proof_report(tmp_path) == []


class TestMergeProofReports:
    def test_merges_multiple_dirs(self, tmp_path):
        d1 = tmp_path / "group_00"
        d1.mkdir()
        (d1 / "proof_report.json").write_text(
            json.dumps([{"goal": "a", "status": "solved"}])
        )
        d2 = tmp_path / "group_01"
        d2.mkdir()
        (d2 / "proof_report.json").write_text(
            json.dumps([{"goal": "b", "status": "admitted", "report": "failed"}])
        )
        dest = tmp_path / "proof_report.json"
        merged = _merge_proof_reports([d1, d2], dest)
        assert len(merged) == 2
        assert merged[0]["goal"] == "a"
        assert merged[1]["goal"] == "b"
        assert dest.exists()
        written = json.loads(dest.read_text())
        assert len(written) == 2

    def test_missing_report_skipped(self, tmp_path):
        d1 = tmp_path / "group_00"
        d1.mkdir()
        (d1 / "proof_report.json").write_text(
            json.dumps([{"goal": "a", "status": "solved"}])
        )
        d2 = tmp_path / "group_01"
        d2.mkdir()
        dest = tmp_path / "proof_report.json"
        merged = _merge_proof_reports([d1, d2], dest)
        assert len(merged) == 1

    def test_empty_dirs(self, tmp_path):
        dest = tmp_path / "proof_report.json"
        merged = _merge_proof_reports([], dest)
        assert merged == []
        assert json.loads(dest.read_text()) == []


# ---------------------------------------------------------------------------
# Strategy report
# ---------------------------------------------------------------------------

class TestStrategyReports:
    def test_load_valid(self, tmp_path):
        data = {"clusters": [{"name": "A", "representative": "x", "members": ["x"]}]}
        (tmp_path / "proof_strategy_report.json").write_text(json.dumps(data))
        assert _load_strategy_report(tmp_path) == data

    def test_load_missing_returns_none(self, tmp_path):
        assert _load_strategy_report(tmp_path) is None

    def test_load_non_object_returns_none(self, tmp_path):
        (tmp_path / "proof_strategy_report.json").write_text(json.dumps([1, 2]))
        assert _load_strategy_report(tmp_path) is None

    def test_merge_tags_with_group_index(self, tmp_path):
        d1 = tmp_path / "group_00"
        d1.mkdir()
        (d1 / "proof_strategy_report.json").write_text(
            json.dumps({"clusters": [{"name": "A"}], "notes": "d1"})
        )
        d2 = tmp_path / "group_01"
        d2.mkdir()
        # No strategy report in d2 — should be skipped
        d3 = tmp_path / "group_02"
        d3.mkdir()
        (d3 / "proof_strategy_report.json").write_text(
            json.dumps({"clusters": [{"name": "B"}], "notes": "d3"})
        )
        dest = tmp_path / "proof_strategy_report.json"
        merged = _merge_strategy_reports([d1, d2, d3], dest)
        assert len(merged) == 2
        assert merged[0]["group"] == 0
        assert merged[0]["notes"] == "d1"
        assert merged[1]["group"] == 2
        assert merged[1]["notes"] == "d3"


# ---------------------------------------------------------------------------
# Full orchestration (mocked codex)
# ---------------------------------------------------------------------------

def _fake_codex_that_solves(work_dir, prompt, timeout, *, codex=None, use_rocq_mcp=True):
    """Simulate a codex agent that solves all assigned goals."""
    work_dir = Path(work_dir)
    report = []
    worker_manuals = sorted(work_dir.glob("*_manual.v"))
    worker_manual = worker_manuals[0] if worker_manuals else None
    if worker_manual is not None:
        manual_text = worker_manual.read_text(encoding="utf-8")
    for goal_file in sorted(work_dir.glob("goal_*.v")):
        if goal_file.name in prompt:
            parts = goal_file.stem.split("__", 1)
            name = parts[1] if len(parts) > 1 else goal_file.stem
            if worker_manual is not None:
                manual_text = manual_text.replace(
                    f"Lemma {name} : True.\nProof. Admitted.",
                    f"Lemma {name} : True.\nProof. auto. Qed.",
                )
            report.append({"goal": name, "status": "solved"})
    if worker_manual is not None:
        worker_manual.write_text(manual_text, encoding="utf-8")
    (work_dir / "proof_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    # Also write a strategy report
    (work_dir / "proof_strategy_report.json").write_text(
        json.dumps({
            "clusters": [{"name": "A", "representative": report[0]["goal"] if report else "",
                          "members": [r["goal"] for r in report]}],
            "notes": "fake agent solved all",
        }, indent=2),
        encoding="utf-8",
    )
    return 0


def _fake_codex_that_fails(work_dir, prompt, timeout, *, codex=None, use_rocq_mcp=True):
    """Simulate a codex agent that fails all goals (leaves Admitted)."""
    work_dir = Path(work_dir)
    report = []
    for goal_file in sorted(work_dir.glob("goal_*.v")):
        if goal_file.name in prompt:
            parts = goal_file.stem.split("__", 1)
            name = parts[1] if len(parts) > 1 else goal_file.stem
            report.append({"goal": name, "status": "admitted", "report": "could not solve"})
    (work_dir / "proof_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return 0


class TestRunConcurrentAllSolved:
    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_all_goals_solved(self, mock_run, mock_check, workspace):
        result = run_concurrent(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            max_parallel=2,
            chunk_size=5,
            timeout=60,
        )
        assert result["status_counts"].get("solved", 0) == 3
        assert result["status_counts"].get("admitted", 0) == 0

    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_summary_written(self, mock_run, mock_check, workspace):
        run_concurrent(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            max_parallel=2,
            chunk_size=5,
            timeout=60,
        )
        summary_path = workspace["work_dir"] / "concurrent_summary.json"
        assert summary_path.exists()
        summary = json.loads(summary_path.read_text())
        assert summary["status_counts"]["solved"] == 3

    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_merged_proof_report(self, mock_run, mock_check, workspace):
        """A single merged proof_report.json should be written at the base work dir."""
        run_concurrent(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            max_parallel=2,
            chunk_size=5,
            timeout=60,
        )
        merged = workspace["work_dir"] / "proof_report.json"
        assert merged.exists()
        data = json.loads(merged.read_text())
        assert len(data) == 3
        goals = {e["goal"] for e in data}
        for name in workspace["names"]:
            assert name in goals

    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_merged_strategy_report(self, mock_run, mock_check, workspace):
        """Per-group strategy reports should be merged at the base work dir."""
        run_concurrent(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            max_parallel=2,
            chunk_size=5,
            timeout=60,
        )
        merged = workspace["work_dir"] / "proof_strategy_report.json"
        assert merged.exists()
        data = json.loads(merged.read_text())
        assert isinstance(data, list)
        assert len(data) >= 1
        assert "group" in data[0]
        assert "clusters" in data[0]


class TestRunConcurrentSinglePass:
    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_fails)
    def test_one_agent_per_group(self, mock_run, mock_check, workspace):
        """In adaptive mode, exactly one agent runs per group (no waves)."""
        run_concurrent(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            max_parallel=2,
            chunk_size=5,  # 1 group containing all 3 goals
            timeout=60,
        )
        assert mock_run.call_count == 1


class TestRunConcurrentMultipleGroups:
    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_multiple_groups(self, mock_run, mock_check, workspace):
        """With chunk_size=2, 3 goals -> 2 groups -> 2 agents."""
        result = run_concurrent(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            max_parallel=2,
            chunk_size=2,
            timeout=60,
        )
        assert result["status_counts"].get("solved", 0) == 3
        # 2 groups => 2 agents, no waves
        assert mock_run.call_count == 2


class TestProofReusePrepass:
    def test_reuse_index_without_compile_check_does_not_remove_worker_scope(self, workspace):
        solved_manual = workspace["tmp_path"] / "solved_manual.v"
        first = workspace["names"][0]
        solved_manual.write_text(
            "Require Import MyLib.\n\n"
            f"Lemma {first} : True.\n"
            "Proof. exact I. Qed.\n",
            encoding="utf-8",
        )
        index = build_index(
            solved_manual,
            lib_file=str(workspace["lib"]),
            frozen_prefix_end_line=None,
        )
        index_path = workspace["work_dir"] / "reuse_index.json"
        index_path.write_text(json.dumps(index, indent=2), encoding="utf-8")

        report = apply_reuse_prepass(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            reuse_index_path=index_path,
            compile_check=False,
        )

        assert report is not None
        assert report["reused_goal_names"] == []
        assert report["status"] == "direct_reuse_disabled_without_compile_check"
        manifest = json.loads(workspace["manifest_path"].read_text(encoding="utf-8"))
        assert manifest["source_file"] == str(workspace["src"])
        assert [entry["name"] for entry in manifest["lemmas"]] == workspace["names"]

        summary = finalize([], workspace["work_dir"], manifest_path=workspace["manifest_path"])
        assert summary["status_counts"]["no_report"] == len(workspace["names"])

    @patch("proof_reuse_index.check_rocq_file_with_deps", return_value=None)
    def test_reused_goals_are_removed_from_worker_scope_after_compile_gate(self, _mock_check, workspace):
        solved_manual = workspace["tmp_path"] / "solved_manual.v"
        first = workspace["names"][0]
        solved_manual.write_text(
            "Require Import MyLib.\n\n"
            f"Lemma {first} : True.\n"
            "Proof. exact I. Qed.\n",
            encoding="utf-8",
        )
        index = build_index(
            solved_manual,
            lib_file=str(workspace["lib"]),
            frozen_prefix_end_line=None,
        )
        index_path = workspace["work_dir"] / "reuse_index.json"
        index_path.write_text(json.dumps(index, indent=2), encoding="utf-8")

        report = apply_reuse_prepass(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            reuse_index_path=index_path,
            compile_check=True,
        )

        assert report is not None
        assert report["reused_goal_names"] == workspace["names"]
        manifest = json.loads(workspace["manifest_path"].read_text(encoding="utf-8"))
        assert manifest["source_file"].endswith("proof_reuse_candidate_proof_manual.v")
        assert manifest["lemmas"] == []
        candidate = Path(manifest["source_file"]).read_text(encoding="utf-8")
        assert f"Lemma {first} : True.\nProof. exact I. Qed." in candidate

        summary = finalize([], workspace["work_dir"], manifest_path=workspace["manifest_path"])
        assert summary["status_counts"]["solved"] == len(workspace["names"])


class TestTimeoutPerGoal:
    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_timeout_per_goal_scales_with_group_size(self, mock_run, mock_check, workspace):
        """When --timeout is unset, per-group timeout = timeout_per_goal × len(group)."""
        run_concurrent(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            max_parallel=2,
            chunk_size=5,  # 1 group with 3 goals
            timeout=None,
            timeout_per_goal=100,
        )
        # Agent was called with timeout = 100 × 3 = 300
        assert mock_run.call_count == 1
        # Inspect the call: 4th positional arg is timeout
        # New signature: run_codex_agent(work_dir, prompt, timeout, *, codex=...). Timeout is the 3rd positional arg.
        called_timeout = mock_run.call_args[0][2] if len(mock_run.call_args[0]) >= 3 else mock_run.call_args.kwargs.get("timeout")
        assert called_timeout == 300

    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_explicit_timeout_overrides(self, mock_run, mock_check, workspace):
        """When --timeout is set, it overrides the per-goal computation."""
        run_concurrent(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            max_parallel=2,
            chunk_size=5,
            timeout=999,
            timeout_per_goal=100,
        )
        # New signature: run_codex_agent(work_dir, prompt, timeout, *, codex=...). Timeout is the 3rd positional arg.
        called_timeout = mock_run.call_args[0][2] if len(mock_run.call_args[0]) >= 3 else mock_run.call_args.kwargs.get("timeout")
        assert called_timeout == 999


# ---------------------------------------------------------------------------
# Phase separation: prepare / run / finalize
# ---------------------------------------------------------------------------

class TestPhaseSeparation:
    def test_prepare_groups_does_not_call_codex(self, workspace):
        """prepare_groups must not spawn any agents."""
        with patch("run_agent_concurrent.run_codex_agent") as mock_run:
            group_manifests = prepare_groups(
                manifest_path=workspace["manifest_path"],
                lib_file=workspace["lib"],
                chunk_size=5,
            )
        assert len(group_manifests) >= 1
        assert mock_run.call_count == 0

    def test_prepare_groups_writes_manifest(self, workspace):
        """prepare_groups writes groups_manifest.json at the base work dir."""
        prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=5,
        )
        path = workspace["work_dir"] / GROUPS_MANIFEST_NAME
        assert path.exists()
        data = json.loads(path.read_text())
        assert isinstance(data, list)
        assert len(data) >= 1
        assert "work_dir" in data[0]
        assert "goals" in data[0]

        preflight = json.loads(
            (workspace["work_dir"] / "vc_proving_preflight.json").read_text(encoding="utf-8")
        )
        assert preflight["status"] == "passed"
        assert preflight["goal_count"] == 3
        assert preflight["group_plan_covered_goal_count"] == 3

    def test_prepare_groups_respects_manifest_worker_execution_mode(self, workspace):
        manifest = json.loads(workspace["manifest_path"].read_text(encoding="utf-8"))
        manifest["worker_execution_mode"] = WORKER_MODE_COQC_ONLY
        manifest["use_rocq_mcp"] = True
        workspace["manifest_path"].write_text(json.dumps(manifest, indent=2), encoding="utf-8")

        gms = prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=5,
        )

        assert gms[0]["worker_execution_mode"] == WORKER_MODE_COQC_ONLY
        assert gms[0]["use_rocq_mcp"] is False
        manifest = json.loads(workspace["manifest_path"].read_text(encoding="utf-8"))
        assert manifest["worker_execution_mode"] == WORKER_MODE_COQC_ONLY
        assert manifest["use_rocq_mcp"] is False

    def test_prepare_groups_uses_explicit_group_plan_file(self, workspace):
        group_plan = workspace["work_dir"] / "vc_checking_groups.json"
        group_plan.write_text(
            json.dumps({
                "proof_groups": [
                    {
                        "proof_group_id": "entail-shape",
                        "members": [
                            "proof_of_foo_entail_wit_2",
                            "proof_of_foo_entail_wit_1",
                        ],
                        "representative_witness": "proof_of_foo_entail_wit_2",
                        "natural_language_proof_pattern": "same entailment shape",
                        "shared_helper_candidates": ["helper_entail"],
                        "proving_hints": ["prove the second entailment first"],
                        "grouping_confidence": "high",
                    },
                    {
                        "proof_group_id": "return-shape",
                        "members": ["proof_of_foo_return_wit_1"],
                    },
                ]
            }),
            encoding="utf-8",
        )

        gms = prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=1,
            group_plan_path=group_plan,
        )

        assert [gm["proof_group_id"] for gm in gms] == ["entail-shape", "return-shape"]
        assert [g["name"] for g in gms[0]["goals"]] == [
            "proof_of_foo_entail_wit_2",
            "proof_of_foo_entail_wit_1",
        ]
        assert gms[0]["representative_witness"] == "proof_of_foo_entail_wit_2"
        agents_md = (Path(gms[0]["work_dir"]) / "AGENTS.md").read_text(encoding="utf-8")
        assert "same entailment shape" in agents_md
        assert "helper_entail" in agents_md

        manifest = json.loads(workspace["manifest_path"].read_text(encoding="utf-8"))
        assert manifest["grouping_source"].startswith("group_plan_file:")
        assert manifest["proof_groups"][0]["proof_group_id"] == "entail-shape"
        assert manifest["task_local_scratch_lib_file"] == str(workspace["lib"])

    def test_prepare_creates_group_workdirs(self, workspace):
        """Each group gets its own work directory with assigned goal files."""
        gms = prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=5,
        )
        for gm in gms:
            wd = Path(gm["work_dir"])
            assert wd.is_dir()
            assert (wd / "AGENTS.md").is_file()
            for entry in gm["goals"]:
                name = Path(str(entry["split_rocq_file"])).name
                assert (wd / name).is_file()

    def test_load_groups_manifest_round_trip(self, workspace):
        original = prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=5,
        )
        loaded = load_groups_manifest(workspace["work_dir"])
        assert len(loaded) == len(original)
        assert loaded[0]["work_dir"] == original[0]["work_dir"]
        assert [g["name"] for g in loaded[0]["goals"]] == \
               [g["name"] for g in original[0]["goals"]]

    def test_load_groups_manifest_missing_exits(self, tmp_path):
        with pytest.raises(SystemExit):
            load_groups_manifest(tmp_path)

    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_run_agents_only_against_prepared(self, mock_run, mock_check, workspace):
        """Prepare first, then run_agents reads the manifest and spawns one agent per group."""
        gms = prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=5,
        )
        results = run_agents(
            group_manifests=gms,
            max_parallel=2,
            timeout=60,
        )
        assert len(results) == len(gms)
        assert mock_run.call_count == len(gms)

    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_run_agents_propagates_no_rocq_mcp(self, mock_run, mock_check, workspace):
        gms = prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=5,
            use_rocq_mcp=False,
        )
        run_agents(group_manifests=gms, max_parallel=2, timeout=60)

        assert mock_run.call_count == 1
        prompt = mock_run.call_args[0][1]
        assert "rocq-mcp is disabled" in prompt
        assert mock_run.call_args.kwargs["use_rocq_mcp"] is False

    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_run_agents_worker_execution_mode_is_authoritative(self, mock_run, mock_check, workspace):
        gms = prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=5,
            use_rocq_mcp=True,
        )
        work_dir = Path(gms[0]["work_dir"])
        config_dir = work_dir / ".codex"
        config_dir.mkdir(exist_ok=True)
        (config_dir / "config.toml").write_text(
            '[mcp_servers.rocq-mcp]\n'
            'command = "/usr/local/bin/rocq-mcp"\n'
            f'cwd = "{work_dir}"\n',
            encoding="utf-8",
        )
        gms[0]["worker_execution_mode"] = WORKER_MODE_COQC_ONLY
        gms[0]["use_rocq_mcp"] = True

        run_agents(group_manifests=gms, max_parallel=2, timeout=60)

        prompt = mock_run.call_args[0][1]
        assert "rocq-mcp is disabled" in prompt
        assert mock_run.call_args.kwargs["use_rocq_mcp"] is False
        assert not (config_dir / "config.toml").exists()
        assert (config_dir / "config.toml.disabled-by-coqc-only").exists()

    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_skip_prepare_workflow(self, mock_run, mock_check, workspace):
        """Two-step workflow: prepare_groups, then load + run_agents + finalize."""
        # Step 1: prepare only
        prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=5,
        )
        assert mock_run.call_count == 0

        # Step 2: load and run
        gms = load_groups_manifest(workspace["work_dir"])
        run_agents(group_manifests=gms, max_parallel=2, timeout=60)
        result = finalize(gms, workspace["work_dir"])

        assert result["status_counts"].get("solved", 0) == 3
        # Only one batch of agent calls (no duplicate from prepare)
        assert mock_run.call_count == len(gms)

    def test_skip_prepare_main_honors_manifest_worker_execution_mode(self, tmp_path):
        """`main() --skip-prepare` must resolve the worker mode with prepare's
        precedence: explicit --worker-execution-mode > recorded manifest mode,
        with the Windows guard always winning and --no-rocq-mcp forcing coqc
        unless an explicit --worker-execution-mode overrides it.

        Pins the incident fix (a prepared rocq_mcp manifest must be HONORED, not
        silently downgraded to coqc_only) plus the explicit-override behavior.
        """
        import run_agent_concurrent

        def _write_manifest(name, mode):
            work_dir = tmp_path / name
            work_dir.mkdir()
            gms = []
            for i in range(2):
                gdir = work_dir / f"group_{i:02d}"
                gdir.mkdir()
                gms.append({
                    "work_dir": str(gdir),
                    "proof_group_id": f"group_{i:02d}",
                    "worker_execution_mode": mode,
                    "use_rocq_mcp": mode == "rocq_mcp",
                    "goals": [{"split_rocq_file": str(gdir / f"goal_01__g{i}.v"),
                               "name": f"g{i}"}],
                })
            (work_dir / GROUPS_MANIFEST_NAME).write_text(json.dumps(gms), encoding="utf-8")
            mpath = work_dir / "manifest.json"
            mpath.write_text(json.dumps({"work_dir": str(work_dir)}), encoding="utf-8")
            return mpath

        def _drive(manifest_path, extra_argv, effective):
            captured = {}

            def _spy(group_manifests, **kwargs):
                captured["modes"] = [g["worker_execution_mode"] for g in group_manifests]
                captured["use_rocq_mcp"] = [g["use_rocq_mcp"] for g in group_manifests]
                return {}

            argv = ["run_agent_concurrent.py", str(manifest_path),
                    "--skip-prepare", "--skip-finalize"] + extra_argv
            with patch.object(run_agent_concurrent, "run_agents", side_effect=_spy), \
                 patch.object(run_agent_concurrent, "effective_use_rocq_mcp",
                              side_effect=effective), \
                 patch.object(sys, "argv", argv):
                assert run_agent_concurrent.main() == 0
            return captured

        posix = lambda requested: bool(requested)   # non-Windows: pass the request through
        nt = lambda requested: False                # Windows guard: rocq-mcp unavailable
        rocq = _write_manifest("rocq", "rocq_mcp")
        coqc = _write_manifest("coqc", "coqc_only")

        # 1. Bare --skip-prepare: HONOR the prepared rocq_mcp manifest (the incident).
        r = _drive(rocq, [], posix)
        assert r["modes"] == ["rocq_mcp", "rocq_mcp"], \
            "skip-prepare downgraded a prepared rocq_mcp manifest to coqc_only"
        assert r["use_rocq_mcp"] == [True, True]

        # 2. --no-rocq-mcp (no --worker-execution-mode) downgrades to coqc_only.
        assert _drive(rocq, ["--no-rocq-mcp"], posix)["modes"] == ["coqc_only", "coqc_only"]

        # 3. Windows guard forces coqc_only regardless of the manifest.
        assert _drive(rocq, [], nt)["modes"] == ["coqc_only", "coqc_only"]

        # 4. Explicit --worker-execution-mode coqc_only is HONORED over a rocq_mcp
        #    manifest (lets a resume force coqc/coqtop when rocq-mcp is broken).
        r = _drive(rocq, ["--worker-execution-mode", "coqc_only"], posix)
        assert r["modes"] == ["coqc_only", "coqc_only"]
        assert r["use_rocq_mcp"] == [False, False]

        # 5. Explicit --worker-execution-mode rocq_mcp is HONORED over a coqc_only manifest.
        r = _drive(coqc, ["--worker-execution-mode", "rocq_mcp"], posix)
        assert r["modes"] == ["rocq_mcp", "rocq_mcp"]
        assert r["use_rocq_mcp"] == [True, True]

        # 6. Windows guard still wins over an explicit --worker-execution-mode rocq_mcp.
        assert _drive(coqc, ["--worker-execution-mode", "rocq_mcp"], nt)["modes"] \
            == ["coqc_only", "coqc_only"]

        # 7. --worker-execution-mode overrides a conflicting --no-rocq-mcp (mirrors prepare).
        assert _drive(coqc, ["--worker-execution-mode", "rocq_mcp", "--no-rocq-mcp"], posix)["modes"] \
            == ["rocq_mcp", "rocq_mcp"]


# ---------------------------------------------------------------------------
# Selective group execution
# ---------------------------------------------------------------------------

class TestSelectiveGroups:
    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_only_groups_filters(self, mock_run, mock_check, workspace):
        """only_groups=[1] should only spawn an agent for group 1."""
        # Use chunk_size=1 so we get 3 groups
        gms = prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=1,
        )
        assert len(gms) == 3
        results = run_agents(
            group_manifests=gms,
            max_parallel=2,
            timeout=60,
            only_groups=[1],
        )
        assert mock_run.call_count == 1
        assert list(results.keys()) == [1]

    @patch("run_agent_concurrent.check_codex", return_value="/usr/bin/codex")
    @patch("run_agent_concurrent.run_codex_agent", side_effect=_fake_codex_that_solves)
    def test_only_groups_multiple(self, mock_run, mock_check, workspace):
        """only_groups=[0, 2] runs two specific groups."""
        gms = prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=1,
        )
        assert len(gms) == 3
        results = run_agents(
            group_manifests=gms,
            max_parallel=2,
            timeout=60,
            only_groups=[0, 2],
        )
        assert mock_run.call_count == 2
        assert sorted(results.keys()) == [0, 2]

    def test_only_groups_invalid_index_exits(self, workspace):
        gms = prepare_groups(
            manifest_path=workspace["manifest_path"],
            lib_file=workspace["lib"],
            chunk_size=5,
        )
        with pytest.raises(SystemExit):
            run_agents(
                group_manifests=gms,
                max_parallel=2,
                timeout=60,
                only_groups=[99],
            )
