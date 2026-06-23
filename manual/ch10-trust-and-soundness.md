# Trust & soundness

A QCP "✔" is not one thing. It is **two** things, and the difference decides how much you can lean on a green result. This chapter tells you exactly what the green check means, what it does **not** mean, and how to open the hood and check for yourself in two minutes.

Read this chapter before you decide that a verified function is "done." Everything else in the manual — when to adopt QCP ([ch 2](ch02-should-you-use-qcp.md)), why a goal is stuck ([ch 11](ch11-stuck-goal-differential.md)), what the limits are ([ch 13](ch13-honest-limits.md)) — leans on the model you learn here.

> **The one rule to carry out of this chapter:** the trustworthy unit is a **`Qed`**, not a file and not a green build. A manual verification condition is re-checked by the Coq/Rocq kernel **only when its proof ends in `Qed`**. Everything else is trusted, not re-checked.

## The two-tier trust model

QCP splits every **verification condition** (VC — an entailment `P |-- Q` that `symexec` emits for one step of your annotated code) into two pools, and the two pools earn their checkmark differently.

| Tier | Which VCs | Lives in | How the proof ends | Kernel status |
|---|---|---|---|---|
| **Auto** | VCs `symexec`'s strategy solver discharges | `*_proof_auto.v` | `Lemma … Proof. Admitted.` | **trusted** — accepted as an axiom, **not** re-checked |
| **Manual** | VCs a human or the LLM proves | `*_proof_manual.v` | `… Qed.` | **kernel-checked** — fully re-elaborated by the Coq/Rocq kernel |

The **auto** pool is the larger one — roughly two-and-a-half to three auto VCs for every manual one (i.e. roughly a quarter to a third of proof effort is manual; see [ch 12](ch12-scope-and-scaling.md) for the effort calibration and its methodology). Those VCs close with `Admitted`. In Coq/Rocq, `Admitted` means *"accept this as true without a proof."* The strategy solver decided the entailment holds; the kernel never re-checks that decision. You trust the solver.

The **manual** pool is the minority, and it is where the kernel does real work. A manual proof that ends in `Qed` has been re-elaborated, term by term, against the emitted VC. If the proof is wrong, `Qed` fails and the build goes red. That is the strong, real guarantee — and the next two sections pin down its exact shape.

> 🟢 **Tier 1** — You never read either file. What matters to you: the green check is *partly* a solver's word (auto) and *partly* a kernel-checked proof (manual). When you need to know which, run the two-minute audit below — no Coq knowledge required.

> 🔵 **Tier 2** — The proofs you read and fix live in `*_proof_manual.v`. Every `Qed` you close there is genuinely re-checked. The `*_proof_auto.v` file beside it is `Admitted` end to end; don't go looking for a bug there — there's no proof to read.

## Why a green build doesn't mean "every VC was proved"

A green `goal_check.vo` means every VC is *present*, not that every VC was kernel-checked. Here is why. The acceptance gate is a per-case file, `<name>_goal_check.v`. It builds a Coq module that bundles both proof files together. You annotate the C under `QCP_examples/`, but `symexec` writes the generated `*_proof_*.v` and `*_goal_check.v` files into the parallel `SeparationLogic/examples/` tree — two different directories, not one (the generated-file taxonomy is [ch 9](ch09-goals-symexec-and-proof.md)'s subject). For the shipped `swap` example (`QCP_examples/QCP_demos_human/swap.c`), `symexec` writes the proof files into `SeparationLogic/examples/QCP_demos_human/`, where `swap_goal_check.v` reads in full:

```coq
From SimpleC.EE.QCP_demos_human Require Import swap_goal swap_proof_auto swap_proof_manual.

Module VC_Correctness : VC_Correct.
  Include swap_proof_auto.
  Include swap_proof_manual.
End VC_Correctness.
```

That `: VC_Correct` annotation is a **completeness** check: it forces the module to provide a proof member for *every* VC `symexec` emitted, exactly once — none silently dropped, none proved twice. That is genuinely useful: it guarantees the VC set is fully accounted for.

But here is the catch that the word "completeness" hides. Coq's module-type matching is satisfied by an `Admitted` member as readily as by a `Qed` one. So `swap_goal_check.vo` compiles **green even though all of its auto VCs (13 in this checkout) are admitted.** The gate proves the VCs are all *present*; it does not prove they are all *kernel-checked*.

> **Warning:** `goal_check` is a completeness gate, not a proof. A green `goal_check.vo` means *"every VC has a member"* — not *"every VC was re-checked by the kernel."* The auto members are trusted on the way through.

And nothing in the shipped build forces the issue. No Makefile or script runs `Print Assumptions` or `coqchk` to forbid `Admitted`. The batch driver `run-example-linux.sh` runs only `symexec` and `StrategyCheck` — it never even invokes `coqc` on a `goal_check` file. (Source: `docs/verification-pipeline.md` §2, §6, §7; `docs/project-overview.md`.)

This is the single most important thing to internalize: **do not read a green build as kernel-checked end to end.** It is *complete*, with the manual fraction kernel-checked and the auto fraction trusted.

## The strong, true property — and its limits

It is easy to over-correct here into cynicism. Don't. The manual path carries a genuinely strong guarantee — state it precisely:

> On the **manual** path, the Coq/Rocq kernel re-checks every `Qed` proof term against the **emitted VC** and the **imported axioms**. So no one can produce a `Qed` for a VC that is **false** — that is, not provable from those axioms — short of the axioms themselves being unsound. A generator bug that emits an unprovable VC makes that VC **stay red**; it cannot turn a false VC green on the manual path.

That is the property to quote when someone asks "but how do you know the proof is right?" — for the manual fraction, *a `Qed` on a false VC is impossible* (absent an unsound axiom).

Three limits keep this honest:

- **It guards the proof, not the VC's faithfulness.** "Kernel-checked" means "the proof matches the VC `symexec` emitted, under the axioms QCP imports" — **not** "the VC faithfully models your C." A VC that is **provable but unfaithful** (too weak, or modelling the wrong thing) earns a perfectly valid `Qed`, and the kernel cannot catch that. So the property stops *unsound proofs*, not *wrong specifications or mistranslations*. That faithfulness gap is a separate, unaudited assumption — the largest one in the stack (see the Trusted Computing Base, or TCB, below).
- **It does not extend to the auto path at all.** The auto VCs are `Admitted`; the kernel never sees a proof for them. The no-false-`Qed` property is about `Qed`s, and auto VCs have none.
- **A green manual file may still hold trusted obligations.** The manual-proof admission policy is a **convention, not an enforced guarantee** (`docs/verification-pipeline.md` §6 calls it a convention). The shipped corpus proves the point: one manual file, `SeparationLogic/examples/QCP_demos_LLM/array_cases_noinv_proof_manual.v`, ships with **admitted manual stubs** (≈30 in this snapshot — `grep -c Admitted` that file) — a deliberately no-invariant benchmark case whose VCs can't be discharged. Those VCs are neither auto-solved nor proved; they are trusted. So "manual = checked" holds **per `Qed`**, never per file.

> **Honest limit:** three tempting overstatements are all false here — that a green build certifies the whole proof, that nothing in it is merely trusted, and that every manual file is fully proved. The accurate claim is narrow and strong: *a manual VC is kernel-checked when, and only when, it ends in `Qed`.*

## Open the hood: the two-minute audit

You don't have to take any of this on faith — QCP ships the tools to check a specific result yourself. Two recipes, from fastest to most authoritative.

**Recipe 1 — grep the proof files (no Coq needed).** Count how each pool ends:

```bash
grep -c Admitted SeparationLogic/examples/QCP_demos_human/swap_proof_auto.v    # 13 (auto, trusted)
grep -c Qed      SeparationLogic/examples/QCP_demos_human/swap_proof_manual.v  #  5 (manual, kernel-checked)
```

For the shipped `swap` case this returns **13 auto `Admitted` / 5 manual `Qed`** in this checkout — the commands above are the source of truth, so treat any quoted count as a snapshot (`swap` happens to be stable; the LLM-benchmark cases regenerate). That ratio *is* the trust split for this function, at a glance.

Then always audit the manual file for leftover `Admitted` — the convention is not enforced, so check it:

```bash
grep -rl Admitted SeparationLogic/examples --include="*_proof_manual*.v"
```

In this checkout this command prints one path; re-run it before you rely on the result, since the example tree regenerates. If your case appears here after a proving run, some manual VCs were left unproved (often a crashed pipeline — see [ch 13](ch13-honest-limits.md) and [R5](reference/TROUBLESHOOTING.md)).

**Recipe 2 — `Print Assumptions` (authoritative, per VC).** This asks the kernel itself what a specific result depends on. From the `SeparationLogic/` directory, in a Coq session — use the **fully-qualified** import (an unqualified `Require Import swap_goal_check` is ambiguous, since both `QCP_demos_human` and `QCP_demos_LLM` ship a `swap_goal_check`):

```coq
From SimpleC.EE.QCP_demos_human Require Import swap_goal_check.
Print Assumptions VC_Correctness.proof_of_swap_return_wit_1.
Print Assumptions VC_Correctness.proof_of_swap0_return_wit_1_eq.
```

Read the answer like this:

- `Closed under the global context` ⇒ that VC is **kernel-checked** — a real manual `Qed` with no admitted dependency. (`proof_of_swap_return_wit_1` is a manual VC; expect this.)
- An `Axioms: …_proof_auto…` line ⇒ that VC is **admitted/trusted** — the auto pool. (`proof_of_swap0_return_wit_1_eq` lives in `swap_proof_auto.v`; expect this.)

`Print Assumptions` is the ground truth: it traverses the actual dependency graph the kernel built, so it catches an admitted lemma hiding three levels down that a grep would miss. Use the grep for a fast scan; use `Print Assumptions` when the answer has to be airtight.

> 🟣 **Tier 3** — `Print Assumptions` also surfaces the foundational axioms (the `unifysl` / `SeparationLogic` base, the trusted strategy rules). To go one level deeper and re-validate the kernel's own bookkeeping on the compiled artifacts, run `coqchk` over the `.vo` files; it re-checks proof terms independently of `coqc`. Neither tool is wired into the shipped build, so this is a manual audit step you opt into.

## The Trusted Computing Base

Every "✔" rests on a set of things you are trusting without re-checking. Know the list — it is the honest boundary of the guarantee.

| # | You trust… | Why it's in the TCB |
|---|---|---|
| 1 | The **Coq/Rocq kernel** (`coqc`, 8.20.1) | It re-checks every `Qed`; if it's wrong, everything is. |
| 2 | `SeparationLogic/` + `unifysl` and their **foundational axioms** | The logic the proofs are built on; assumed sound. |
| 3 | `symexec`'s **annotation → VC translation** | `coqc` checks proofs *match* the VCs, never that the VCs *faithfully model your C*. **This faithfulness is unaudited.** |
| 4 | `symexec`'s **strategy solver** | Every auto VC is `Admitted` on the solver's word. The solver is in-house and *proof-producing* (it builds a derivation, with no external SMT) — but that certificate is **not emitted**, so the kernel never re-checks it. A `--soundness-proof` pathway exists in the binary but is dormant/empty today; until it's wired up, the auto pool is trusted. |
| 5 | The **6 admitted strategy rules** | `SeparationLogic/stdlib/string_strategy_proof.v` (×2) and `Applications_human/minigmp/gmp_strategy_proof.v` (×4) ship as `Admitted`; all but these 2 of the ~45 `*_strategy_proof.v` files (~43) close with `Qed` and are re-checked. So even the strategy layer is mostly kernel-checked, with a small named trusted residue. |
| 6 | The **user's annotations** | A wrong `Require`/`Ensure` is faithfully "verified" — QCP proves your spec, not your intent. |

Item 3 is the subtle one and the one most people miss. `symexec` emits **both** the VC goals **and** the `goal_check` gate that accepts them — a small circularity. The kernel guarantees the proofs are valid *for the goals as emitted*; it cannot tell you the goals are the *right* goals for your C source. If `symexec` translates a `*p` dereference into the wrong entailment, a perfectly kernel-checked `Qed` certifies the wrong thing. This faithfulness is the largest unaudited assumption in the stack — flagged here, treated at length in [ch 13](ch13-honest-limits.md). (Source: `docs/verification-pipeline.md` §1–§2; `docs/coq-backend.md`.)

Item 6 is the one *you* control. QCP proves that your code satisfies the spec you wrote. If the spec is too weak, or says the wrong thing, the proof is still valid — and useless. A green check is only as meaningful as the `Require`/`Ensure` behind it.

## What to take away

- A QCP "✔" is **two-tier**: manual VCs that end in `Qed` are kernel-checked; auto VCs are `Admitted` and trusted.
- A green `goal_check.vo` proves **completeness** (every VC is present), **not** that every VC was kernel-checked.
- The strong, true property: on the manual path, no one can produce a `Qed` for a **false** (unprovable) VC — a false `Qed` is impossible, absent an unsound axiom. It does **not** guarantee the VC is *faithful* to your C: a provable-but-wrong VC still passes (the TCB's faithfulness gap), and the property does not cover the auto path at all.
- Manual files *can* contain `Admitted`, so audit before you rely: the trustworthy unit is a **`Qed`**, not a file.
- You can check any specific result yourself in two minutes: `grep -c Admitted/Qed` for a fast scan, `Print Assumptions` for the authoritative per-VC answer.

When a green result turns red, this chapter has a mirror: [ch 11 — The Stuck-Goal Differential](ch11-stuck-goal-differential.md) asks "red — whose fault?" the way this chapter asks "green — why believe it?" For the separation-logic semantics behind the VCs themselves, see [ch 8](ch08-separation-logic-memory-model.md) and the [tutorials](../tutorial/). For the effort cost of the manual fraction, see [ch 12](ch12-scope-and-scaling.md).
