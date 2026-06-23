# Your first spec

You have a green `goal_check` for a shipped example ([ch 4](ch04-quickstart-stage-a.md)). Now you write the spec yourself. A spec is the part QCP can never guess: **what your function promises.** This chapter walks you from a blank function to a checked `Require`/`Ensure` pair, using real functions from `QCP_examples/QCP_demos_human/simple_arith/` — and it stops at exactly the things that trip up a C programmer on day one: why an integer spec needs an overflow bound, and what the `__return` and `@pre` markers mean.

No Rocq knowledge is assumed. Everything here is C with a few annotations in `/*@ ... @*/` comments. The deeper annotation surface — every keyword, every predicate shape — is [ch 6](ch06-annotations-as-specs.md); the quantifier reference is the [bestiary](reference/BESTIARY.md). This chapter is the on-ramp.

## The spec triple

A QCP spec answers three questions about a function, in three clauses:

| Clause | Keyword | Asks |
|---|---|---|
| What may the caller assume holds **before** the call? | `Require` | the **precondition** |
| What does the function promise holds **after**? | `Ensure` | the **postcondition** |
| What logical values are shared across both? | `With` | the **ghost variables** (optional) |

You write the spec in an annotation comment attached to the function. Here is the simplest real one — `add` from `QCP_examples/QCP_demos_human/simple_arith/add.c`:

```c
int add(int x, int y)
  /*@ Require
        0 <= x && x <= 100 &&
        0 <= y && y <= 100 && emp
      Ensure
        __return == x + y && emp
   */
{
  int z;
  z = x + y;
  return z;
}
```

Read it as a contract. **`Require`**: the caller guarantees `x` and `y` are each in `[0, 100]`. **`Ensure`**: in exchange, the function guarantees the result equals `x + y`. The body is ordinary C; `symexec` turns the annotated function into the **verification conditions** (VCs) it must discharge to prove the body honors that contract.

Two pieces of vocabulary, used everywhere:

- **`__return`** is the function's return value, usable only in `Ensure`. `__return == x + y` is how you say "the value handed back equals `x + y`."
- **`emp`** means "this function touches no heap memory." The `&& emp` on a pure-arithmetic function says it owns and modifies no memory cells. (For functions that *do* read or write memory, `emp` is replaced by storage predicates like `store(...)` — that is [ch 6](ch06-annotations-as-specs.md)'s subject.)

> **Note:** `&&` is **ordinary conjunction** — it joins **pure facts** (`0 <= x`, `__return == x + y`), heap-independent propositions, and on a pure-arithmetic spec it is the only connective you see. The heap operator `*` (**separating conjunction**, covered in [ch 6](ch06-annotations-as-specs.md) / the [bestiary](reference/BESTIARY.md)) is the one you meet the moment you touch memory.

## Why an integer spec needs a range bound

Look at `add` again: `0 <= x && x <= 100`. Why fence the inputs at all? The answer is the single most important thing to internalize about specs in QCP, and it surprises every newcomer.

**Inside a spec, `int` is not C's 32-bit `int`. It is `Z` — the unbounded mathematical integer.** Rocq's `Z` has no `INT_MAX`, no overflow, no wraparound; it stretches to infinity in both directions. So when `symexec` reasons about `x + y`, it reasons over `Z`, where the sum is always exactly `x + y` — *but a real 32-bit signed `int` has no such guarantee: exceeding its range is **undefined behavior** in C.* The bound `x <= 100 && y <= 100` is how you promise the caller will never hand `add` values whose true sum leaves the representable `int` range. Without it, the spec would claim something false about the machine. This hand-written re-imposition of C's bounds is the **`Z` leak**, and it is the recurring tax of verifying arithmetic in QCP: **there is no overflow automation.** Every integer result you specify needs its own range or overflow reasoning, written by you (or drafted by the LLM and reviewed by you). It is a minority of total proof effort, but it never goes to zero — budget for it whenever a function does arithmetic. (The effort calibration across the whole corpus is [ch 12](ch12-scope-and-scaling.md).)

This shows up most cleanly in `abs` (`QCP_examples/QCP_demos_human/simple_arith/abs.c`):

```c
/*@ Extern Coq (Zabs: Z -> Z) */

int abs(int x)
  /*@ Require
        INT_MIN < x &&
        x <= INT_MAX && emp
      Ensure
        __return == Zabs(x) && emp
   */
{
  if (x < 0) {
    return -x;
  }
  else {
    return x;
  }
}
```

The precondition opens with `INT_MIN < x && x <= INT_MAX`. That is not redundant decoration — it is **load-bearing**, and the `<` (strict) on the low end is deliberate. `abs` returns `-x`; the one value a 32-bit `int` cannot negate is `INT_MIN` (because `-INT_MIN` overflows). By requiring `INT_MIN < x` you exclude exactly that case, so `-x` is always representable. The bound re-imposes, by hand, the C reality that `Z` has thrown away — the **`Z` leak** at work again.

The `Zabs` in `__return == Zabs(x)` is a Rocq function — the *mathematical* absolute value over `Z` — pulled in by the `/*@ Extern Coq (Zabs: Z -> Z) */` line at the top (the directive keyword is literally `Extern Coq`; QCP's proof assistant is Rocq, formerly named Coq, so prose says "Rocq" while the syntax keeps `Coq`). The spec says the return value equals the true `|x|`, and the in-range precondition is what makes that promise honest for a 32-bit machine.

> 🟢 **Tier 1** — You don't need to know Rocq's `Z` theory to write these bounds. The rule of thumb is mechanical: any `int` parameter that feeds arithmetic gets a `INT_MIN ... INT_MAX` (or tighter, like `0 <= x && x <= 100`) bound in `Require`, chosen so the operations can't overflow. When you forget one, the goal goes red on an overflow obligation — fix it by adding the bound.

## ∀ in, ∃ out: who supplies which value

Specs quantify over values, and the *motion* is one a C programmer already owns from math: **some values the caller supplies going in (for-any, ∀); some the function produces coming out (there-is, ∃).** `With` is the ∀ direction — a **ghost variable** the caller picks, shared across both `Require` and `Ensure`; `exists` in an `Ensure` (or invariant) is the ∃ direction — a value the function produces that the caller didn't supply.

`add` and `abs` need neither — their `Ensure` is pinned entirely by the parameters and `__return`, so there is no ghost to share and no witness to produce. You first reach for `With` when `Require` and `Ensure` must name the same abstract value (a list, a tree, an array's contents), and for `exists` when the output is "some value with a property" rather than a closed formula. The full triad — with real predicate examples, and why `With` is a distinct keyword from an in-assertion `forall` — is [§2 of the bestiary](reference/BESTIARY.md).

## Your first loop invariant

A straight-line function like `add` needs only `Require`/`Ensure`. The moment you add a loop, you owe one more annotation: the **loop invariant** (`Inv`) — an assertion true *every* time execution reaches the top of the loop.

Here is the critical point, and it is central to how QCP works: **you (or the LLM you direct) supply the invariant; the tool only checks it.** `symexec` does **not** figure the invariant out for you — it won't study the loop and guess the right one. It expects an invariant to be written, then verifies that it holds; if a loop has no `Inv`, `symexec` simply tells you it expected one.

The same `add.c` ships `slow_add`, which computes `x + y` by counting down — a real loop with a real invariant:

```c
int slow_add(int x, int y)
  /*@ Require
        0 <= x && x <= 100 &&
        0 <= y && y <= 100 && emp
      Ensure
        __return == x + y && emp
   */
{
  /*@ Inv
        0 <= x && x <= 100 &&
        0 <= y && y <= 200 &&
        x + y == x@pre + y@pre && emp
   */
  while (x > 0) {
    x = x - 1;
    y = y + 1;
  }
  return y;
}
```

The invariant's heart is `x + y == x@pre + y@pre`. Each iteration moves one unit from `x` to `y`, so their *sum* never changes — it always equals the sum the function was called with. The marker **`@pre`** means "the value of this variable at function entry," so `x@pre` and `y@pre` are the original arguments, frozen. (Note also the widened range `y <= 200`: `y` grows as the loop runs, so the invariant must admit values the *precondition* never did — `0 <= x && x <= 100` plus `0 <= y` from entry can drive `y` as high as 200.)

The tool checks a supplied invariant two ways — classic Hoare-style inductive checking:

1. **Establishment (P → I):** the invariant holds on first entry, given the precondition. If it doesn't, `symexec` reports *"Loop invariant cannot be derived based on pre-condition, i.e. failed in P -> I."*
2. **Preservation (I → I):** if the invariant holds at the top and the loop runs one more iteration, it still holds. If not: *"Loop invariant is not inductive, i.e. failed in I -> I."*

Get both, and the invariant — together with the loop's exit condition — implies the postcondition. That is the whole job of an `Inv`.

> **Why no loop in `gcd`.** The companion `gcd.c` in this same directory computes the GCD by **recursion**, not a loop — so it carries no `Inv` at all. QCP verifies recursion *by contract*: each recursive call is checked against the function's own `Require`/`Ensure`, exactly as if it were a call to a separately-specified function. A loop needs an invariant you write; a recursive call reuses the spec you already wrote. (`QCP_examples/QCP_demos_human/simple_arith/gcd.c`.)

> 🔵 **Tier 2** — When an `Inv` fails P → I or I → I, the message names which leg broke, and that tells you where to look: a P → I failure means your invariant claims more than the precondition gives at entry; an I → I failure means one loop step can violate it (often a range bound that needs loosening, like `y <= 200` above). The LLM drafts most invariants with the dial up; reviewing them is reading whether the pure facts in the `Inv` actually survive one iteration.

> **Honest limit:** a green check on a function with a loop means *the invariant you supplied was checked* — its P → I and I → I obligations were discharged (each one auto-solved or kernel-checked, the two-tier split of [ch 10](ch10-trust-and-soundness.md)) — not that QCP found the right invariant for you. A too-weak invariant that still passes P → I and I → I but doesn't imply your postcondition leaves the goal red at the loop exit — and that is **your** annotation to strengthen, not a tool failure ([ch 11](ch11-stuck-goal-differential.md) triages this).

To check a spec you wrote, run it through the same `symexec` + `make <name>_goal_check.vo` flow from [ch 4](ch04-quickstart-stage-a.md) — substitute your file for the shipped example.

## What you've got, and what's next

You can now write and check a spec for a simple function:

- The triple — `With` (ghosts), `Require` (pre), `Ensure` (post) — with `__return` for the result and `emp` for "no heap."
- The **`Z` bound**: every integer spec re-imposes C's `INT_MIN`/`INT_MAX` reality by hand, because `Z` is unbounded and there is no overflow automation. This is the recurring arithmetic tax.
- The **∀-in / ∃-out** motion: `With` for caller-given values shared across the triple; `exists` for function-produced witnesses.
- The **loop invariant**: you write the `Inv`, `symexec` checks it (P → I and I → I); the tool never infers it. Recursion is checked by contract instead.

Where to go next: the **full annotation surface** — `Assert`, `which implies`, the `data_at`/`store` storage predicates, multiple specs — is [ch 6](ch06-annotations-as-specs.md). The **quantifier triad** in depth, including `forall` and the CPS form, is the [bestiary §2](reference/BESTIARY.md). When a spec you wrote goes red, [ch 11](ch11-stuck-goal-differential.md) tells you whose fault it is; what a green check actually certifies is [ch 10](ch10-trust-and-soundness.md).
