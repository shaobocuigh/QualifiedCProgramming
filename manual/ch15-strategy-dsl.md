# The strategy DSL

This chapter is the practitioner's sketch of the `.strategies` rule language — the small DSL you write to teach QCP's automation a new cancellation. [Chapter 14](ch14-extension.md) showed the *workflow* (define a predicate, write a rule, discharge its soundness proof) by example; this chapter is the *language* underneath those examples: the grammar at a glance, and what the solver does with a rule when it fires. It is a 🟣 **tier-3** reference — if you only *use* the shipped strategy library, you never need it; you need it when you author rules.

> **Note:** Everything below is grounded in the shipped `.strategies` corpus — every form is quoted from a file in `QCP_examples/`, and nothing here is invented syntax. The rule language is formally specified in the research literature as **Stellis** (*A Strategy Language for Purifying Separation Logic Entailments*, arXiv:2512.05159); see [Further reading](#further-reading) for the formal grammar and the soundness metatheorem. This chapter gives you enough to read and write rules; the paper is the authoritative spec.

## What a strategy is, in one line

A **strategy** is a pattern-directed rewrite on the **entailment** the solver is trying to close — `left` is what you have, `right` is what you must show — plus an `action` that rewrites both sides when the pattern matches. Its purpose is to make a spatial **[verification condition](reference/GLOSSARY.md#vc)** (`P |-- Q`, an entailment `symexec` emits for one step) collapse into ordinary pure facts the solver can finish on its own. The library of these rules is *the* reason most VCs land in the auto file instead of on you ([ch 14](ch14-extension.md)).

## Anatomy of a rule

Here is a verified rule from `QCP_examples/QCP_demos_human/sll.strategies` (id 6) — it cancels a non-empty `sll` against an `sll` at the same head pointer:

```text
id : 6
priority : core(0)
left : sll(?p, cons{Z}(?x0, ?l0)) at 0
right : sll(p, cons{Z}(?x1, ?l1)) at 1
action : left_erase(0);
         right_erase(1);
         right_add(x0 == x1);
         right_add(l0 == l1);
```

- `id` — a number naming the rule (drives the generated `sll_strategy6` goal). Need not be contiguous.
- `priority` — a class plus a level (`core(0)`) that controls *when* this rule is tried relative to others.
- `left` / `right` — the patterns to match against the have-side and show-side of the entailment. Each pattern ends in `at N`, the **slot index** an `erase` action refers to.
- `action` — the rewrite to perform when the rule matches. Here: erase both `sll` predicates (`left_erase(0)`, `right_erase(1)`) and add the two residual pure equalities to the right (`x0 == x1`, `l0 == l1`). Two spatial predicates become two ordinary equalities.

A rule may also carry a `check` block of side conditions, and a file may begin with `#include "..._def.h"` to bring a predicate's declarations into scope.

## The grammar at a glance

A `.strategies` file is a list of rules (blank-line separated), with optional `#include`s; `//` line comments and `/* … */` block comments may appear anywhere — block comments are also how the corpus disables a whole rule. A rule has exactly these fields:

| Field | Required | Repeatable | What it is |
|---|---|---|---|
| `id : N` | yes | once | rule identifier |
| `priority : class(level)` | yes | once | scheduling class + level (below) |
| `left : <pattern> at N` | one of left/right | yes | have-side patterns (may repeat and interleave with `right`) |
| `right : <pattern> at N` | one of left/right | yes | show-side patterns |
| `check : <cond>; …` | optional | one block | side conditions (below) |
| `action : <op>; …` | yes | one block | the rewrite (below) |

**Priority classes** (the level orders rules within a class):

| Class | Used for | Example file |
|---|---|---|
| `core(n)` | the general cancellation / entailment rules — the dominant class | `QCP_examples/QCP_demos_human/sll.strategies` |
| `local(n)` | local side-fact derivation (e.g. injecting an integer range bound from a typed `store`) | `QCP_examples/QCP_demos_human/common.strategies` |
| `post(n)` | rules applied late (e.g. re-folding a focused array cell back into the whole-array predicate) | `QCP_examples/QCP_demos_human/int_array.strategies` |
| `unfold_<pred>(n)` / `fold_<pred>(n)` | unfold a representation predicate one step / fold its components back; the suffix is your predicate's name | `QCP_examples/QCP_demos_human/sll.strategies` (`unfold_sll`, `fold_sll`) |
| `Tagcancel(n)` / `Pcancel(n)` | sweep the solver's internal marker propositions back out | `QCP_examples/QCP_demos_human/common.strategies`, `QCP_examples/QCP_demos_human/safeexec.strategies` |

**Checks** — exactly two combinators; both gate whether a matched rule fires:

| Check | Fires only if | Example file |
|---|---|---|
| `absense(P)` | `P` is **not already present** — a guard against the rule re-firing on its own output | `QCP_examples/QCP_demos_human/common.strategies` |
| `infer(P)` | `P` is **derivable** from the current pure facts — e.g. an in-bounds index `infer(0 <= i)` | `QCP_examples/QCP_demos_human/int_array.strategies` |

**Actions** — the moves the shipped files use (treat this as the catalogue; don't extrapolate forms that don't appear in the corpus):

| Action | Effect |
|---|---|
| `left_erase(N)` / `right_erase(N)` | remove the pattern at slot `N` from the have-/show-side |
| `left_add(f)` / `right_add(f)` | add a fact — a pure equality (`x0 == x1`) *or* a predicate (`IntArray::missing_i(...)`) — to that side |
| `left_exist_add(x[: T])` / `right_exist_add(x[: T])` | introduce a fresh existential variable on that side |
| `instantiate(x -> t)` | choose witness `t` for an existential `x` |

**Patterns** — what `left`/`right` match:

- `?x` **binds** a fresh pattern variable; a bare `x` (no `?`) reuses an already-bound value (so `store(p, ty, ?y)` after `store(?p, ?ty, ?x)` forces the *same* `p`, `ty`). `?A` is a type hole; `x : Z` ascribes a type.
- Built-in spatial atoms: `store(addr, ty, val)`, `undef_data_at(addr, ty)`, with `field_addr(base, struct, field)` for addresses, `PTR(...)` / `I32` / `U32` / … for C types, and `sizeof(T)` in address arithmetic.
- Your own representation predicates (`sll`, `store_tree`, `IntArray::full`, …) once their `_def.h` is `#include`d.
- Pure/propositional patterns: equalities and comparisons (`x == y`, `p != NULL`), disjunction `(a == b) || (b == a)`, and `exists x, …` (paired with `instantiate`).

A compact form of the whole grammar:

```text
file    ::= { '#include' STRING | rule | comment }
comment ::= '//' …            (* line *)
          | '/*' … '*/'        (* block; also used to disable a rule *)
rule    ::= 'id' ':' INT
            'priority' ':' class '(' INT ')'
            { ('left'|'right') ':' pattern 'at' INT }
            [ 'check' ':' { ('absense'|'infer') '(' prop ')' ';' } ]
            'action' ':' { action ';' }
action  ::= 'left_erase'|'right_erase' '(' INT ')'
          | 'left_add'|'right_add' '(' assertion ')'
          | 'left_exist_add'|'right_exist_add' '(' var [':' type] ')'
          | 'instantiate' '(' var '->' term ')'
```

## How the solver runs a strategy

When `symexec`'s solver faces an entailment `H |-- G`, it repeatedly applies strategies until the **spatial** part is gone — Stellis calls this **purifying** the entailment: cancel every separation-logic predicate so that only pure facts remain, which the solver's arithmetic/equality side can discharge. One step is:

1. **Match** the `left` patterns against `H` and the `right` patterns against `G`, binding the `?`-variables (and checking that reused bare names line up). Multi-conjunct patterns require *all* the listed slots to be present at once.
2. **Check** the side conditions: `absense(P)` must find `P` absent; `infer(P)` must derive `P` from the current pure facts.
3. **Act**: erase the matched conjuncts, add the residual facts/predicates, introduce or instantiate existentials.

Rules are tried in `priority` order, and the solver applies a matching rule **without reconsidering it** — there is no backtracking. Two consequences for how you write rules:

- An **over-broad pattern** can strand a goal: once the solver commits to a rewrite, it won't undo it to try a different rule, so it can rewrite a goal into a shape it then can't finish. Keep patterns tight.
- `absense`/`infer` and `priority` are your control surface for ordering and termination. The `absense` guard paired with an `add` that plants a marker is the idiom that makes a rule fire **once** (see `QCP_examples/QCP_demos_human/common.strategies` rule 6, which plants a marker so its `absense` guard fails on a re-match).

> **Warning:** a strategy is applied *blindly* once it matches — its correctness is **not** self-evident from the rule text. A wrong rule is caught only by its soundness proof (next section), and **only if you actually close that proof with `Qed` and compile it**. Leaving it `Admitted` is a trusted hole that silently licenses the rewrite everywhere ([ch 10](ch10-trust-and-soundness.md)).

## The soundness goal a rule generates

Every rule becomes one Rocq (formerly Coq) proof obligation: that the rewrite it performs is a valid entailment. `StrategyCheck` emits it as a `Definition <name>_strategyN` in `<name>_strategy_goal.v`, and you prove the matching `<name>_strategyN_correctness` lemma in `<name>_strategy_proof.v`. [Chapter 14, Step 3](ch14-extension.md) walks the full discharge workflow and the `coqc` step that kernel-checks it; [ch 10](ch10-trust-and-soundness.md) owns the trust accounting (most strategy proofs end in `Qed` and are kernel-checked; within the shipped strategy library two files — `string` and `minigmp` — carry a small `Admitted` residue that is trusted, not proven, and any out-of-tree example library you import carries its own residue to audit).

<details><summary>🟣 Rocq detail: the shape of the generated goal</summary>

The generated goal has the frame-and-wand shape `PRE |-- (residual-left) ** (new-right -* old-right)` — proving it shows the rewrite preserves the entailment under any untouched frame. For sll rule 6 above, `sll_strategy6` (in `sll_strategy_goal.v`) is closed by:

```coq
Lemma sll_strategy6_correctness : sll_strategy6.
  pre_process_default.
  Intros.
  subst.
  entailer!.
Qed.
```

The magic wand `-*` carries the "give back the original show-side once you've supplied the new one" obligation; the residual `**` conjunct is what stays on the have-side. When both reduce to `emp`, the rule is a pure rewrite with no leftover spatial obligation. This shape is exactly the soundness condition Stellis writes `A ⊢ C * (D -* B)` (arXiv:2512.05159, §4.1); its metatheorem is that if this goal holds, applying the rule is sound.

</details>

## Further reading

- **The formal spec** — *Stellis: A Strategy Language for Purifying Separation Logic Entailments*, arXiv:2512.05159 (the grammar, the matching semantics, and the soundness metatheorem in full). QCP's entailment solver builds on it (*QCP: A Practical Separation Logic-based C Program Verification Tool*, arXiv:2505.12878, §4.2).
- **The by-example workflow** — [Chapter 14](ch14-extension.md): define the predicate, write the rule, discharge the proof.
- **The corpus** — the shipped `.strategies` files are your pattern catalogue. Start with `QCP_examples/QCP_demos_human/sll.strategies` (fold/unfold + cancellation), `QCP_examples/QCP_demos_human/int_array.strategies` (the cell-pull idiom with `check : infer`), and `QCP_examples/QCP_demos_human/bst.strategies` (custom-tree cancellation).
- **When a rule should have fired but didn't** — [Chapter 11, the Stuck-Goal Differential](ch11-stuck-goal-differential.md), cause #4 (automation came up short).

## What to take away

- **A strategy is a guarded rewrite on an entailment**: `left`/`right` patterns + `check` guards + an `action` that erases spatial predicates and adds the residual pure facts — driving the goal toward an all-pure form the solver finishes.
- **The grammar is small and corpus-fixed**: six fields, a handful of priority classes, two checks (`absense`, `infer`), and the erase/add/exist_add/instantiate actions. Write only the forms the shipped files show.
- **Matching is greedy and un-backtracked**: keep patterns tight and use `priority` + `absense` for ordering and one-shot termination, or the solver can strand a goal.
- **Every rule owes a soundness proof** ([ch 14](ch14-extension.md) discharges it, [ch 10](ch10-trust-and-soundness.md) audits it): land yours in the `Qed` majority — an `Admitted` strategy proof is a trusted hole.
- **The DSL has a name and a spec**: it's *Stellis* (arXiv:2512.05159); this chapter is the practitioner sketch, the paper is the formal reference.
