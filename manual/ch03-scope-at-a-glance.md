# Scope at a glance

Before you write a single annotation, answer one question: **can QCP handle code like mine?** This chapter is the fast lookup. Scan the matrix, check your code against the **Not supported** box, and you'll know in a minute whether QCP is even in the running — and where the sharp edges are.

This is the *glance*. The cost axis (how much manual proof effort each feature really takes) lives in [ch 12](ch12-scope-and-scaling.md); the full table with per-feature evidence is the [support matrix reference](reference/SUPPORT_MATRIX.md); the predicate inventory is the [bestiary](reference/BESTIARY.md). Here you get the verdicts and the one framing — you write ordinary C; the frontend desugars it — that shrinks most of these to syntax, not semantics.

## You write ordinary C; the frontend desugars

The thing that surprises most newcomers: QCP's C surface is wider than its small core suggests. You do **not** restrict yourself to some verifier-friendly dialect. You write ordinary C — `for`, `while`, `switch`, `break`, `continue`, `do`/`while`, nested structs, pointer arithmetic — and the `symexec` frontend **desugars** it down to a tiny `if`/`while`/`seq` core before reasoning about it. Full structured control flow is in scope; you don't hand-translate your loops into a normal form.

So the boundary that matters is not "which C syntax can I write" — it's **which C *semantics* the shipped verification path can actually carry.** That is what the matrix below maps. The four hard "no"s share one trait — **no usable shipped C verification path** — but they get there by *different routes*, and that difference is load-bearing: `goto` has no AST node at all (the model truly can't represent it); shared-memory concurrency *is* proven sound in `unifysl` but is never wired into the C frontend; and floats are the trap — the closed frontend represents them and emits a VC, but the shipped proof layer can't discharge it. So read each failure mode below; "unsupported" does not mean "the parser chokes on the syntax," and it does not mean the same thing four times.

## The support matrix

What QCP can verify, in one table. ✅ = supported; ⚠️ = supported with a real limit; ❌ = out of scope. The evidence differs by row: the four ❌ rows rest on **open-model** evidence (a missing AST node, an undischargeable VC, an unwired soundness proof — cited below); the ✅/⚠️ rows are backed by the facts pack plus live corpus and library evidence (a working example, a predicate definition, a frontend behavior). Most ✅ features are exercised by the example corpus — but a few (e.g. `continue`) are model-supported via the desugaring without a worked corpus case in this checkout; see the row caveats.

| Feature | Status | The one caveat |
|---|---|---|
| Integers (`char`/`short`/`int`/`int64`, signed + unsigned), pointers | ✅ supported | pointer model is ILP32 (~32-bit); flat byte heap, no provenance; **every `Z` result needs a manual range/overflow bound** |
| Structs (dot/arrow/nested) | ✅ supported | padding/layout not modeled (`struct_padding = emp`); no aliasing by reinterpretation |
| Arrays | ✅ supported | the **strongest built-in** — typed array library (full/seg/undef views) plus heavy strategy automation; multidimensional = manual nesting |
| Strings (null-terminated) | ✅ supported | `store_string` over a char array + null; result predicates for `memchr`/`strcmp`/`strncpy`/… |
| Recursion | ✅ supported | by-contract self-calls; reasoned via inductive predicates |
| `for`/`while`/`switch`/`break`/`continue`/`do`-`while` | ✅ supported | frontend desugars to an `if`/`while`/`seq` core — **you write ordinary C** (`continue` is model-supported via the desugaring but has **no** worked corpus case in this checkout — `grep -rn 'continue' QCP_examples --include='*.c'` returns nothing at snapshot) |
| Polymorphic / generic predicates | ✅ supported (under-sold) | one list spec reused across any struct/field (`super_poly_sll2`) |
| Multi-file / modular | ✅ supported (under-sold) | shared contracts in a `_def.h` + `/*@ Import/Extern Rocq @*/` |
| Unions | ⚠️ limited | tagged-union only; write-one/read-another (overlapping storage) is **not** modeled |
| `malloc` / `free` | ⚠️ limited | no built-in allocator; you declare contracted wrappers (flexible — but you write the spec) |
| OS sync (LiteOS, via STS) | ⚠️ limited | via **STS** state-machine abstractions; the shipped corpus is a ~17-function kernel sorted-link/list case set (snapshot — count below), **not** the whole RTOS — and **not** shared-memory parallelism |
| **Floats / doubles** | ❌ unsupported | **silent half-stub** — apparent success, uncompilable obligation (see below) |
| **`goto`** | ❌ unsupported | no `Sgoto` AST node in the open library; rejected |
| **Function pointers / indirect calls** | ❌ unsupported | **errors loudly** — fatal error, `EXIT=1` |
| **Shared-memory concurrency** | ❌ unsupported | sound in theory, never wired into the C frontend |

> **Note:** ✅ here means the feature is supported — exercised across the example corpus for all but the noted exceptions (`continue`), not that any given proof is free. Supported still costs effort — particularly the per-result `Z` overflow bound, which has **no** automation. [ch 12](ch12-scope-and-scaling.md) puts numbers on it. Behind every ✅ sits a large strategy library — `grep -rho 'id :' . --include='*.strategies' | wc -l` returns ≈540 rules across ≈46 `.strategies` files at snapshot (the example tree regenerates; re-measure), backed by a matching set of `_strategy_proof.v` modules — that drives the automation; it is *why* the array and list cases need so little hand-proof.

## Not supported

Four things QCP cannot verify — four hard boundaries with **four different failure modes**. Treat them differently; the box says how.

> **Warning — the four "no"s do not fail alike.** `goto` is rejected; function pointers error loudly; shared-memory concurrency is absent. **Floats are the trap:** the engine *appears to succeed* and leaves you an obligation that can never be discharged. Read each one before you assume a clean rejection.

### Floats / doubles — the dangerous case (silent half-stub)

This is the only ❌ you have to actively watch for, because it does **not** announce itself. The closed `symexec` engine has a complete float front-end: hand it `float fadd(float x, float y) { return x + y; }` and it **exits 0 — "Successfully finished"** — and emits a genuine IEEE verification condition (with `fp32`/`fp32_add` and finiteness symbols). It *looks* verified.

But the shipped `SeparationLogic/` Rocq layer **defines none of those symbols** — there are zero `fp32` definitions in the library (verified live). So the generated `_goal.v` references undefined names: it **won't compile**, and the obligation can be discharged by neither the auto solver nor a manual proof. You are left with **apparent success and an uncompilable, unprovable obligation** — strictly worse than a clean rejection, because nothing flags it at the `symexec` step.

> **Honest limit:** floats and doubles are **off-limits in practice.** Not because they're "cleanly rejected" — because the engine is ahead of the shipped proof base. The reason matters: don't trust a green `symexec` exit on float code; it tells you nothing. (Exit code 0 is not proof of success in general — see [ch 13](ch13-honest-limits.md).)

### `goto` — rejected

There is **no `Sgoto` AST node** in the open library (zero matches across `SeparationLogic/**.v`, verified live). Unstructured jumps have no representation, so `goto` is out. This is a clean limit — restructure to the structured control flow QCP fully supports.

### Function pointers / indirect calls — a safe hard limit (errors loudly)

There is no call-expression constructor for an indirect call in the open library. Call through a function pointer in verification mode and `symexec` fails with a **fatal error** — `fatal error: FindFuncInfo: func_info not found`, `EXIT=1`. This is the **safest** of the four: it stops you at the door, loudly, with a non-zero exit. The one funcptr field in the corpus is downgraded to a plain `addr` (provenance in [ch 13](ch13-honest-limits.md) / the [support matrix reference](reference/SUPPORT_MATRIX.md)) — a hard, *safely-failing* scope limit, not a soundness hole.

> **Note:** the `symexec`/`lsp` frontend is **closed-source**, so "no construct in the open library" is the precise, definitive claim for what ships. Nothing observed suggests the frontend adds lowering for these — but the honest framing is "no support in the open model," not "proven impossible."

### Shared-memory concurrency — unsupported (don't confuse it with OS sync)

Concurrent separation logic is proven sound inside `unifysl` — but it is **never wired into the C frontend**, which has no fractional-permission support (the heap model in `Mem.v` carries only full-or-no permission). You cannot verify two threads racing on shared memory.

Keep this distinct from **OS synchronization**, which *is* supported: the shipped LiteOS corpus is a small kernel **sorted-link/list** case set (sorted doubly-linked-list operations — `store_dll`/`store_sorted_dll`/…), reasoned via **STS** state-machine abstractions — `find QCP_examples/Applications_human/LiteOS -maxdepth 1 -name '*.c' | wc -l` returns ≈17 at snapshot. STS *can* model RTOS sync state — the library defines abstract event/mutex/semaphore states — but no verified C function in the corpus exercises a lock, event, or interrupt operation. These are two different stories.

> **Warning:** never read QCP's verified LiteOS STS cases as evidence that shared-memory concurrency works. STS abstracts an RTOS *state machine*; it is not parallel-thread reasoning over a shared heap. Marketing the first on the strength of the second is the over-claim to avoid.

## Don't overlook the under-sold "yes"es

The matrix is honest about its "no"s; it also **under-sells** three of its "yes"es. Predicate polymorphism reuses one list spec across *any* struct and field (`super_poly_sll2`); the array library is the strongest built-in (typed full/segment/undefined views plus strategy automation that discharges most array VCs hands-off); and multi-file modularity verifies across translation units via a shared `_def.h` — the seam that lets proofs scale. If you're sizing QCP for real code, weigh these. The trade-off they don't erase is the manual fraction (roughly a quarter to a third of proof effort) and the per-`Z`-result overflow bound — [ch 12](ch12-scope-and-scaling.md) is the cost chapter, and the [support matrix reference](reference/SUPPORT_MATRIX.md) carries each verdict's evidence.

## What to take away

- **You write ordinary C**; the frontend desugars it. The real boundary is the value/memory/AST *model*, not C syntax.
- **The four "no"s fail differently** — and the difference is load-bearing: **floats** are a *silent half-stub* (apparent success, uncompilable obligation — the dangerous case); **`goto`** is rejected (no `Sgoto` node); **function pointers** error loudly (`EXIT=1` — the safe limit); **shared-memory concurrency** is absent (don't confuse it with supported OS sync).
- For the **cost** behind every ✅, see [ch 12 — Scope & scaling in depth](ch12-scope-and-scaling.md). For the **full matrix** with per-feature evidence, see the [support matrix reference](reference/SUPPORT_MATRIX.md). For the **predicates** you'll write specs with, see the [bestiary](reference/BESTIARY.md).
