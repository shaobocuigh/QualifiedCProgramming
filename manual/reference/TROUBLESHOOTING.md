# Reference — Troubleshooting & Known Infrastructure Issues

> A living list. When something goes wrong, first decide **which kind** of failure you have, then
> jump to the right place. Verify every entry against live source — the example tree regenerates.

## Step 0: which failure is this?

| Symptom | Kind | Where to go |
|---|---|---|
| Python traceback / `NameError` / "before worker launch" / a non-Rocq (formerly Coq) tool error | **infrastructure failure** (the tool crashed) | this page + [ch 13](../ch13-honest-limits.md) |
| `symexec` says "Successfully finished" / exits 0, but the proof won't compile | **silent success** (e.g. floats) | [ch 13](../ch13-honest-limits.md) |
| A Rocq VC is red / you can't close a goal | **proof failure** | [ch 11 — Stuck-Goal Differential](../ch11-stuck-goal-differential.md) |
| A green build you're not sure you can trust | **trust question** | [ch 10 — Trust & soundness](../ch10-trust-and-soundness.md) |

**Exit code is not a reliable signal.** Re-measured at `9804a85`: no-args / missing input /
missing `--program-path` return **EXIT=1**, but a **malformed parse** and a **float program** both
return **EXIT=0**. So `$? == 0` does *not* mean success — scan the output.

## Self-diagnosis recipes

```bash
# 1. Static-check the shipped pipeline scripts before relying on them:
python3 -m pyflakes .agents/skills/*/scripts/*.py      # (or: ruff check --select F821)

# 2. After any tool failure, audit for obligations left admitted:
grep -rl Admitted SeparationLogic/examples --include="*_proof_manual*.v"

# 3. Per-VC trust audit (fully-qualified import; see [ch 10](../ch10-trust-and-soundness.md)):
#    From SimpleC.EE.<dotted.path> Require Import <name>_goal_check.
#    Print Assumptions VC_Correctness.proof_of_<witness>.
```

## Known shipped-script bugs

| # | Bug | Symptom | Fix |
|---|---|---|---|
| 1 | `vc-proving` undefined globals `COQC_TRANSIENT_RETRIES` / `TRANSIENT_COQC_SIGNALS` in `.agents/skills/vc-proving/scripts/manual_goal_utils.py` (`check_rocq_file_in_project`, a live path) | vc-proving aborts *before worker launch* with "references missing globals…"; the case's `*_proof_manual.v` is left with admitted stubs | Define the two missing constants near the other module constants (top of the file; `os`/`signal` are already imported): `COQC_TRANSIENT_RETRIES = int(os.environ.get("COQC_TRANSIENT_RETRIES", "2"))` and `TRANSIENT_COQC_SIGNALS = frozenset({-signal.SIGKILL})`. This is a **script** fix, not an env-var fix — the names are undefined *globals*, so exporting the env var alone does nothing. Ships unfixed in the current build. |

> Detection: at `9804a85`, those two are the only undefined-name (`pyflakes` F821) bugs across the
> shipped skill scripts. Re-run the static check after editing any pipeline script.
