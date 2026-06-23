# Reference — Glossary

> Plain-language definitions of the terms used across this manual, in the canonical wording.
> Each entry is a one-line gloss plus a pointer to the chapter or reference page that treats it
> in full. When two terms are easy to confuse (`*` vs `&&`, `Z` vs `int`, auto vs manual,
> `Admitted` vs `Qed`), this page disambiguates them side by side. For *why* separation logic
> behaves as it does, follow the [tutorials](../../tutorial/) or qua.codes — this is a reference,
> not a course.

The list is alphabetical. A handful of pairs that are only meaningful together (`Require` /
`Ensure`, `auto` / `manual`, `Admitted` / `Qed`) are defined as a pair under the first member.

---

## A

**`Admitted` / `Qed`** {#admitted-qed} — the two ways a Rocq lemma can end, and the line between
*solver-settled* and *kernel-checked*. A proof that ends in `Qed` is fully re-elaborated by the
Rocq kernel; a lemma that ends in `Admitted` is accepted **without** a re-checked proof. QCP uses
the split deliberately: auto VCs in `*_proof_auto.v` end in `Admitted` (the strategy solver
settled them; its result is accepted without a re-checkable certificate), and manual VCs in
`*_proof_manual.v` end in `Qed` (kernel-checked). The auto `Admitted` is expected, not a hole —
it records solver-verified reasoning. An `Admitted` in a *manual* file or case lib is the one
genuine watch-item — a real unproven hole. See [ch 10](../ch10-trust-and-soundness.md).

**AI dial** {#ai-dial} — the amount of work you delegate to the LLM, turned up or down. It is a **dial, not
a tier**: every tier 🟢🔵🟣 runs it high or low. Dial up and the LLM drafts the loop invariants
and the manual proofs (you review them); dial down and you write more by hand. See
[ch 7](../ch07-invariants-and-the-ai-dial.md).

**Annotation** — a `/*@ ... @*/` comment carrying formal spec content for `symexec` (a spec, a
loop invariant, an assertion, a hint). Plain C comments to a human reader; load-bearing input to
the tool. See [ch 6](../ch06-annotations-as-specs.md).

**`@pre` (`x@pre`)** — inside `Ensure`, the value of `x` as it was at function entry. Lets a
postcondition relate the result to the original inputs. See
[R1 §7](BESTIARY.md) and [ch 5](../ch05-your-first-spec.md).

**`Assert`** — an in-body annotation that **fixes the symbolic state** at a program point
(emitting a [VC](#v) that the state so far implies it). Use it to pin down what you believe is
true mid-function. Not a runtime check. See [R1 §7](BESTIARY.md).

**auto / manual (fraction)** — the two pools every [VC](#v) falls into. **Auto** = VCs
`symexec`'s [strategy solver](#strategy) discharges on its own (land in `*_proof_auto.v`, end in
`Admitted` — accepted without a re-checkable certificate, but solver-verified, not a hole).
**Manual** = VCs that need a written Rocq proof (land in `*_proof_manual.v`, end in `Qed`,
kernel-checked). "Manual" means *needs-a-Rocq-proof*, **not** *a human must type it* — with the
AI dial up the LLM drafts most manual proofs and you review them. Roughly a quarter to a third of
proof effort is manual on average. See [ch 10](../ch10-trust-and-soundness.md) and
[ch 12](../ch12-scope-and-scaling.md).

## C

**case lib (`*_lib.v`)** — the Rocq library for one verified case: its representation predicates,
spec definitions, and helper lemmas. Like a manual proof file, it is meant to be free of
`Admitted`/`Axiom`. See [ch 9](../ch09-goals-symexec-and-proof.md).

## D

**`data_at`** {#data-at} — a **storage predicate** ("this address holds this value"), written in
several shapes: typed 3-arg `data_at(p, int, v)`, basic 2-arg `data_at(&x, v)`, and concise
value-omitted `data_at(&(node->next), struct list*)`. In the example corpus the equivalent
storage is usually written with `store(...)` or `undef_data_at(...)` instead; bare `data_at(` is
rare in corpus C. See [`store(...)`](#store) below and [R1 §3](BESTIARY.md) for the full shape
table.

## E

**`Ensure`** — see [`Require` / `Ensure`](#require-ensure).

**entailment (`P |-- Q`)** {#entailment} — "every state satisfying `P` also satisfies `Q`." This is the shape
of every VC: a separation-logic implication from a precondition `P` to a postcondition `Q` (of
the entailment, not necessarily of the function). See [ch 9](../ch09-goals-symexec-and-proof.md).

**`Extern Coq` / `Import Coq`** — annotation directives that connect C annotations to Rocq.
`Extern Coq (name : type)` *declares* a Rocq predicate/function/type for use in annotations;
`Import Coq Require Import <Module>` pulls in a Rocq library module. (The keyword stays spelled
`Coq` even though the prover is now Rocq — it is a literal token.) See
[ch 6](../ch06-annotations-as-specs.md) and [R1 §8](BESTIARY.md).

## G

**ghost / logical variable** — a variable that exists only in annotations (e.g. the abstract
`list Z` a linked list represents), never in the compiled C. The `With` clause introduces
ghost variables. See [`With`](#with) and [R1 §2](BESTIARY.md).

**`goal_check` (`*_goal_check.v`)** — the **completeness** gate: a generated module that checks
every emitted VC has **exactly one** entry (none dropped, none double-counted). A green
`goal_check.vo` means the VC set is *complete*, **not** that every VC was kernel-checked — an
`Admitted` entry satisfies the gate as readily as a `Qed` one. Completeness ≠ proof. See
[ch 10](../ch10-trust-and-soundness.md).

## I

**`Inv` (loop invariant)** — an assertion that holds before every test of a loop condition. You
(or the LLM) supply it; `symexec` does **not** infer it — it *checks* the one you give it. The
canonical surface spelling is `/*@ Inv Assert ... @*/`; bare `Inv` is also valid. See
[ch 7](../ch07-invariants-and-the-ai-dial.md) and [R1 §7](BESTIARY.md).

## O

**ordinary conjunction (`&&`)** — joins two **pure**, heap-independent facts ("both hold"); it
makes no claim about memory. Contrast with [separating conjunction (`*`)](#separating-conjunction). See
[R1 §1](BESTIARY.md).

**ownership predicate** — see [representation predicate](#representation-predicate).

## Q

**QCP (Qualified C Programming)** — the tool this manual is about: you annotate C with a spec and
ownership predicates, `symexec` symbolically executes it to emit verification conditions, and
those are discharged by the strategy solver and Rocq. The promise: you write **WHAT** the code
does; the **WHY** (loop invariants and proofs) is largely delegated. See
[ch 1](../ch01-what-qcp-is.md).

**`Qed`** — see [`Admitted` / `Qed`](#admitted-qed).

## R

**representation predicate** {#representation-predicate} — a Rocq predicate (type `Assertion`) describing how a data
structure is laid out in memory, e.g. `sll(p, l)` = "a singly-linked list at `p` holding the
abstract list `l`." Also called an **ownership** predicate: holding it means owning that memory.
The corpus ships many (`store_tree`, `store_string`, the array families, …). See
[R1 §4–§6](BESTIARY.md) and [ch 8](../ch08-separation-logic-memory-model.md).

**`Require` / `Ensure`** {#require-ensure} — the precondition / postcondition pair that, with `With`, forms a
function's spec triple. `Require P` states what must hold on entry; `Ensure Q` states what the
function guarantees on return. The spec is the **irreducible human-review point** — QCP proves
the spec you wrote, not the behavior you meant. See [ch 5](../ch05-your-first-spec.md) and
[R1 §7](BESTIARY.md).

**Rocq (formerly Coq)** — the proof assistant the VCs are discharged in (required version
**8.20.1**). Coq was renamed Rocq; this manual says "Rocq" in prose but keeps the literal tokens
spelled `Coq` (`coqc`, `Extern Coq`, `Import Coq`, `_CoqProject`). See
[ch 9](../ch09-goals-symexec-and-proof.md).

**`__return`** — inside `Ensure`, the function's return value. See [R1 §7](BESTIARY.md).

## S

**separating conjunction (`*`)** {#separating-conjunction} — **THE #1 false friend.** In an annotation, `*` joins two
**disjoint** memory regions ("the heap splits into a part for `P` and a separate part for `Q`").
It is **not** C multiplication and **not** logical "and." Pure facts join with `&&`; spatial
facts join with `*`. The Rocq form is `**`. See [R1 §1](BESTIARY.md) and
[ch 8](../ch08-separation-logic-memory-model.md).

**separation logic (SL)** — the logic QCP reasons in: a logic for heap and pointer programs whose
key operator, the separating conjunction `*`, asserts that two memory regions are disjoint —
which is what makes pointer reasoning tractable. You can use QCP at tier 1 without studying it;
for the theory, follow the [tutorials](../../tutorial/). See
[ch 8](../ch08-separation-logic-memory-model.md).

**`-slp` vs `-I`** — two distinct `symexec`/`StrategyCheck` path flags, not interchangeable:
`-slp` resolves `.strategies` files and Rocq logical paths; `-I` resolves C `#include`s. See
[R3 invocation anatomy](INVOCATION.md) for the full flag semantics.

**`store(...)`** {#store} — the corpus's common **storage predicate**: a typed-by-context memory
cell, e.g. `store(&(q -> tail), ...)`. It is the form you'll most often see in worked examples
(≈436 uses in the example corpus), alongside `undef_data_at(...)` for uninitialized cells.
Conceptually the same job as [`data_at`](#data-at). See [R1 §3](BESTIARY.md).

**strategy / `.strategies` / `StrategyCheck`** {#strategy} — the automation extension point. A **strategy**
is a user-authored rewrite/cancellation rule (in a `.strategies` file) the solver uses to
discharge routine VCs automatically; the 50+-rule strategy library is what drives the auto
fraction. **`StrategyCheck`** is the binary that emits Rocq soundness obligations for those
rules — most close with `Qed` and are re-checked, a small named residue is `Admitted`. See
[ch 14](../ch14-extension.md) and [R3](INVOCATION.md).

**symbolic execution / `symexec`** — running the program over **symbolic** (abstract) values,
carrying a separation-logic assertion as the program state, to derive the VCs. `symexec` is the
binary that does this and writes the four generated files. See
[ch 9](../ch09-goals-symexec-and-proof.md) and [R3](INVOCATION.md).

## T

**tiers (🟢 / 🔵 / 🟣)** — the three depths QCP is used at, an **overlay** on shared content (not
separate tracks): 🟢 **Tier 1** — C programmer, no Rocq, autopilot; 🔵 **Tier 2** — reads and
fixes the manual proofs; 🟣 **Tier 3** — SL/Rocq expert who writes new predicates and strategies.
The [AI dial](#ai-dial) is orthogonal to the tiers. See [ch 1](../ch01-what-qcp-is.md).

**Trusted Computing Base (TCB)** — the set of things a QCP "✔" rests on without re-checking: the
Rocq kernel, `unifysl`'s foundational axioms, `symexec`'s annotation→VC translation (unaudited —
the kernel checks proofs match the VCs, never that the VCs faithfully model your C), the strategy
solver, the few `Admitted` strategy rules, and your own annotations. See
[ch 10](../ch10-trust-and-soundness.md) for the full table.

**two-tier trust model** — the fact that a QCP "✔" is two things: manual VCs ending in `Qed` are
**kernel-checked**; auto VCs ending in `Admitted` are **solver-verified** — settled by the
strategy solver, whose result the kernel doesn't independently re-check. Relying on the auto path
is **trust-the-tool** (as with any verifier's automated core), **not** a soundness hole; the
`Admitted` there records solver reasoning, not an unproven guess. A green build is genuinely
strong but is **not** "every VC machine-checked end to end." The precise, true claim: a manual VC
is kernel-checked when, and only when, it ends in `Qed`. See
[ch 10](../ch10-trust-and-soundness.md).

## V

**verification condition (VC)** — a proof obligation emitted by symbolic execution, in the form
of an [entailment](#entailment) `P |-- Q`. Proving all of a function's VCs proves it meets its spec. Each
VC is either auto-discharged or proved manually. See [ch 9](../ch09-goals-symexec-and-proof.md).

## W

**`where`** — a call-site annotation that manually instantiates a callee's logical/type variables
when the solver can't infer them. See [R1 §7](BESTIARY.md).

**`which implies`** — an in-body **forward hint**: it states that the current symbolic state
implies a stronger or unfolded state, which then becomes the new state (e.g. opening up one node
of a linked list). It emits its own VC. See [R1 §7](BESTIARY.md).

**`With (x:T)`** {#with} — the spec-head clause that introduces a **ghost / logical variable**: a ∀ over
the **whole triple** {Pre} f {Post}, chosen by the **caller** and shared across both `Require`
and `Ensure`. Distinct from a `forall` (trapped in one assertion) and `exists` (a value the
**callee** produces). The motion is **∀-in / ∃-out**. See [R1 §2](BESTIARY.md).

**witness** — an individual VC, or the lemma that discharges it. In the generated files the VC
definition is named `<fn>_<kind>_wit_N` and the lemma proving it is `proof_of_<fn>_<kind>_wit_N`.
See [ch 9](../ch09-goals-symexec-and-proof.md).

## Z

**`Z`** — Rocq's type of **unbounded mathematical integers**. It is **not** a fixed-width C
`int`: it never overflows, so a `Z` result carries no automatic range/overflow bound. This is the
load-bearing source of the effort tax — every `Z` arithmetic result needs a **manual
range/overflow bound** (e.g. `abs.c` opens with `INT_MIN < x && x <= INT_MAX`). See
[ch 5](../ch05-your-first-spec.md) and [ch 12](../ch12-scope-and-scaling.md).

---

*See also:* the full predicate/operator inventory → [R1 Bestiary](BESTIARY.md); every
`symexec`/`StrategyCheck` flag → [R3 Invocation anatomy](INVOCATION.md); the support matrix →
[R2 Support matrix](SUPPORT_MATRIX.md); what the green check means → [ch 10](../ch10-trust-and-soundness.md).
