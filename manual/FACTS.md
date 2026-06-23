# QCP User Manual — Facts Pack

> **The single source of truth for every factual and quantitative claim in the manual.**
> Each fact carries a **source citation** (repo path, and a line where one pins it). Writers
> pull the slice they need and cite *this file* (which in turn cites source). **Rule:** if a
> claim isn't here and you can't verify it against live repo source, it doesn't ship — mark it
> *intended-workflow* or cut it. Snapshot baseline: commit `9804a85`, QCP v2.0.3, Coq/Rocq
> **8.20.1**. ⚠ The generated proofs under `SeparationLogic/examples/` are **regenerated
> artifacts** — exact counts are a moving target (they shifted during this manual's own
> authoring), so every count below leads with its **command** and is quoted as **approximate**;
> re-measure before a release.

---

## F1. The two-tier trust model (the manual's most important fact)

QCP's "verified" is **two-tier**. Conflating the tiers is the #1 over-claim to avoid.

| Tier | Where | How it ends | Kernel status |
|---|---|---|---|
| **Auto** — VCs `symexec`'s strategy solver discharges | `*_proof_auto.v` | `Lemma … Proof. Admitted.` | **trusted, accepted as an axiom — NOT re-checked** |
| **Manual** — VCs a human/LLM proves | `*_proof_manual.v` | `… Qed.` | **fully re-elaborated by the Coq kernel** |

**Live counts — treat as a SNAPSHOT; lead with the command, quote the number as approximate.**
Baseline commit `9804a85`, but the files under `SeparationLogic/examples/` are **regenerated
artifacts** whose exact counts drift as the corpus is re-run (they shifted measurably even during
this manual's authoring). Re-measure before a release.

```bash
grep -rh "Admitted" SeparationLogic/examples --include="*_proof_auto.v"    | wc -l  # ≈ 4350 (auto)
grep -rh "Qed"      SeparationLogic/examples --include="*_proof_manual*.v" | wc -l  # ≈ 1744 (manual Qed, shard-aware)
grep -rh "Qed"      SeparationLogic/examples --include="*_proof_manual.v"  | wc -l  # ≈ 1464 (umbrella files only)
grep -rl "Admitted" SeparationLogic/examples --include="*_proof_manual*.v"          # ⚠ manual files that contain Admitted
```

- **Auto:** ≈ 4350 `Admitted` lemmas (one per auto VC) across ≈ 120 `*_proof_auto.v` files; all
  but one contain `Admitted` (the exception is a zero-VC file).
- **Manual:** predominantly `Qed` (≈ 1744 shard-aware / ≈ 1464 umbrella-only — pair the number
  with its scope, see F3 sharding). **Caveat:** raw `Qed` ≠ "manual VCs" — it also counts helper
  lemmas (per-VC stubs `proof_of_*` are ≈ 1700; ≈ 90 `Qed`s are helper lemmas/theorems). It is a
  proof-*effort* proxy, not a VC count. And it is **NOT exclusively `Qed`** — ⚠ The no-`Admitted` rule on
  manual files is a **convention, not enforced** — the shipped corpus currently contains **≈ 30
  admitted manual stubs**, all in `QCP_demos_LLM/array_cases_noinv_proof_manual.v` (a
  deliberately *no-invariant* benchmark case whose VCs can't be discharged). **So the precise,
  honest claim is: a manual VC is kernel-checked _only when it ends in `Qed`_.** Never assume a
  manual file is `Admitted`-free — audit it (the `grep -rl` command above, or `Print
  Assumptions`, F1.1). This *reinforces* the two-tier message: "manual = checked" holds per-`Qed`,
  not per-file.

**Why `goal_check` still goes green with auto `Admitted`:** the per-case
`<name>_goal_check.v` builds `Module VC_Correctness : VC_Correct` by `Include`-ing the auto and
manual proof modules. Module-type matching is satisfied by an `Admitted` member, so
`goal_check.vo` compiles green even though the auto VCs are admitted. **No Makefile or script
runs `Print Assumptions` / `coqchk` to forbid `Admitted`.** `run-example-linux.sh` runs only
`symexec` + `StrategyCheck`, never `coqc` on `goal_check`.
(Source: `docs/verification-pipeline.md` §2, §6; `docs/project-overview.md` "What's actually
in this repository".)

**The strong, true property (state it precisely):** the Coq kernel re-checks every `Qed` proof
term against the **emitted VC** and the **imported axioms/assumptions** — so on the **manual**
path no one can produce a `Qed` for a **false** (unprovable) VC, absent an unsound axiom; such a
VC stays *unprovable* (red). **Crucial caveat — don't overstate it:** this stops *unsound
proofs*, **not** *unfaithful VCs*. A VC that is provable but **doesn't faithfully model your C**
(too weak, or mistranslated) earns a perfectly valid `Qed`; the kernel cannot catch that — it's
the faithfulness gap (F1.2 #3). The residual trust is *not* zero: it sits in the **axioms / TCB**
(`unifysl`'s foundational axioms, the trusted `Admitted` strategy rules, and VC faithfulness).
And the guarantee does **not** extend to the auto path at all. So: "kernel-checked relative to
the VC and the axioms," not "a false proof is impossible" in any absolute sense, and *not* "the
verified property is the one you meant."

### F1.1 The `Print Assumptions` self-serve audit recipe (give readers this)

From `SeparationLogic/`, with a **fully-qualified** import (an unqualified
`Require Import <name>_goal_check` is ambiguous when the same case name ships under more than one
subtree — e.g. `swap` exists in both `QCP_demos_human` and `QCP_demos_LLM`):

```coq
From SimpleC.EE.<dotted.path> Require Import <name>_goal_check.
Print Assumptions VC_Correctness.proof_of_<witness>.
```

- `Closed under the global context` ⇒ that VC is **kernel-checked** (manual `Qed`).
- `Axioms: …_proof_auto…` ⇒ that VC is **admitted/trusted** (auto).

**Proxy without launching Coq:** `grep -c Admitted <name>_proof_auto.v` vs
`grep -c Qed <name>_proof_manual.v`.

**Worked specimen:** `SeparationLogic/examples/QCP_demos_human/swap_*` →
**13 auto `Admitted` / 5 manual `Qed`** (verified live). Use this as the canonical
"open the hood" example.

### F1.2 The Trusted Computing Base (TCB)

What you trust when you trust a QCP "✔":
1. The **Coq kernel** (`coqc` 8.20.1).
2. `SeparationLogic/` + `unifysl` and their foundational axioms.
3. **`symexec`'s annotation→VC translation** — `coqc` checks proofs *match* the emitted VCs,
   never that the VCs *faithfully model the C source*. This faithfulness is **unaudited**.
4. **`symexec`'s strategy solver** for every auto-`Admitted` VC.
5. Residual **`Admitted` strategy rules**: of the **~45** `*_strategy_proof.v` files, only **2**
   carry `Admitted` — `SeparationLogic/stdlib/string_strategy_proof.v` (×2) and
   `SeparationLogic/examples/Applications_human/minigmp/gmp_strategy_proof.v` (×4); the other
   **~43** close with `Qed` and are re-checked. So the strategy layer is *mostly* kernel-checked,
   with a small named trusted residue (6 admitted lemmas across those 2 files).
6. The **user's annotations** (a wrong spec is faithfully "verified").

**TCB circularity:** `symexec` emits *both* the VC goals and the `goal_check` gate that accepts
them. (Source: `docs/verification-pipeline.md` §1–§2 (the annotation→VC translation + the four
generated files) and §5 (StrategyCheck); `docs/coq-backend.md`; scope-matrix + trust-model
investigations.)

### F1.3 What the auto solver actually is (binary RE — sharpens "Admitted = trusted")

Reverse-engineering the closed `symexec` binary (unstripped, `debug_info`) refines the trust
story — use this precise framing:

- **The auto solver is in-house and proof-PRODUCING, not an SMT call.** It is a separation-logic
  **entailment checker with witness generation** (`CheckEntailment`, `EntailmentCheckerWit…`),
  plus EUF/congruence closure and linear-arith simplification, building explicit `ProofTerm`
  objects. There is **no external SMT solver and no subprocess** (links only libc/libm). So an
  auto VC is discharged *by a derivation the engine constructs* — not asserted blind.
- **…but the certificate is not emitted or checked.** That derivation stays inside the engine;
  what lands on disk is `Lemma proof_of_<wit> : <wit>. Proof. Admitted.` (and `_goal.v` declares
  the matching `Axiom proof_of_<wit>` inside `Module Type VC_Correct`). The Coq kernel never sees
  it. So the precise claim is **"discharged by an in-house proof-producing oracle whose
  certificate isn't emitted, so the kernel doesn't re-check it"** — not "asserted without proof,"
  but also not "kernel-checked."
- **A dormant certificate pathway EXISTS.** The binary has `--soundness-proof` / `--program-path`
  flags and an `Automation/Soundness` module. But running `--soundness-proof` on a valid `add`
  produced an **empty** `*_program_soundness.v` and the auto file still shipped `Admitted`;
  `run-example-linux.sh` uses these flags **zero** times. So the auditable artifact is **latent
  and unwired** in the shipped flow (completeness unknown from outside). Don't promise it; do note
  it exists as a future trust lever.

---

## F2. Scope support matrix (VERIFIED — high confidence)

The Coq value/AST/memory model bounds what C can be verified. The "unsupported" verdicts below
were established by direct inspection of the open Coq library (see the per-feature evidence in
F2.1 — each cites a file/line). **Cite the evidence by provenance — the four hard "no"s do not
all rest on the same kind of proof.**

| Feature | Status | One-line caveat |
|---|---|---|
| Integers (char/short/int/int64 + unsigned), pointers | ✅ supported | pointer ~32-bit, flat byte heap, no provenance; **every `Z` result needs manual range/overflow bounding** |
| Structs (dot/arrow/nested) | ✅ supported | padding/layout not modeled (`struct_padding=emp`); no aliasing-by-reinterpretation |
| Arrays (10 typed modules) | ✅ supported | **strongest built-in** (ArrayLib full/seg/undef + strategy automation); multidim = manual nesting |
| Strings (null-terminated) | ✅ supported | `store_string` over `CharArray` + null; `memchr`/`strcmp`/`strncpy`/… result predicates |
| Recursion | ✅ supported | by-contract self-calls; reasoned via inductive predicates |
| `for`/`while`/`switch`/`break`/`continue`/`do-while` | ✅ supported | frontend desugars to an if/while/seq core — **you write ordinary C** |
| Polymorphism / generic predicates | ✅ supported (UNDER-SOLD) | one list spec reused across any struct/field (`super_poly_sll2`) |
| Multi-file / modular | ✅ supported (UNDER-SOLD) | contracts in shared `_def.h` + `/*@ Import/Extern Coq @*/` |
| Unions | ⚠️ limited | tagged-union only; write-one/read-another (overlapping storage) NOT modeled |
| malloc / free | ⚠️ limited | no built-in allocator; you declare contracted wrappers (flexible; but you write the spec) |
| OS sync (locks/events/interrupts) | ⚠️ limited | via **STS abstractions** (LiteOS RTOS, 17 fns) — state-machine, NOT shared-memory parallelism |
| **Floats / doubles** | ❌ unsupported — **SILENT HALF-STUB** | ⚠ the closed engine *accepts* floats and exits 0, but the shipped Coq layer can't discharge the VCs (F2.1a) — the dangerous case |
| **goto** | ❌ unsupported | no `Sgoto` node in the open library; rejected (F2.1b) |
| **Function pointers / indirect calls** | ❌ unsupported — **errors loudly** | verification mode fails with `fatal error: FindFuncInfo` (EXIT=1) — a safe hard limit, not silent (F2.1b) |
| **Shared-memory concurrency** | ❌ unsupported | CSL proven sound but never wired into the C frontend (F2.1c) |

### F2.1 Evidence provenance for the four "no"s (don't blanket them)

- **(a) Floats/doubles — a SILENT HALF-STUB, not a clean boundary (corrected via binary RE).**
  The earlier "floats are positively-proven unsupported via `Invalid_store`" describes only the
  *open Coq layer's* store typing rejecting float *storage* (`CommonAssertion.v:351/443`). But
  the **closed `symexec` engine has a complete float front-end**: on `float fadd(float x,float y)
  {return x+y;}` it **exits 0 ("Successfully finished")** and emits a *genuine* IEEE VC
  (`… |-- fp32_isFinite (fp32_add x_pre y_pre)`, with `fp32`/`fp32_add`/safety-constraint
  symbols). **The shipped `SeparationLogic/` Coq layer defines none of those symbols** (zero
  `fp32` definitions), so the generated `_goal.v` references undefined symbols, **won't compile,
  and can't be discharged auto OR manual.** Net: the engine *looks like it succeeded* but leaves
  an unprovable, uncompilable obligation — **more dangerous than a clean rejection.** Manual
  stance: floats are **off-limits in practice**, and the reason is "engine ahead of the shipped
  proof base," not "cleanly rejected." (Also a degenerate `(X)\/(X)` VC artifact suggests the
  float VC-gen is itself unfinished.)
- **(b) goto / function pointers — "no construct in the open library," and funcptr ERRORS
  LOUDLY.** No `Sgoto` AST node exists (zero matches in `SeparationLogic/**.v`); no
  call-expression constructor for indirect calls. **Function-pointer calls fail loudly in
  verification mode** — `fatal error: FindFuncInfo: func_info not found`, **EXIT=1** (corrected
  via RE: an earlier "funcptr = silent unsoundness" claim was **refuted** — the empty-VC story
  only applies to *unannotated* functions, since QCP emits obligations only from
  `/*@ Require/Ensure @*/`). The single funcptr field in the corpus is downgraded to `addr`
  (*"it is in fact a function pointer, how to model it?"*,
  `…/LiteOS/lib/Los_Verify_State_def.v:242`). **Caveat:** the `symexec`/`lsp` frontend is
  **closed-source**; funcptr is a hard, *safely-failing* scope limit, not a soundness hole.
- **(c) Shared-memory concurrency — sound-but-unwired.** Concurrent SL is proven sound in
  `unifysl`, but it is **never connected to the C frontend**; fractional permissions are
  commented-out dead code. Distinct from OS-sync, which *is* supported via STS state machines.
  **Never market shared-memory concurrency on the strength of LiteOS STS.**

### F2.2 Effort calibration (reproducible counts — cite a command, invent no number)

Manual proof is a **minority but real** share of effort. The exact ratio depends on **what you
count and over what scope**, so always pair a number with how it was counted:

| Counting method | Auto : Manual | ≈ % manual |
|---|---|---|
| Lemma count, **shard-aware**: ≈ 4350 auto `Admitted` / ≈ 1744 manual `Qed` | **≈ 2.5 : 1** | **≈ 29%** |
| Lemma count, **umbrella manual files only**: ≈ 4350 / ≈ 1464 | **≈ 3.0 : 1** | **≈ 25%** |
| `scripts/collect_and_analyze.py` paired methodology (**re-run in a writable dir** — it writes its output, and counts lemma *stubs* including any `Admitted`, not `Qed`s) | ≈ 3 : 1 | ≈ 24–25% |

(Commands for rows 1–2 are in F1; all numbers are snapshots — re-run.) **Headline phrasing for
prose: "roughly a quarter to a third of proof effort is manual on average."** Do **not** quote a
frozen `collect_and_analyze.py` number as fact. Note the manual `Qed` count **excludes** the ≈ 30
admitted manual stubs in `array_cases_noinv` (F1) — those VCs are neither auto-discharged nor
proven, so they don't count as "manual effort done."

**Skew (qualitative, medium confidence — category estimates, NOT reproduced by one command;
label as such or cut):** more manual for arithmetic/number-theory & OS/STS code; much less for
array/string/list/algorithmic code that reuses shipped predicates; a shard-aware count finds
**roughly 1 in 9** measured cases hits **zero** manual `Qed` lemmas (state the denominator and
whether you count `Qed`s or stubs — `array_cases_noinv` has stubs, not `Qed`s). **Recurring cost
(solid):** every `Z` arithmetic result is an unbounded mathematical integer → **a manual
range/overflow bound per VC** (no overflow automation). This tax *is* the `Z` leak (F4.4),
billed per VC.

### F2.3 Under-sold capabilities to PROMOTE

predicate polymorphism · multi-file modularity · full structured control flow · user-programmable
allocation · the **50+-rule strategy library** (what drives the automation — roughly 2.5–3 : 1
auto:manual depending on counting scope, F2.2) · math libs (`MaxMinLib`/`SumLib`) · `GraphLib` ·
the verified **LiteOS STS case set** (17 functions — a kernel sorted-link/list case set, **not**
the whole RTOS).

---

## F3. The four-file pipeline taxonomy

For each input `<name>.c`, `symexec` writes into `SeparationLogic/examples/<sub>/`:

| File | Contents | Editable? |
|---|---|---|
| `<name>_goal.v` | one `Definition` per VC: the entailment `P \|-- Q` | tool-owned (never hand-edit) |
| `<name>_proof_auto.v` | `Lemma proof_of_<wit>` for solver-discharged VCs (`Admitted`) | tool-owned |
| `<name>_proof_manual.v` | `Lemma` stubs for VCs needing a human/LLM Coq proof (`Qed`) | **human-editable** |
| `<name>_goal_check.v` | `Module VC_Correctness : VC_Correct` `Include`-ing both proof files — the **completeness** gate (every VC accounted for exactly once) | tool-owned |

Key behaviors (Source: `docs/verification-pipeline.md` §2):
- **`symexec` never overwrites an existing `*_proof_manual.v`.** The warning
  `manual proof file not updated` is **normal** — it protects your proofs on regeneration.
  Force a backup-then-overwrite with `--gen-and-backup`.
- VC/witness numbering and hypothesis names (`H1`, `PreH2`, …) **shift** on regeneration. Never
  hard-code them; re-read the current `_goal.v`.
- **Sharding (two naming patterns observed):** a large `<name>_proof_manual.v` is hand-split and
  wired under an umbrella that `Require`s/`Include`s the parts. Naming is **not uniform**:
  `minigmp`/`minigmp_sumlib` use `gmp_proof_manual_part1.v … _part6.v` (the `_partN` pattern),
  while `cnf_trans` uses `cnf_trans_proof_manual1.v … 3.v` (a bare-number `…manualN` pattern).
  `--proof-manual-file` still points at the **single umbrella** — `symexec` is unaware of the
  shards; the `.depend.*` files wire the build. So **not every manual proof is one file**, and
  don't assume a single shard-naming convention.
- **`goal_check` completeness ≠ proof.** It guarantees the VC set is *complete* (each VC has a
  member), not that each VC is *kernel-proved* (F1).

### F3.1 Canonical command line (Source: `docs/verification-pipeline.md` §3)

```bash
linux-binary/symexec \
  --input-file=QCP_examples/QCP_demos_human/simple_arith/gcd.c \
  --goal-file=SeparationLogic/examples/QCP_demos_human/simple_arith/gcd_goal.v \
  --proof-auto-file=SeparationLogic/examples/QCP_demos_human/simple_arith/gcd_proof_auto.v \
  --proof-manual-file=SeparationLogic/examples/QCP_demos_human/simple_arith/gcd_proof_manual.v \
  --coq-logic-path=SimpleC.EE.QCP_demos_human.simple_arith \
  -slp QCP_examples/QCP_demos_human/ SimpleC.EE.QCP_demos_human \
  --no-exec-info
```

- **`-I` ≠ `-slp`.** `-I<dir>` resolves C `#include`s; `-slp <dir> <Coq.Path>` resolves
  `.strategies` files and Coq logical paths. Many cases need several of each; `-slp` pairs nest
  (up to three in `mergeablelist/sll_project`).
- **Logic-path derivation:** `SimpleC.EE.` + the directory path segment-by-segment.

---

## F4. The annotation surface (specimens for the bestiary & chapters)

### F4.1 `*` is separating conjunction, not multiply (THE #1 false friend)

`*` joins **disjoint** memory regions (separating conjunction, Coq `**`); `&&` joins **pure**
heap-independent facts (Coq `[| P |]` or the generated `“ P ”`). Specimen (typed int-storage
form `data_at(p, int, v)` from tutorial T2):

```c
exists v, v >= 0 && data_at(p, int, v) * data_at(q, int, v)
//          └─ pure (&&): v ≥ 0 ─┘        └─ spatial (*): p, q DISJOINT cells, same value ─┘
```

> **Predicate-naming fact (verified):** `store_int(...)` is a **qua.codes/tutorial-website**
> spelling and appears **zero** times in `QCP_examples/` or `tutorial/`. The corpus's storage
> surface forms are (counts via
> `grep -rho '\bNAME(' QCP_examples --include='*.c' --include='*.h'`): the generic
> **`store(addr)`** predicate (436; e.g. `store(&(tail->data))`, `store(field_addr(t, next))`,
> `store(nums + j*sizeof(int))`), **`undef_data_at(...)`** for uninitialized cells (78; bare
> `data_at(` is **≈0** in the corpus C — it's a tutorial/docs form, F4.2), and typed compound
> predicates — top counts: `store_tree` (121), `store_string` (115), `store_term` (86),
> `store_type` (62), `store_dll` (38), `store_queue`/`store_solution` (32 each), `store_map`
> (24). Use repo forms in worked examples; the qua.codes `store_int` specimen is fine *only*
> when explicitly teaching the false-friend point in isolation.

### F4.2 `data_at` surface shapes (documented annotation syntax — mostly tutorial/docs)

`data_at` is **valid user-written annotation syntax** in several shapes, but **bare `data_at(`
is ≈0 in the example corpus C** (the corpus uses `store(...)` and `undef_data_at(...)`;
`data_at` lives in the tutorials and `docs/`). Treat these as *documented syntax*, not "common
corpus forms":

- **typed 3-arg** `data_at(p, int, v)` / `data_at(p, int*, v)` (tutorial T2);
- **basic 2-arg** `data_at(&x, v)` ("address of `x` stores `v`" — basic style, T3/T4);
- **concise value-omitted** `data_at(&node->next, struct list*)` (docs/tutorials; the corpus's
  nearest real form is `undef_data_at(&(node->next), struct list*)`).
`symexec` also carries the 2-arg shape in symbolic-state dumps — it is *not* "internal only,"
but for *worked corpus examples* prefer `store(...)` / `undef_data_at(...)`. (Source:
`docs/glossary.md`; `docs/annotation-language.md` §9–§10.)

### F4.3 The quantifier triad — `With` (∀) vs `forall` vs `exists` (∃)

Corpus counts (`grep -rho '\bKW\b' QCP_examples --include='*.c'`, snapshot — re-run): `exists`
≈ 718, `With` ≈ 382, `forall` ≈ 252. (Counts rise over `*.c`+`*.h`; state the scope when you
cite them.)

- **`With x`** = ∀ over the **whole triple** {Pre} f {Post} — a ghost/logical param the
  **caller** picks, shared across `Require` AND `Ensure`. (= VST `WITH`.)
  e.g. `With l  Require sll(p,l)  Ensure sll(__return, rev(l))`.
- **`forall (i:Z), …`** = ∀ **inside one assertion** (a pure proposition; e.g. every array index
  in range).
- **`exists x, …`** = ∃ **inside one assertion** (usually `Ensure`/`Inv`) — the **callee**
  produces a value the caller didn't supply.

Teaching motion: **∀-in / ∃-out** — `With`/`forall` = caller-given (for-any); `exists` in a post
= callee-produced (there-is). **Why `With` ≠ `forall`:** a `forall` is trapped in one assertion,
but a ghost must appear in both Pre and Post, so the triple-level ∀ needs its own keyword.
**Open detail to pin before documenting:** the trailing `X` in `With l X` (frame/auxiliary
ghost?) — confirm its role.

### F4.4 The `Z` leak (load-bearing, not cosmetic)

`Z` = **unbounded mathematical integer** ≠ fixed-width `int`. Corpus (`*.c` scope, snapshot):
`: Z` ≈ 687, `list Z` ≈ 584; `: nat`/`: N` **0** at the surface. This is exactly why `abs.c` opens with
`INT_MIN < x && x <= INT_MAX` — the user manually re-imposes C bounds on Coq's `Z`. **The
manual cannot paper over `Z`;** it can only cushion it (a ~10-symbol "Coq types you'll meet, in
C terms" translation table). The CPS/monadic spec style (`With {B} l0 (c: list Z -> program
unit B) X`) is the *avoidable, advanced* leak — quarantine to a tier-3 "higher-order specs"
section.

---

## F5. The Stuck-Goal Differential (flagship, ch.11)

A red goal has **four** distinct causes. Triage by asking *"is it even true?"* before *"why
won't it prove?"*, and diagnose by **authorship** (you wrote the spec; the LLM wrote the
invariant):

1. **Wrong spec** — the `Require`/`Ensure` doesn't say what you meant. (Your bug.)
2. **Real program bug** — the code is wrong; the tool is *succeeding* by refusing to prove a
   false thing. (The tool working as intended.)
3. **Coq + SL limitation** — true, but needs a lemma/predicate the library lacks, or a manual
   proof step. (Tier-2/3 territory.)
4. **Automation/LLM came up short** — provable and in-scope, but the solver/LLM didn't find it.
   (Dial the AI, add a `.strategies` rule, or prove by hand.)

This chapter is the **mirror** of the trust chapter: trust = "green — why believe it?";
differential = "red — whose fault?". Best rendered as a **decision-tree diagram**.

---

## F6. Honesty ledger — known over-claims to NOT reproduce

The surrounding material shipped these errors; the manual must not repeat them:
- **"every VC is machine-checked" / "no `Admitted`" / "strategy soundness is machine-checked"**
  — false for the auto fraction and the 6 admitted strategy rules (F1, F1.2). The internal
  `docs/` were corrected on 2026-06-23; older copies/tutorials may still over-claim.
- **"manual proof files never contain `Admitted`"** — also false: the shipped corpus has ≈ 30
  admitted manual stubs in `QCP_demos_LLM/array_cases_noinv_proof_manual.v` (F1). The
  no-`Admitted` rule is a convention, not a guarantee; the trustworthy unit is a `Qed`, not a
  file.
- **qua.codes `store_int` bug** — `exists v, store_int(p,v)*store_int(q,v)` was labeled
  "non-negative" while missing `v >= 0`. Correct form adds `v >= 0 &&` (F4.1).
- **qua.codes `add1_ptr` bug** — body `* x ++` parses as `*(x++)` (increments the pointer); the
  spec wants `(*x)++` (increments the value). Code/spec contradiction.
- Full external-tutorial backlog: `docs/qua-codes-tutorial-fixes.md` (external; can't edit from
  repo). **Implication:** mine-but-vet — re-verify before quoting any tutorial/qua.codes claim.

---

## F7. The staged example ladder (the syllabus = the authoring gradient)

The complexity gradient that doubles as the manual's worked-example spine (all paths verified
present at `9804a85`):

| Stage | Example | Path | Teaches |
|---|---|---|---|
| 1 | `abs` / `add` | `QCP_examples/QCP_demos_human/simple_arith/abs.c`, `add.c` | simplest spec; the `Z`/overflow bound (`INT_MIN < x && x <= INT_MAX`) |
| 2 | `gcd` | `QCP_examples/QCP_demos_human/simple_arith/gcd.c` | loops + `Inv`; recursion-by-contract |
| 3 | array | `QCP_examples/QCP_demos_human/array_auto.c` (+ `int_array_def.h`) | `IntArray::full/seg/undef`; `forall`-in-assertion |
| 4 | `sll` | `QCP_examples/QCP_demos_human/sll.c` | separation logic, pointers, `which implies` unfolding (tutorials T1–T6, T8) |
| 5 | `bst` | `QCP_examples/QCP_demos_human/bst_*.c` (+ `bst_def.h`) | trees; deeper custom predicates + `.strategies` |
| 6 | `minigmp` | `QCP_examples/Applications_human/minigmp{,_sumlib}/gmp.c` | production scale; **sharded** manual proofs; credibility bookend |

**Corpus geography** (Source: `docs/examples-catalog.md`; `.c` counts re-verified at `95437ee`):
`Applications_human/` (26 `.c`, production scale), `QCP_demos_human/` (33, teaching set),
`QCP_demos_LLM/` (**38**, LLM-oriented; the agent workflow's canonical reference), `LLM_bench/`
(23, LLM benchmark), `stdlib/` (shared `string.h`).

---

## F8. Driving QCP — the three surfaces & the AI dial

- **CLI** — `symexec`/`StrategyCheck` directly, or `run-example-{linux,windows}.sh` for batch
  corpus regeneration.
- **QIDE** (VS Code, `qide.vsix` → `lsp` binary) — `Alt+→` "interpret to point" shows the live
  symbolic-assertion state while you annotate.
- **MCP servers** — `qcp-mcp` (interactive symbolic execution / annotation checking) and
  `rocq-mcp` (interactive Coq proof dev) expose QCP to LLM agents. *(Maturity: MCP/AI is partly
  **intended-workflow**; label friction honestly — frontier-model-required today, setup
  friction, Windows gaps.)*
- **Agent workflow** — a main orchestrator + fixed sub-agents run a phase state machine
  (`intake → annotation → goal-frozen → vc-checking → vc-proving → final-check → done`).
  Contracts in `AGENTS.md` (Chinese; English summary in `docs/agent-workflow.md`). The
  deprecated skill is `annotation-and-symbolic-execution` (its deprecation is stated in
  Chinese: `这个 skill 是旧版…`); the other six skills are active.

**AI is a dial, not a tier** — every tier turns delegation up or down (F: STYLE_GUIDE §3).

---

## F9. Pipeline maturity & known infrastructure failures (honest-limits)

The **CLI / `symexec` / `coqc` core is battle-tested**; the **LLM agent-workflow scripts are
intended-workflow** and not bulletproof. They can fail *as software* — a crash in the tooling,
distinct from a proof being stuck (F5 is about a *red goal*; this is the tool **crashing** before
it gets there). Document this honestly; it's a credibility win, not a weakness.

- **Concrete, verified specimen — the `vc-proving` `NameError`.**
  `.agents/skills/vc-proving/scripts/manual_goal_utils.py` references two **undefined** module
  globals, `COQC_TRANSIENT_RETRIES` (line ~605) and `TRANSIENT_COQC_SIGNALS` (line ~618), in
  `check_rocq_file_in_project()` — a live path hit on every per-`.v` `coqc` compile. Result:
  vc-proving aborts *before worker launch* (*"Script infrastructure failure … references missing
  globals …"*). **It is documented in no `README*`/setup/`AGENTS*`/MCP file** — only in the
  failed run's auto-generated `timing_log.md`. Full root-cause + fix: `docs/agent-workflow.md`
  §9.1.
- **It is unfixed upstream and in every public fork (verified 2026-06-23).** The defect ships
  from upstream `QinxiangCao/QualifiedCProgramming`; both known public forks
  (`lixing-hust/…`, `Vitalrubbish/…`, last pushed 2026-06-22) carry a **byte-identical**
  `manual_goal_utils.py` (`sha256 d357dfa6…`) — `pyflakes` reproduces the same two undefined
  names on all three. So a reader who hits this cannot resolve it by switching forks; the fix in
  §9.1 must be applied locally. This is the documentation gap made concrete: a known,
  reproducible, *shipped-everywhere* tool crash that no official doc mentions.
- **Why this matters for trust:** when vc-proving dies, the manual proofs are never filled, so
  the case's `*_proof_manual.v` is left with **`Admitted` stubs** — exactly how
  `array_cases_noinv` shipped with ≈30 admitted manual stubs (F1). A pipeline *crash* can thus
  masquerade as "30 unproven obligations" rather than an infrastructure fault.
- **Self-diagnosis recipe for the manual (give readers this):**
  1. Distinguish **infrastructure failure** (Python traceback / `NameError` / "before worker
     launch" / non-Coq error) from a **proof failure** (a Coq goal you can't close → F5
     Stuck-Goal Differential). Different fix paths.
  2. Static-check the shipped scripts before relying on them:
     `python3 -m pyflakes .agents/skills/*/scripts/*.py` (or `ruff check --select F821`). At
     `9804a85` the two globals above are the **only** undefined-name bugs across all 44 skill
     scripts.
  3. After any tool failure, **audit for `Admitted` left behind**:
     `grep -rl Admitted SeparationLogic/examples --include="*_proof_manual*.v"`.
- **General honest-limits to state (maturity labels):** frontier-model-required today; MCP/AI
  setup friction; Windows packaging gaps (`scripts/setup-windows-*.ps1` referenced by
  `README_WINDOWS.md`/`AGENTS_WIN.md` but **not shipped** in this redistributable's `scripts/`);
  `AGENTS.md` is Chinese (English summary only in `docs/agent-workflow.md`); the shipped agent
  scripts can carry undocumented bugs like F9's.
- **Engine-vs-shipped-layer edges (binary RE) — state these in ch 13:**
  - ⚠ **Floats are a *silent half-stub* (the one soundness-adjacent edge).** `symexec` accepts a
    float program, exits 0 "Successfully finished", and emits real IEEE VCs — but the shipped Coq
    layer can't discharge them, so you get *apparent success* with an uncompilable obligation
    (F2.1a). Unlike `goto`/funcptr (which are rejected/error loudly), floats fail **silently**.
  - **`symexec` returns exit code 0 even on `fatal error`** (e.g. a missing `--program-path` or a
    bad annotation parse); only an in-verification-mode funcptr call returns EXIT=1. **So an exit
    code of 0 is not proof of success** — scripts/CI must scan output, not just `$?`. (No
    `--version` flag on any binary, either.)
  - **A dormant `--soundness-proof` certificate pathway exists** (F1.3) — latent, unwired, emits
    empty output today; note it as a *future* trust lever, don't present it as a feature.
  - **Pointer model is ILP32** (`sizeof_ptr = 4`) — the ~32-bit pointer caveat (F2) is a hard
    model choice, wrong for 64-bit targets.
