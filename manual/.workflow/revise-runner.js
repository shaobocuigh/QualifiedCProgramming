export const meta = {
  name: 'qcp-manual-revise',
  description: 'Apply each chapter\'s Codex review findings: one reviser per chapter, in parallel, verifying fixes against live source',
  phases: [{ title: 'Revise', detail: 'one reviser per chapter applies its Codex findings' }],
}

// args = array of {slug, title, reviewFile}
const chapters = (typeof args === 'string' ? JSON.parse(args) : args)
if (!Array.isArray(chapters) || !chapters.length) throw new Error('revise-runner: args must be a non-empty array')
const REPO = '/home/shaobo/QualifiedCProgramming'

const prompt = (c) => `You are revising ONE chapter of the QCP (Qualified C Programming) User
Manual to apply an independent Codex review's findings. The manual is PRACTITIONER-first and
complements the tutorials (no from-scratch SL pedagogy — link out). Accuracy and honest framing
are paramount.

Read first (absolute paths):
- ${REPO}/${c.file}  — the chapter to revise.
- ${c.reviewFile}  — the Codex review findings to apply (BLOCKER/MAJOR mandatory; apply MINOR/NIT
  unless they conflict with STYLE_GUIDE).
- ${REPO}/manual/FACTS.md (source of truth, already corrected this session — trust it over the
  chapter), ${REPO}/manual/STYLE_GUIDE.md (honesty rules + banned phrasings),
  ${REPO}/manual/SECTIONS.md (canonical filename map + this chapter's brief).

Already-resolved cross-cutting facts (use these; don't re-derive wrong):
- EXIT CODES (re-measured live): no-args / missing input / missing --program-path return EXIT=1;
  a malformed parse AND a float program return EXIT=0. The precise claim is "exit 0 ≠ success"
  (bad-parse + float exit 0), NOT a blanket "fatal errors exit 0" (FACTS §F9).
- reference/SUPPORT_MATRIX.md and reference/TROUBLESHOOTING.md NOW EXIST — links to them resolve.
- Strategy library: ~538 'id :' rules across ~46 .strategies files — if you cite a number make it
  command-first ("grep -rho 'id :' ... | wc -l", a snapshot); do NOT assert a contested figure.
- QCP_demos_LLM has 5 LLM-only cases (array_cases, array_cases_noinv, sortArray2, sortArray3,
  union_find_err_rel), not 4.
- The "≈30 admitted manual stubs" specimen is STALE (tree regenerated to 0) — frame any
  Admitted-in-manual mention drift-robustly ("convention unenforced, was violated during
  authoring; audit with grep — the count moves").
- Cross-chapter links use canonical slugs; links to repo docs need the ../ prefix
  (e.g. ../docs/coq-backend.md#tactics), NOT manual/docs/...

TASK: apply EVERY BLOCKER and MAJOR finding (verify each fix against LIVE repo source with grep
before writing), plus MINOR/NIT where sound. Edit ${REPO}/${c.file} in place. Do NOT introduce
banned phrasings. Keep numbers command-first + snapshot-qualified.

Return a tight changelog: each finding → applied/rejected (reason) + the live evidence used; plus
any residual risk.`

const results = await parallel(
  chapters.map((c) => () => agent(prompt(c), { label: `revise:${c.slug}`, phase: 'Revise' }))
)
return results
