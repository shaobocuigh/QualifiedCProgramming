# Honest limits & maturity

This is the chapter that earns the rest of the manual its credibility. Every other chapter tells you what QCP *can* do; this one tells you, plainly, where the rough edges are — the unsupported features, the silent failure modes, and the parts of the workflow that are designed but not yet hardened.

Read this before you stake anything consequential on a QCP result. None of what follows is a roadmap or a promise of future work — it is the honest state of the shipped artifact, drawn from the repo as it stands. Where a limit is a hard scope boundary, [ch 12](ch12-scope-and-scaling.md) has the cost and depth; where it touches what a green check means, [ch 10](ch10-trust-and-soundness.md) has the full trust story; where it is an operational failure you can hit, [R5](reference/TROUBLESHOOTING.md) has the triage recipe.

> **The one rule to carry out of this chapter:** an exit code of `0` is **not** proof of success, and a green build is not proof that every obligation was kernel-checked. Verify the *output*, not the *return code* — and audit for what got left behind.

## The honesty ledger: where the *trust story* gets over-stated

This is narrow on purpose. It is **not** a catalog of every typo in the surrounding material — it is the short list of places where docs or tutorials over-state *what a QCP green check guarantees*. Those are the claims worth correcting, because believing them changes how much you'd lean on a result.

A **verification condition (VC)** is an entailment `P |-- Q` that `symexec` emits for one step of your annotated code; the manual leans on the term throughout.

| Over-claim you'll see elsewhere | The honest correction |
|---|---|
| "every VC is machine-checked" / "no `Admitted`" | The auto fraction is `Admitted` — solver-verified but not kernel-re-checked ([ch 10](ch10-trust-and-soundness.md)). Reasonable to rely on; just not "independently re-checked end to end." |
| "strategy soundness is machine-checked" | Mostly true: all but 2 of the ~45 `*_strategy_proof.v` files close with `Qed` and are re-checked; 2 ship `Admitted` (6 lemmas — `string_strategy_proof.v`, `minigmp/gmp_strategy_proof.v`). |
| "manual proof files never contain `Admitted`" | A convention, not a guarantee — and the **one over-claim worth actively checking**, because an admit in a *manual* proof is a genuine unproven hole. The trustworthy unit is a `Qed`, not a file. Audit before you rely. |

> **Aside — vet external examples before you copy them.** Separately, and far more mundanely, the public tutorials carry ordinary **typo-level** bugs — e.g. a `store_int` example missing its `v >= 0` constraint, or a `* x ++` that parses as `*(x++)` instead of `(*x)++`. These are **not** QCP limits or over-claims about QCP; they're a reminder that any source can have copy-paste slips, so re-verify a snippet against live source before you trust it.

## Exit code 0 does not prove success

The most general tool-behavior trap — true of *all* input, not only the unsupported features — is this: **an exit code of `0` does not prove `symexec` succeeded.** Re-measured live at the snapshot baseline, most fatal errors *do* return EXIT=1 (no arguments, a missing or nonexistent input file, a missing `--program-path`). But two cases slip through with **EXIT=0**: a **malformed/truncated parse**, and — the dangerous one — a **float program**, which exits `0` reporting `Successfully finished` while emitting obligations no shipped Rocq symbol can discharge (the float half-stub below). So the return code is an unreliable signal in exactly the cases that matter. (There is no `--version` flag on any binary, either.)

> **Warning:** scripts and CI must scan `symexec` *output* for `Successfully finished` and for `fatal error`, never only test `$?`. An exit code of 0 is not proof of success. The float silent half-stub below is the dangerous worked instance: a feature that exits 0 *and* emits real-looking obligations, yet cannot be discharged.

## Hard scope limits — and how each one fails

[Ch 12](ch12-scope-and-scaling.md) and [R2](reference/SUPPORT_MATRIX.md) carry the full support matrix. The credibility point here is narrower and more important: **the four unsupported features do not all fail the same way.** They fail in three distinct ways: `goto` and function pointers are rejected or error out (funcptr returns EXIT=1); shared-memory concurrency has no path to even attempt; and floats fail *silently* — the dangerous case.

| Unsupported feature | How it fails | What you see |
|---|---|---|
| **`goto`** | Unsupported in the open model — there is no construct for it. | Rejected / errors. |
| **Function pointers / indirect calls** | Errors out in verification mode. | An `Error: FindFuncInfo: func_info not found` message, **EXIT=1**. A safe hard limit. |
| **Shared-memory concurrency** | Not wired in. Concurrent separation logic is proven sound in `unifysl` but never connected to the C frontend. | No path to attempt it. |
| **Floats / doubles** | **Silent half-stub.** | *Apparent success* — see below. |

> **Honest limit:** "OS synchronization is supported" (LiteOS locks/events/interrupts via STS state machines) and "shared-memory concurrency is supported" are **not** the same claim. The first is real; the second is unsupported. Never market the second on the strength of the first.

### The float silent half-stub

Floats are the one soundness-adjacent edge, and the only unsupported feature that fails *quietly*. The closed `symexec` engine has a complete float front-end. Hand it an *annotated* float function — the annotation matters, because `symexec` emits obligations only from `/*@ Require/Ensure */`-annotated functions; an *unannotated* float function emits an empty `VC_Correct` module with no float VC at all:

```c
float fadd(float x, float y)
  /*@ Require emp
      Ensure emp */
{ return x + y; }
```

and it **exits 0 ("Successfully finished")** and emits a genuine IEEE verification condition referencing `fp32`, `fp32_add`, and finiteness-safety symbols — `“ (fp32_isFinite (fp32_add (x_pre) (y_pre)) ) ”` (verified live). (Note the annotation closes with `*/`, the corpus convention — `@*/` does not parse.)

But the shipped `SeparationLogic/` Rocq layer **defines none of those symbols** — there are zero `fp32` definitions in the open library (`grep -rl fp32 SeparationLogic/ --include="*.v"` lists no files — use `-rl` or `rg`, since `grep -rc` would print a `:0` line per file rather than nothing). So the generated `_goal.v` references undefined symbols, won't compile, and can't be discharged on the auto path *or* the manual path. The engine *looks like it succeeded* and leaves you an unprovable, uncompilable obligation.

This is more dangerous than a clean rejection, because the success signal lies. Unlike `goto` and function pointers — which reject or error — a float program slips through `symexec` and only fails downstream at `coqc`, where the cause is far from obvious. The reason is "engine ahead of the shipped proof base," not "cleanly rejected." Manual stance: **floats are off-limits in practice.** Don't trust a clean `symexec` run on float code.

> 🔵 **Tier 2 / 🟣 Tier 3** — If you read Rocq, you can confirm the half-stub directly: open the generated `_goal.v` and you'll see the `fp32_isFinite (fp32_add …)` obligation against undefined `fp32`/`fp32_add` symbols, so the file won't compile. A tier-1 reader can't inspect this — for them the rule is "no float code."

## The pointer model is ILP32 — a model-choice caveat, not a failure mode

This one is deliberately *not* under the scope limits above: pointers are fully supported. It is a model-choice caveat worth knowing before you verify pointer-heavy code. QCP fixes the pointer width at 4 bytes — `Axiom sizeof_ptr: sizeof_front_end_type FET_ptr = 4` (`SeparationLogic/SeparationLogic/CNotation.v:54`). The memory model is a flat byte heap with no provenance. This is an **ILP32 (~32-bit) model**, a hard design choice baked into the Rocq layer. If your code's correctness depends on 64-bit pointer width or pointer-to-integer round-trips at 64 bits, the model does not match your target. State this as a limit, not a bug — but know it's there.

## Maturity: what's battle-tested vs. intended-workflow

Not every part of QCP carries the same warranty. Label them honestly.

- **Battle-tested:** the CLI core — `symexec`, `StrategyCheck`, and the `coqc`/Rocq backend. These are exercised across the whole corpus (production-scale cases like `minigmp` through teaching cases like `gcd`). When you run the CLI path from [ch 4](ch04-quickstart-stage-a.md), you are on solid ground.
- **Intended-workflow:** the LLM agent pipeline — the orchestrator, the sub-agent skills, the MCP servers (`qcp-mcp`, `rocq-mcp`), and the phase state machine (`intake → annotation → goal-frozen → vc-checking → vc-proving → final-check → done`). This is *designed* and partly working, but it is not bulletproof, and it can fail **as software** — a crash in the tooling, distinct from a proof being stuck.

That distinction matters because the two failure classes need different responses. A red goal is the [Stuck-Goal Differential](ch11-stuck-goal-differential.md)'s subject ("whose fault is this proof?"). A *crashing pipeline* is something else entirely: the tool died before it ever produced a goal to be stuck on.

## A known crash in this build: the `vc-proving` script

When `vc-proving` compiles generated `.v` files, a memory-heavy proof can be killed mid-compile by the OS OOM-killer — a *transient* failure that a re-run often clears. The pipeline is designed to absorb that with a retry knob: `COQC_TRANSIENT_RETRIES` is meant to set how many times to retry a `coqc` that died on a transient signal, paired with `TRANSIENT_COQC_SIGNALS` for which signals count as transient (an OOM `SIGKILL`, *not* a genuine crash such as `SIGSEGV`, which should fail fast).

**That knob does not work in this build.** Both globals are *referenced but not defined* in `vc-proving`'s `manual_goal_utils.py`, so the retry path raises a `NameError` and `vc-proving` aborts before it compiles anything. This is a shipped bug, not configuration you can tune — it ships unfixed, and switching to another copy of QCP won't resolve it; it is fixed locally, with the recipe in [R5](reference/TROUBLESHOOTING.md).

Treat this as an **infrastructure failure**, not a proof failure. One operational consequence is worth carrying: because the crash happens *before* proofs are filled, it can leave a case's `*_proof_manual.v` with `Admitted` stubs that look like a batch of unproven obligations rather than a tool fault. That is the real lesson — distinguish a tool crash from a stuck proof:

### Tell an infrastructure failure apart from a proof failure

When something goes wrong, separate an **infrastructure failure** (the tool crashed) from a **proof failure** (a goal won't close) before you spend effort on the wrong fix.

1. **Classify the failure.** A Python traceback, a `NameError`, "before worker launch", or any non-Rocq error is an **infrastructure failure** → fix the tooling (this section, [R5](reference/TROUBLESHOOTING.md)). A Rocq goal you can't close is a **proof failure** → [ch 11](ch11-stuck-goal-differential.md), the Stuck-Goal Differential.
2. **Static-check the shipped scripts before relying on them.** This catches the `NameError` class without running anything. Scope the check to undefined names — a plain `pyflakes` run reports other lint (unused imports, f-string warnings) that persists even after the two globals are fixed, so it is never "clean":

   ```bash
   ruff check --select F821 .agents/skills/*/scripts/*.py
   # or: python3 -m pyflakes .agents/skills/*/scripts/*.py | grep 'undefined name'
   ```

   At the snapshot baseline the two globals above are the *only* undefined-name bugs across all 44 skill scripts — so a run with no `undefined name` lines is a meaningful all-clear *for the `NameError` class*.
3. **After any tool failure, audit for `Admitted` left behind.** A crashed pipeline leaves trusted stubs masquerading as proofs:

   ```bash
   grep -rl Admitted SeparationLogic/examples --include="*_proof_manual*.v"
   ```

   If your case appears, some manual VCs were never proved. Note these example files are **regenerated artifacts** whose counts drift between runs — `array_cases_noinv_proof_manual.v` is the documented case that has shipped with admitted manual stubs, but the exact count is a moving snapshot. Lead with the command, re-run it, and trust what it prints now over any number in this manual.

## Operational friction: MCP, AI, and Windows

The maturity split has two more operational consequences — both rough edges in the intended-workflow surface, not logical limits.

**MCP and the AI workflow carry real friction.** The agent pipeline is frontier-model-required today — it expects a capable model to draft invariants and proofs. Beyond that there is genuine setup cost, the `NameError` class of shipped-script bugs above, and the fact that the canonical agent contract `AGENTS.md` is written in Chinese. Budget for friction; this is the least mature surface.

**Windows packaging is incomplete in this redistributable.** `README_WINDOWS.md` and `AGENTS_WIN.md` both instruct you to run `scripts/setup-windows-env.ps1` (and `scripts/setup-windows-mcp-env.ps1` for MCP) before starting — but those scripts are **not shipped** in this redistributable's `scripts/` directory (which contains only `collect_and_analyze.py`). A Windows user following the documented onboarding hits a missing-file wall. The Linux/macOS CLI path ([ch 4](ch04-quickstart-stage-a.md)) is the supported route; treat Windows as intended-workflow.

## The unaudited annotation → VC faithfulness gap

This is the real trust floor, and the last thing to internalize before you act on a QCP result. The largest unaudited assumption in the whole stack is one the kernel cannot help you with: `coqc` checks that a proof **matches the VC `symexec` emitted**, never that the VC **faithfully models your C source**. So even a perfectly kernel-checked `Qed` certifies only that your annotations entail the obligations `symexec` derived — not that those obligations are the right ones. This faithfulness gap bounds what *any* QCP result can mean; it is **unaudited**; and the residual trust it leaves is **not zero**.

The full Trusted Computing Base — what a kernel-checked `Qed` does and does not certify — is the trust chapter's job ([ch 10](ch10-trust-and-soundness.md)). The practitioner takeaway is the faithfulness gap itself: a green check certifies that your code satisfies the spec you gave it, never that the spec captures what you meant. There is no command that confirms the latter; that is the floor.

> 🟢 **Tier 1** — You can't audit faithfulness — there is no Rocq to read and no command to run that confirms the VC models your C. For you, treat it as the fixed floor: a green check means "my spec was proved," never "my spec was right." Keep specs small and review them by eye.

> **Honest limit:** a green QCP check means "your annotations entail the obligations `symexec` derived from your code, and the manual ones were kernel-checked." It does **not** mean "the obligations are the right ones" or "the spec is what you meant." That residual trust — VC faithfulness plus the foundational axioms — is the real floor, and it is not zero.

## What to take away

- **Exit code 0 is not success — and the four hard limits fail differently.** Scan `symexec` output, not `$?`. `goto` is rejected/errors; function pointers error loudly with EXIT=1; shared-memory concurrency has no path; floats fail *silently* — the dangerous case, exiting 0 with an uncompilable obligation. The pointer model is ILP32 (~32-bit).
- **Maturity is split:** the CLI / `coqc` core is battle-tested; the LLM agent pipeline is intended-workflow and can crash as software — e.g. the `vc-proving` `NameError`, which ships unfixed in this build.
- **Diagnose before you fix:** infrastructure failure (Python traceback) ≠ proof failure (red goal). Static-check the scripts for undefined names; audit `*_proof_manual*.v` for leftover `Admitted` after any crash.
- **The faithfulness gap is the real floor:** the kernel checks proofs against the emitted VCs, never that the VCs model your C. No command confirms the spec is the one you meant — review it by eye.

For the cost of the supported scope, see [ch 12](ch12-scope-and-scaling.md); for what the green check means, see [ch 10](ch10-trust-and-soundness.md); for step-by-step infra-failure triage, see [R5](reference/TROUBLESHOOTING.md).
