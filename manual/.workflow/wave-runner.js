export const meta = {
  name: 'qcp-manual-wave',
  description: 'Draft a wave of QCP manual chapters, each clean-context draft -> parallel structure/prose/source-fact-check -> revise, all chapters pipelined in parallel',
  phases: [
    { title: 'Draft', detail: 'one clean-context tech-writer per chapter' },
    { title: 'Review', detail: 'structure | prose | source-fact-check per chapter, in parallel' },
    { title: 'Revise', detail: 'apply all accepted findings; fix every fact-check item' },
  ],
}

// args = array of chapter specs: {num, title, file, factsSlices, sources, guidance}
const chapters = (typeof args === 'string' ? JSON.parse(args) : args)
if (!Array.isArray(chapters) || !chapters.length) {
  throw new Error('wave-runner: args must be a non-empty array of chapter specs')
}
const REPO = '/home/shaobo/QualifiedCProgramming'

const REVIEW_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    verdict: { type: 'string', enum: ['SHIP', 'SHIP_WITH_FIXES', 'REWORK'] },
    findings: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        properties: {
          severity: { type: 'string', enum: ['BLOCKER', 'MAJOR', 'MINOR', 'NIT'] },
          location: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' },
        },
        required: ['severity', 'location', 'problem', 'fix'],
      },
    },
  },
  required: ['verdict', 'findings'],
}

const common = (c) => `
You are authoring/refereeing ONE chapter of the QCP (Qualified C Programming) User Manual — a
PRACTITIONER-first manual that COMPLEMENTS the tutorials/qua.codes (judgment + reference, NOT a
re-teaching of separation-logic mechanics from scratch — link out for that).

Read these first (absolute paths under ${REPO}):
- manual/STYLE_GUIDE.md  — voice, the WHAT/WHY promise, the 🟢/🔵/🟣 tier overlay + AI-dial
  convention, canonical terminology, the HONESTY rules (two-tier trust — never claim a green
  build is checked end to end; the effort tax; hard scope boundaries; mine-but-vet), formatting +
  Mermaid conventions, the canonical filename map.
- manual/FACTS.md  — the SINGLE SOURCE OF TRUTH for every factual/quantitative claim. This
  chapter's slices: ${c.factsSlices}. Every number/flag/path/predicate must trace to FACTS
  (numbers are command-first + approximate snapshots — keep them that way). If a claim isn't in
  FACTS and you can't verify it live, do NOT ship it.
- manual/SECTIONS.md  — find the "Ch ${c.num}" brief (goal/scope/sources/tier/length) AND the
  "Canonical filenames" map; use those EXACT slugs for cross-reference links.
- repo sources for this chapter: ${(c.sources || []).join(', ')}.
- manual/ch10-trust-and-soundness.md already exists (the finished pilot) — match its voice, and
  link to it for the full trust story rather than repeating it.

Hard rules: second person, active voice, task/decision first. Inline-code every identifier/path/
flag. Tier callouts ONLY where a tier diverges. A diagram only where it beats prose. Examples
real (cite QCP_examples paths). NO invented syntax/numbers/flags/predicates. Honesty rules are
load-bearing — model the two-tier trust framing, the float "silent half-stub" nuance, and
"funcptr errors loudly" exactly as FACTS states them.
`

async function draft(c) {
  await agent(
    `${common(c)}

Also read-and-follow ${REPO}/.agents/skills/bmad-agent-tech-writer/write-document.md (authoring
discipline; no interactive persona).

TASK: write Chapter ${c.num} — "${c.title}" — to ${REPO}/${c.file} (create it; GFM; H1 = title).
Length/scope per the SECTIONS brief.

Chapter-specific guidance:
${c.guidance}

Write the file with Write. Return ONLY a 3-5 line note: the outline used, any claim you could
NOT verify (and how you handled it), and any open question for review.`,
    { label: `draft:ch${c.num}`, phase: 'Draft' }
  )
  return c
}

async function review(c) {
  const mk = (kind, instr) => agent(
    `${common(c)}\n\nYou are the ${kind} reviewer for ${REPO}/${c.file}. ${instr} Return findings.`,
    { label: `review:${kind}:ch${c.num}`, phase: 'Review', schema: REVIEW_SCHEMA }
  )
  const reviews = (await parallel([
    () => mk('structure', 'Judge altitude (re-teaching mechanics it should link out for?), ordering, cuts, scope adherence, tier-callout placement, whether it hits the SECTIONS goal. Propose concrete cuts/reorders.'),
    () => mk('prose', 'Copy-edit against STYLE_GUIDE: second person/active voice, banned words ("powerful/seamless/simply/just") and banned honesty phrasings, term consistency, define-on-first-use, code-fence language tags, callout format.'),
    () => mk('facts', 'NON-NEGOTIABLE: verify EVERY claim/number/flag/path/predicate/example against LIVE repo source (grep SeparationLogic, QCP_examples, tutorial, docs) and manual/FACTS.md. Flag any over-claim (esp. two-tier trust, the float silent-half-stub, funcptr-errors-loudly), any nonexistent predicate/flag, any example that wouldn\'t parse, any number not traceable to FACTS or not snapshot-qualified. BLOCKER = a factual error or banned over-claim.'),
  ])).filter(Boolean)
  return { c, reviews }
}

async function revise({ c, reviews }) {
  const findings = reviews.flatMap(r => r.findings || [])
  const findingsText = findings
    .map((f, i) => `${i + 1}. [${f.severity}] (${f.location}) ${f.problem}  ->  FIX: ${f.fix}`)
    .join('\n')
  const note = await agent(
    `${common(c)}

TASK: revise ${REPO}/${c.file} by applying the review findings below. Apply ALL fact-check
findings (BLOCKER/MAJOR mandatory; verify each fix against live source first). Apply
structure/prose findings unless one violates STYLE_GUIDE (if you reject one, say why). Edit in
place.

FINDINGS:
${findingsText || '(none — confirm the draft is clean and return a one-line note)'}

Return a short changelog: changed / rejected (why) / residual risk for a final Codex pass.`,
    { label: `revise:ch${c.num}`, phase: 'Revise' }
  )
  return {
    chapter: `Ch ${c.num} — ${c.title}`, file: c.file,
    verdicts: reviews.map(r => r.verdict),
    findings: findings.length, blockers: findings.filter(f => f.severity === 'BLOCKER').length,
    note,
  }
}

const results = await pipeline(chapters, draft, review, revise)
return results.filter(Boolean)
