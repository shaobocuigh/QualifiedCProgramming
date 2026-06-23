# QCP Engine Internals (reverse-engineered)

> **Status / provenance.** This page is reconstructed by **reverse-engineering the shipped
> `linux-binary/` executables** — `symexec`, `StrategyCheck`, `lsp`, `mcp` — which are ELF
> x86-64, PIE, **unstripped, with full DWARF `debug_info`** (GCC 11.4.0 / C11 / `-O3`, Ubuntu
> 22.04). No QCP engine source ships; everything below is read out of symbol tables, DWARF type
> DIEs, `.rodata` strings, and targeted disassembly, then **adversarially re-derived** (a second
> pass that tried to refute each claim with an independent command). Treat it as a high-confidence
> *map*, not ground truth — symbol names can mislead, and the SMT subsystem (see §2) ships
> **without DWARF**, so its structure is inferred from `.text`/symbols only.
>
> Confidence tags: **[V]** independently verified from the binary · **[V~]** verified with a
> noted imprecision · **[inf]** inferred from names/strings, not disassembly-confirmed.
> For the **trust** consequences of all this, see [FACTS.md](../FACTS.md) §F1 and
> [ch10-trust-and-soundness.md](../ch10-trust-and-soundness.md) — this page is *architecture*; that
> one is *what you're trusting*.

Reproduce the corpus:
```bash
file linux-binary/*                                  # unstripped, debug_info, PIE
readelf --debug-dump=info linux-binary/symexec | grep -A30 DW_TAG_structure_type   # struct layouts
nm linux-binary/symexec                              # ~4000 symbols, names intact
strings -n 6 linux-binary/symexec                    # error taxonomy, Coq templates
```

---

## 1. Four binaries, one engine

All four executables are **the same compiled engine behind four front-ends**. **3,886** named
defined symbols share the same name across all four; that is **98.4 %** of `symexec`, 98.1 % of
`lsp`, 98.3 % of `mcp`, and **100 % of `StrategyCheck`** (its 3,887 symbols are core + one unique
entry). **[V]**

| Binary | What it is | Front-end delta vs the shared core |
|---|---|---|
| `symexec` | The batch verifier (annotated `.c` → VC `.v` files). | The reference build. |
| `StrategyCheck` | A **strategy-soundness goal generator**, *not* a checker. | **Drops** the entire symbolic-execution pipeline (`SymExecutor.c`, `StmtTrans.c`, `PS_ExprTrans.c`, `StateMachine.c`, `PSTreePrinter.c`, `SymExec/main.c` — builds from **109** source files vs 114) and adds `StrategyCheck.c`. **[V]** |
| `lsp` | **Not** a Microsoft-LSP server. A custom **QIDE stdin line server** — zero `textDocument`/`publishDiagnostics`/`Content-Length`/`jsonrpc` strings exist. Adds a capture/replay introspection model + a ~400 KB execution-tree display buffer (`nodes_at_row : int[100][1000]`). **[V]** |
| `mcp` | **Not** JSON-RPC. A **tag-based line REPL** (`<step>`,`<check>`,`<symbolic>`,`<proof>`,`<end>`) over the shared engine. The actual MCP/JSON-RPC layer is the **out-of-binary Python `mcp/qcp-mcp` wrapper**, which exposes exactly **6 tools** (`load_target_file`, `symbolic`, `step`, `proof`, `check`, `close`) and translates them to these tags. **[V]** |

> **Naming caveat for the manual:** "lsp" and "mcp" name *intended integration points*, not the
> protocols the binaries actually speak. Both speak QCP's own line protocol; the standard-protocol
> adapters live outside (Python for MCP; a QIDE client for `lsp`).

---

## 2. Build surface & the invisible SMT subsystem

- **Toolchain:** `GCC: (Ubuntu 11.4.0-1ubuntu1~22.04.3)`, `GNU C11 … -O3 -O3 … -fstack-protector-strong
  -fcf-protection`. **[V]**
- **CI provenance (leaked by DWARF paths):** `/opt/atlassian/pipelines/agent/build/…` →
  **Atlassian Bitbucket Pipelines**; comp-dir `…/build/build/release`. The downstream Coq project is
  internally called **`SimpleC`**. No version banner, no embedded secrets/tokens/URLs. **[V]**
- **Linkage is `libc` + `libm` only.** Everything else is *static*: the flex/bison runtime, and a
  **vendored mini-gmp** (`mini-gmp.c`; symbols `mpn_*`, `mpz_congruent_p`, no `__gmp` prefix, no
  version string → the compact bundled subset, not system `libgmp`). **[V]**
- **The SMT solver ships without DWARF.** The CDCL(T) subsystem (§6) — `CDCL.c`, `nelson_oppen.c`,
  `lia_theory_gmp.c`, `uf_proof.c`, `fp32/fp64_interval_solver.c`, `mini-gmp.c` — has **`.text` and
  symbols but no compile-unit DWARF**, so it is **absent from the DWARF-derived module map**. The
  documented engine tree (`SymExec/` 81 files, `compiler/` 34, `dsl_parser/` 3) therefore
  *understates* the codebase: a whole certifying SMT solver is bolted on beside it. **[V]**

`★ Why this matters` — the build/buy line is drawn by *trust role*, not by genericity:
**trust-neutral computation is reused OSS** (flex+bison tokenize/parse; mini-gmp does the bignum
arithmetic), while **everything on the proof-certification path is in-house and certifying** (the
SL engine, the SMT solver, the Coq printer). mini-gmp sits *inside* `lia_theory_gmp` yet is trusted
only as an arithmetic oracle — the *inference* around it is still re-derived as a proof term.

---

## 3. The pipeline (entry → VC files)

`main()` (`main.c`, `0x5920`) is a **bootstrap that does not run the pipeline directly**. It: **[V]**

1. inits (`ProcessArgv`, `dsl_init`, `JsonFormatAllCreate`, `init_env`, `LogicNameManagerInit`);
2. **wires solvers by dependency injection** — writes concrete function pointers into BSS to break a
   module cycle: `PropSolver ← PropEntail` (`0x2006c8`), `SepSolver ← SepLogicEntail` (`0x2006d8`),
   `FailSepSolver ← FailSepLogicEntail` (`0x2006d0`), each written exactly once at startup;
3. registers `exec_handler`'s address as a **per-declaration callback**;
4. drives a **bison _push_ parser** (`yypstate_new`/`yypush_parse`/`yypstate_delete` over `yylex`;
   `parse_program`/`parse_program_path`) — **streaming**, not parse-whole-AST-then-walk.

For each top-level declaration the parser invokes `exec_handler`, which runs
`elaborate_pp_to_ps` (partial-program → partial-statement lowering) then `SymbolicExec`, stepping
statements via `PSExec`/`ControlFlowExec`/`ExprExec` over a `SymState`. Each verification condition
becomes a **`Witness`** (§4); `WitnessTrySolve` dispatches it (§5). Output is emitted by
`PrintCoqOutputFiles` (→ seven Coq emitters) and `JsonFormatAllCreate` (§8). **[V]**

---

## 4. The intermediate representation (DWARF struct layouts)

QCP's logic is a family of **tagged-union ADTs** (discriminant + anonymous data union). Recovered
layouts: **[V]**

- **`Separation`** (40 B) — the spatial heap model has **exactly four** separating-conjunction
  forms: `enum SepartionType {T_DATA_AT=0, T_UNDEF_DATA_AT=1, T_ARR=2, T_OTHER=3}` (the last = a
  user-defined predicate). `DATA_AT{addr:ExprVal*, ty:SimpleCtype*, val:ExprVal*}`.
- **`Proposition`** (32 B) — **first-order logic**: `PropBinOP{AND,OR,IMPLY,IFF}`, a separate
  `PropUnaryOP{NOT}`, explicit **`FORALL`/`EXISTS`** quantifiers, and three pointer-nullness
  predicates. User predicates are polymorphic.
- **`ExprVal`** (32 B, 11-way union) — richer than C: `EZ_VAL`(integer/`Z`), `FP_VAL`, `REAL_LIT`
  (reals), `SIZE_OF`, list-indexing, string values, and a **zero-size `TIME_COST` term** →
  evidence of **resource / time-credit accounting** in the assertion language. **[inf on intent]**
- **`PolyType`** (24 B) — user predicates are typed by an **ML-style higher-order type system**:
  `{POLY_VAR=0, POLY_FUNCAPP=1, POLY_ARROW=2}` (type variables, application, arrows).
- **`SimpleCtype`** — the structural float gap: the enum declares **13** tags *including*
  `C_float=5`/`C_double=6`, but the data union has **only 11** members and **omits the two float
  cases**. Float constants are stored as **unparsed text**. (See §9; cross-ref [FACTS.md F2.1a].)
- **`SymState`** (16 B) — `NORMAL=0` → `AsrtList*` (a head-linked **disjunction** of assertion
  branches) vs `WITH_VAL=1` → return-value-partitioned list.
- **`Witness`** (48 B) — the proof-obligation certificate: **six 8-byte members**, one per VC
  category (safety / entailment / return / which-implies / partial-solve, + linkage). **[V~]**
- **`EntailmentCheckerWit`** (56 B) — carries an **`auto_solved : int`** field at +4. This is the
  **data-level two-tier-trust gate**: it decides whether the Coq emitter prints `Proof. Admitted.`
  (auto, trusted) or leaves a kernel-checkable goal. **[V]**
- **`PartialSolveWit`** — records the **inferred separation-logic frame** as a first-class
  `frame : Assertion*` field → frame inference is explicit and materialized. **[V]**
- **`FPSpec`** `{fp_addr:ExprVal*, func_info:func_info*}` — function pointers are **first-class in
  the assertion language** ("address X satisfies func spec Y" is representable). This *refutes*
  silent-unsoundness for funcptr specs — though indirect *calls* still fail loudly in the executor
  (§9). **[V]**

---

## 5. The separation-logic entailment engine

One unified, witness-producing core serves **all** VC categories. `SepLogicEntail` is a **4-stage
fall-through pipeline**: **[V]**

1. **custom strategy solve** (`custom_solve_no_core`) — gated by a mutable BSS flag
   (`witness_try_solve @0x200690`; skipped when zero);
2. **existential / ghost-variable unification** — `asrt_unify` (`Automation/StrategyLibDef/AsrtUnify.c`)
   builds an `IntMapping` (logic-var id → `ExprVal`) by **second-order matching** and applies it via
   `SepSubst`/`PropSubst`;
3. **separating-conjunct cancellation** — `tag_cancel_solve` / `prop_cancel_solve`;
4. **pure-proposition decision** — `PropEntail` (→ the SMT solver, §6).

Two facts about the structure:

- **One rule engine, reused five ways.** The strategy match-and-rewrite core `solve` (`0x44860`)
  is invoked by **exactly five** wrappers — `custom_solve`, `custom_solve_no_core`, `post_solve`,
  `prop_cancel_solve`, `tag_cancel_solve`. Even *cancellation* is expressed as strategy-library
  invocation. **[V]**
- **Every witness category shares one pipeline and short-circuits on vacuous truth.** All five
  `*WitTrySolve` functions begin by calling **`TryEntailFalse`** (if the precondition is already
  `False`, the entailment holds vacuously) before falling back to the solver. **[V]**

> The "no external SMT solver" fact (true — only libc/libm link) **understates** what's here: the
> separation engine is one thing; the *pure-proposition* backend it calls is a complete in-house
> SMT solver (next section).

---

## 6. The CDCL(T) SMT solver — and its *latent* proof machinery — the headline

`PropEntail` lowers `Proposition`s to an internal **`SmtProp`** normal form
(`PropTransSmtProp`/`ProplistTransSmtProplist`) and calls `SingleSmtPropCheck → smt_solver_with_mode`
— a **complete, from-scratch CDCL(T) SMT solver**. It *ships* a full proof-producing subsystem too,
but — verified by call-graph trace — **that subsystem is dead code in the shipped flow** (see the
"Certification" row and the note below); the live verification path uses the **non-proof** solver: **[V]**

| Layer | Symbols (evidence) |
|---|---|
| CNF / Tseitin encoding | `cnf_trans`, `prop2cnf` |
| **CDCL SAT core** | `cdcl_solver`, `bcp` (unit propagation), `decide`, `backtrack`, `clause_learning`, `clause_resolution`, `conflict_analysis` |
| **Theory combination** | **`nelson_oppen_convex`**, `nelson_oppen_theory_check_with_conflict` (Nelson-Oppen) |
| Theory: **EUF / congruence** | `areCongruent`, `propagate_equalities_from_uf`, `eq_trichotomy_clauses`, `uf_proof` |
| Theory: **LIA** | `lia_infer`, **`real_shadow_gmp`** / `eliminate_xn_gmp` = **Fourier–Motzkin** elimination over **mini-gmp `mpz`** bignums (`mpz_lcm`/`divexact`/`addmul`/`gcd`) |
| Theory: **floating-point** | `interval_theory_check` (`0x12e5e0`, a 274-instruction Nelson-Oppen dispatcher) driving `fp32_interval_run_fixpoint` / `fp64_interval_run_fixpoint` / `int_interval` solvers |
| **Certification (DEAD CODE)** | a parallel **`_proof` family** (~34: `cdcl_solver_proof`, `bcp_proof`, `cnf_trans_proof`, `lia_proof_FME`, `SmtProp2ProofTerm`, `clause2ProofTerm`, …) building a **`ProofTerm`** and emitting **SMT/Alethe `:rule` certificates** (`:rule RESOLUTION/CONG/TRANS/LIA_TRANS/UF_CONTRA_FALSE/…`), plus an internal proof *checker* `smt_proof_check_high`. **⚠ Verified unreachable:** the entry `SingleSmtPropCheck_proof` has **zero callers and its address is never taken** (its 2 in-binary refs are internal jumps); `smt_solver_proof`/`cdcl_solver_proof`/`smt_proof_check_high` all trace to "no live root." The live path calls **`cdcl_solver`**, not `cdcl_solver_proof`. So this is proof-producing *capability*, not exercised certification. The certificate format is **SMT-style, not Coq.** |
| Scope guard | `NiaPropIdentify`/`new_name_Niaterm` — **nonlinear arithmetic is only *detected and abstracted*, never decided**. No bitvector theory, no array theory. |
| Maturity | self-profiled (`get_no_lia_infer_success_cnt`, `get_cnf_time_ms`, `get_no_uf_to_lia_time_ms`, …). |

**Why in-house and not Z3/CVC5.** Note first that the once-tempting reason — "it emits Coq-replayable
proof terms that compose with the SL proof" — is **not supported by the evidence**: the certificate
machinery is dead code and its format is SMT/Alethe `:rule`, not Coq (corrected after a call-graph
trace; an earlier draft overstated this). What the evidence *does* support: **self-containment** (a
deterministic static binary, only libc/libm/mini-gmp, no native Z3 dependency or version skew);
**TCB minimization** (no million-line C++ black box in the trusted base — [FACTS.md F1.2]);
**deliberate fragment scoping** (LIA + EUF + fp intervals are decidable; nonlinear is abstracted, and
anything harder is *punted to the manual Coq tier* — the two-tier model); and an evident **intent to
become certifying** (they built a full proof-term subsystem *and* an SMT proof checker) that is **WIP
/ not yet wired** in these binaries. A future trust lever, not a present guarantee.

> **No certificate is produced *or* checked in the shipped flow.** The dedicated certifying pipeline
> is unreachable, and the live solver's in-memory proof-nodes (built for internal unsat-core /
> conflict tracking) are never serialized. What lands on disk is `Proof. Admitted.` (§8). So an auto
> VC is *decided by a real in-house decision procedure* — not "asserted blind" — but the Rocq kernel
> never re-checks it, and there is no SMT certificate to check either. See [FACTS.md F1.3].
>
> **How far along is the certifying machinery (and what would it even attest)?** Substantial but
> dual-gated. The emitter family is real — a `ProofTerm` type, printers that `fwrite` an
> **Alethe/cvc5-style `:rule` calculus** (~24 rules: `RESOLUTION/CNF_TRANS/CONG/REFL/ARITH_FME/
> LIA_TRANS/EQUALITY_RESOLUTION/…`), and an internal checker `smt_proof_check_high` — but *every*
> proof function (solvers **and** printers **and** checker) is dead code reachable only from the
> orphan `SingleSmtPropCheck_proof`. **And even if wired, an SMT certificate would attest only the
> pure-proposition residual** (LIA/EUF/boolean) that reaches `PropEntail` — i.e. the *last* stage of
> §5's pipeline. The separation-logic reasoning before it (frame inference, `tag_cancel_solve`
> cancellation, `asrt_unify` existential instantiation, predicate matching) emits **no** proof
> object; its only "certificate" is the Coq goal, which is `Admitted`. So closing the gap needs two
> independent steps: (a) **wire** the SMT emitter + run an external Alethe checker (a finish-the-WIP
> task), and (b) **certify the SL reasoning** itself (a much deeper problem with no evidence of a
> start). The Alethe machinery is a half-built lever on the *pure-logic leaf only*, currently off.

---

## 7. The strategy DSL (the extensibility surface)

QCP's proof automation is **programmable** via a small declarative DSL (`.strategies` files;
`dsl_parser/` + `Automation/{StrategyLibDef,PatternASTDef,dsl_match}`). It is a **bison/yacc LALR
grammar** (`dsl_parser/parser.c`; DWARF `yysymbol_kind_t` nonterminals
`CMD_ID`/`PRIO`/`PRIOS`/`PATTERNS`/`PATTERN`/`CHECK`/`ACTION`). **[V]**

Every rule compiles to a fixed data model: **[V]**

- left/right **separation patterns** — 5 kinds: `StrategyLibPatternType{data_at, undef_data_at, arr,
  pred, patpred}` (`patpred` = a metavariable predicate);
- a **CHECK list** — 2 kinds: `StrategyLibCheckType{ABSENSE=0 [sic], INFER=1}`;
- an **ACTION list** — **8 primitives**: `StrategyLibActionType{DEL_LEFT=0, DEL_RIGHT, ADD_LEFT,
  ADD_RIGHT, ADD_LEFT_EXIST, ADD_RIGHT_EXIST, INST=6, SUBST=7}`. The **16 surface keywords**
  (`left_erase`/`left_prop_erase`/`left_sep_erase`, …) collapse onto these 8 via `actToLibAction` —
  the `_prop_`/`_sep_` variants are pure synonyms.

Rules carry a **priority ≤ 199**, group into named **scopes**, and `.strategies` files may
**`include`** one another. Array/string builtins exist **both** as on-disk text templates
(`builtin/common.strategies`, `builtin/string_literal.strategies`, …) **and** as programmatic
generators. **[V]**

**`StrategyCheck`'s real job** is not safety-checking — it **transpiles each scope into a Coq
soundness obligation**, emitting per scope: `<name>_strategy_goal.v`, `<name>_strategy_goal_check.v`,
`<name>_strategy_proof.v`. The auto-emitted proof body is the single tactic **`pre_process_default.`
followed by `Admitted.`** (`print_strategy_lemmas`), or `Axiom %s_strategy%d_correctness`
(`print_strategy_soundness`). **So a user-written strategy is *sound-by-Admit until a human proves
it*** — the two-tier trust model extends to user automation. **[V]** (Of the ~45 shipped
`*_strategy_proof.v`, only 2 files still carry `Admitted` — see [FACTS.md F1.2].)

---

## 8. Coq/Rocq emission & the trust mechanism

- **The binaries never run Coq.** No `system`/`exec*`/`popen`/`fork`/`posix_spawn` in any PLT.
  They are **pure Coq _source_ emitters**; an external `coqc` (8.20.1) checks the `.v` files in a
  separate step. **[V]**
- **The binary emits only `Admitted`, never `Qed`.** The substring `Qed` is **wholly absent** from
  all four binaries (bytes, strings, symbols); `Proof. Admitted.` (`.rodata 0x15a819`) and
  `Admitted.` (`0x15c567`) are emitted actively. **`Qed` only appears in human-edited
  `_proof_manual.v` files** — the Qed/Admitted split is a *file convention*, not engine logic. **[V]**
- **The soundness gate is a Coq module-type ascription trick, not a proof.** `_goal.v` declares
  `Module Type VC_Correct` listing every VC as an **`Axiom`**; `_goal_check.v` writes
  `Module VC_Correctness : VC_Correct.` (a **sealed/opaque** ascription, single `:`) that `Include`s
  `_proof_auto` (Admitted) + `_proof_manual` (Qed). The kernel only forces **names/types to line
  up**; the `Admitted` bodies **pass the gate freely**. This is the mechanical form of the "TCB
  circularity" in [FACTS.md F1.2]. **[V]**
- **Seven emitters**, fixed multi-file scaffold (`_goal.v`, `_goal_check.v`, `_proof_auto.v`,
  `_proof_manual.v`, `_lib.v`, `_strategy_*.v`). The output is **married to a specific QCP Coq
  library** (`CoqPrintSacProgHeader`/`GoalHeader`/`ProofHeader` hardcode imports of the `SimpleC`
  `LogicGenerator`, `AUXLib`, `SetsClass`) — not generic Coq. **[V]**
- **`RamifyDef.c` is an *active* generator** (`gen_rc`/`print_rc`/`rearrange`): it emits
  **magic-wand "ramified condition"** Coq goals for strategy rules — always closed with `Admitted`.
  **[V]**
- **`--soundness-proof` is the genuinely *dormant* path.** Hard-gated on `--program-path`, it opens
  an empty `%s_soundness.v` (`fp_soundness` global) that is referenced exactly twice (store handle +
  `fclose`) and **never written to**. (`lsp` and `StrategyCheck` drop even the flag's generator;
  `symexec`/`mcp` keep the no-op.) Confirms [FACTS.md F1.3]: latent, unwired. **[V]**

---

## 9. The capability frontier (honest limits, from `.rodata`)

The shipped engine hard-codes its boundary as fatal `failwith`-routed strings. The interesting
pattern is **"front-end ahead of backend"** — the engine *accepts* more than the Coq layer can
*discharge*:

- **Floats are bifurcated, not a uniform stub.** A *real* fp interval theory solver exists in the
  SMT backend (§6) **and** the front-end emits genuine IEEE VCs (`fp32_isFinite`,
  `BinFp32AddSafetyConstrait`, …) — **but** the heap/type model can't store a float (`SimpleCtype`
  omits the float union cases, §4) and the shipped `SeparationLogic/` Coq layer defines **no `fp32`
  symbols**, so the emitted goal won't compile. Net: *accepts and exits 0, leaves an unprovable
  obligation* — see [FACTS.md F2.1a]. The danger is the silent success, not the math.
- **Function pointers:** *representable* as specs (`FPSpec`, §4) but indirect **calls** fail loudly
  — `fatal error: FindFuncInfo: func_info not found`, exit 1. A safe hard limit. [FACTS.md F2.1b].
- **The "not supported yet" taxonomy** (code-reachable `failwith` guards): `Nontrivial function /
  predicate / separation predicate is not supported yet`, `Declaring variable with global storage
  in function is not supported yet`, `Ptr Prop not supported`, `unsupported array type`,
  `RemoveMemPermission: struct/union not supported yet`. The pattern/strategy engine also has many
  `Not implemented in <op>()` branches (`matchSeparation`, `instPatternSep`, `substSep`, …).

---

## 10. The interactive proof protocol (`AICommand` / MCP)

`AICommand.c` is an **`mcp`-only** compile unit (absent from `symexec`/`StrategyCheck`/`lsp`)
implementing a **stateful single-step proof-driving REPL** — *not* embedded LLM/API calls. The LLM
(or any client) drives it through the Python wrapper. **[V]**

- `mcp` uniquely exports `One_step`, `Step`, `ai_exec_handler`, `Symbolic_until_line`,
  `Check_until_line`, `Find_func`, `Exec_func`, `Reset_env`.
- `One_step = NewWitness → SymbolicExec → WitnessTrySolve → JsonFormatUpdateWitness` — one step over
  the shared engine, results serialized back as JSON.
- The `proof` tool's `witness_type` is the in-binary enum **`ai_goal_kind {AI_GOAL_NONE=0,
  ENTAILMENT=1, SAFETY=2, RETURN=3, WHICH_IMPLIES=4, PARTIAL_SOLVE=5}`** — the same five VC
  categories as the `Witness` union (§4), validated by an in-binary `cmp 1..5` dispatch.
- The pretty-printers `PPAICommand{Step,Symbolic,Proof,CheckLine,End}` correspond to the
  `<step>`/`<symbolic>`/`<proof>`/`<check>`/`<end>` tags, which are shared with the front-end's
  single 173-member `yytokentype` enum (values 258..425) — i.e. the interactive protocol markers and
  the C/annotation tokens live in **one** token space.

---

## Appendix — one-liners to reproduce the load-bearing claims

```bash
B=linux-binary/symexec
# §1 shared core across all four binaries:
for f in symexec StrategyCheck lsp mcp; do nm linux-binary/$f | awk '$2~/[TtBD]/{print $3}'|sort -u>/tmp/$f.s; done
comm -12 /tmp/symexec.s /tmp/mcp.s | wc -l
# §2 only libc/libm; mini-gmp vendored; no DWARF for the SMT files:
ldd $B; nm $B | grep -E ' mpn_|mpz_congruent_p'; nm $B | grep -c cdcl_solver
# §6 the certifying CDCL(T) solver:
nm $B | grep -E 'cdcl_solver|nelson_oppen|lia_proof_FME|interval_theory_check|_proof$' | sort
# §8 emits Admitted, never Qed; the module-type gate:
strings $B | grep -E 'Qed|Proof. Admitted|Module Type VC_Correct|VC_Correctness'
# §9 the capability frontier:
strings $B | grep -iE 'not supported yet|FindFuncInfo|fp32_isFinite'
```
