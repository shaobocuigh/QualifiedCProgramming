export const meta = {
  name: 'manual-sweep-audit',
  description: 'Cross-chapter integration sweep + final adversarial audit of the QCP User Manual',
  phases: [
    { title: 'Find', detail: 'one finder per review dimension, reads the whole manual' },
    { title: 'Verify', detail: 'adversarially verify each BLOCKER/MAJOR finding' },
    { title: 'Synthesize', detail: 'dedupe + order verified findings into a reconcile list' },
  ],
}

const REPO = '/home/shaobo/QualifiedCProgramming'
const M = `${REPO}/manual`

// The distributed corpus (reader-facing). FACTS/STYLE/SECTIONS are GROUND TRUTH, not reviewed.
const CHAPTERS = [
  'ch01-what-qcp-is', 'ch02-should-you-use-qcp', 'ch03-scope-at-a-glance',
  'ch04-quickstart-stage-a', 'ch05-your-first-spec', 'ch06-annotations-as-specs',
  'ch07-invariants-and-the-ai-dial', 'ch08-separation-logic-memory-model',
  'ch09-goals-symexec-and-proof', 'ch10-trust-and-soundness', 'ch11-stuck-goal-differential',
  'ch12-scope-and-scaling', 'ch13-honest-limits', 'ch14-extension',
].map(s => `${M}/${s}.md`)
const REFS = ['BESTIARY', 'SUPPORT_MATRIX', 'INVOCATION', 'GLOSSARY', 'TROUBLESHOOTING', 'INSTALLATION']
  .map(s => `${M}/reference/${s}.md`)
const CORPUS = [...CHAPTERS, ...REFS]

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    dimension: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          doc: { type: 'string', description: 'repo-relative path of the doc with the problem' },
          location: { type: 'string', description: 'section heading or "file:line" so it can be found' },
          severity: { type: 'string', enum: ['BLOCKER', 'MAJOR', 'MINOR', 'NIT'] },
          problem: { type: 'string' },
          fix: { type: 'string', description: 'concrete, minimal fix' },
          evidence: { type: 'string', description: 'quote the conflicting text / cite FACTS slice / the other doc it contradicts' },
        },
        required: ['doc', 'location', 'severity', 'problem', 'fix', 'evidence'],
      },
    },
  },
  required: ['dimension', 'findings'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    isReal: { type: 'boolean', description: 'true only if the problem genuinely exists and the fix is warranted' },
    confidence: { type: 'string', enum: ['HIGH', 'MED', 'LOW'] },
    note: { type: 'string', description: 'why; if refuted, say what the finder missed' },
    revisedFix: { type: 'string', description: 'optional: a better/narrower fix than the finder proposed' },
  },
  required: ['isReal', 'confidence', 'note'],
}

const PREAMBLE = `You are auditing the QCP (Qualified C Programming) **User Manual** for cross-document
integration and final quality. The manual is a USER manual: a C programmer with no separation-logic /
Rocq / symbolic-execution background should be able to start and use QCP, with theory strictly opt-in.

The distributed corpus (read what you need):
CHAPTERS: ${CHAPTERS.join(', ')}
REFERENCE: ${REFS.join(', ')}

GROUND TRUTH (treat as authoritative; do NOT file findings against these, use them to judge the corpus):
- ${M}/FACTS.md — every number/flag/path/claim must trace here (numbers are command-first + snapshot-approximate).
- ${M}/STYLE_GUIDE.md — voice, §4 the user-manual discipline (technical detail only if it changes what the user does;
  no engine internals / provenance / WIP / dormant features; no docs/* or ENGINE_INTERNALS links in reader docs),
  §5 canonical terminology, the 🟢/🔵/🟣 tier + AI-dial convention, the Rocq-vs-Coq rule (prose says "Rocq, formerly Coq";
  literal keywords stay "Extern Coq"/"Import Coq"; tool binary stays "coqc").
- ${M}/SECTIONS.md — the per-chapter brief and the "Out / link" routing map (who OWNS each topic).

Report ONLY real problems with a concrete fix. Be precise about location so a fix can be applied. Prefer
fewer high-confidence findings over a long speculative list. Severity: BLOCKER = factually wrong / contradicts
FACTS or another chapter / breaks the no-prereq promise; MAJOR = misleading or materially inconsistent;
MINOR = clarity/consistency; NIT = polish. Return the structured object.`

const DIMENSIONS = [
  {
    key: 'terminology',
    prompt: `${PREAMBLE}

DIMENSION: **terminology & naming uniformity.** Read every doc and flag drift from the canonical terms (STYLE §5):
- "Rocq (formerly Coq)" in prose; literal keywords stay "Extern Coq"/"Import Coq"; binary/command stays "coqc"/"coqchk"/"_CoqProject". Flag any stray "Extern Rocq"/"Import Rocq", any prose still calling the prover "Coq" without the "(formerly Coq)" gloss on first use per doc, or any literal keyword mangled to "Rocq".
- the trust vocabulary: "two-tier trust", "auto VC / manual VC", "Admitted = trusted/solver-settled vs Qed = kernel-checked", "manual = needs-a-Rocq-proof (NOT a human must hand-type it)", "the one real watch-item = an Admitted in a manual proof". Flag inconsistent or contradictory phrasings of these across chapters.
- the tier overlay 🟢/🔵/🟣 and the "AI dial" (a dial, not a 4th tier) — flag misuse or a tier emoji used with the wrong meaning.
- scope vocabulary: floats = "silent half-stub"; function pointers = "errors loudly"; "separating conjunction" for *; "store/data_at". Flag drift.
Return findings (doc, location, severity, problem, fix, evidence-quote).`,
  },
  {
    key: 'crossref',
    prompt: `${PREAMBLE}

DIMENSION: **cross-reference routing & altitude.** Using SECTIONS' "Out / link" ownership map:
- Every "for X see ch N / R k" must point to the chapter/reference that actually OWNS topic X. Flag mis-routed links (e.g., predicate inventory should route to R1 Bestiary; full trust story to ch10; effort calibration to ch12; flags to R3; glossary to R4; install to R6; troubleshooting/infra-failure to R5).
- Altitude/duplication: a topic should be taught in ONE place; other chapters give a recap and link. Flag any chapter that re-teaches at length what another owns (e.g., re-deriving the memory model outside ch8, re-explaining the full annotation surface outside ch6).
- Flag any internal cross-link whose anchor or filename looks wrong, and any place that SHOULD link to a sibling chapter/reference but doesn't (a dangling concept the reader is left to find alone).
Do NOT re-run the mechanical file-existence check (already done); focus on whether links go to the RIGHT owner and whether altitude is right. Return findings.`,
  },
  {
    key: 'factual',
    prompt: `${PREAMBLE}

DIMENSION: **factual consistency vs FACTS and across chapters.** This is the highest-value lens.
- Every quantitative claim (auto:manual ratio, % manual effort, store-count, strategy-rule count, Rocq version 8.20.1, OCaml version, example counts) must match FACTS and be stated command-first/snapshot-qualified. Flag any hard number that drifts between chapters or isn't in FACTS.
- Behavioural claims must be consistent everywhere they appear: the float "silent half-stub, exits 0" story (ch8/ch13/SUPPORT_MATRIX/ch4); the exit-code caveat (0 on bad-parse + float, 1 on most fatals); funcptr "errors loudly EXIT=1"; the two-tier trust model (auto Admitted trusted/not-rechecked vs manual Qed kernel-checked, per-lemma); the StrategyCheck soundness residue (mostly Qed, named Admitted in string/minigmp); symexec emits FOUR VC files / StrategyCheck three strategy artifacts; the goal_check completeness gate accepting Admitted members; the vc-proving COQC_TRANSIENT_RETRIES bug framing; the canonical command + -slp/-I distinction; -s = stdout-only debug. Flag ANY two docs that state the same fact differently, or any claim contradicting FACTS.
- Flag any claim that is plain wrong against the live repo if you can tell (you may read repo files to check).
Return findings with evidence quoting BOTH conflicting locations (or the FACTS slice).`,
  },
  {
    key: 'promise',
    prompt: `${PREAMBLE}

DIMENSION: **promise-keeping & honesty (adversarial).** Read as a skeptical new user and as a skeptical expert.
- No-prerequisite promise: can a C programmer with zero SL/Rocq/symex background actually start (ch1→ch4) without being blocked or intimidated? Flag any early chapter that front-loads theory, assumes Coq/SL knowledge to even begin, or uses intimidating jargon that would dissuade — especially un-glossed terms before they're defined.
- "Manual ≠ you hand-write it": is it consistently clear the LLM drafts most manual proofs and human effort is small (review + rare hard cases)? Flag anywhere "manual" reads as "you must type proofs by hand".
- Trust honesty WITHOUT over-dramatization: the auto/Admitted fraction is the tool's trusted automation (real verification, just no re-checkable artifact), NOT a soundness hole; the ONE real watch-item is an Admitted in a MANUAL proof. Flag anywhere the manual over-dramatizes the auto fraction as a hole, OR under-states the manual-admit risk.
- STYLE §4 leaks: flag ANY engine-internals (SMT/CDCL/proof-terms/parser/IR), provenance ("reverse-engineered"), WIP/dormant features presented as usable, or links to docs/* or ENGINE_INTERNALS in a reader-facing doc.
Return findings.`,
  },
  {
    key: 'gaps',
    prompt: `${PREAMBLE}

DIMENSION: **completeness / gaps (final-audit critic).** What does a user NEED that is missing or too thin?
Benchmark against what a mature tool manual (e.g. CompCert's) provides. Consider: a top-level index / "start here" / reading-order page; a worked END-TO-END example (esp. a Stage-B / MCP session walkthrough); an error-message catalogue; whether every config knob is documented (R3); whether the install path is complete per-OS; whether there's a clear "what to read for my situation" router; version/changelog/compat notes. Flag genuine gaps (with the doc that should hold the missing content and a concrete fix), and flag any section that is too thin to be useful. Do NOT invent a need the user manual format doesn't have. Return findings.`,
  },
]

phase('Find')
const reviewed = await pipeline(
  DIMENSIONS,
  d => agent(d.prompt, { label: `find:${d.key}`, phase: 'Find', schema: FINDINGS_SCHEMA }),
  (review, d) => {
    const findings = (review?.findings || []).map((f, i) => ({ ...f, dimension: d.key, _id: `${d.key}-${i}` }))
    // Verify only BLOCKER/MAJOR adversarially; pass MINOR/NIT through as auto-real.
    const toVerify = findings.filter(f => f.severity === 'BLOCKER' || f.severity === 'MAJOR')
    const passthrough = findings.filter(f => f.severity === 'MINOR' || f.severity === 'NIT')
      .map(f => ({ ...f, verdict: { isReal: true, confidence: 'MED', note: 'low-severity, not adversarially verified' } }))
    if (!toVerify.length) return passthrough
    return parallel(toVerify.map(f => () =>
      agent(
        `${PREAMBLE}\n\nADVERSARIALLY VERIFY this audit finding. Default to isReal=false unless you can confirm the problem genuinely exists in the named doc and contradicts FACTS / another chapter / the user-manual promise. Read the actual doc(s) and quote the real current text — the finding's line numbers may be stale.\n\nFINDING (dimension ${f.dimension}):\n- doc: ${f.doc}\n- location: ${f.location}\n- severity: ${f.severity}\n- problem: ${f.problem}\n- proposed fix: ${f.fix}\n- finder's evidence: ${f.evidence}\n\nReturn the verdict object. If real but the fix is wrong/too broad, give a revisedFix.`,
        { label: `verify:${f._id}`, phase: 'Verify', schema: VERDICT_SCHEMA }
      ).then(v => ({ ...f, verdict: v })).catch(() => ({ ...f, verdict: { isReal: true, confidence: 'LOW', note: 'verifier errored; kept for manual review' } }))
    )).then(verified => [...verified, ...passthrough])
  }
)

phase('Synthesize')
const all = reviewed.flat().filter(Boolean)
const confirmed = all.filter(f => f.verdict?.isReal)
log(`${all.length} findings; ${confirmed.length} confirmed real after adversarial verify`)

const synthesis = await agent(
  `${PREAMBLE}

You are the SYNTHESIS step of the manual sweep+audit. Below are the verified findings (JSON). Produce a single
de-duplicated, actionable reconcile plan for the main agent to apply.

VERIFIED FINDINGS:
${JSON.stringify(confirmed.map(f => ({ doc: f.doc, location: f.location, severity: f.severity, dimension: f.dimension, problem: f.problem, fix: f.revisedFix || (f.verdict?.revisedFix) || f.fix, confidence: f.verdict?.confidence })), null, 2)}

Tasks:
1. Merge findings that touch the same doc+location (one combined fix each).
2. Drop any that are actually fine or contradict each other (note which).
3. Group the result BY DOC, ordered by severity within each doc.
4. For each kept item give: doc, location, severity, the one-line problem, and the exact concrete fix.
5. End with a short "cross-cutting" list: fixes that must be applied uniformly across many docs (e.g. a term sweep).
Return prose (markdown), not JSON. Be concrete enough that edits can be made directly from your plan.`,
  { label: 'synthesize', phase: 'Synthesize' }
)

return { totalFindings: all.length, confirmed: confirmed.length, byDoc: confirmed.reduce((m, f) => ((m[f.doc] = (m[f.doc] || 0) + 1), m), {}), plan: synthesis }
