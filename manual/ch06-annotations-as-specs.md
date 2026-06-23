# Annotations as specs

This chapter is your reference for the annotation language as a **spec tool** — the keywords you write, where each one goes, and what each one obligates QCP to prove. It is not a separation-logic course. When you need the *theory* behind the predicates — what `*` means, how a heap splits — follow the [tutorials](../tutorial/) and [qua.codes](https://qua.codes); for the memory model itself see [ch 8](ch08-separation-logic-memory-model.md). This chapter stays at the level of syntax-as-spec: you write **WHAT** the code does, and these annotations are how you say it.

Everything you write lives inside special C comments. A normal compiler ignores them; `symexec` reads them.

```c
int add(int x, int y)
  /*@ Require 0 <= x && x <= 100 && 0 <= y && y <= 100 && emp
      Ensure  __return == x + y && emp
   */
{ int z; z = x + y; return z; }
```

> **Note:** if your C uses the preprocessor (`#define`, macros), preprocess first with `cpp -C` — QCP natively handles only `#include`.

> **`*` is not multiply.** The single most common misread in QCP: inside an annotation, `*` is **separating conjunction** — it joins two *disjoint* regions of memory — never C multiplication and never logical “and”. Pure, heap-independent facts join with `&&`; spatial facts join with `*`.
>
> ```c
> exists v, v >= 0 && data_at(p, int, v) * data_at(q, int, v)
> //          └─ pure (&&): v ≥ 0 ─┘        └─ spatial (*): p and q are DISJOINT cells ─┘
> ```
>
> The full operator inventory lives in [R1 — the bestiary](reference/BESTIARY.md#1-operators--connectives--read-this-box-first).

---

## The function spec: `With` / `Require` / `Ensure`

A function specification is the spine of everything else. It has three parts: optional ghost variables (`With`), a precondition (`Require`), and a postcondition (`Ensure`).

```c
struct list *reverse(struct list *p)
  /*@ With (l: list Z)
      Require sll(p, l)
      Ensure  sll(__return, rev(l))
   */;
```

- **`Require P`** — what must hold when the function is entered. QCP assumes it.
- **`Ensure Q`** — what the function guarantees on exit. QCP must *prove* it.
- **`With (x: T)`** — a **ghost (logical) variable**: a value the *caller* picks, shared across both `Require` and `Ensure`. Above, `l` is the abstract list before reversal; the post says you get `rev(l)` back. Ghosts are how the pre and post talk about the same logical object.
- **`__return`** — the function's return value. Usable only in `Ensure`.
- **`x@pre`** — the value of `x` at entry. Use it in `Ensure` when the body mutates `x` but you need to refer to the original.

One rule trips people up: in a spec, a **parameter name means the value the caller passed**, not the local variable. You therefore **cannot take the address of a parameter** in a spec. (Internally QCP rewrites `sll(p, l)` into `exists p_v, data_at(&p, p_v) * sll(p_v, l)` for the body, but that is the tool's bookkeeping, not yours to write.)

**Every `Z` you write is unbounded.** A `Z` in a spec is an **unbounded mathematical integer**, not a fixed-width `int` — so any arithmetic result needs you to re-impose C bounds by hand. That is exactly why the shipped `abs` (`QCP_examples/QCP_demos_human/simple_arith/abs.c`) opens its `Require` with the bound, not a bare type:

```c
int abs(int x)
  /*@ Require
        INT_MIN < x &&
        x <= INT_MAX && emp
      Ensure
        __return == Zabs(x) && emp
   */
```

There is no overflow automation; the bound is part of the spec you own.

### Why `With` is its own keyword

`With` is universal quantification over the *whole triple* `{Pre} f {Post}`, not a `forall` trapped inside one assertion — and because a ghost must appear in both `Require` and `Ensure`, it needs its own triple-level keyword. The full quantifier triad — `With` (∀-over-triple), `forall` (∀-in-assertion), `exists` (∃-in-assertion) — and the **∀-in / ∃-out** motion are laid out in [R1 §2](reference/BESTIARY.md#2-the-quantifier-triad--with---forall---exists-).

---

## In-body annotations: `Assert` and `Inv`

Annotations interleave with statements. Two kinds fix the symbolic state at a program point.

**`Assert`** pins the state at one spot. `symexec` records a verification condition (a **VC** — an entailment that the strategy solver discharges automatically, or that a written Rocq proof closes and the kernel re-checks at `Qed`) that the *prior* state implies your asserted state, then continues from your assertion. Use it to re-shape the state into the form a later step needs.

**`Inv`** marks a **loop invariant** — the assertion that holds before each test of the loop condition. This is the single most important in-body annotation, because `symexec` does **not** infer invariants: you (or the LLM you direct) supply one, and the tool *checks* it two ways — that the precondition establishes it (`P → I`) and that the body preserves it (`I → I`). A stuck loop goal is usually a missing or too-weak invariant rather than a tool limitation — but "usually" is not "always"; [ch 11](ch11-stuck-goal-differential.md) gives the full four-cause differential (and [ch 7](ch07-invariants-and-the-ai-dial.md) covers delegating invariants to the LLM). The canonical surface spelling is `Inv Assert` (dominant in the corpus); a bare `Inv` is the equally-valid shorthand — here from `QCP_examples/QCP_demos_human/sll.c`:

```c
/*@ Inv exists l1 l2,
         l == app(rev(l1), l2) &&
         sll(w, l1) * sll(v, l2)
   */
while (v) { ... }
```

A lightweight variant, **`... by local`**, exports one local type or range fact into the symbolic state without re-stating the whole assertion. `gcd.c` uses it to feed the missing upper bound into a recursive arithmetic proof:

```c
/*@ x <= INT_MAX by local */
```

---

## Forward hints: `which implies`

When you know the current state can be strengthened or *unfolded* — most often to expose a predicate's contents — say so inline with `which implies`. The left side must follow from the current state; the right side becomes the new state, and QCP emits the matching VC. The classic use is opening one node of a non-empty list (from `sll.c`):

```c
/*@ exists l2, p != 0 && sll(p, l2)
    which implies
    exists l3, l2 == cons(p -> data, l3) && sll(p -> next, l3)
 */
```

This turns "`p` points to *some* non-empty list" into "`p` is a head cell `p -> data` followed by a shorter list `sll(p -> next, l3)`" — the shape the body needs before it reads `p -> data`. Think of `which implies` as a hand-applied rewrite that bridges the gap between what the solver currently knows and what the next statement requires.

---

## Function calls: `where`

At a call site, QCP auto-instantiates the callee's ghost variables and frames the heap. When it cannot infer an instantiation, give it one with a `where` clause — here from `QCP_examples/QCP_demos_human/avl_insert.c:111`:

```c
struct tree *temp = rotateR(root) /*@ where l=r1 */;
```

You supply value arguments before an optional `;`, and type arguments after it (`where l = l0, storeA = storeInt; A = Z`). A function may also carry **multiple specifications** at different abstraction levels — exactly one is verified against the body, and the rest must be *derivable* from that one. Pick which spec a call uses with `where (high_level_spec) …`. The full multi-spec mechanics (including the magic-wand derivation pattern) live in [R1 §7](reference/BESTIARY.md#7-spec--in-body-annotation-keywords).

---

## The in-body and call-site keywords at a glance

| Keyword | You write | QCP obligation | Typical use |
|---|---|---|---|
| `Assert ...` | a full target state | prior state `|--` your assertion | re-shape the state for a later step |
| `Inv ...` | the loop invariant | `P → I` **and** `I → I` | every loop (required — not inferred) |
| `which implies` | a left → right rewrite | left follows from state; emit right | unfold a predicate (open a list node) |
| `where ...` | ghost/type instantiations | none from the hint itself — but the call still has its usual callee-precondition / frame / postcondition VCs | a call QCP can't auto-instantiate |

---

## The storage surface: `store(...)`, typed compounds, and `data_at`

A **storage predicate** says "this address holds this value." There is more than one spelling, and what the *corpus* uses differs from what the tutorials show — so know both.

**What the corpus actually writes.** The dominant form is the generic **`store(addr)`** predicate, e.g. `store(&(tail->data))` or `store(field_addr(t, next))` — a cell whose type is fixed by context. For a cell that exists but has **not** been written yet, the corpus uses **`undef_data_at(...)`**, e.g. `undef_data_at(&(node->next), struct list*)` or the bare `undef_data_at(&(list -> pstNext))` — you can't load from it until something writes it. On top of those sit the **typed compound predicates** that describe whole data structures — `store_tree`, `store_string`, `store_term`, `store_dll`, and so on. These are **representation predicates**: they describe the *shape* of data in memory; their theory belongs to [ch 8](ch08-separation-logic-memory-model.md), and the full family inventory to [R1 §4–§6](reference/BESTIARY.md#4-representation-predicates--the-data-shape-inventory).

To see how often each appears in the current example tree (which regenerates, so any count is a snapshot), count them yourself — for example:

```bash
grep -rhoE '\bstore\(' QCP_examples --include='*.c' --include='*.h' | wc -l
grep -rhoE '\bundef_data_at\(' QCP_examples --include='*.c' --include='*.h' | wc -l
```

At one such snapshot `store(...)` led with several hundred uses and `undef_data_at(...)` trailed it by roughly an order of magnitude — the takeaway is the ordering, not the exact integers.

> **Note:** `store_int(...)` is a **qua.codes / tutorial-website** spelling — it appears **zero** times in `QCP_examples/`. Don't reach for it when working from the corpus; use `store(...)` or a typed compound. It is one of the documented copy-from-the-tutorial traps.

### The three `data_at` shapes

`data_at` is valid hand-written syntax in three shapes — all things a user *types*. But **bare `data_at(` is essentially absent from the corpus C** (zero occurrences at the snapshot checked); it lives in the tutorials, while the corpus prefers `store(...)` and `undef_data_at(...)`. Treat these as syntax you'll *read* more than write:

| Shape | Form | Means | Where |
|---|---|---|---|
| **typed 3-arg** | `data_at(p, int, v)` / `data_at(p, int*, v)` | `p` holds typed value `v` | tutorial T2 |
| **basic 2-arg** | `data_at(&x, v)` | the address of `x` holds value `v` | tutorials T3/T4 |
| **concise value-omitted** | `data_at(&node->next, struct list*)` | value left implicit | tutorials |

The 2-arg shape also shows up in `symexec`'s symbolic-state dumps (`data_at(&p, p_v)`) — but that does **not** make it "internal only"; it is equally valid basic annotation syntax. When you mean a specific shape, name which. This is the curated subset, not the catalog: the full storage-primitives inventory is in [R1 §3](reference/BESTIARY.md#3-storage-primitives--data_at-store-and-the-crocq-map).

### Basic vs concise assertions

The same fact can be written two ways:

- **Basic** — you spell out storage for *every* program variable, e.g. `exists v_v, data_at(&v, v_v) * sll(v_v, l2)`. Rigorous and verbose. Expressions must be **effect-free**: write `data_at(&x, x_v)`, never a bare read of `x`.
- **Concise** — sugar that lets you name the program variable directly (`sll(v, l2)`) and lets a sub-expression like `v -> data` imply the storage read it needs. QCP desugars concise → basic internally.

Most corpus examples — including every `sll.c` snippet above — use the concise form. Reach for basic only when you need to control the exact storage shape.

---

## Connecting to Rocq: `Extern Coq`, `Import Coq`, `include strategies`

When the predicate or function you want isn't already in scope, three directives bring it in from the proof assistant. A terminology note first, because it bites:

> 🔵 **The prover is "Rocq"; the keywords still say "Coq."** The proof assistant QCP targets is **Rocq** (formerly named Coq) — that is the name to use in prose. But the *literal directive keywords* in the annotation syntax are still spelled `Extern Coq` and `Import Coq`. The corpus is unanimous on this: every directive uses the `Coq` spelling, and `grep -rE '\bExtern Rocq\b|\bImport Rocq\b' QCP_examples` returns nothing. Write the keywords exactly as they appear — `Coq`, not `Rocq` — even though you call the prover Rocq in prose.

| Directive | What it does |
|---|---|
| `/*@ Extern Coq (name : type) */` | declare a Rocq function, predicate, or type so annotations can name it |
| `/*@ Import Coq Require Import <Module> */` | pull in a Rocq library module (its definitions and lemmas) |
| `/*@ include strategies "<file>.strategies" */` | load the solver strategies that auto-discharge VCs about those predicates |

In practice these live in a shared `*_def.h` header so a whole project declares its vocabulary once. A representation predicate is typically introduced with all three together:

```c
/*@ Extern Coq (sll : {A} -> (Z -> A -> Assertion) -> Z -> list A -> Assertion) */
/*@ Import Coq Require Import poly_sll_lib */
/*@ include strategies "sll.strategies" */
```

The shipped `abs.c` shows the smallest case — `Extern Coq` *declaring a name* (a single Rocq function) so the spec can mention it; it imports no library and ships no lemmas:

```c
/*@ Extern Coq (Zabs: Z -> Z) */
```

`verification_list.h` (`QCP_examples/QCP_demos_human/verification_list.h`) is the same kind of file — pure `Extern Coq` declarations of `nil`/`cons`/`app`/`rev`/`Zlength`, names only, no `Import Coq`. Keep the two directives straight: `Extern Coq` introduces a *name*; `Import Coq` pulls in a *library module* (definitions **and** lemmas). One more constraint worth stating plainly: `Assertion` — the type of a representation predicate — can describe memory, globals, and structs down to bytes, but **cannot** mention local variables.

> 🔵 **Tier 2** — `Import Coq` is how you reach the lemmas you'll cite by hand in `*_proof_manual.v`. The imported module (e.g. `/*@ Import Coq Require Import poly_sll_lib */` in `poly_sll_def.h`, or `functional_queue_lib`) is your lemma toolbox.

> 🟣 **Tier 3** — `include strategies` is the auto-solving lever: a `.strategies` rule discharges a class of VC for every future call. Defining new predicates and writing the strategy rules that make them auto-solve is [ch 14](ch14-extension.md)'s subject.

---

## A checklist for annotating a function

1. Include the headers your annotations use — e.g. `verification_stdlib.h` for common utilities, plus the relevant data-structure `*_def.h` (`sll_def.h`, `int_array_def.h`, …). Many shipped files need only the one `*_def.h` they build on.
2. If you need a predicate or Rocq function not yet in scope, `Extern Coq`-declare it and `Import Coq` its library.
3. Write the spec: `With` ghosts, `Require` pre, `Ensure` post (use `__return`, `x@pre`). Re-impose C bounds on every `Z` result by hand.
4. Add an `Inv` for **every** loop; add `Assert` / `which implies` where `symexec` needs help unfolding a predicate.
5. Use `where` at call sites QCP can't auto-instantiate.
6. Run `symexec`; inspect the VCs; let strategies auto-discharge the routine ones and prove the rest (see [ch 9](ch09-goals-symexec-and-proof.md)).

---

## What to take away

The checklist above is the procedure; these are the judgment calls that bite hardest:

- **Every `Z` is unbounded.** A `Z` in a spec is a mathematical integer, not a C `int` — there is no overflow automation, so re-impose C bounds on every arithmetic result by hand.
- **Know both storage spellings.** The corpus surface is `store(...)` and `undef_data_at(...)` plus typed compounds — **not** the qua.codes-only `store_int`, and rarely bare `data_at`. Reading the tutorials and the corpus shows you two different vocabularies for the same thing.
- **The prover is Rocq; the keywords say `Coq`.** Write `Extern Coq` / `Import Coq` / `include strategies` literally, even though the proof assistant's name is **Rocq**.
- **`symexec` generating goals is not a finished proof.** Routine VCs are auto-discharged by the strategy solver (trusted, not re-checked); the rest land in `*_proof_manual.v` for a written Rocq proof. For what a passing check actually guarantees — the two-tier trust story — see [ch 10](ch10-trust-and-soundness.md).

For the full predicate and operator inventory, see [R1 — the bestiary](reference/BESTIARY.md). For *why* these predicates mean what they mean — the separation logic and memory model — see [ch 8](ch08-separation-logic-memory-model.md) and the [tutorials](../tutorial/). For writing your own predicates and strategies, see [ch 14](ch14-extension.md). For delegating invariants and proofs to the LLM, see [ch 7](ch07-invariants-and-the-ai-dial.md).
