# Goals, symbolic execution & proof

This chapter tells you **what `symexec` actually does** to your annotated C — how it walks the code, what it emits, and the shape of the **verification conditions (VCs)** you (or the LLM) end up proving. The point is *legibility*: when a goal goes red, you should be able to read it and know what step of your program it came from. The diagnosis itself — *whose fault is a red goal?* — is [ch 11](ch11-stuck-goal-differential.md)'s job, and ch 11 leans on the mental model you build here.

This is not a symbolic-execution course. For the step-by-step derivations and a hands-on proving walkthrough, follow [tutorial T4 (symbolic execution)](../tutorial/T4-symbolic-execution.md) and [tutorial T5 (proving a VC)](../tutorial/T5-prove-vc.md); for the proof assistant — **Rocq** (formerly Coq; the command is still `coqc`) — and the full tactic reference, [`docs/coq-backend.md`](../docs/coq-backend.md#tactics). Here you get the judgment layer: the architecture, the file map, and the gotchas.

## Symbolic execution: the symbolic state, statement by statement

`symexec` runs your function **symbolically**. It carries a **symbolic state** — a separation-logic assertion describing memory at the current program point — and updates it as it walks each statement. It never executes concrete values; it tracks *what is known* about the heap and the program variables.

Here is how the state evolves (source: [`docs/verification-pipeline.md`](../docs/verification-pipeline.md) §1):

| C construct | Effect on the symbolic state |
|---|---|
| **Variable declaration** `T w;` | allocates uninitialized memory: `undef_data_at(&w)` — you may not load from it until it's written |
| **Assignment** `w = e` | computes `e`'s symbolic value, updates `data_at(&w, _)` to it |
| **A manual `Assert` / `Inv`** | *becomes* the new state, and records a VC that the *previous* state implies it |
| **Condition** (`if` / `while`) | adds the branch fact — `cond != 0` on the true branch, `== 0` on the false/after branch |
| **Scope exit** `}` | frees locals declared inside the block |
| **`return e`** | computes `e`, substitutes it for `__return` in the postcondition, records a VC that the final state (locals removed) implies the postcondition |
| **Function call** | instantiates the callee's ghosts, splits the heap into `pre_mem` (the part matching the callee's `Require`) and the **frame**, then replaces `pre_mem` with the callee's `Ensure` while keeping the frame untouched |

Two of these rows carry the weight. An **`Assert` or `Inv` is the one place you take over the state**: instead of letting `symexec` carry the inferred assertion forward, you *declare* what holds here, and `symexec` records a VC obligating the previous state to imply your declaration. A **function call** is where the frame rule does its work: `symexec` carves off `pre_mem` for the callee's contract and threads the rest (the frame) past untouched (the call mechanics, including the `where` clause that supplies un-inferable ghosts, are [ch 6](ch06-annotations-as-specs.md) and [T8](../tutorial/T8-function-call.md)).

The net effect is the whole reason the rest of the manual works: **program correctness is reduced to a finite set of separation-logic entailments `P |-- Q`** — the VCs. `symexec` produces them; the solver, the LLM, and you discharge them. Nothing about this step proves anything yet — it *generates the obligations*.

> 🟢 **Tier 1** — You never read the symbolic state by hand. In QIDE, `Alt+→` ("interpret to point") shows you the live state at the cursor while you annotate — that's the practical way to see this table in action without touching Rocq.

## The four files `symexec` emits

For each input `<name>.c`, `symexec` writes four files into the parallel `SeparationLogic/examples/<sub>/` tree (source: [`docs/verification-pipeline.md`](../docs/verification-pipeline.md) §2; FACTS §F3):

| File | Contents | Edit it? |
|---|---|---|
| `<name>_goal.v` | one `Definition` per VC: the entailment `P \|-- Q` | **tool-owned** — never hand-edit |
| `<name>_proof_auto.v` | `Lemma proof_of_<wit>` for VCs the strategy solver discharged, each ending `Proof. Admitted.` | tool-owned |
| `<name>_proof_manual.v` | `Lemma` stubs for VCs needing a written Rocq proof — *intended* to end in `Qed` (kernel-checked only when they do; audit for stray `Admitted`) | **human-editable** |
| `<name>_goal_check.v` | `Module VC_Correctness : VC_Correct` that `Include`s both proof files — the **completeness** gate | tool-owned |

The split between `_proof_auto.v` and `_proof_manual.v` is the **two-tier trust model**: auto VCs are discharged by `symexec`'s proof-producing solver and ride as `Admitted` (trusted, certificate not re-emitted); manual VCs are *meant* to end in `Qed` — and a manual VC is re-checked by the Rocq kernel exactly when it does, so audit for any stray `Admitted` a crashed run left behind. The `_goal_check.v` gate enforces *completeness* (every VC has a member, exactly once) — **not** that every VC was kernel-checked. The full story, the audit recipe, and why a green build is not "checked end to end" is [ch 10](ch10-trust-and-soundness.md); this chapter is about the *shapes* in those files, not their trust weight.

## The shape of a VC: witnesses and the five kinds

Each VC is a named **witness** — a `Definition <name>_<kind>_wit_<n>` in `_goal.v`, with a matching `proof_of_<...>` in one of the proof files. The witness *name encodes which program step produced it*, and that is what makes a red goal legible. Five kinds cover the corpus (re-run `grep -rhoE '_(entail|return|safety|partial_solve|which_implies)_wit' SeparationLogic/examples/QCP_demos_human --include="*_goal.v"` to see which kinds appear in your corpus):

| Witness kind | Comes from | What it obligates |
|---|---|---|
| `safety_wit` | a memory access or arithmetic step | the operation is safe (in bounds, no division by zero, the `Z` result fits — the **overflow bound** you must supply) |
| `entail_wit` | an `Assert`/`Inv`, or a branch join | the prior state implies the asserted state (or the loop invariant) |
| `return_wit` | a `return e` | the final state implies the postcondition with `e` substituted for `__return` |
| `partial_solve_wit` | a function call | the current heap supplies the callee's `Require` (the `pre_mem` split) |
| `which_implies_wit` | a `which implies` annotation | one assertion rewrites to another (a predicate fold/unfold step you wrote) |

A real specimen — a representative VC of `abs` (`SeparationLogic/examples/QCP_demos_human/simple_arith/abs_goal.v`), the simplest rung of the worked-example ladder (`QCP_examples/QCP_demos_human/simple_arith/abs.c`; see [ch 12](ch12-scope-and-scaling.md) for the full gradient up to production scale):

```coq
Definition abs_safety_wit_2 :=
forall (x_pre: Z) (PreH1 : (x_pre < 0)) (PreH2 : (INT_MIN < x_pre)) (PreH3 : (x_pre <= INT_MAX)) ,
  ((( &( "x" ) )) # Int  |-> x_pre)
|--
  “ (x_pre <> (INT_MIN)) ”
.
```

Read it left to right. The `forall` binds the ghost/program values and the **pure premises** (`PreH1`…`PreH3`, fed in as hypotheses) — and note these mix two sources: here `PreH1` is the **branch fact** `x_pre < 0` (this VC sits inside the `if (x < 0)` arm), while `PreH2`/`PreH3` are your `Require` bounds. The left of `|--` is the symbolic heap (`&("x") # Int |-> x_pre` — the address of `x` stores `x_pre`); the right is what must follow. The `“ … ”` smart quotes are a **pure proposition** (heap-independent). It is the generated-file spelling of the tutorials' `[| P |]`. This particular VC is a `safety_wit`: it guards the negation `-x` against `INT_MIN` overflow — exactly the `Z`-is-unbounded tax that every integer result pays, because `Z` is an unbounded mathematical integer and `symexec` will not invent the range bound for you.

> **Note:** `safety_wit`s are where the **overflow tax** is billed. There is no overflow automation — each `Z` arithmetic step emits a safety VC that someone (the solver, the LLM, or you) must discharge, and the premises that make it provable come from the bounds you wrote in the `Require`. If you didn't bound the inputs, the safety VC is unprovable and the goal goes red (a *wrong spec*, ch 11 cause 1).

## Loops: you supply the invariant; `symexec` checks it

Loops are the sharpest illustration of the "**you write WHAT, you delegate the WHY**" promise. `symexec` does **not** infer loop invariants — it does no invariant *inference* (it won't analyze a loop and discover one). It *expects* a `/*@ Inv … */` (or `/*@ Inv Assert … */`) on the loop and **checks** it, the classic Hoare-inductive way (source: FACTS §F3.2, from binary reverse-engineering):

- **P → I** — the state entering the loop must establish the invariant. If it doesn't, you get `Loop invariant cannot be derived based on pre-condition, i.e. failed in P -> I.`
- **I → I** — one iteration must preserve the invariant. If it doesn't: `Loop invariant is not inductive, i.e. failed in I -> I.`

Both checks surface as `entail_wit` VCs. `symexec` does ease the burden in one way: **Partial Invariant Solve** mechanically fills the easy/frame parts of the invariant (it reports `Partial Solved Invariant:`), so you typically supply the essential *pure* part — the arithmetic relation that holds each iteration — rather than re-stating the whole heap shape. The `slow_add` loop (`QCP_examples/QCP_demos_human/simple_arith/add.c`) is the canonical small example: a `while (x > 0)` with a hand-written `/*@ Inv 0 <= x && x <= 100 && 0 <= y && y <= 200 && x + y == x@pre + y@pre && emp */`, which `symexec` turns into the `slow_add_entail_wit_1` (P → I) and `slow_add_entail_wit_2` (I → I) pair in `add_goal.v`.

The practical upshot: **"the tool writes invariants" is false.** It checks and partial-solves the ones you provide. A stuck loop goal is almost always a *missing or too-weak invariant* — and with the AI dial up, **the LLM drafts that invariant** and you review it (ch 11 cause 4; [ch 7](ch07-invariants-and-the-ai-dial.md) covers the delegation).

> 🔵 **Tier 2** — Read the failing `entail_wit` to tell P → I from I → I. A P → I failure means your invariant claims more than the loop entry guarantees; an I → I failure means it isn't preserved across the body. The fix is almost always in the `Inv`, not the code.

## The proof loop and the division of labor

A manual VC stub in `<name>_proof_manual.v` is an ordinary Rocq lemma whose statement is the witness. The routine motion is `Intros` → `Exists` → `sep_apply`/`prop_apply` → `entailer!`, then ordinary Rocq for the residual math; [tutorial T5](../tutorial/T5-prove-vc.md) walks each of those tactics step by step, and [`docs/coq-backend.md`](../docs/coq-backend.md#tactics) is the full reference. (`pre_process` is the usual combined entry tactic — it does the `Intros` step and a bit more.)

The Ch-9-level point is *where the line falls*, not how each tactic works. A real manual proof — `gcd_return_wit_1` (`SeparationLogic/examples/QCP_demos_human/simple_arith/gcd_proof_manual.v`):

```coq
Lemma proof_of_gcd_return_wit_1 : gcd_return_wit_1.
Proof.
  pre_process.
  entailer!.
  subst.
  pose proof Z.gcd_rem x_pre y_pre ltac:(lia).
  rewrite Z.gcd_comm, H, Z.gcd_comm.
  reflexivity.
Qed.
```

Note the residue: after `entailer!` discharges the separation-logic structure, what's left is a **plain mathematical fact** about `Z.gcd` closed with ordinary Rocq (`rewrite`, `lia`, `reflexivity`). That is the typical division of labor — the SL tactics clear the heap reasoning, and you (or the LLM) supply the domain lemma. The auto file beside it, `gcd_proof_auto.v`, holds the same kind of lemma statement but every proof ends `Proof. Admitted.` — solver-verified, certificate not re-emitted; why that is fine (and not an unproven hole) is [ch 10](ch10-trust-and-soundness.md).

> 🟣 **Tier 3** — When the *same* `entail_wit` shape recurs across many calls, don't re-prove it: write a `.strategies` rule so it discharges into `_proof_auto.v` automatically for every future case. That moves a VC from the manual pool to the auto pool ([ch 14](ch14-extension.md)).

## Regeneration gotchas

`symexec` is designed to be re-run as your code and annotations evolve, and three behaviors trip people up (source: [`docs/verification-pipeline.md`](../docs/verification-pipeline.md) §2; FACTS §F3):

- **`symexec` never overwrites an existing `*_proof_manual.v`.** The warning `manual proof file not updated` is **normal and intended** — it protects the proofs you've written when you regenerate `_goal.v` and `_proof_auto.v`. To force a backup-then-overwrite, pass `--gen-and-backup`.
- **Witness numbering and hypothesis names shift on regeneration.** `safety_wit_3` may become `safety_wit_4`; `H3` may become `PreH5`; disjunction branches may reorder (the v2.0.3 `AggressivePreProcess` change is the usual culprit). **Never hard-code a witness number or a hypothesis name** in a manual proof — re-read the current `_goal.v`, and prefer `match goal with … end` over a literal `H3`.
- **Large cases shard the manual proof.** A big `*_proof_manual.v` is hand-split into parts wired under an umbrella that `Include`s them — but the naming is *not* uniform (`minigmp` uses `gmp_proof_manual_part1.v … _part6.v`; `cnf_trans` uses `cnf_trans_proof_manual1.v … 3.v`). `--proof-manual-file` still points at the single umbrella; the `.depend.*` files wire the shards into the build. **Don't assume every manual proof is one file, or one naming convention.**

> 🔵 **Tier 2** — After any regeneration, re-open `_goal.v` before touching your proof. A proof that worked yesterday can fail today purely because a hypothesis was renamed — that's a *rename*, not a regression in your reasoning.

## What to take away

- `symexec` walks your annotated C and maintains a **symbolic state**, reducing correctness to a finite set of entailments `P |-- Q` — the VCs. It *generates* obligations; it proves nothing on its own.
- Four files come out: `_goal.v` (the VCs), `_proof_auto.v` (`Admitted`, solver-discharged), `_proof_manual.v` (the file you edit — `Qed` when proved; audit for stray `Admitted`), `_goal_check.v` (the completeness gate).
- A VC is a named **witness** in one of five kinds — `safety` / `entail` / `return` / `partial_solve` / `which_implies` — and the name tells you which program step it came from. `safety_wit`s carry the `Z` overflow tax.
- **You supply loop invariants; `symexec` checks them** (P → I and I → I) and partial-solves the frame. It does not infer them — with the dial up, the LLM drafts them.
- The proof loop is `Intros` → `Exists` → `sep_apply`/`prop_apply` → `entailer!`, then ordinary Rocq for the residual math. Learn it hands-on in [tutorial T5](../tutorial/T5-prove-vc.md).
- On regeneration: the manual file is **never overwritten**, witness numbers and hypothesis names **shift**, and large proofs **shard**. Re-read `_goal.v`; never hard-code names.

For what a green build actually guarantees — and why `Admitted` in the auto file is fine but in the manual file is not — read [ch 10 (Trust & soundness)](ch10-trust-and-soundness.md). For diagnosing a *red* goal by its witness kind, [ch 11 (The Stuck-Goal Differential)](ch11-stuck-goal-differential.md).
