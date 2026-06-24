---
name: verification-orchestrator
description: 为单个验证 case 维护 phase、固定 phase subagent 合同、phase ownership、scratch 生命周期、formal 文件边界、工件模板和失效传播规则；用于主 agent 编排子 agent 与各个验证 skill。
---

# Verification Orchestrator

这个 skill 是单个验证 case 的唯一编排入口。
任何端到端验证、phase 切换、返工判断、固定 phase subagent 启动、phase ownership、scratch 生命周期、formal 文件边界和 stale 管理，都应先遵守本 skill 的规则，再进入具体 domain skill。

## 何时使用

- 开始一个新的验证 case。
- 从一个 phase 切换到另一个 phase。
- 需要为某个 delegated domain phase 启动固定命名的 subagent。
- 需要为 `annotation-subagent` 或 `vc-proving-subagent` 创建、重建或清理 scratch 文件。
- 需要判断当前长时间迭代 phase 是否应继续由 subagent 持有，还是应以 `completed` / `blocked` / `stale` 返回。
- 需要判断某次改动会让哪些下游结论失效。
- 需要为当前 case 建立或更新 `Case Brief`、`Witness Ledger`、`Phase Status`。
- 需要记录各 phase、关键命令、witness/helper 证明、subagent 等待、失败重跑、正式集成和 cleanup 的耗时，并在收尾时判断主要耗时点；关键命令摘要不能替代完整 wall-clock 账本。
- 需要在 `final-check` phase 由主 agent 直接执行正式收尾检查。

## 主 / 子 Agent 总边界

- 主 agent 是单点编排者、单点正式写入者、单点 phase 状态提交者。
- 当前仓库只承认 3 个固定命名的 phase subagent：
  - `annotation-subagent`
  - `vc-checking-subagent`
  - `vc-proving-subagent`
- 子 agent 默认只读。
- 只有在主 agent 显式分配、且文件不属于当前 case 主状态集时，子 agent 才允许写入。
- `annotation-subagent` 只拥有 annotation C scratch、`annotation_scratch_lib` 和该 C scratch 上的 `qcp-mcp` 会话。
- `annotation-subagent` 同时拥有本轮 annotation / spec 质量门：每次 `annotation-filling` 形成候选 C annotation 和 `annotation_scratch_lib` spec patch 后，必须调用 `annotation-checking`；检查未通过时继续在同一 annotation 轮次中返工，不得交回 main 触发正式回填或 symexec。
- `vc-proving-subagent` 只拥有 proving scratch、`.tmp` worker workdir、`task_local_scratch_lib` 和本轮脚本化 worker-local `coqc.exe` / `coqtop.exe` 编译反馈使用权；Windows 下不得调用 `rocq-mcp`，默认通过 concurrent worker pipeline 推进证明。若已有证据表明 Codex CLI / transport / backend / worker 会话不可恢复，则允许它在同一轮次切换到 proving scratch 上的串行 fallback 证明。证明期间不得写 `common_case_formal_lib`。
- `qcp-mcp` 只用于 annotation / QCP symbolic execution 相关隔离检查；Windows 下 `vc-proving` 不使用 `rocq-mcp`。主 agent 若要复核，必须等当前 subagent / worker 结束并关闭本轮工作区后再串行接手，且不得把复核变成本轮 vc-proving 的替代性串行证明。进入 vc-proving 串行 fallback 时，也仍然只允许当前 `vc-proving-subagent` 使用隔离的 Rocq 编译循环。
- 当前 case 的主状态文件永远由主 agent 独占。
- `annotation`、`vc-checking`、`vc-proving` 只允许交给各自固定绑定的 subagent；`final-check` 由主 agent 直接持有。
- 只要进入上述 delegated phase 的新轮次，主 agent 都必须先新开对应 subagent 进程；不得继续把该 phase 的 domain 分析长期留在 main 线程中。
- 对 `annotation` / `vc-proving` 这类长时间迭代 phase，subagent 一旦接手就拥有整个本轮 domain loop；主 agent 不能因为等待较久就提前打断并自己接管。
- 主 agent 只有在输入 stale、用户明确取消/改向、或会话已不可恢复时，才可以结束当前 subagent 轮次；结束后应优先重开同名 subagent，而不是改由 main 线程继续该 phase。

## Lib 术语定义

当前 agent 系统只使用以下四类 lib 名称；文档、ticket、prompt 和脚本报告都应使用这些名称，不使用未限定泛称。

- `annotation_scratch_lib`：annotation phase 中由 `annotation-subagent` 从 `common_case_formal_lib` 复制或创建的 spec 定义候选库。它只用于设计 / 修正数学 spec，并在通过 `annotation-checking` 后由主 agent 将候选变更集成回 `common_case_formal_lib`。
- `worker_helper_scratch_lib`：vc-proving 并发模式下，每个 proof group worker 自己的组内 helper 库。worker 只能在这里写 reusable helper lemmas 和必要的 audited helper imports，不能把 helper 写入 worker manual 或任何 case formal 文件。
- `task_local_scratch_lib`：单轮 vc-proving 的 case-local 集成候选库。它从 `common_case_formal_lib` 最新快照创建，保持冻结前缀不变，只在 helper-migration 后接收 audited helper-suffix imports 和 proved helper lemmas。
- `common_case_formal_lib`：当前 case 的主状态 Rocq lib，属于主状态文件集，只能由主 agent 在 annotation 通过质量门或 vc-proving 全部 witness 完成后批量集成修改。`common_case_formal_lib` 是 final-check 与正式 coqc 的对象，不允许 worker 或 phase subagent 直接修改。

## 当前 case 主状态集

默认包含：

- 目标 `.c`
- 对应 `*_goal.v`
- 对应 `*_proof_auto.v`
- 对应 `*_proof_manual.v`
- 对应 `*_goal_check.v`
- 对应 `common_case_formal_lib`

其中：

- `*.c`、`*_proof_manual.v`、`common_case_formal_lib` 只允许主 agent 手工修改；annotation-subagent 只能提出 scratch C / `annotation_scratch_lib` patch。
- `*_goal.v`、`*_proof_auto.v`、`*_goal_check.v` 只允许主 agent 通过 symexec 刷新，不允许任何 agent 手工改写。
- `*_proof_manual.v` 最终只允许保留当前 case 的 manual witness theorem 证明；worker-local / merged scratch manual 可暂存 proved helper lemmas，但进入正式集成前必须连同必要的 audited helper-suffix imports 迁移到本轮 `task_local_scratch_lib`。
- `common_case_formal_lib` 的 user-owned 前缀必须在 `Case Brief` 中冻结；若 annotation phase 集成了 checked spec 定义变更，主 agent 必须先刷新 `lib_frozen_prefix_end_line` / `lib_frozen_prefix_snapshot`，再进入 `goal-frozen` / proving。worker proving 阶段和 vc-proving 迭代阶段对 `common_case_formal_lib` 一律只读。audited helper-suffix imports 与 proved helper lemmas 先汇总到本轮 `task_local_scratch_lib` 后缀；只有当前 proving 轮次所有目标 VC 都完成、handoff manual 已去除 helper 后，主 agent 才能把 `task_local_scratch_lib` 后缀与 handoff manual 一次性合并回 `common_case_formal_lib` / `*_proof_manual.v`。

## 当前 case phase scratch 集

这些文件不属于主状态集，但属于 phase-owned 临时工作区：

- annotation 轮次：
  - `.tmp/<relative-case-dir>/<stem>__annotation_subagent_tmp.c`
  - `.tmp/<relative-output-dir>/<stem>__annotation_subagent_tmp_lib.v`
- proving 轮次：
  - `.tmp/<relative-case-dir>/<stem>__vc_proving_subagent_tmp_proof_manual.v`
  - `.tmp/<relative-case-dir>/<stem>__vc_proving_subagent_tmp_lib.v`

规则：

- scratch 文件应位于 `.tmp` 子目录下，并尽量保持与正式文件一致的相对目录结构。
- scratch 必须由 owning subagent 从最新正式快照重新创建；不能长期复用旧轮次副本。
- phase 完成、phase 输入 stale、主 agent 已正式集成、或上游刷新后，scratch 必须立即删除。
- `vc-proving` round checkpoint、`partial_proof_packet.json` 和 `reuse_index.json` 是 `.agents/reports` 下的持久 report artifact，只能用于下一轮 fresh scratch 的 proof-reuse prepass：上下文匹配时做 direct reuse candidate，存在相似 VC 但上下文不匹配时生成 worker proof-pattern reference；它们不是第五类 lib，也不是可继续运行的 scratch。
- 主 agent 在进入 `done` 或结束当前 case 工作流前，必须先把完整用时报告固化到不会被 cleanup 删除的位置，再执行最终临时文件清理，删除本轮 `.tmp` 内容、Coq `.aux`、pytest / Python 编译缓存等非交付产物。
- 若当前 case 还没有 `common_case_formal_lib`，`vc-proving-subagent` 仍应为本轮创建最小 `task_local_scratch_lib` 搭档；是否需要正式落盘，由主 agent 在集成时决定。
- proving scratch pair 必须保持与正式文件相同的结构合同：worker-local / merged scratch `*_proof_manual.v` 可暂存 witness proof 和 proved helper lemmas；helper-migration 后的 scratch `*_proof_manual.v` 只保留 witness proofs，`task_local_scratch_lib` 保留冻结前缀并在后缀接收 audited helper-suffix imports 与 migrated helper lemmas。`task_local_scratch_lib` 是本轮唯一可写 helper 汇总区；`common_case_formal_lib` 不得在单个 witness 或单个 subagent 目标完成时被增量修改。

## Persistent Reports Layout

每个 case 的持久 report 必须保存在当前 `.agents/reports` 组织方式下：

- run root: `.agents/reports/<relative-case-dir>/<YYYY-MM-DD>/<case-name>-<YYYYMMDDTHHMMSS>/`
- run root 固定保存：`case_brief.md`、输入快照、正式生成物快照、最终 timing / checklist 等跨 phase 工件。
- round dir: `<YYYYMMDDTHHMMSS>-<phase>-r<N>[-<scope>]`，例如 `20260521T010100-annotation-r2`、`20260521T012500-vc-triage-r1`。
- round dir 固定保存本轮 report：`timing_log.md`、`subagent_return_report.md`、phase 专属 report；worker 产物放入 `worker_reports/` 或复制为 round-level summary。
- `vc-proving` round dir 可保留 `reuse_checkpoints/<round-id>/`：其中固定包含 `vc_proving_round_checkpoint.json`、`partial_proof_packet.json`、`reuse_index.json`、helper-free manual snapshot 和本轮 `task_local_scratch_lib` snapshot。该目录是审计 / 复用报告，不属于 active scratch；最终 cleanup 不删除 `.agents/reports` 下的 checkpoint。
- canonical report 文件名使用 snake_case：`annotation_filling_analysis.md`、`annotation_checking_report.md`、`vc_checking_informal_proof_report.md`、`proof_strategy_report.md`、`vc_proving_failure_analysis.md`。若历史目录存在 hyphen 版本，只读参考，不再新建。

`Case Brief` 必须记录 `persistent_report_dir` 和 `report_layout: run-root-snapshots-plus-round-dirs`。每个 delegation ticket 必须给出本轮 `round_report_dir`、`timing_log_path` 和对应 phase 的 expected report path。最终 cleanup 不得删除 `.agents/reports` 下的持久工件。

## Delegation 硬规则

- 只有 `annotation`、`vc-checking`、`vc-proving` 允许分派子任务，且只能分派给固定绑定的 phase subagent。
- `intake`、`goal-frozen`、`final-check` 和 `done` 禁止分派；这些 phase 只允许主 agent 串行推进状态。
- 每个子 agent 只服务自己绑定的 phase；phase、目标 witness 集或冻结版本一旦变化，应以同名角色重新开新进程。
- stale 的子任务结果不能续用；必须按 `invalidation-rules.md` 重新开分析。
- `qcp-mcp` 只允许在 annotation C scratch 上分派给 `annotation-subagent`。
- Windows 下 `vc-proving-subagent` 不使用 `rocq-mcp`；只允许使用脚本创建的 worker-local manual / proving scratch 上的 `coqc.exe` / `coqtop.exe` 编译循环。若并发 worker 环境已被确认不可恢复，则允许切换到 proving scratch 或 scratch-local manual 上执行串行 fallback。
- symexec、coqc、`Admitted` / 额外 `Axiom` review、`final-check` 的正式执行、phase 切换和主状态文件写入，永远不能分派给子 agent。
- `common_case_formal_lib` helper 合并是主 agent 独占的集成动作，且只能在当前 vc-proving 轮次所有目标 witness 都完成后执行；不得因为某个 worker/subagent 先证明出 helper lemma 就提前追加到 `common_case_formal_lib`。
- 对 `annotation` / `vc-proving`，delegation 的单位是“整个本轮迭代流程”，不是“先出一版再说”。
- 已绑定给 subagent 的 phase，不允许因为 main 等待过久就切回 main 线程接管。
- “哪个 phase 绑定哪个 subagent、何时必须重开”，以 `docs/state-machine.md` 和 `docs/delegation-contracts.md` 为准。
- 每次 phase 进入和离开都必须更新 `Phase Status` 中的 timing 字段；delegated phase 的耗时由 subagent report 提供，main-owned phase 的耗时由主 agent 直接记录。除命令耗时外，主 agent 还必须记录人工分析、等待 subagent、失败重跑、正式文件回填/合并、proof 修改、helper lemma / 冗余 lemma 清理、review/cleanup 等 wall-clock activity 耗时。
- Timing 必须做 wall-clock 守恒检查：最终 `total_elapsed_seconds` 应等于或覆盖从 intake 开始到 cleanup 结束的真实总耗时；所有已知子项（命令、subagent、人工 activity、等待、cleanup）都要分项列出。若任何时段没有精确记录，不得用几个命令耗时冒充完整报告，必须把剩余时间显式列为 `timing_gap_seconds`，并说明缺口来源（例如 subagent setup/teardown、重复 coqc 失败重跑、主线程集成、等待通知）。
- Timing 必须使用增量 `activity ledger`，不能只在事后估算。主 agent 和 subagent 在开始一段非命令工作前，必须先向 `timing_log.md` 追加一条 `START` 记录；该段工作结束后立即追加对应 `END` 记录，并写明 `elapsed_seconds`、`status` 和高层摘要。这里的 “thinking” 只指可审计的 proof-planning / proof-generation activity，不得记录隐藏 chain-of-thought；摘要只写策略、目标、失败原因、产物。
- 主 agent 启动 subagent 时必须拆分记录：`subagent-launch-requested`、`subagent-spawn-returned`、`subagent-first-timestamp-observed`（来自 subagent 自己的第一条 ledger 记录）、`subagent-finished-observed`、必要时的 `subagent-close-requested` / `subagent-close-finished`。最终报告必须分别给出 main 等待时间、subagent 自身运行时间、启动/通知/关闭开销，不能把它们混成一个 `subagent-wait`。
- 每条 activity ledger 记录至少包含：`event_id`、`parent_event_id`、`actor`（main 或 subagent 名）、`phase`、`round_id`、`witness_or_helper`（若适用）、`activity_kind`、`started_at`、`finished_at`、`elapsed_seconds`、`status`、`artifact_paths`、`summary`。若发生崩溃或中断，未闭合的 `START` 必须在返回报告中列为 `open_or_incomplete_timing_events`。
- 长耗时/blocked 记录阈值固定为 `long_subagent_threshold_seconds = 600`。任何 subagent 轮次若返回 `blocked`，或 elapsed/wait wall-clock 超过 600 秒，主 agent 必须在 `Phase Status` 和最终 `Timing Summary` 中记录：
  - `subagent_name`
  - `round_outcome`
  - `elapsed_seconds`
  - `blocking_reason`（若 blocked）
  - `long_duration_reason`（若超过 600 秒）
  - 主要证据（失败命令、超时、慢 witness/helper、工具不可用、等待 worker、反复编译等）
  - `recommended_next_phase` / 后续动作

## 先读哪些文档

1. `docs/use-notes.md`
2. `docs/phase-ownership.md`
3. `docs/state-machine.md`
4. `docs/artifact-templates.md`
5. `docs/delegation-contracts.md`
6. `docs/invalidation-rules.md`
7. `docs/forbidden_lemma.md`（forbidden lemma 列表 — vc-proving 和 final-check 都必须参考）

## 编排步骤

1. 为当前 case 建立或更新 `Case Brief`，并记录：
   - `lib_frozen_prefix_end_line`
   - `lib_frozen_prefix_snapshot`
   - `proof_manual_scope: witness-proofs-after-lib-migration`
   - `annotation_style: predicate-first`（若是 refinement proof，则至少注明 `refinement-required + predicate-first-annotation`）
   - `style_reference_cases`（正例 / 反例都要写清楚）
   - `anti_patterns`（至少覆盖“不要在 Rocq 中重写 C 算法本体”）
   若当前 case 尚无 `common_case_formal_lib`，则把 frozen prefix 记录为空。若 annotation phase 后续集成了 checked `annotation_scratch_lib` spec 变更，main 必须刷新此记录。
2. 根据 `state-machine` 确认当前所处 phase 和下一合法 phase；进入新 phase 时记录 wall-clock `phase_started_at`，离开 phase 时记录 `phase_finished_at`、`phase_elapsed_seconds` 和初步 `major_time_sinks`。每段非命令工作也要按 activity 分类计时，至少包括 `manual-analysis`、`subagent-wait`、`annotation-edit`、`proof-edit`、`helper-cleanup`、`integration-edit`、`review-cleanup`。如果无法精确分段，也要记录该阶段的总 wall-clock，并在最终报告中把无法细分的部分标为 timing gap。
3. 如果当前是从下游 phase 回流后重新进入 `annotation` 或 `vc-proving`，先按 `artifact-templates` 构造 `Re-entry Brief`，明确上一轮失败原因、受影响 witness / 文件和本轮修正重点。
4. 如果下一步进入 `annotation`、`vc-checking` 或 `vc-proving`，先按 `delegation-contracts` 生成 `Delegation Ticket`，其中必须设置 `timing_required: true` 和本轮 `timing_log_path`，再启动固定绑定的 subagent；`vc-proving` ticket 若存在上一轮可复用 report artifact，必须显式给出 `previous_vc_proving_checkpoint`、`checkpoint_reuse_policy` 和 direct-reuse stale 条件，且说明 checkpoint 只能初始化 fresh scratch 或生成 worker proof-pattern reference，不能继承旧 `.tmp`。其中 `annotation` ticket 必须显式设置 `annotation_checking_required: true`、本轮 `annotation_scratch_lib` 路径和 `spec_definition_review_required: true`，并带上：
   - 本轮优先使用的隐藏性质 / 直观谓词
   - 禁止采用的算法镜像模式
   - 对应正例 / 反例参考
   Delegation Ticket 还必须要求 subagent 使用 activity ledger 计时，并把 `activity_ledger_required: true`、`activity_ledger_path`、`subagent_first_event_required: true` 写入 ticket；主 agent 在调用 spawn 前先记录 `subagent-launch-requested`，spawn 返回后记录 `subagent-spawn-returned`。
5. 若 phase 是 `annotation` 或 `vc-proving`，由对应 subagent 基于 delegation ticket 创建 fresh scratch；annotation phase 必须创建 fresh C scratch 和 fresh `annotation_scratch_lib`。若检测到旧 scratch，先删除再重建。
6. 把对应 domain skill 交给该 subagent，或由主 agent 直接执行 `final-check`：
   - `annotation-subagent` -> `annotation-filling`，负责 C annotation 和 `annotation_scratch_lib` spec，随后同一 subagent 必须调用 `annotation-checking`
   - `vc-checking-subagent` -> `vc-checking`
   - `vc-proving-subagent` -> `vc-proving`
   - `main agent` -> `final-check`
7. 对 `annotation` / `vc-proving`，subagent 接手后即拥有整个本轮迭代流程；`annotation-subagent` 的本轮迭代流程包含 `spec-definition review/edit -> annotation-filling -> annotation-checking`，若 checking 发现 C annotation 或 `annotation_scratch_lib` spec 不合理则回到 filling 继续修正。主 agent 只做编排类动作，并等待 subagent 以 `completed`、`blocked` 或 `stale` 显式返回。
8. 主 agent 在 subagent 返回结果后，先把 `Subagent Return Report` 中的 timing 摘要、activity ledger、checkpoint reuse summary 和 round checkpoint 路径合并到 `Phase Status` / `Timing Summary`，并把等待 subagent 的 wall-clock 拆成 `subagent-launch-overhead`、`subagent-self-elapsed`、`subagent-notification-wait`、`subagent-close-overhead`；如果该轮 `blocked` 或超过 600 秒，必须同时合并其 blocked / long-duration 原因和证据。对于 `annotation`，在任何正式回填或 symexec 之前，主 agent 还必须运行 `.agents/skills/verification-orchestrator/scripts/validate_annotation_gate.py`；若校验失败，不得进入 `goal-frozen`。再继续独占执行正式主状态文件修改、symexec、coqc、`Admitted` / 额外 `Axiom` review、`Final Check Checklist` 更新和 phase 切换。main-owned 命令要逐项计时，失败后重跑的命令也必须逐次计入，main-owned 编辑/分析/清理也要按 activity 逐段计时。不能只记录最终成功命令；失败编译、超时、worker 准备和等待都属于当前 case 的真实耗时。若 subagent 返回 helper lemmas，主 agent 只能在本轮所有目标 witness 都已完成后，将 helper-free handoff manual 与 `task_local_scratch_lib` 后缀作为一个集成批次同步回填；不能先改 `common_case_formal_lib` 再继续证明剩余 witness。
9. 每次上游变动后，按 `invalidation-rules` 标记 stale / invalidated 输出，并删除对应 scratch。
10. 只有在 exit gate 满足、`Timing Summary` 已能说明各 phase 耗时和主要瓶颈、且完整报告已经在 cleanup 前持久化、且本轮不再需要的 scratch 与临时文件均已清理时，才允许进入下一 phase。
