# Reference — The QCP Predicate & Operator Bestiary

> A **practitioner reference**, not a separation-logic course. It answers "what can I write in
> an annotation, and what does it mean?" — at a glance, with a corpus-verified specimen for
> each entry. For *why* `**` behaves as it does, follow the tutorials / qua.codes (link out).
> Surface counts are from `QCP_examples/` at commit `95437ee`; see `manual/FACTS.md` for the
> facts these rest on.

---

## 1. Operators & connectives — read this box first

The single most common misread in QCP is `*`. **`*` is separating conjunction, not C
multiplication and not logical "and."**

```c
exists v, v >= 0 && data_at(p, int, v) * data_at(q, int, v)
//          └─ pure (&&) ─┘             └─ spatial (*): p and q are DISJOINT cells ─┘
```

| Symbol (C annotation) | Name | Joins | Rocq form | Meaning |
|---|---|---|---|---|
| `*` | **separating conjunction** | two **disjoint** memory regions | `**` | "this heap splits into a part for `P` and a *separate* part for `Q`" |
| `&&` | **ordinary / pure conjunction** | heap-independent facts | `&&` | "both propositions hold" — no disjointness claim |
| `exists x,` | existential | — | `EX x,` | a value the **callee** supplies (∃-out) |
| `forall (i:T),` | universal (in one assertion) | — | `forall` | a pure fact over all `i` (e.g. every index in range) |
| `==` / `!=` | equality / inequality | — | `=` / `<>` | |
| `-*` | **magic wand** | — | `-*` | "memory that, combined with any `P`-memory, yields `Q`-memory" (used in multi-spec derivation) |
| `emp` | empty heap | — | `emp` | owns no memory |
| *(bare prop)* `P` | pure proposition | — | `[\| P \|]` *or* `“ P ”` | heap-independent; two Rocq spellings — `[\| P \|]` (tutorials) vs typographic `“ P ”` (generated `*_goal.v`) |

> 🟢 **Tier 1** — In practice you only need the top three rows fluently: `*` separates memory,
> `&&` joins facts, `exists` introduces a value. The rest you'll *read* before you *write*.

---

## 2. The quantifier triad — `With` (∀) · `forall` (∀) · `exists` (∃)

The most learnable slice of the "Rocq-in-disguise" surface: a C developer already owns ∀/∃ from
math. Learn **scope** (whole triple vs one assertion) and **direction** (caller-given vs
callee-produced), not new logic. Corpus frequency (`*.c`, snapshot ≈): `exists` (≈718) >
`With` (≈382) > `forall` (≈252).

| Keyword | Scope | Direction | Specimen |
|---|---|---|---|
| **`With (x:T)`** | the **whole triple** {Pre} f {Post} | **caller-given** (∀, for-any) | `With l  Require sll(p,l)  Ensure sll(__return, rev(l))` |
| **`forall (i:Z),`** | **inside one assertion** | for-any (pure) | `forall i, 0 <= i < n -> Znth i l 0 >= 0` |
| **`exists x,`** | **inside one assertion** (usually `Ensure`/`Inv`) | **callee-produced** (∃, there-is) | `Ensure exists l0, Permutation(l,l0) && increasing(l0) && sll(__return,l0)` |

- **The core motion = ∀-in / ∃-out.** The caller fixes the `With` ghosts going in; the callee
  produces the `exists` witnesses coming out.
- **Why `With` ≠ `forall`:** a `forall` is trapped inside one assertion, but a ghost variable
  must appear in **both** `Require` and `Ensure` (the same `l`), so the triple-level ∀ needs its
  own keyword. (Heritage from Rocq/VST — but heritage *with a reason*.)

> 🟣 **Tier 3** — `With {B} l0 (c: list Z -> program unit B) X` is the CPS/monadic form for
> higher-order/callback specs (QCP has no function pointers, so callbacks are encoded this way).
> Quarantined to advanced specs; it won't ambush tier-1 code.

---

## 3. Storage primitives — `data_at`, `store`, and the C↔Rocq map

**Reality check (verified):** `store_int(...)` is a **qua.codes/tutorial-website** spelling and
appears **zero** times in `QCP_examples/`. Note too that **bare `data_at(` is ≈0 in the corpus
C** — it is documented annotation syntax (tutorials / `docs/`), while the corpus's real storage
forms are `store(...)` and `undef_data_at(...)`:

| Form | Shape | Where / count | Note |
|---|---|---|---|
| `store(addr)` | generic typed-by-context cell | **corpus, ≈436** (`store(&(tail->data))`, `store(field_addr(t,next))`) | **the common one** |
| `undef_data_at(addr)` | uninitialized cell | **corpus, ≈78** (`undef_data_at(returnSize)`) | can't load until written |
| `data_at(p, int, v)` | typed 3-arg | tutorial T2 (**≈0 in corpus C**) | documented syntax |
| `data_at(&x, v)` | basic 2-arg address/value | tutorials T3/T4; **also** in symbolic-state dumps | documented; not "internal-only" |
| `data_at(&node->next, struct list*)` | concise value-omitted | docs/tutorials | corpus's nearest real form: `undef_data_at(&(node->next), struct list*)` |

**C ↔ Rocq notation map:**

| Meaning | C annotation | Rocq |
|---|---|---|
| separating conjunction | `*` | `**` |
| existential | `exists` | `EX` |
| equality / inequality | `==` / `!=` | `=` / `<>` |
| pure proposition | `P` | `[\| P \|]` or `“ P ”` |
| empty heap | `emp` | `emp` |
| 4-byte int storage | `data_at(p, int, v)` | `p # Int \|-> v` |
| pointer storage | `data_at(p, int*, v)` | `p # Ptr \|-> v` |
| magic wand | `-*` | `-*` |
| struct member | `p -> f` | `p ->ₛ "f"` *(keep the `ₛ`)* |
| pointer cast to struct | `(struct T*)x` | `x # "T"` |

---

## 4. Representation predicates — the data-shape inventory

A **representation predicate** describes how a structure is laid out in memory. It is defined in
Rocq (type `Assertion`) and *declared* into C with `Extern Rocq`. The common compound predicates
in the corpus (with surface counts):

| Predicate | Describes | Corpus uses |
|---|---|---|
| `sll(p, l)` / `sll(storeA, p, l)` | singly-linked list at `p` holding `l` (polymorphic form takes a store fn) | tutorials T1–T6, T8 |
| `store_tree(...)` | binary tree | ≈121 |
| `store_string(p, s)` | C string (see §6) | ≈115 |
| `store_term(...)` / `store_type(...)` | term/type structures (typeinfer, alpha_equiv) | ≈86 / ≈62 |
| `store_dll(...)` | doubly-linked list | ≈38 |
| `store_queue` / `store_map` / `store_solution` | queues, maps, SAT solutions | ≈32 / ≈24 / ≈32 |

**Declaring one** (`Extern Rocq` + `Import Rocq` + `include strategies`), typically in a `*_def.h`:

```c
/*@ Extern Rocq (sll : {A} -> (Z -> A -> Assertion) -> Z -> list A -> Assertion) */
/*@ Import Rocq Require Import poly_sll_lib */
/*@ include strategies "sll.strategies" */
```

Example Rocq definition (int list):

```coq
Fixpoint sll (x: addr) (l: list Z): Assertion :=
  match l with
  | nil    => [| x = NULL |] && emp
  | z :: l0 => [| x <> NULL |] && EX y: addr,
      &(x # "list" ->ₛ "data") # Int |-> z **
      &(x # "list" ->ₛ "next") # Ptr |-> y ** sll y l0
  end.
```

> 🟣 **Tier 3** — `Assertion` describes memory/globals/structs down to bytes but **cannot**
> mention local variables. New predicates + their `.strategies` are how you extend QCP (ch 14).

---

## 5. The array predicate family (the strongest built-in)

`ArrayLib.v` instantiates one predicate **module per element type**; in annotations each is a
`Module::name` namespace (verified `::` separator, e.g. `IntArray::full` ≈ 800 uses, snapshot):

| Module | C type | | Module | C type |
|---|---|---|---|---|
| `IntArray` | `int` | | `ShortArray`/`UShortArray` | `short`/`unsigned short` |
| `UIntArray` | `unsigned int` | | `Int64Array`/`UInt64Array` | 8-byte (un)signed |
| `CharArray` | `char` | | `PtrArray` | `T *` |
| `UCharArray` | `unsigned char` | | | |

Within **every** module the same predicates exist, across **three orthogonal axes**:

| Predicate | Tracks values? | Meaning |
|---|---|---|
| `TArray::full(p, n, l)` | yes | whole length-`n` array at `p`, exact contents `l : list Z` |
| `TArray::seg(p, lo, hi, l)` | yes | sub-range `[lo,hi)`, exact contents `l` |
| `TArray::full_shape(p, n)` / `seg_shape(p, lo, hi)` | no (shape only) | memory exists/accessible, values unconstrained |
| `TArray::undef_full(p, n)` / `undef_seg(p, lo, hi)` | uninitialized | block exists, not yet written |
| `TArray::missing_i(p, i, lo, hi, l)` (+ `_shape`, `undef_`) | yes (minus `i`) | strategy intermediate: one element carved out for read/write |

- **full vs seg** — whole array vs one contiguous sub-range. Use `seg` for double-pointer /
  multi-cursor / merge algorithms that split a buffer into adjacent logical pieces.
- **value vs shape** — `full`/`seg` carry an exact `list Z` (needed for `Znth`, `sublist`,
  `sum`, `Permutation`, sortedness); `*_shape` only asserts the memory exists. Pick `*_shape`
  when the goal never mentions element values.
- **initialized vs uninitialized** — the canonical loop-fill invariant is "written prefix
  (`seg`/`seg_shape`) + unwritten suffix (`undef_seg`)", starting from `undef_full`.

```c
// real corpus spec (sort): exact contents in, a sorted permutation out
Require Zlength(l) == n && IntArray::full(nums, n, l) * undef_data_at(returnSize)
Ensure  exists l1, Permutation(l, l1) && increasing(l1) && IntArray::full(__return, n, l1)
// loop invariant splits the buffer:  IntArray::seg(nums,0,i,l0) * IntArray::seg(nums,i,n,l2)
```

`missing_i` / `missing_i_shape` / `undef_missing_i` are strategy intermediates (one element
opened for access) — rarely written by hand.

---

## 6. String predicates

`string.h` (`Import Rocq … string_lib`) adds C-string predicates on top of `CharArray`:

| Predicate | For | Definition / note |
|---|---|---|
| `store_string(p, s)` | **mutable** C-string buffer (`char *`, `char a[]`) | sugar: `CharArray::full(p, string_length s + 1, c_string s)`, `c_string s = s ++ [0]`; logical `s` **excludes** the terminating `0` (≈115 corpus uses) |
| `store_stringLit(p, s)` | **read-only** string literal (`char *p = "abc"`) | literal kept as a Rocq `string`; writing through it is illegal — a writable `char a[]="abc"` must be `store_string`/`CharArray::full` |
| `GlobalStrings(LitMap)` | global string-literal table | `LitMap : string → addr` interning map |
| `GlobalStrings_missing(LitMap, l)` | the table with literals `l` split out | library axioms peel/merge one literal |

- The same literal always maps to the same address (`LitMap s`); **distinct literals are not
  assumed disjoint** unless a case states it.
- A plain byte buffer (not a real C string) should use `CharArray::full/seg/undef_*` directly —
  e.g. `memcpy`/`memset` specs use `CharArray::undef_full` + `CharArray::full`.
- `valid_string s` (a *separate* companion in the public `string_lib`) = `all_ascii s` (every
  byte `0 <= z <= 127`) **and** `no_inner_nul s` (`z <> 0`). The backend `StringLib.v` uses a
  *different* `valid_char` (`0 < z < 256`) — **don't conflate the two.**

---

## 7. Spec & in-body annotation keywords

Counts below are **snapshot ≈, over `*.c`+`*.h`** (C-only is lower — e.g. `With` ≈382 in `*.c`);
re-run before citing.

| Keyword | Where | Means | Corpus (C+hdrs) |
|---|---|---|---|
| `With (x:T)` | spec head | ghost/logical params (∀ over the triple) | ≈486 |
| `Require P` / `Ensure Q` | spec | precondition / postcondition | — |
| `__return` | `Ensure` | the function's return value | ≈742 |
| `x@pre` | `Ensure` | value of `x` at entry | ≈4595 |
| `Assert ...` | body | fix the symbolic state here (emits a VC) | — |
| `Inv Assert ...` | before a loop | **loop invariant** (canonical spelling; bare `Inv` also valid) | ≈145 |
| `which implies` | body | forward hint: current state implies a stronger/unfolded state (e.g. open a list node) | ≈203 |
| `where ...` | call site | manually instantiate a callee's logical/type vars | ≈86 |
| `... by local` | body | export a local type/range fact (e.g. `x <= INT_MAX by local`) without rewriting |  |

**Multiple specs** (different abstraction levels) — exactly one is verified against the body;
the others are *derived* via the magic wand `high_pre \|-- low_pre ** (low_post -* high_post)`:

```c
/*@ high_level_spec <= low_level_spec
    With l Require sll(x,l)
    Ensure exists l0, Permutation(l,l0) && increasing(l0) && sll(__return,l0) */
// ... low_level_spec verified against the body; pick one at the call site:
y = insertion_sort(x) /*@ where (high_level_spec) l = l */;
```

**`which implies` specimen** (unfold a non-empty list):

```c
/*@ exists l2, p != 0 && sll(p, l2)
    which implies
    exists l3, l2 == cons(p -> data, l3) && sll(p -> next, l3) */
```

---

## 8. Directives & shared headers

| Directive | Meaning |
|---|---|
| `/*@ Extern Rocq (name : type) */` | declare a Rocq function/predicate/type for use in annotations (≈485 uses) |
| `/*@ Import Rocq Require Import <Module> */` | import a Rocq lib module (definitions + lemmas) (≈184) |
| `/*@ include strategies "<file>.strategies" */` | pull in solver strategies for the predicates used (≈63) |

Common shared headers (`*_def.h` collect these): `verification_stdlib.h` (utilities, `option`,
`UINT_MAX`, `common.strategies`); `verification_list.h` (`nil`/`cons`/`app`/`rev`/`Zlength`
over `list A`); `int_array_def.h` (the `Int`/`UInt` array instances + `int_array.strategies`);
`string.h` (string predicates + `string.strategies`); per-structure `sll_def.h`, `bst_def.h`, ….

> **Note:** if your C uses the preprocessor (`#define`, …), preprocess first with `cpp -C` —
> QCP natively supports only `#include`. Effect-free expressions only in basic assertions
> (write `data_at(&x, x_v)`, not a bare read of `x`).

---

*Cross-references:* the support matrix → `reference/SUPPORT_MATRIX.md` (FACTS §F2); the
invocation flags → `reference/INVOCATION.md`; the example ladder → FACTS §F7; trust of the
green check → ch 10.
