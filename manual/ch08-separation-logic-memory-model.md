# Separation logic & the memory model

You do not need to learn separation logic to use QCP. You need to *read* it — enough to look at a `Require sll(p, l)` line and know what it claims about memory, and enough to recognize when a predicate says "these two things don't overlap." This chapter gives you exactly that reading fluency and stops there. It is not a course: for *why* the rules hold, or how to derive them, follow the tutorials — [T1 (representation predicates)](../tutorial/T1-representation-predicates.md), [T3 (assertions & invariants)](../tutorial/T3-assertion-and-invariant.md) — and [qua.codes](https://qua.codes), which teach the mechanics from first principles. Here you get the practitioner's mental model: what the heap is, what a predicate is a picture of, and the handful of memory-model facts that quietly bound what QCP can prove about your C.

A tier-1 C programmer can work in QCP at autopilot without any of this — write specs, let the strategy solver discharge the routine VCs, and let the LLM draft the remaining manual proofs. Read this chapter when a predicate's shape stops being obvious, or when you want to know *why* a particular kind of C (floats, shared memory) is off the table. The body stays at the C / annotation level; Rocq (formerly Coq) detail is folded into 🟣 `<details>` blocks you can skip.

## The one idea: assertions describe *memory*, not values

An ordinary C assertion (`assert(x > 0)`) talks about a *value*. A QCP assertion talks about *memory* — which addresses you own, what they hold, and how those regions relate. That is the whole shift. Once you read every predicate as "I own this chunk of the heap, and here's its shape," the rest follows.

The heap, in QCP's model, is a map from addresses to cells. An assertion carves out a *piece* of that heap and describes it. When you write a precondition, you are saying: "the function owns exactly this much memory on entry, laid out like this." The postcondition says what it owns on exit. Everything between is bookkeeping the tool does for you.

## `*` vs `&&` — the false friend, recapped

The full operator table lives in the [R1 bestiary](reference/BESTIARY.md#1-operators--connectives--read-this-box-first); this is the one-line recap. In an annotation, **`*` is separating conjunction** — it joins two pieces of the heap and asserts they are **disjoint** — while **`&&` is ordinary conjunction**, joining heap-independent **pure** facts (`x >= 0`, `Zlength(l) == n`) that make no ownership claim. `data_at(p, int, v)` is a **storage predicate** — it claims one typed cell at `p` holding `v` ([R1 §3](reference/BESTIARY.md#3-storage-primitives--data_at-store-and-the-crocq-map)):

```c
exists v, v >= 0 && data_at(p, int, v) * data_at(q, int, v)
//          └─ pure (&&): v ≥ 0 ─┘        └─ spatial (*): p and q are DISJOINT cells ─┘
```

> **Warning:** `*` joining memory is the gateway misread. If a spec looks like it's "multiplying" two predicates, it isn't — it's asserting they live in disjoint memory. Every time you see `*` between two storage predicates, read "and, separately."

## The heap, `emp`, and disjointness

Three intuitions carry almost all the weight.

**The heap is a piece you own, not the whole address space.** A precondition describes *only* the memory the function touches. A function that walks a linked list owns the list's nodes — not the rest of the program's memory. This "own exactly what you need" discipline is what makes the proofs local: you reason about your piece, and the tool *frames* the rest (carries it through untouched) automatically.

**`emp` is the empty heap — owns nothing.** A pure-arithmetic function owns no memory at all, so its spec ends in `emp`:

```c
// QCP_examples/QCP_demos_human/simple_arith/abs.c
/*@ Require INT_MIN < x && x <= INT_MAX && emp
    Ensure  ... && emp */
```

`emp` is not "nothing is true" — the pure facts (`INT_MIN < x`) still hold. It means "the heap I own is empty." Many pure-arithmetic specs look exactly like this: some pure constraints `&&`-joined, then `emp`.

**Disjointness is the point of `*`.** When you write `sll(w, l1) * sll(v, l2)`, you are claiming two list segments that share no memory — `w`'s nodes and `v`'s nodes are entirely separate. This is what lets QCP reason about, say, splicing one list into another without worrying that you've accidentally aliased a node. The separating conjunction *bakes the non-aliasing assumption into the spec* — and the tool will hold you to it: if your code makes them overlap, the proof goes red.

Here is the splice-style invariant from the shipped reverse example, where `*` separates the already-reversed prefix from the not-yet-reversed suffix:

```c
// QCP_examples/QCP_demos_human/sll.c — reverse loop invariant (abridged)
/*@ Inv exists l1 l2, l == app(rev(l1), l2) && sll(w, l1) * sll(v, l2) */
```

The `*` is the promise that `w`'s segment and `v`'s segment never touch — which is exactly the fact the proof needs to move a node from one to the other.

## Representation predicates are memory *shapes*

A **representation predicate** is a named picture of how a data structure sits in memory. You do not write the picture out cell by cell — you name it (`sll`, `IntArray::full`, `store_string`) and the predicate expands to the byte-level layout under the hood. This is the abstraction that lets you spec "a linked list holding `l`" instead of a page of `data_at` cells.

Three families cover most code:

- **Linked structures** — `sll(p, l)` is "a singly-linked list starting at `p` holding the logical list `l`." `store_tree`, `store_dll` (doubly-linked), `store_queue` are the same idea for other shapes. These are *recursive*: a list is a node `*` (separately) the rest of the list.
- **Arrays** — `IntArray::full(p, n, l)` is "a length-`n` `int` array at `p` whose exact contents are `l`." The array family is QCP's strongest built-in: `full`/`seg` carry exact contents, the `*_shape` variants (`full_shape`, `seg_shape`) assert the memory exists with values unconstrained, and the `undef_*` variants (`undef_full`, `undef_seg`) mark it uninitialized — so an invariant can say "this prefix is written, that suffix is not." See [R1 §5](reference/BESTIARY.md#5-the-array-predicate-family-the-strongest-built-in) for the full variant list (including the `missing_i` strategy carve-out).
- **Strings** — `store_string(p, s)` is a null-terminated C string at `p` with logical content `s` (the terminator is implicit). It's sugar over `CharArray::full` plus the trailing `0`.

The key reading skill: a predicate name *stands for* a disjoint bundle of memory cells, joined by `*`. When you see `sll(p, l)`, picture the nodes, each owning a `data` cell and a `next` cell, all separate, chained to `NULL`. You rarely unfold this by hand — the `which implies` hint and the solver do it — but knowing the shape is what makes a stuck goal legible.

> 🔵 **Tier 2** — When a goal won't close, it's often because a predicate needs *unfolding* into its cells (open one list node) before the cells line up with what you're reading or writing. That's what `which implies` does. You'll read the unfolded form in `*_proof_manual.v`; the shape below is what it expands to.

<details><summary>🟣 Rocq detail: what <code>sll</code> actually is</summary>

The C-level `sll(p, l)` is sugar for a Rocq `Fixpoint` of type `Assertion`. The shipped definition (`SeparationLogic/examples/QCP_demos_human/sll_lib.v:24`):

```coq
Fixpoint sll (x: addr) (l: list Z): Assertion :=
  match l with
    | nil     => “ x = NULL ” && emp
    | a :: l0 => “ x <> NULL ” &&
                 EX y: addr,
                   &(x # "list" ->ₛ "data") # Int |-> a **
                   &(x # "list" ->ₛ "next") # Ptr |-> y **
                   sll y l0
  end.
```

Read the C↔Rocq map ([R1 §3](reference/BESTIARY.md#3-storage-primitives--data_at-store-and-the-crocq-map)): `*`↔`**`, `exists`↔`EX`, `emp`↔`emp`, and a pure proposition `P` is written `[| P |]` in tutorials or `“ P ”` (smart quotes) in the generated `*_goal.v` files. The empty list is the *empty heap* (`emp`) with a pure null-pointer fact; the cons case owns a `data` cell `**` (separately) a `next` cell `**` (separately) the rest of the list. The `**` chain is the disjointness made literal. `Assertion` describes only *memory* — globals and struct fields down to bytes. In the **basic** assertion form a C local enters an assertion through its **address/cell** (`data_at(&x, x_v)` — the cell at `&x`), not as a bare program-variable name. The **concise** form lets you skip that: you can write `sll(v, l2)` with the program variable `v` directly, and QCP desugars it to the basic `exists v_v, data_at(&v, v_v) * sll(v_v, l2)` for you ([T3](../tutorial/T3-assertion-and-invariant.md)). The reverse-loop invariant above uses exactly this concise form.

</details>

## The memory model — the quiet boundary

Behind the predicates is a concrete memory model, and a few of its choices bound what C you can verify. None of these will surprise you in everyday code, but each is a hard edge worth knowing.

**The heap is a flat map of bytes.** Memory is `address → cell` — no segmentation, no provenance tracking, no separate "objects."

**Cells carry full-or-no permission.** A cell is in one of three states: *no permission* (you don't own it), *uninitialized* (you own it but it holds no value yet), or *holds a byte*. Crucially, ownership is **all-or-nothing** — there is no notion of owning "half" a cell. When two heap pieces combine, every address belongs to *at most one* of them; you can never have two pieces that both hold the same live cell. This is the model's most consequential choice, and it is the direct reason shared-memory concurrency is unsupported (below).

<details><summary>🟣 Rocq detail: the three-state cell and why there are no fractional permissions</summary>

`SeparationLogic/SeparationLogic/Mem.v:43` defines a cell as a three-constructor inductive (and at `Mem.v:57`, memory as a total function from address to cell — where both `addr` and `byte` are `Z`):

```coq
Inductive mem_var :=
  | Noperm (* No permission *)
  | Noninit (* Non-initialized *)
  | value (b: byte) (* assign to a byte *)
.
Definition mem : Type := addr -> mem_var.
```

The relation that combines two heaps into one (`mem_join`, `Mem.v:104`) is what makes ownership exclusive: at every address, at least one of the two sides must hold *no permission*. There is no case where both sides hold a live `value`. A *fractional* permission model would add exactly such a case — two readers each owning a share of one cell — and this model has none. So a cell is owned by one piece or the other, never split. This is the formal shape of "full-or-no permission": separating conjunction `**` corresponds to this disjoint join, so `P * Q` literally means "`P` and `Q` own non-overlapping cells." With no way to split a cell, two threads can't each hold a partial claim on shared state — which is the direct reason shared-memory concurrency is unsupported (see the concurrency note below).

</details>

**Pointers are ~32-bit (ILP32).** A pointer is four bytes in the model — a hard choice that is *wrong for 64-bit targets*, with no flag to widen it.

<details><summary>🟣 Rocq detail: <code>sizeof_ptr</code></summary>

`SeparationLogic/SeparationLogic/CNotation.v:54` fixes the pointer width as an axiom:

```coq
Axiom sizeof_ptr: sizeof_front_end_type FET_ptr = 4.
```

The array library (`ArrayLib.v`) rewrites with `sizeof_ptr` to compute pointer-array layouts, so the 4-byte width propagates into every `PtrArray` and pointer-cell calculation.

</details>

**Struct padding is not modeled.** QCP treats the padding bytes between struct fields as owning *no* memory — they're `emp`. You spec the fields you name; the gaps are invisible to the proof.

<details><summary>🟣 Rocq detail: <code>struct_padding = emp</code></summary>

`SeparationLogic/SeparationLogic/CommonAssertion.v:464`:

```coq
Definition struct_padding (x : lvalue_expr) (struct_name : string) : CRules.expr := emp.
```

Padding contributes the empty heap. The practical consequences: you cannot reason about what's *in* the padding, and you cannot do alignment- or layout-dependent tricks (reinterpreting a struct's bytes, reading the gap). For ordinary field-by-field access this is exactly what you want — the padding never gets in your way.

</details>

These four facts — flat byte heap, full-or-no permission, ~32-bit pointers, padding-as-`emp` — are the model. They are also why the support matrix says what it does.

## Why this model rules some C out

The memory model isn't only background; two hard scope lines follow directly from what you've now read:

- **Full-or-no permission is *why* shared-memory concurrency can't be expressed.** Two threads writing shared state would need *fractional* (splittable) permissions so each could hold a partial claim on the same cell — and `mem_join` has no such case. So shared-memory concurrency is unsupported. (See [ch 13](ch13-honest-limits.md) for the full verdict and the OS-synchronization distinction.)
- **No float in the byte/value model is part of *why* floats are off-limits — but the failure is silent, not clean.** The core type model has no float case and the shipped Rocq layer defines no `fp32` symbols, so a float can't be stored or its obligations discharged. Yet the closed `symexec` *accepts* float code and **exits 0**, emitting IEEE VCs that nothing downstream can compile — so a clean `symexec` run on float code is **not** success. This silent half-stub is the dangerous case ([ch 13](ch13-honest-limits.md)).

`goto` and function pointers are also unsupported, but for a different reason — no construct in the open library, not a memory-model limit. The full matrix and its evidence live in [ch 3](ch03-scope-at-a-glance.md) and [R2](reference/SUPPORT_MATRIX.md).

## The `Z` reminder: values are unbounded math integers

Annotation integers are `Z` — **unbounded mathematical integers**, not fixed-width C `int`s — and that shapes every spec you write. This is a value-, not memory-fact: the heap stores bytes, but the *logical* contents you reason about are arbitrary-precision.

This is why `abs.c` opens with `INT_MIN < x && x <= INT_MAX`: you are *manually* re-imposing C's bounds on Rocq's unbounded `Z`. There is no automatic overflow checking — every integer result you care about needs a manual range bound. This is the recurring effort tax ([ch 12](ch12-scope-and-scaling.md)); the memory model doesn't pay it for you. ([R4 glossary](reference/GLOSSARY.md) has the "Rocq types in C terms" cheat — forward link; R4 ships in a later wave.)

## What to take away

- A QCP assertion describes **memory** — which heap you own and its shape — not values alone. Read every predicate as "I own this disjoint chunk."
- `*` is **separating conjunction**: two *disjoint* regions. `&&` joins **pure** (heap-independent) facts. `emp` is the empty heap. (Full operator table: [R1](reference/BESTIARY.md#1-operators--connectives--read-this-box-first).)
- **Representation predicates** (`sll`, `IntArray::full`, `store_string`) are named memory shapes — disjoint bundles of cells you name instead of writing out.
- The memory model is a **flat byte heap**, **full-or-no permission** (no fractional shares), **~32-bit (ILP32) pointers**, and **struct padding = `emp`**. These are hard model choices.
- Full-or-no permission is *why* **shared-memory concurrency is unsupported**. Floats are off-limits too, but **silently**: `symexec` accepts float code and exits 0, leaving an obligation nothing can discharge — never trust a clean float exit.
- Annotation integers are **`Z`**, unbounded — so every C overflow bound is yours to write by hand.

For deriving the separation-logic rules themselves, the tutorials — [T1 (representation predicates)](../tutorial/T1-representation-predicates.md) through [T4 (symbolic execution)](../tutorial/T4-symbolic-execution.md), and [T8 (function calls)](../tutorial/T8-function-call.md) — and [qua.codes](https://qua.codes) are the course. For what a green check over these VCs actually guarantees, see [ch 10 — Trust & soundness](ch10-trust-and-soundness.md). For the annotation syntax that puts these predicates to work, see [ch 6 — Annotations as specs](ch06-annotations-as-specs.md).
