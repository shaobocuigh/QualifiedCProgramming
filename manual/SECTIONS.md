# QCP User Manual — Sections & Per-Chapter Briefs

> The TOC plus a **brief per chapter**. Each chapter writer is handed: this brief +
> `STYLE_GUIDE.md` + `FACTS.md` + the named source excerpts. A brief fixes **goal · scope
> (in/out + what to link out) · sources · tier/AI overlay · dependencies · maturity · length ·
> wave**. The exclusion rule (no from-scratch SL/symex pedagogy — link out to tutorials /
> qua.codes) applies to **every** chapter.

## Map at a glance

```text
Part I  — Orient        : 1 What QCP is · 2 Should you use it? · 3 Scope at a glance
Part II — Get working   : 4 Quickstart (Stage A, no AI) · 5 Your first spec
Part III— How it works  : 6 Annotations as specs · 7 Invariants & the AI dial · 8 SL & memory
                          model · 9 Goals, symbolic execution & proof · 10 Trust & soundness
Part IV — Diagnose/scale/extend : 11 The Stuck-Goal Differential · 12 Scope & scaling in depth
                          · 13 Honest limits & roadmap · 14 Extension (new predicates)
Reference backbone      : R1 Bestiary · R2 Support matrix · R3 Invocation anatomy · R4 Glossary
```

### Canonical filenames (use these EXACT slugs for files and cross-references)

All chapters live at `manual/`, all reference pages at `manual/reference/`. Writers must link
using these names so forward-references resolve:

```
ch01-what-qcp-is.md            ch06-annotations-as-specs.md        ch11-stuck-goal-differential.md
ch02-should-you-use-qcp.md     ch07-invariants-and-the-ai-dial.md  ch12-scope-and-scaling.md
ch03-scope-at-a-glance.md      ch08-separation-logic-memory-model.md ch13-honest-limits.md
ch04-quickstart-stage-a.md     ch09-goals-symexec-and-proof.md     ch14-extension.md
ch05-your-first-spec.md        ch10-trust-and-soundness.md
reference/BESTIARY.md  reference/SUPPORT_MATRIX.md  reference/INVOCATION.md  reference/GLOSSARY.md  reference/TROUBLESHOOTING.md
```
(ch 10 already exists from the pilot and uses these slugs in its forward-links.)

**Waves** (parallelize within a wave; checkpoint between):
- **Pilot (pre-Wave-1): ch 10 Trust** — written and finalized **first**; it is the source of
  truth for the trust story and validates the chapter pipeline.
- **Wave 1 — judgment core:** ch 1, 2, 3, 11, 12, 13.
- **Wave 2 — connective:** ch 4, 5, 6, 7, 8, 9 + R1 bestiary (drafted early as 0.4).
- **Wave 3 — depth:** ch 14 (**blocked on missing T7**) + R3 invocation anatomy.
- Reference R2 (matrix) derives from FACTS §F2; R4 (glossary) mines `docs/glossary.md` (vet).

**Dependency model (important):** a chapter's *reading-order* cross-references run both ways
(judgment chapters reference mechanics chapters and vice-versa). The *writing* waves are ordered
by **research-readiness**, not reading order. So a Wave-1 judgment chapter (e.g. ch 11) that
references a Wave-2 mechanics chapter (e.g. ch 9) draws the **facts it needs from FACTS**, not
from the unwritten chapter, and uses a **forward link** for the cross-reference. The pilot ch 10
is the one hard write-order edge: it is finalized before any chapter that leans on the trust
story (ch 2's teaser links to it).

---

## Part I — Orient

### Ch 1 — What QCP is + the one promise
- **Goal:** in one sitting, a practitioner understands what QCP does and the WHAT/WHY promise,
  and can place it among tools they know.
- **In:** the one promise (STYLE §2); annotate→symexec→VCs→prove→check pipeline at a *glance*
  (one diagram); the three surfaces (CLI/QIDE/MCP) named; tiers 🟢🔵🟣 introduced as an overlay;
  the first `*`-is-not-multiply box.
- **Out / link:** how `**` works from first principles → tutorials. Deep pipeline mechanics →
  ch 6–9. Full trust → ch 10.
- **Sources:** FACTS §F1 (teaser only), §F3 (pipeline), §F8 (surfaces); `docs/project-overview.md`;
  `README.md`.
- **Tier/AI:** introduce the overlay + dial; no deep callouts yet.
- **Maturity:** battle-tested. **Deps:** none (entry point). **Length:** ~1200–1600 words. **Wave 1.**

### Ch 2 — Should you use QCP?
- **Goal:** a go/no-go decision aid — when QCP beats (or complements) tests/fuzzing/review, and
  what "verified" buys you, honestly.
- **In:** the decision framing (cost vs assurance); what verification gives that testing can't
  (and vice-versa); the **trust teaser** (green check = two-tier; full story ch 10); a pointer
  to scope (ch 3) and effort (ch 12). A short "is it worth it for *my* code?" rubric.
- **Out / link:** the full two-tier audit recipe → ch 10; the full matrix → ch 3/12.
- **Sources:** FACTS §F1 (teaser), §F2.2 (effort one-liner), §F6 (honesty). **"Is it worth it
  for my code?" rubric skeleton to flesh out:** (1) is correctness *consequential* here
  (safety/security/protocol/money)? (2) is the code in QCP's supported scope (ch 3)? (3) is the
  spec stable enough to be worth pinning? (4) do you have budget for the ~25–30% manual tax
  (ch 12)? (5) would a test/fuzz catch this more cheaply? — frame as a decision flow.
- **Tier/AI:** dial framing (tier-1 leans on AI; tier-3 may not). **Maturity:** battle-tested.
  **Deps:** ch 1; **trust teaser must match the finalized ch 10 (written first).** **Length:**
  ~1200–1500. **Wave 1.**

### Ch 3 — Scope at a glance
- **Goal:** fast yes/no on "can QCP handle code like mine?"
- **In:** the support matrix in compact form (FACTS §F2) with the **"Not supported" box**
  (floats · goto · function pointers · shared-memory concurrency) and the right evidence
  provenance (F2.1); "you write ordinary C, the frontend desugars" framing; pointer to ch 12
  for depth and R2 for the full matrix.
- **Out / link:** effort calibration depth → ch 12; predicate inventory → R1 bestiary.
- **Sources:** FACTS §F2 (whole), §F2.3 (under-sold). **Tier/AI:** minimal. **Maturity:**
  battle-tested (verdicts HIGH-confidence). **Deps:** ch 1. **Length:** ~1000–1400. **Wave 1.**

## Part II — Get working

### Ch 4 — Quickstart: Stage A (core verifier, no AI → first green)
- **Goal:** reader gets a real example to a green `goal_check` using only the CLI/QIDE — **no
  MCP/AI setup** (so the AI-setup cliff can't block the day-0 win).
- **In:** install/run path (Linux/macOS; Windows caveated); run `symexec` on a shipped example
  (`QCP_examples/QCP_demos_human/simple_arith/abs.c` / `gcd.c`); read the four output files;
  **then compile to green** — the explicit `make <name>_goal_check.vo` / `coqc` step (note:
  `run-example-linux.sh` runs only `symexec`+`StrategyCheck`, **not** `coqc` on `goal_check`, so
  spell the compile step out); what "green" means here (completeness, teaser → ch 10). Canonical
  command (FACTS §F3.1).
- **Out / link:** AI/MCP onboarding → ch 7 (Stage B); annotation syntax depth → ch 6.
- **Sources:** FACTS §F3, §F7; `README_LINUX.md`/`README_MACOS.md`; `run-example-linux.sh`;
  `docs/verification-pipeline.md` §6/§8; `docs/environment-setup.md`. **VERIFY the commands run
  as written** against the binaries.
- **Tier/AI:** AI dial **off** by design here. **Maturity:** battle-tested (CLI); Windows =
  intended-workflow, caveat. **Deps:** ch 1. **Length:** ~1400–1800. **Wave 2.**

### Ch 5 — Your first spec
- **Goal:** reader writes a `With`/`Require`/`Ensure` spec for a simple function and gets it
  checked.
- **In:** the spec triple; `__return`, `@pre`; a pure-arithmetic example with the `Z`
  range/overflow bound (F4.4, `abs.c`); the ∀-in/∃-out motion (F4.3) at an intro level; first
  `Inv` for a loop (`gcd`).
- **Out / link:** full annotation surface → ch 6; quantifier triad depth → R1.
- **Sources:** FACTS §F4; tutorials T2/T5 (vet); `QCP_examples/QCP_demos_human/simple_arith/`
  `abs.c`,`gcd.c`. **Tier/AI:** light. **Maturity:** battle-tested. **Deps:** ch 4. **Length:**
  ~1400–1800. **Wave 2.**

## Part III — How it works (the pipeline backbone)

### Ch 6 — Annotations as specs
- **Goal:** the practitioner reference for the annotation language as a *spec* tool (not an SL
  course).
- **In:** `With`/`Require`/`Ensure`, `Assert`, `Inv Assert`, `which implies`, `where`,
  `Extern Coq`/`Import Coq`/`include strategies`; basic vs concise; the `data_at` surface shapes
  (all three, F4.2); the storage-predicate reality (`store(...)`, typed compounds — F4.1).
  **Keep to syntax-as-spec.**
- **Out / link:** **full predicate/operator inventory → R1 bestiary**; representation-predicate
  *theory* → ch 8 + tutorials; strategy authoring → ch 14.
- **Sources:** `docs/annotation-language.md` (vet); FACTS §F4. **Tier/AI:** 🔵 for Coq terms.
  **Maturity:** battle-tested. **Deps:** ch 5. **Length:** ~2000–2600. **Wave 2.**

### Ch 7 — Invariants & the AI dial (Stage B: MCP/AI)
- **Goal:** how to delegate invariants & proofs to the LLM, and how to dial delegation per tier.
- **In:** invariants as the WHY you delegate (STYLE §2); the AI **dial** (not a tier); MCP
  onboarding (`qcp-mcp`/`rocq-mcp`) as **Stage B**; the agent phase state machine named (F8);
  honest friction (frontier-model-required, setup cost, Windows gaps).
- **Out / link:** trust of AI-produced proofs → ch 10; stuck AI → ch 11 cause #4.
- **Sources:** FACTS §F8; `docs/mcp-servers.md`, `docs/agent-workflow.md`; `mcp/`. **Tier/AI:**
  central. **Maturity:** **intended-workflow in large part — label clearly.** **Deps:** ch 4, 6.
  **Length:** ~1800–2400. **Wave 2.**

### Ch 8 — Separation logic & the memory model (practitioner depth)
- **Goal:** *just enough* SL/memory model to read predicates and specs fluently — judgment, not
  a course.
- **In:** `*` vs `&&` (a **recap** of the false friend — the *full* box lives in R1; link there,
  don't duplicate); the heap/`emp`/disjointness intuition;
  representation predicates as memory shapes (`sll`, arrays, strings); the flat-byte/~32-bit
  pointer model + struct padding caveats (F2).
- **Out / link:** deriving SL rules / proving `**` properties → tutorials/qua.codes.
- **Sources:** `docs/annotation-language.md` §7–§9, `docs/glossary.md`; FACTS §F2, §F4.
  **Tier/AI:** 🟢 keep the body C-level; 🟣 details in `<details>`. **Maturity:** battle-tested.
  **Deps:** ch 6. **Length:** ~1800–2400. **Wave 2.**

### Ch 9 — Goals, symbolic execution & proof
- **Goal:** what `symexec` *does* and the shape of the VCs you'll prove — so a stuck goal is
  legible.
- **In:** symbolic state, statement-by-statement (F3 + `docs/verification-pipeline.md` §1); the
  four files (F3); witnesses/VC kinds; the proof loop & key tactics named (`Intros`/`Exists`/
  `entailer!`/`sep_apply`); regeneration gotchas (numbering shifts; manual file not overwritten).
- **Out / link:** tactic *tutorial* → `tutorial/T5-prove-vc.md` + `docs/coq-backend.md#tactics`;
  trust meaning → ch 10.
- **Sources:** `docs/verification-pipeline.md`, `docs/coq-backend.md`; FACTS §F3. **Tier/AI:**
  🔵/🟣 heavy. **Maturity:** battle-tested. **Deps:** ch 6. **Length:** ~2000–2600. **Wave 2.**

### Ch 10 — Trust & soundness (PILOT) {#ch10}
- **Goal:** what the green check *actually* means — the two-tier model and how to audit it.
- **In:** the two-tier model (auto `Admitted`/trusted vs manual `Qed`/kernel-checked, F1); the
  `Print Assumptions` audit recipe + the `swap` specimen (F1.1); the TCB (F1.2); the strong true
  property (no false manual proof); the `goal_check`=completeness≠proof distinction; the 6
  admitted strategy rules.
- **Out / link:** SL semantics → ch 8; the "red goal" mirror → ch 11.
- **Sources:** FACTS §F1 (whole); `docs/verification-pipeline.md`, `docs/project-overview.md`.
  **Tier/AI:** all tiers (this is universal); 🟣 for `coqchk`/module-type detail. **Maturity:**
  battle-tested (reproduced live). **Deps:** none hard (write first). **Length:** ~2000–2600.
  **Wave 1 — PILOT.**

## Part IV — Diagnose · scale · extend

### Ch 11 — The Stuck-Goal Differential (flagship)
- **Goal:** when a goal is red, diagnose *whose fault* and what to do — the manual's signature
  contribution.
- **In:** a **pre-check first** — *did the tool even run?* An infrastructure failure (a Python
  traceback / `NameError` / "before worker launch", F9) is **not** a red goal and routes to R5/
  ch13, not into this differential. Then the 4 causes (FACTS §F5) as a **decision-tree diagram**;
  "is it even true?" before "why won't it prove?"; diagnose by authorship (your spec vs LLM's
  invariant); per-cause actions (fix spec / fix code / add predicate-or-lemma / dial AI or add
  strategy). Mirror of ch 10.
- **Out / link:** trust → ch 10; scope limits as cause #3 → ch 12/13; strategy authoring → ch 14.
- **Sources:** FACTS §F5 (+ §F1, §F3 for the facts it needs); `Version_Log/V2-0-3.md` (real
  repair guide); `docs/coq-backend.md`. **Tier/AI:** all tiers; the dial is cause #4's lever.
  **Maturity:** flagship — battle-tested reasoning, but label any tactic recipe that's
  intended-workflow. **Deps:** facts from FACTS (not from unwritten chapters); **forward-links**
  to ch 9 (symexec/goals) and ch 10 (trust). **Length:** ~2200–3000. **Wave 1.**

### Ch 12 — Scope & scaling in depth
- **Goal:** beyond the glance (ch 3) — the *cost* axis and how QCP scales to real codebases.
- **In:** feature-coverage vs effort-cost as two axes (F2.2); the effort calibration (both
  numbers + methodology, F2.2); modular/contract-as-seam scaling; sharded proofs at scale
  (minigmp, F3/F7); the under-sold capabilities (F2.3).
- **Out / link:** the at-a-glance verdicts → ch 3; the full matrix → R2.
- **Sources:** FACTS §F2, §F3, §F7; `docs/examples-catalog.md`. **Tier/AI:** light. **Maturity:**
  battle-tested (global ratio HIGH; category splits medium — say so). **Deps:** ch 3.
  **Length:** ~1800–2400. **Wave 1.**

### Ch 13 — Honest limits & maturity
- **Goal:** the rough edges, stated plainly — the credibility chapter. (Title is **"Honest
  limits & maturity"**, not "& roadmap": the brief bans a speculative roadmap, so "maturity" —
  the chapter's actual spine — is the honest title. Deliberate, recorded rename.)
- **In:** the honesty ledger (F6); the hard boundaries (F2.1) restated as limits; maturity
  labels (battle-tested core vs intended-workflow agent pipeline); MCP/AI friction; Windows
  packaging gaps; the unaudited annotation→VC faithfulness (F1.2); **pipeline infrastructure
  fragility (F9)** — shipped agent-scripts can crash (e.g. the `vc-proving` `NameError`), masking
  a tool fault as unproven obligations; give the self-diagnosis recipe (infra-failure vs
  proof-failure; `pyflakes`/`F821`; audit leftover `Admitted`). **No speculative roadmap — state
  only what the repo documents as intended-workflow vs shipped.**
- **Out / link:** scope detail → ch 12; trust TCB → ch 10; infra-failure triage → R5.
- **Sources:** FACTS §F6, §F1.2, §F2.1, §F8, §F9; `docs/environment-setup.md`, `docs/mcp-servers.md`,
  `docs/qua-codes-tutorial-fixes.md`; the Windows-gap note (`scripts/setup-windows-*.ps1`
  referenced by `README_WINDOWS.md`/`AGENTS_WIN.md` but **not shipped** in this redistributable's
  `scripts/`). **Tier/AI:** all. **Maturity:** this chapter *is* the maturity statement.
  **Deps:** ch 3, 10, 12. **Length:** ~1600–2200. **Wave 1.**

### Ch 14 — Extension: new predicates & strategies
- **Goal:** for tier-3 — add a representation predicate and a `.strategies` rule to extend QCP.
- **In:** defining a Coq `Assertion` predicate; `Extern Coq`-declaring it; writing a
  `.strategies` rule; the `_strategy_proof.v`/`Include` mechanism (verification-pipeline §5);
  the strategy soundness obligation (mostly `Qed`, some trusted).
- **⚠ T7 GAP — release decision (made):** tutorial T7 (strategy authoring) is missing. **Ship a
  by-example chapter** grounded in the shipped `.strategies` files + `verification-pipeline` §5
  and the `_strategy_proof.v`/`Include` mechanism, **clearly labeled intended-workflow /
  by-example**, with named exemplars (e.g. `QCP_demos_human/sll.strategies`,
  `int_array.strategies`, `bst.strategies`). **Do NOT invent strategy DSL syntax** — show only
  forms that appear in real `.strategies` files. (Shorter than a full chapter until T7 lands.)
- **Out / link:** strategy DSL theory → (T7 when written) / `docs/coq-backend.md#strategies`.
- **Sources:** `docs/coq-backend.md`, `docs/verification-pipeline.md` §5; `*.strategies` in the
  corpus. **Tier/AI:** 🟣 only. **Maturity:** **intended-workflow / by-example — flag the T7
  gap.** **Deps:** ch 6, 9. **Length:** ~1800–2400 (or a stub + gap note). **Wave 3.**

## Reference backbone

- **R1 — Bestiary** (`reference/BESTIARY.md`, drafted early as Phase 0.4): predicate/operator
  inventory; the `*` false-friend box; the quantifier triad; the array/string predicate
  families; the `data_at` shapes; the storage-predicate reality (F4). **Wave 2 (early).**
- **R2 — Support matrix** (`reference/SUPPORT_MATRIX.md`): the full FACTS §F2 table + evidence
  provenance + effort calibration. Derives from FACTS. **Wave 1/2.**
- **R3 — Invocation anatomy** (`reference/INVOCATION.md`): every `symexec`/`StrategyCheck` flag;
  `-I` vs `-slp`; logic-path derivation; `-slp` nesting; batch scripts. Source:
  `docs/verification-pipeline.md` §3–§7. **Wave 3.**
- **R4 — Glossary** (`reference/GLOSSARY.md`): mine `docs/glossary.md` (vet every entry).
  **Wave 2/3.**
- **R5 — Troubleshooting & known infrastructure issues** (`reference/TROUBLESHOOTING.md`):
  infra-failure vs proof-failure triage; the static-check recipe (`pyflakes`/`F821`); the
  leftover-`Admitted` audit; the catalogue of known shipped-script bugs (currently the
  `vc-proving` `COQC_TRANSIENT_RETRIES`/`TRANSIENT_COQC_SIGNALS` `NameError`, FACTS §F9 /
  `docs/agent-workflow.md` §9). **Keep it a living list; verify each entry against live source.**
  **Wave 2/3.**

---

## Per-chapter pipeline (every chapter, in clean context)
1. **Assemble** — this brief + FACTS slice + named source excerpts.
2. **Draft** — clean-context writer follows STYLE_GUIDE; task-oriented; diagram where it beats
   prose; tier callouts only where a tier diverges.
3. **Reviews in parallel** — structure · prose · **source fact-check (non-negotiable)**.
4. **Codex review** (`gpt-5.5`/`xhigh`) — independent accuracy gate over the revised draft.
5. **Revise** — apply structure/prose + fix ALL fact-check & Codex findings → final.
