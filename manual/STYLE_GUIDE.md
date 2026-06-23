# QCP User Manual — Style Guide

> **This is the linchpin.** Every chapter draft and every review is fed this file as its
> `style_guide`. It is what makes N independently-written sections read as one book. When a
> rule here conflicts with a writer's instinct, this file wins. When this file is silent,
> default to the [Google developer documentation style](https://developers.google.com/style)
> (plain, task-oriented, second person).
>
> **Companions (produced alongside this file in Phase 0):** `FACTS.md` (the cited facts pack —
> the single source for every quantitative claim and the trust-audit recipe) and `SECTIONS.md`
> (per-chapter briefs). References to them below are forward references to those files.

---

## 1. Who this manual is for, and what it is *not*

**Audience: practitioners** — engineers deciding whether to adopt QCP, and using it to ship
verified C. Not students learning separation logic for its own sake.

**Identity: the judgment & orientation layer.** The QCP manual is a **complement**, not a
re-teaching. The tutorials (`tutorial/T1`–`T6` and `T8`; T7 — strategy authoring — is currently
missing) and the qua.codes site already teach the
*mechanics* (syntax, how to write a `Require`, how symbolic execution steps). This manual
answers the questions those don't:

- *Should* I use this? (vs. tests / fuzzing / review)
- What can it do, and at **what cost**?
- Why is my goal **stuck** — and whose fault is it?
- What does the **green check** actually mean? (trust)
- How do I **drive the AI**?
- What are the **honest limits**?

**The one exclusion rule (enforced in every chapter):** *from-scratch separation-logic and
symbolic-execution pedagogy is OUT of scope.* We do not re-teach what `**` means from first
principles, or derive Hoare logic. When a reader needs that, **link out** to the tutorials or
qua.codes. We teach *judgment about* the mechanics, plus a **practitioner reference** (the
bestiary, the matrix, the invocation anatomy) — not a course.

> **Writer's test:** if a paragraph would fit equally well in a university SL lecture, it
> probably belongs in the tutorial, not here. Cut it or replace it with a link + the
> *judgment* a practitioner needs.

---

## 2. The one promise (state it consistently)

The manual's lead promise — phrase it this way, and don't contradict it later:

> **You write WHAT the code does** — a `Require`/`Ensure` spec plus ready-made ownership
> predicates (`sll`, `store(...)`, `IntArray::full`, …). **The WHY — loop invariants and
> proofs — is largely delegated:** the strategy solver discharges the routine proof obligations
> automatically, and (with the AI dial up) the LLM drafts the loop invariants and the remaining
> proofs, which you review to the depth your tier demands. You only descend into deep separation
> logic when you need a predicate the library doesn't already have.

- Use the **WHAT / WHY** split as the spine metaphor: "you own the WHAT; you delegate (and
  review) the WHY." Be precise about agency — loop invariants are *annotations someone writes*
  (you, or the LLM you direct), **not** something `symexec` invents; `symexec` turns the
  annotated code into the proof obligations and the solver/LLM/human close them.
- Don't oversell it into "no effort." The honest counterweight is the **effort tax** (§6):
  **roughly a quarter to a third of proof effort is still manual** on average (FACTS.md gives
  the exact figures + methodology), and *every* integer result costs a manual range/overflow
  bound. Promise and tax always travel together.

---

## 3. The three tiers + the AI dial (the overlay convention)

QCP is used at three depths. These are an **overlay on shared content**, not separate tracks
or separate books. **Write the main text tier-agnostically; add a tier callout only where a
tier genuinely diverges** (different action, different escape hatch, different expectation).

| Tier | Who | Mode | Relationship to Coq |
|---|---|---|---|
| 🟢 **Tier 1** | C programmer, no Coq | **autopilot** | never reads Coq; writes specs, lets auto-solve + LLM close proofs |
| 🔵 **Tier 2** | C programmer who reads Coq | **co-pilot** | reads/fixes the manual proofs the LLM drafts |
| 🟣 **Tier 3** | SL / Coq expert | **tactical director** | writes new predicates, `.strategies`, extends the library |

**AI is a DIAL, not a fourth tier.** Every tier turns AI delegation up or down; it is not a
persona. Don't write "the AI user" — write "turn the dial up" (more delegation) or "down"
(more by-hand control). Tier-1 practitioners run the dial high; tier-3 often runs it low for
the parts they want to control.

### Callout format (use verbatim)

Use a blockquote led by the tier emoji + bold label. Keep callouts to 1–3 sentences.

```markdown
> 🟢 **Tier 1** — You won't touch this file. If the proof goes red here, hand it to the LLM
> (Chapter 7) and move on.

> 🔵 **Tier 2** — Open `*_proof_manual.v` and read the failing `entailer!`; the missing fact
> is usually a range bound you can add with one `Intros`/`lia` step.

> 🟣 **Tier 3** — Write a `.strategies` rule so this VC discharges automatically for every
> future call (Chapter 14).
```

Rules:
- **Never** gate the *main* narrative behind a tier. The default reader (tier 1) must get a
  complete, working story from the body text alone; callouts add depth for 🔵/🟣.
- A section may have **zero** callouts. Only add one where the tier's action really differs.
- The AI dial is shown inline in prose ("dial up / dial down"), not as a fourth emoji.

---

## 4. Coq exposure: hide by default, expand for experts

The manual is a **layered single document**. Coq detail is **collapsed by default**.

- Lead with the C-level / annotation-level view. Show Coq only when it changes what the reader
  does.
- Put extended Coq (tactic listings, `.v` internals, module-type plumbing) inside a
  `<details>` block or a clearly-marked 🟣 subsection, so tier-1 readers skim past it.

```markdown
<details><summary>🟣 Coq detail: what <code>entailer!</code> leaves behind</summary>

... expert-only material ...

</details>
```

---

## 5. Terminology & notation (canonical — do not vary)

Consistency here is non-negotiable; divergent terms are the fastest way the book stops reading
as one voice. Use the left column; avoid the "don't say" column.

| Concept | Say | Don't say | Note |
|---|---|---|---|
| The tool | **QCP** | "the verifier", "the system" (vary) | "Qualified C Programming" |
| Proof assistant | **Coq/Rocq** | pick one silently | renamed Rocq; repo uses both — say "Coq/Rocq" on first use, then "Coq" |
| `**` / `*` in annotations | **separating conjunction** | "and", "times", "multiply" | THE #1 false friend — see §5.1 |
| `&&` | **ordinary conjunction** (pure facts) | "separating" | pure, heap-independent |
| `Z` | **unbounded mathematical integer** | "int", "number" | load-bearing: the overflow-tax source (§6) |
| `data_at` | **storage predicate** | "pointer" | has surface vs symbolic-state forms (§5.2) |
| `store(...)`, `sll`, `IntArray::full`, … | **ownership / representation predicates** | "structs", "objects" | `store_int` is qua.codes-only (§5.1) |
| `Require`/`Ensure` | **precondition / postcondition** | "input/output spec" | the spec triple |
| `With (x:T)` | **ghost / logical variable** | "parameter" | caller-chosen; spans pre AND post |
| `Inv` / `Inv Assert` | **loop invariant** | "loop assertion" | canonical surface spelling `/*@ Inv Assert … */` (dominant in corpus); bare `Inv` also valid |
| `Assert` | **assertion** (fixes symbolic state) | "check" | |
| VC | **verification condition** | "goal" (ambiguous), "obligation" (vary) | an entailment `P \|-- Q` |
| auto fraction | **auto-solved / strategy-discharged** | "auto-proved" | it's *Admitted*, not re-checked (§7) |
| manual fraction | **kernel-checked / `Qed`-proved** | "machine-checked" *(blanket)* | only this fraction is re-elaborated |

### 5.1 The `*` false friend (always disambiguate on first use in a chapter)

`*` in an annotation is **separating conjunction** (two memory regions, **disjoint**), never C
multiplication and never logical "and". Pure facts join with `&&`; spatial facts join with `*`.
The point is predicate-agnostic; a clear specimen (using the documented typed int-storage form
`data_at(p, int, v)` from tutorial T2):

```c
exists v, v >= 0 && data_at(p, int, v) * data_at(q, int, v)
//          └─ pure (&&): v ≥ 0 ─┘        └─ spatial (*): p and q are DISJOINT cells, same value ─┘
```

> **Note for writers:** `store_int(...)` is a **qua.codes/tutorial-website** spelling and does
> **not** appear in the repo corpus (verified: zero occurrences in `QCP_examples/` and
> `tutorial/`). The corpus's storage surface forms are the generic `store(addr)` predicate (the
> common one), `data_at(...)`, and typed compound predicates (`store_tree`, `store_string`, …).
> Use repo forms in worked examples; the bestiary fixes the exact inventory.

Reserve a **"`*` is not multiply"** box for the first chapter that shows an annotation
(Chapter 1 or 6). The bestiary owns the full treatment.

### 5.2 `data_at` has several surface shapes — keep them straight

`data_at` is **user-written annotation syntax** in more than one shape (all are things a user
types, not just internal state):

- **Typed 3-arg** `data_at(p, int, v)` / `data_at(p, int*, v)` — the typed form taught in
  tutorial T2.
- **Basic 2-arg address/value** `data_at(&x, v)` — "the address of `x` stores value `v`"; this
  is the *basic* annotation style users write (tutorials T3/T4; `docs/glossary.md`,
  `docs/annotation-language.md`), **not** merely an internal form.
- **Concise value-omitted** `data_at(&node->next, struct list*)` — value left implicit.

`symexec` *also* carries the 2-arg shape in the symbolic state it tracks, so you'll see
`data_at(&p, p_v)` in symbolic-state dumps — but don't describe the 2-arg form as
"symbolic-state-only"; it is equally valid hand-written basic syntax. When you mean a specific
shape, say which. In worked examples the corpus most often uses the generic `store(...)`
predicate and typed compounds (`store_tree`, `sll`, `IntArray::full`) rather than raw
`data_at`; prefer those unless the point *is* `data_at`. (Large cases **shard** the
human-editable proof into `*_proof_manual_part1.v … _partN.v` wired under an umbrella
`*_proof_manual.v` — don't imply every manual proof is a single file.)

### 5.3 Coq notation cheat (use the C surface form in body text)

In body prose use the **C annotation** form; show the Coq form only in 🟣 detail.
`*`↔`**`, `exists`↔`EX`, `==`/`!=`↔`=`/`<>`, `emp`↔`emp`, `-*`↔`-*`,
`data_at(p,int,v)`↔`p # Int |-> v`. Keep the `ₛ` in `->ₛ` when you must show Coq struct access.
**Pure propositions have two Coq spellings:** the classic `[| P |]` (tutorials) and the
typographic `“ P ”` (smart quotes) used in the *generated* SimpleC `*_goal.v` files (e.g.
`“ (Z.le 0 i) ”`) — show whichever matches the artifact you're quoting, and gloss it on first
use.

---

## 6. Honesty is a feature — the framings you MUST keep accurate

The existing docs and public tutorials shipped real over-claims and logic bugs; this manual's
credibility *is* its honesty. The following are **load-bearing accuracy rules**. A reviewer
will reject violations.

1. **Two-tier trust (never blur it).** Say: *a manual VC is re-checked by the Coq kernel **when
   it ends in `Qed`**; auto VCs are discharged by symexec's strategy solver and **trusted**
   (`Admitted`), not re-checked.* **Banned phrasings:** "every VC is machine-checked", "no
   `Admitted`", "manual files never contain `Admitted`", "the proof is fully machine-checked"
   *as a blanket statement* — the corpus itself has admitted *manual* stubs (FACTS §F1), so the
   trustworthy unit is a `Qed`, not a file. The strong, true property to state instead: *the
   kernel makes a false **`Qed`** impossible — a generator bug can only make a goal unprovable,
   never falsely "verified", on the manual path.* (Full treatment: trust chapter; see FACTS.md
   for the `Print Assumptions` audit recipe.)
2. **Effort tax travels with every capability claim.** Manual proof is a **minority but real**
   share — **roughly a quarter to a third** of proof effort on average. The example proofs are
   **regenerated artifacts**, so quote counts as approximate snapshots (lead with the command):
   a **shard-aware** lemma count is ≈ **4350 auto / ≈ 1770 manual `Qed` ≈ 2.5 : 1 (≈ 29%
   manual)**; umbrella-only ≈ **3.0 : 1 (≈ 25%)**; the benchmark script reports ≈ **24%**.
   FACTS.md §F2.2 carries the commands — cite a counted number, don't invent one. Skew is
   qualitative/medium-confidence (more manual for arithmetic/OS; less for array/string/list
   reusing shipped predicates). Every `Z` arithmetic result needs a **manual range/overflow
   bound** — there is no overflow automation. Say so wherever you say "automated."
3. **Scope boundaries are hard, but cite the right evidence.** **Floats/doubles, `goto`,
   function pointers / indirect calls, and shared-memory concurrency are unsupported** — but the
   *evidence differs by feature*, so don't blanket them all as "proven from the Coq model":
   - **Floats/doubles** — a genuine **value-model boundary**: every non-int/non-ptr type falls
     through to `Invalid_store` (`SeparationLogic/.../CommonAssertion.v`; `CTypes.v`). State this
     as a hard boundary.
   - **`goto` / function pointers / indirect calls** — there is **no construct for them in the
     open library** (no `Sgoto` AST node; no call-expression constructor; the one LiteOS funcptr
     field is downgraded to `addr` with a "how to model it?" comment). The `symexec`/`lsp`
     **frontend is closed-source**, so this is definitive for the open library; nothing suggests
     the frontend adds lowering, but write "no support in the open model," not "proven
     impossible."
   - **Shared-memory concurrency** — CSL is proven sound in `unifysl` but **never wired into the
     C frontend** (fractional permissions are commented-out dead code).
4. **Separate the two concurrency stories.** Shared-memory concurrency = **unsupported**.
   OS synchronization (LiteOS locks/events/interrupts via **STS** state-machine abstractions) =
   **supported**. Never market the first on the strength of the second.
5. **Label maturity.** Mark content **battle-tested** (proven in the corpus) vs.
   **intended-workflow** (designed, not yet corpus-proven) — especially for tier-2/3 and for
   MCP/AI and Windows. Don't present an intended workflow as a shipped guarantee.
6. **Mine-but-vet.** Every technical claim, example, flag, path, and predicate name is
   **source-verified before it ships** (see §9). Do not copy from the existing `docs/`, the
   tutorials, or qua.codes without re-checking against live repo source — they contain known
   bugs (e.g. the `store_int` missing `v>=0`, the `*(x++)` deref bug).

---

## 7. Voice & mechanics

- **Second person, present tense, active voice.** "You run `symexec`", not "the user should
  run". "QCP emits four files", not "four files are emitted".
- **Lead with the task / the decision, then the mechanism.** Practitioners skim for "what do I
  do / should I". Topic sentence first.
- **Short sentences. One idea per paragraph.** Prefer a table or a diagram to a wall of prose
  when structure beats narration.
- **Confident, not breathless.** No "powerful", "seamless", "simply", "just", "of course".
  If something is hard, say it's hard (that's the honesty dividend).
- **Define-on-first-use, then assume it.** First use of a term in a chapter: bold + one-line
  gloss, with a link to the glossary. Don't redefine across chapters.
- **Examples are real and runnable.** Pull from `QCP_examples/`; cite the path. No invented
  syntax. If you show output, it's output you could actually get.
- **No invented numbers.** Every quantitative claim traces to FACTS.md (which cites source).

---

## 8. Formatting conventions

- **Headings:** sentence case (`## Should you use QCP?`). One `#` H1 per chapter = the title.
- **Code fences — always language-tagged:**
  - `c` — annotated C (specs in `/*@ ... @*/`).
  - `coq` — Coq/Rocq source (`.v`, predicate definitions, tactics).
  - `bash` — shell / `symexec` invocations.
  - `text` — VC dumps, symbolic-state snapshots, tool output, ASCII diagrams.
- **Inline code** for every identifier, path, flag, filename, predicate, tactic: `symexec`,
  `-slp`, `*_proof_manual.v`, `entailer!`, `IntArray::full`.
- **Tables** for reference matter (flags, predicate families, the support matrix, notation).
- **Callouts** via blockquote: tier callouts (§3), and `> **Note:**` / `> **Warning:**` /
  `> **Honest limit:**` for asides. Don't invent new admonition styles.
- **Cross-references:** link by relative path to other chapters and to `tutorial/Tn-*.md`;
  link qua.codes by URL. Reference repo files as `path/to/file:line` where a line helps.
- **Format-agnostic markdown for now.** Drafts are plain GitHub-flavored markdown; an mkdocs
  skeleton comes later (Phase 3). Don't hard-code mkdocs-only syntax beyond `<details>`.

### Mermaid diagrams

Use a diagram when it beats prose — pipelines, state machines, decision trees (the Stuck-Goal
Differential is the flagship diagram). Otherwise prefer a table or a short list.

- Fence with ` ```mermaid `. Prefer `flowchart TD`/`LR` and `stateDiagram-v2`.
- Keep nodes to a handful; label edges. No color theming in drafts (the mkdocs theme handles
  that later). Every diagram has a one-line caption above it stating what it shows.
- Diagrams illustrate, never *replace* the textual claim — a reader who can't render Mermaid
  must still get the point from the surrounding prose.

---

## 9. The verification bar (every draft must pass before it ships)

This manual exists partly *because* the surrounding material over-claimed. So every section is
checked three ways before it's done:

1. **Structure review** — cuts, reorder, altitude (is anything re-teaching mechanics it should
   link out for?).
2. **Prose review** — copy-edit against this guide.
3. **Source fact-check (non-negotiable)** — *every* claim, example, flag, path, predicate, and
   number is verified against **live repo source** + FACTS.md. This is the stage that stops
   over-claims and `store_int`-class bugs. An unverifiable claim is cut or marked
   **intended-workflow**, never shipped as fact.

> When in doubt between "impressive" and "true", ship **true**. The manual's entire value
> proposition is that a practitioner can trust it where they couldn't trust the tutorials.

---

## 10. Quick reference card (pin this while drafting)

- Audience = **practitioner**; identity = **judgment layer**; exclusion = **no from-scratch SL
  pedagogy** (link out).
- The promise = **you write WHAT; you delegate (and review) the WHY** (solver + LLM) — and it
  costs **roughly a quarter to a third manual** (FACTS.md for exact figures).
- Tiers 🟢🔵🟣 are an **overlay**; AI is a **dial**, not a tier.
- `*` = **separating conjunction**, not multiply. `&&` = pure. `Z` = **unbounded** (overflow
  tax).
- Trust is **two-tier**: manual `Qed` re-checked; auto `Admitted` trusted. Never say "every VC
  machine-checked".
- Unsupported, hard: **floats · goto · function pointers · shared-memory concurrency**.
- **Verify every claim against live source.** True beats impressive.
