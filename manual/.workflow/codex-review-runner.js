export const meta = {
  name: 'qcp-manual-codex-review',
  description: 'Run a Codex (gpt-5.5/xhigh) review of each manual doc separately — one agent per doc, each shelling out to `codex exec` and returning structured findings',
  phases: [{ title: 'Codex review', detail: 'one Codex review per doc, in parallel' }],
}

// args = array of {slug, title}  (slug = chapter/reference basename without .md, under manual/)
const docs = (typeof args === 'string' ? JSON.parse(args) : args)
if (!Array.isArray(docs) || !docs.length) throw new Error('codex-review-runner: args must be a non-empty array of {slug,title}')
const REPO = '/home/shaobo/QualifiedCProgramming'
const SCRATCH = '/tmp/claude-1000/-home-shaobo-QualifiedCProgramming/c8703996-6a9c-47a6-82e5-0868b8e1d44e/scratchpad'
const TPL = `${SCRATCH}/review-chapter-template.md`

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    verdict: { type: 'string', enum: ['SHIP', 'SHIP-WITH-FIXES', 'REWORK'] },
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

const results = await parallel(docs.map((d) => () => agent(
  `Review ONE QCP manual doc with Codex (gpt-5.5/xhigh) and report the result. Do **not** edit any
repo files. Run exactly these commands from the shell (the review template is the source of the
review instructions and already encodes the user-manual-tone lens):

  sed -e 's#__FILE__#manual/${d.slug}.md#g' -e 's#__TITLE__#${d.title}#g' ${TPL} > ${SCRATCH}/cr-${d.slug}.md
  codex exec -s read-only -C ${REPO} -o ${SCRATCH}/crout-${d.slug}.md - < ${SCRATCH}/cr-${d.slug}.md

If \`codex exec\` errors with a 529/overload, wait briefly and retry it (up to 3 times). When it
succeeds, READ ${SCRATCH}/crout-${d.slug}.md and translate its findings into the structured output:
the overall verdict, and each finding as {severity, location, problem, fix}. Return that — it is
the Codex review of manual/${d.slug}.md, captured structurally.`,
  { label: `codex:${d.slug}`, phase: 'Codex review', schema: SCHEMA, effort: 'low' }
)))

return docs.map((d, i) => ({ doc: `manual/${d.slug}.md`, review: results[i] }))
