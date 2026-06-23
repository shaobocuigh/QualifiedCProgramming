# Reference — Support Matrix

> The full capability envelope, derived from `manual/FACTS.md` §F2 (which cites live source).
> Every count is a **snapshot** of a regenerating tree — lead with the command, re-measure before
> a release. For the at-a-glance version see [ch 3](../ch03-scope-at-a-glance.md); for the cost
> axis see [ch 12](../ch12-scope-and-scaling.md).

## What QCP can verify

| Feature | Status | Caveat |
|---|---|---|
| Integers (char/short/int/int64 + unsigned), pointers | ✅ supported | pointer model is **ILP32** (`sizeof_ptr = 4`), flat byte heap, no provenance; **every `Z` result needs a manual range/overflow bound** |
| Structs (dot/arrow/nested) | ✅ supported | padding/layout not modeled (`struct_padding = emp`); no aliasing-by-reinterpretation |
| Arrays (typed `ArrayLib` modules) | ✅ supported | **strongest built-in**: `IntArray::full/seg/undef/…` + strategy automation; multidim = manual nesting |
| Strings (null-terminated) | ✅ supported | `store_string` over `CharArray` + null; `mem*`/`str*` result predicates |
| Recursion | ✅ supported | by-contract self-calls; inductive predicates |
| `for`/`while`/`switch`/`break`/`continue`/`do-while` | ✅ supported (model) | frontend desugars to an if/while/seq core — *you write ordinary C*. (`continue` is model-supported; not every keyword has a corpus example in a given snapshot.) |
| Polymorphism / generic predicates | ✅ supported (under-sold) | one list spec reused across any struct/field |
| Multi-file / modular | ✅ supported (under-sold) | contracts in shared `_def.h` + `/*@ Import/Extern Rocq @*/` |
| Unions | ⚠️ limited | tagged-union only; overlapping write-one/read-another NOT modeled |
| malloc / free | ⚠️ limited | no built-in allocator; you declare contracted wrappers |
| OS sync (locks/events/interrupts) | ⚠️ limited | via **STS** state-machine abstractions (LiteOS) — not shared-memory parallelism |
| **Floats / doubles** | ❌ **silent half-stub** | the closed engine accepts floats and **exits 0**, but the shipped Rocq layer can't discharge the VCs — *apparent success, uncompilable obligation*. The dangerous case. |
| **goto** | ❌ unsupported | no `Sgoto` node in the open model; rejected |
| **Function pointers / indirect calls** | ❌ unsupported | verification mode **errors loudly** (`fatal error: FindFuncInfo`, EXIT=1) — a safe hard limit |
| **Shared-memory concurrency** | ❌ unsupported | CSL is proven sound in `unifysl` but **never wired into the C frontend** |

**Evidence provenance differs by row (don't blanket it):** the hard ❌ rows cite open-model
evidence (e.g. floats → the proof layer lacks `fp32` theory; `goto` → no `Sgoto` node; shared-mem
→ CSL unwired); the ✅/⚠️ rows rest on FACTS plus live corpus/library evidence. Full per-feature
citations: FACTS §F2.1.

## Effort cost (command-first; snapshot)

Manual proof is **roughly a quarter to a third** of proof effort on average. Re-measure:

```bash
grep -rh "Admitted" SeparationLogic/examples --include="*_proof_auto.v"    | wc -l   # auto  (≈4350)
grep -rh "Qed"      SeparationLogic/examples --include="*_proof_manual*.v" | wc -l   # manual (≈1770 shard-aware)
```

Both are **lemma-count proof-effort proxies, not VC counts** (raw `Qed` includes helper lemmas).
Skew is qualitative/medium-confidence: more manual for arithmetic/OS code, much less for
array/string/list code reusing shipped predicates. Every `Z` arithmetic result costs a manual
range/overflow bound (no overflow automation). Full methodology: FACTS §F2.2.

## Under-sold capabilities to lean on

predicate polymorphism · multi-file modularity · full structured control flow · the strategy
library (hundreds of `id :` rules across ~46 `.strategies` files — the automation that drives the
~2.5–3 : 1 auto:manual ratio) · math libs (`MaxMinLib`/`SumLib`) · `GraphLib` · the verified
LiteOS STS case set.
