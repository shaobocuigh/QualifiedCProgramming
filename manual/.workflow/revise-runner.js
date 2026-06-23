export const meta = {
  name: 'qcp-manual-revise',
  description: 'Apply each chapter\'s Codex review findings + the cross-cutting user-manual-tone rules: one reviser per chapter, in parallel',
  phases: [{ title: 'Revise', detail: 'one reviser per chapter applies its Codex findings + the cross-cutting rules' }],
}

// args = array of {slug, title, file, reviewFile, extra?}
const chapters = (typeof args === 'string' ? JSON.parse(args) : args)
if (!Array.isArray(chapters) || !chapters.length) throw new Error('revise-runner: args must be a non-empty array')
const REPO = '/home/shaobo/QualifiedCProgramming'

const prompt = (c) => `You are revising ONE chapter of the QCP (Qualified C Programming) **USER manual**
to apply an independent Codex review's findings AND a set of cross-cutting rules. The manual is
PRACTITIONER-first; it complements the tutorials (no from-scratch SL pedagogy). Accuracy and a
clean, non-intimidating user-manual voice are paramount.

Read first (absolute paths):
- ${REPO}/${c.file}  — the chapter to revise.
- ${c.reviewFile}  — the Codex review findings (apply BLOCKER/MAJOR; apply MINOR/NIT unless they
  conflict with STYLE_GUIDE).
- ${REPO}/manual/STYLE_GUIDE.md (esp. §4: USER manual — technical detail only if it changes what
  the user does; internal source docs are drafting-only) and ${REPO}/manual/FACTS.md (source of
  truth) and ${REPO}/manual/SECTIONS.md (canonical filename map + this chapter's brief).

CROSS-CUTTING RULES — apply to this chapter regardless of whether a finding names them:
1. **Strip every reference to an internal source doc.** Remove all links AND citations to
   \`docs/*\` (e.g. \`docs/verification-pipeline.md\`, \`docs/coq-backend.md\`, \`docs/agent-workflow.md\`,
   \`docs/mcp-servers.md\`, \`docs/annotation-language.md\`, \`docs/project-overview.md\`,
   \`docs/qua-codes-tutorial-fixes.md\`) and to \`internal/ENGINE_INTERNALS.md\`. \`docs/\` is internal/
   gitignored — a user cloning the distribution does not have it. For each: either state the fact
   plainly inline, OR link a SHIPPED \`tutorial/Tn-*.md\` page or a \`manual/reference/*\` page if the
   content is genuinely there. **DELETE bare "(Source: docs/…)" provenance entirely** — a user
   manual does not cite its own sources. KEEP \`tutorial/*\` links (those ship).
2. **No methodology/provenance** — no "reverse-engineered from the binary", "per DWARF", etc.
3. **No engine internals / WIP** that don't change how the user uses the tool (SMT/CDCL/proof
   terms, module-type *plumbing*, dormant \`--soundness-proof\`). Keep the user-facing consequence.
4. **Keep \`QCP_demos_human\` example paths as-is** — the manual uses them consistently; do NOT
   switch to \`QCP_demos_LLM\` (ignore any finding that says to).
5. Numbers stay command-first + snapshot-qualified; no banned phrasings ("machine-checked"/
   "no Admitted" blanket; "powerful/seamless/simply/just"); no intimidating/over-reassuring tone.
6. Forward-links to not-yet-written \`ch14-extension.md\` / \`reference/GLOSSARY.md\` /
   \`reference/INVOCATION.md\` are OK (canonical slugs; they land in Wave 3) — keep them.

${c.extra ? 'CHAPTER-SPECIFIC NOTE: ' + c.extra : ''}

TASK: apply all BLOCKER/MAJOR findings + the cross-cutting rules (verify any factual fix against
live repo source first). Edit ${REPO}/${c.file} in place. Return a tight changelog: what changed,
what you rejected (with reason), residual risk.`

const results = await parallel(
  chapters.map((c) => () => agent(prompt(c), { label: `revise:${c.slug}`, phase: 'Revise' }))
)
return results
