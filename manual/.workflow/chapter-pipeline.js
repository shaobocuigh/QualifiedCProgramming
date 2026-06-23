export const meta = {
  name: 'qcp-manual-chapter',
  description: 'Draft one QCP manual chapter in clean context, run parallel structure/prose/source-fact-check reviews, then revise to final',
  phases: [
    { title: 'Draft', detail: 'clean-context tech-writer authors the chapter from STYLE_GUIDE + FACTS slice + brief + sources' },
    { title: 'Review', detail: 'structure ∥ prose ∥ source-fact-check, in parallel' },
    { title: 'Revise', detail: 'apply all accepted findings; fix every fact-check item' },
  ],
}

// args = {
//   num, title, file,                // e.g. "10", "Trust & soundness", "manual/ch10-trust-and-soundness.md"
//   factsSlices,                     // e.g. "F1, F1.1, F1.2"
//   sources,                         // array of repo paths to read
//   guidance,                        // chapter-specific drafting guidance (structure, diagram, tier callouts)
// }
// args may arrive as a parsed object OR as a JSON string depending on how it was passed —
// normalize defensively so c.num/c.title/c.file/etc. always populate.
const c = (typeof args === 'string' ? JSON.parse(args) : (args || {}))
if (!c.num || !c.file) {
  throw new Error('chapter-pipeline: args missing required fields (num/file). Got keys: ' + Object.keys(c).join(','))
}
const REPO = '/home/shaobo/QualifiedCProgramming'

const common = `
You are authoring/refereeing ONE chapter of the QCP (Qualified C Programming) User Manual — a
PRACTITIONER-first manual that COMPLEMENTS the tutorials/qua.codes (it gives judgment + reference,
it does NOT re-teach separation-logic mechanics from scratch — link out for that).

Authoritative inputs you MUST read first (absolute paths under ${REPO}):
- manual/STYLE_GUIDE.md  — the linchpin: voice, the WHAT/WHY promise, the 🟢/🔵/🟣 tier overlay +
  AI-dial convention, canonical terminology, the HONESTY rules (two-tier trust — never say
  "every VC is machine-checked"; the effort tax; hard scope boundaries; mine-but-vet), formatting
  + Mermaid conventions.
- manual/FACTS.md  — the single source of truth for every factual/quantitative claim. This
  chapter's slices: ${c.factsSlices}. Every number/flag/path/predicate you state must trace to
  FACTS (which cites live source). If it isn't in FACTS and you can't verify it against live repo
  source, do NOT ship it — cut it or mark it intended-workflow.
- manual/SECTIONS.md  — find the "Ch ${c.num}" brief; it fixes goal/scope(in,out)/sources/
  tier needs/length. Honor the exclusion rule (no from-scratch SL pedagogy → link out).
- These repo sources for this chapter: ${(c.sources || []).join(', ')}.

Hard rules: second person, active voice, task/decision first. Inline-code every identifier/path/
flag. Tier callouts ONLY where a tier diverges. A diagram only where it beats prose. Examples must
be real (cite QCP_examples paths). NO invented syntax, numbers, flags, or predicate names.
`

phase('Draft')
const draftNote = await agent(
  `${common}

Also read-and-follow the methodology in ${REPO}/.agents/skills/bmad-agent-tech-writer/write-document.md
(the document-authoring discipline — do NOT activate any interactive persona; just write).

TASK: write Chapter ${c.num} — "${c.title}" — to ${REPO}/${c.file} (create it; GitHub-flavored
markdown; H1 = the chapter title). Target length and scope per the SECTIONS brief.

Chapter-specific guidance:
${c.guidance}

Write the file with the Write tool. Then return ONLY a 3-5 line note: the section outline you
used, any claim you could NOT verify (and how you handled it), and any open question for review.`,
  { label: `draft:ch${c.num}`, phase: 'Draft' }
)

phase('Review')
const REVIEW_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    verdict: { type: 'string', enum: ['SHIP', 'SHIP_WITH_FIXES', 'REWORK'] },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          severity: { type: 'string', enum: ['BLOCKER', 'MAJOR', 'MINOR', 'NIT'] },
          location: { type: 'string' },
          problem: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['severity', 'location', 'problem', 'fix'],
      },
    },
  },
  required: ['verdict', 'findings'],
}

const reviews = await parallel([
  () => agent(
    `${common}\n\nYou are the STRUCTURE reviewer (bmad editorial-review-structure discipline) for
${REPO}/${c.file}. Read it + the SECTIONS Ch ${c.num} brief + STYLE_GUIDE. Judge: altitude (is it
re-teaching mechanics it should link out for?), ordering, cuts, missing scaffolding, tier-callout
placement, whether the chapter stays within its scope and hits its goal. Propose concrete cuts/
reorders. Return findings.`,
    { label: `review:structure:ch${c.num}`, phase: 'Review', schema: REVIEW_SCHEMA }
  ),
  () => agent(
    `${common}\n\nYou are the PROSE reviewer (bmad editorial-review-prose discipline) for
${REPO}/${c.file}. Copy-edit against STYLE_GUIDE: second person/active voice, banned words
("powerful/seamless/simply/just"), term consistency (the canonical terminology table), define-on-
first-use, code-fence language tags, callout format. Return concrete fixes as findings.`,
    { label: `review:prose:ch${c.num}`, phase: 'Review', schema: REVIEW_SCHEMA }
  ),
  () => agent(
    `${common}\n\nYou are the SOURCE FACT-CHECK reviewer (NON-NEGOTIABLE) for ${REPO}/${c.file}.
Verify EVERY claim, number, flag, path, predicate name, and code example against LIVE repo source
(grep ${REPO}/SeparationLogic, ${REPO}/QCP_examples, ${REPO}/tutorial, ${REPO}/docs) and against
manual/FACTS.md. Flag anything that over-claims (esp. the two-tier trust framing), any predicate/
flag that doesn't exist, any example that wouldn't parse, any number not traceable to FACTS. This
is the stage that stops over-claims and store_int-class bugs. Return findings; BLOCKER = a factual
error.`,
    { label: `review:facts:ch${c.num}`, phase: 'Review', schema: REVIEW_SCHEMA }
  ),
]).then(rs => rs.filter(Boolean))

phase('Revise')
const allFindings = reviews.flatMap(r => r.findings || [])
const findingsText = allFindings
  .map((f, i) => `${i + 1}. [${f.severity}] (${f.location}) ${f.problem}  →  FIX: ${f.fix}`)
  .join('\n')

const reviseNote = await agent(
  `${common}

TASK: revise ${REPO}/${c.file} by applying the review findings below. Apply ALL fact-check
findings (BLOCKER/MAJOR are mandatory; verify each fix against live source before applying).
Apply structure/prose findings unless one would violate STYLE_GUIDE — if you reject one, say why.
Edit the file in place with Edit/Write.

FINDINGS:
${findingsText || '(no findings — confirm the draft is clean and return a one-line note)'}

Return a short changelog: what you changed, what you rejected (and why), and any residual risk a
final Codex pass should look at.`,
  { label: `revise:ch${c.num}`, phase: 'Revise' }
)

return {
  chapter: `Ch ${c.num} — ${c.title}`,
  file: c.file,
  draftNote,
  reviewVerdicts: reviews.map(r => r.verdict),
  findingCount: allFindings.length,
  blockers: allFindings.filter(f => f.severity === 'BLOCKER').length,
  reviseNote,
}
