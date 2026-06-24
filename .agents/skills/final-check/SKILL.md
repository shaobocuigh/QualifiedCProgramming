---
name: final-check
description: 由主 agent 在 symbolic execution 和 manual proof 完成后执行正式 final-check，确认生成文件最新、formal 文件结构合规、相关 Rocq 文件可编译、`*_proof_manual.v` / `common_case_formal_lib` 没有遗留 Admitted 或额外 Axiom，并且没有使用任何 forbidden lemma。
---

# Final Check

这个 skill 只负责正式的收尾检查。
它由主 agent 直接使用；`final-check` phase 保留在状态机中，但不再对应任何 subagent。phase、失败回退点和 stale 规则统一由 `verification-orchestrator` 定义；本 skill 不再重复定义它们。
补充：skill 名称固定为 `final-check`，目录名 `final-check` 仅是文件系统命名。

## 何时使用

- case 已由 `verification-orchestrator` 置于 `final-check` 阶段。
- 本轮 annotation 和 manual proof 已经完成。
- 需要正式确认生成文件没有过期，Rocq 文件可以编译，并且 `*_proof_manual.v` / `common_case_formal_lib` 的结构边界、冻结前缀和 `Admitted` / 额外 `Axiom` review 都符合合同。

## 进入前提

- 当前 case 的 proving 轮次已经收束。
- 主 agent 已确认没有仍在处理中的 witness。
- `Case Brief` 已给出：
  - `lib_frozen_prefix_end_line`
  - `lib_frozen_prefix_snapshot`
  - `proof_manual_scope: witness-proofs-after-lib-migration`

## 直接输出

- 已更新的 `Final Check Checklist`。
- 最终 `Timing Summary`：总 wall-clock 耗时、各 phase 耗时、关键命令耗时、失败重跑耗时、人工 activity 耗时、subagent 等待耗时、最慢 witness/helper 或命令，以及主要耗时归因。关键命令列表只是明细，不能替代总 wall-clock 账本。
- `Blocked / Long Subagent Rounds` 摘要：任何 `blocked` 或耗时超过 600 秒的 subagent 轮次，都必须列出 blocked 原因或长耗时原因、证据和后续动作。
- 清理前固化的完整用时报告 artifact；该报告必须保存在正式交付目录或主状态记录中，不得只留在 `.tmp`。
- 失败原因、回退建议和是否允许进入 `done` 的结论。

## 会使哪些产物失效

- 本 skill 不生成新的 domain 产物。
- 如果检查失败，主 agent 必须把 case 退回正确上游阶段；具体 phase 回退按 orchestrator 规则处理。

## 主 / 子 Agent 局部边界

- `final-check` phase 完全由主 agent 执行，不启动 subagent，也不依赖 delegation ticket。
- 主 agent 独占执行 formal 文件结构审计、symexec、coqc、`Admitted` / 额外 `Axiom` review 和最终 phase 判定。

## 参考文档

1. 先读 `../verification-orchestrator/SKILL.md`
2. `docs/use-notes.md`
3. `docs/symexec-refresh.md`
4. `docs/coq-compilation.md`
5. `docs/admitted-review-and-cleanup.md`
6. `../verification-orchestrator/docs/forbidden_lemma.md`（forbidden lemma 检查）

## 工作步骤

1. 读取当前 `Case Brief`、`Phase Status`、已有 phase timing 记录与 `Final Check Checklist`，确认 `common_case_formal_lib` frozen prefix、`proof_manual_scope`、目标 Rocq 文件和检查范围；记录 `final-check` 的 `phase_started_at`。若前序 phase 缺少人工 activity、subagent wait、失败重跑或 phase 总 wall-clock 计时，立即在 `timing_gaps` 中列出缺口，不要在最后用估算补齐，也不要用少数命令耗时暗示报告已完整。
2. 检查是否残留 annotation / proving scratch、`.tmp` worker workdir、Coq `.aux`、pytest / Python 编译缓存等临时产物，并准备清理。
3. 对比 `common_case_formal_lib` 的冻结前缀与 `Case Brief` 中的 `lib_frozen_prefix_snapshot`；若不一致，立即判定 final-check 失败并回退到正确上游 phase。若差异来自 annotation-phase spec 定义变更但 Case Brief 未重新冻结，应回退到 `annotation` / `goal-frozen` 补齐集成记录；若差异来自 proving 后改写，则回退到 `vc-proving`。
4. 审计 `common_case_formal_lib` 的冻结前缀是否未漂移，且冻结前缀之后只新增 audited helper-suffix `Require Import` 行和 proved helper lemmas；冻结前缀内允许存在 annotation-checking 已批准的数学 spec 定义。若冻结前缀后出现非审计来源的 import、`Admitted`、额外 `Axiom` 或新增顶层 `Definition` / `Fixpoint` / `Inductive` / `Notation`，立即判定 final-check 失败并回退到 `vc-proving`。
5. 审计正式 `*_proof_manual.v` 是否只包含 manual witness theorem 证明；若出现 helper lemmas、helper definitions、`Admitted` 或额外 `Axiom`，立即判定 final-check 失败并回退到 `vc-proving`。
6. 执行 symexec，确认当前生成文件仍对应当前 C 程序，并记录 symexec 命令耗时。
7. 按依赖顺序执行 coqc；每个正式 Rocq 文件分别计时，每一次失败编译和重跑都必须单独记录。长时间编译时尽量补充 `coqc -time` 或等价线索来定位慢 theorem / 慢 tactic。
8. review 检查正式 `*_proof_manual.v` / `common_case_formal_lib` 中是否存在 `Admitted` 定理、额外 `Axiom`，或 helper definitions；工具生成的 `*_proof_auto.v` / `*_goal.v` 中的对应项只识别、不手改，并记录扫描耗时。
9. 对正式 `*_proof_manual.v` 和 `common_case_formal_lib` 执行 **forbidden lemma 扫描**：按 `../verification-orchestrator/docs/forbidden_lemma.md` 中的列表逐个搜索每个 forbidden lemma 名称。若命中任何 forbidden lemma：
   - 记录所有命中位置（文件名、行号、匹配的 lemma 名称）。
   - 判定 `final-check` **失败**。
   - 将 case **回退到 `vc-proving`** 阶段，回退原因：manual proof 中使用了禁止的 lemma。
   - 在失败报告 / `Re-entry Brief` 中附上 forbidden lemma 命中清单，供下一轮 `vc-proving` 修正。
   - 记录扫描耗时。
   若未命中任何 forbidden lemma，记录扫描耗时并继续。
10. 在删除任何 `.tmp` / scratch / worker workdir / `.aux` 之前，先汇总并固化完整 `Timing Summary`。报告必须列出各 phase elapsed seconds、symexec / coqc / review / cleanup 等命令耗时、失败重跑耗时、人工 activity 耗时、subagent 等待耗时、最慢 phase、最慢命令或 witness/helper、主要耗时原因，以及任何 timing gaps。最终摘要必须同时给出 `total_elapsed_seconds`、`total_command_seconds`、`total_failed_rerun_seconds`、`total_human_activity_seconds`、`total_subagent_wait_seconds`、`timing_gap_seconds`；如果某项无法精确获得，写 `unknown` 并说明从哪个 phase 开始缺失。报告还必须包含仍位于 `.tmp` 中、即将被删除的 subagent timing/report/log 的关键信息或摘要，不能只引用即将清理的路径。
   - 守恒要求：`total_elapsed_seconds` 必须是从 case intake 到 cleanup 完成的真实 wall-clock；已记录的子项若不能加总到该值，差额必须作为 `timing_gap_seconds` 明示，不能省略。
   - 报告形态要求：必须区分 `Complete timing ledger`、`Recorded command/subagent details` 和 `Timing gaps`；禁止只写“关键命令耗时”然后称为完整 Timing Summary。
   - 若用户或外部计时器提供了总耗时（例如 1h5m33s），最终报告必须优先纳入该总耗时，并解释内部明细与该总耗时之间的差额。
   - blocked / 长耗时要求：必须单独列出 `Blocked / Long Subagent Rounds`。纳入条件是 `round_outcome = blocked` 或 `elapsed_seconds > 600`。每条记录必须包含 `subagent_name`、phase、elapsed seconds、blocked reason（若有）、long-duration reason（若超过 600 秒）、证据、影响的 witness / 文件、recommended next phase / action。若 subagent report 未提供原因，final-check 必须把它标为 timing/report 缺陷，而不是静默省略。
11. 将第 10 步的完整用时报告保存到不会被 cleanup 删除的位置，例如当前 case 的主状态记录、正式报告文件，或最终答复可引用的持久 artifact；确认报告已写入后，才允许进入 cleanup。
12. 删除本轮产生的临时产物，至少覆盖 `.tmp` 下的 scratch / worker 内容、当前 case 相关 `.aux` 文件，以及本轮测试或脚本产生的 `.pytest_cache` / `__pycache__`；不得删除正式交付文件，并记录 cleanup 耗时。cleanup 耗时若发生在第 10 步报告之后，必须追加到持久报告或在最终答复中补充。
13. 更新 `Final Check Checklist`，并把最终状态建议或失败回退建议交回 `verification-orchestrator` 统一记录。
