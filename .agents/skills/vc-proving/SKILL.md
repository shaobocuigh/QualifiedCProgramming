---
name: vc-proving
description: 默认使用脚本化隔离 Codex worker，并在 Windows 下只通过本地 coqc.exe / coqtop.exe 编译反馈证明 qcp/symexec 生成的 manual VC；若 Codex worker 环境不可恢复，则允许在同一 proving scratch 上执行串行 fallback。worker / fallback 产出的 helper lemmas 先迁移到本轮 task_local_scratch_lib，所有目标 VC 完成后才由主 agent 以 helper-free manual 一次性回填正式文件。
---

# VC Proving

这个 skill 只负责把已确认可证的 manual VC 变成可编译的 Rocq 证明，并保持 formal 文件职责清晰。它固定绑定给 `vc-proving-subagent`；phase、ledger 状态和 delegation 合同统一由 `verification-orchestrator` 定义，本 skill 不再重复这些通用规则。

## 何时使用

- case 已由 `verification-orchestrator` 置于 `vc-proving` 阶段。
- 主 agent 已为当前 proving 轮次启动 `vc-proving-subagent`。
- 目标 witness 已被确认可以进入 proving。
- 默认通过 `split_manual_goals.py`、`prepare_agent_concurrent.py`、`run_agent_concurrent.py`、`validate_and_merge.py`、`migrate_helpers_to_lib.py`、`verify_manual_goals.py` 启动脚本化 sandboxed Codex worker 并发证明 witness。
- 若本轮已产生 compile-gated 的局部成果，应通过 `checkpoint_round.py` 固化 report checkpoint / JSON partial proof packet，供下一轮 fresh scratch 复用。
- 若 Codex worker 环境不可恢复，则在同一轮切换到 proving scratch 上的串行 fallback，并在完成 helper-to-`task_local_scratch_lib` migration 后把可回填结果交给主 agent。
- 若只是 worker 的 `rocq-mcp` 启动或调用失败，但 worker-local `coqc` 可用，这不是证明阻塞；应记录 MCP 失败证据，并立即改用 worker-local `coqc` / 必要时 `coqtop` 驱动同一份 worker manual 继续证明。

## 进入前提

- 当前 `goal` / witness 集合对应最新冻结版本。
- 目标 witness 不处于 stale 状态。
- 主 agent 已决定本轮哪些 witness 正式进入证明。
- 当前 delegation ticket 的 `subagent_name` 固定为 `vc-proving-subagent`。
- 当前 delegation ticket 已给出最新正式 `*_proof_manual.v` / `common_case_formal_lib` 快照以及本轮 proving scratch 路径；若旧 proving scratch 仍存在，必须先删除再重建。
- 当前 delegation ticket 至少明确以下字段：`proof_manual_write_contract`、`lib_write_contract`、`protected_lib_prefix_end_line`、`task_local_scratch_lib_module`、`worker_execution_mode`、`witness_group_plan`、`previous_vc_proving_checkpoint`、`previous_partial_proof_packet`、`checkpoint_reuse_policy`。
- checkpoint direct-reuse 在 `source_goal_version`、`lib_frozen_prefix_hash`、`protected_lib_prefix_end_line`、packet hash、helper payload 冲突或 direct candidate compile gate 失败时必须失效；但在 `exact_or_pattern` / `pattern_reference` 策略下，仍应生成 proof-pattern reference 供 worker 复用思路。
- 当前 delegation ticket 还必须明确：本轮 `vc-proving` 的 `iteration_owner` 是 `vc-proving-subagent`，main 线程不会因等待较久而接管 proving。
- 若来自返工、重证明或下游回流，当前 ticket 必须附带 `Re-entry Brief`，说明上一轮在哪个 witness / 文件上失败，以及这次为什么重开。

## 直接输出

- 已在 proving scratch `*_proof_manual.v` / `task_local_scratch_lib` 上验证过、可回填到正式 manual 的 witness proofs，以及可回填到 `common_case_formal_lib` 的 helper-suffix imports / helper lemmas。它们都只是本轮批量集成候选，subagent / worker 不得提前修改正式 `common_case_formal_lib`。
- worker 产生的 `proof_report.json`、`proof_strategy_report.json`、merged scratch manual 路径、migrated scratch manual/lib 路径以及参考案例映射。
- 若本轮不是 annotation-bug / stale，且存在已通过 merge / migration / compile gate 的 solved witness 或 helper payload，应输出 `vc_proving_round_checkpoint.json`、`partial_proof_packet.json`、`reuse_index.json` 的持久 report 路径，以及 checkpoint reuse 命中数 / 未解 witness 列表。checkpoint 是 report artifact，不是继续沿用旧 scratch。
- 本轮 proving 的完整 timing 摘要：wall-clock、split / prepare / run / validate / migrate / verify 各步骤耗时、worker-local 或串行 fallback 的 proof search / coqc 耗时、失败编译和重跑耗时、proof 分析 / 编辑、helper 设计 / 迁移 / 清理、worker 等待 / fallback 切换等 activity 耗时、最慢 witness/helper 以及主要 bottleneck。
- proof activity ledger：每个 witness/helper 的 `proof-planning` / `proof-generation` activity 在开始前写 `START`，结束后写 `END`，不能事后凭印象估算；ledger 至少要回答空间部分、pure 部分、helper 设计和 coqc 反馈分别花了多久。
- 若本轮返回 `blocked` 或总耗时超过 600 秒，必须额外输出 blocked / long-duration 诊断：blocked reason、long-duration reason、具体证据、受影响 witness/helper/文件、已尝试路径和下一步建议。
- 正式回填 `*_proof_manual.v` / `common_case_formal_lib` 前的集成建议、依赖顺序和风险提示；若本轮包含多个 witness / worker，必须说明 helper-free manual 与 `task_local_scratch_lib` 应在所有目标 VC 完成后作为同一批次合并。
- `Subagent Return Report`，其 `round_outcome` 只能是 `completed`、`blocked` 或 `stale`。

## Proof Activity Ledger 最小粒度

`vc-proving-subagent` 和 worker 在每个 witness/helper 上都必须维护 activity ledger。每条活动都先写 `START`，结束后写 `END`，并记录 `event_id`、`parent_event_id`、`witness_or_helper`、`activity_kind`、`started_at`、`finished_at`、`elapsed_seconds`、`status`、`artifact_paths`、`summary`。`summary` 只写高层可审计信息，不写隐藏 chain-of-thought。

每个 witness 至少拆分以下 activity；若某类活动不存在，显式记录 `not-applicable` 或 `0` 秒：

- `proof-state-reduction`：运行 `pre_process`、实例化 existential、观察剩余 goals。
- `spatial-proof-generation`：生成空间部分证明，例如 `cancel`、数组 / segment 拆合、`store_string` 展开、`undef_seg` 合并。
- `pure-proof-generation`：生成纯证明，例如 `Znth` / `sublist` / `Zlength` / `lia`、量词分支、等式和不等式证明。
- `helper-design`：设计 helper statement、拆 premise、决定 helper 写入 `worker_helper_scratch_lib` 还是 `task_local_scratch_lib`。
- `helper-proof-generation`：证明 helper 本身。
- `proof-script-edit`：把已决定的证明步骤写入 one-goal manual 或 worker-local manual。
- `coqc-run`：每次 `coqc` / `coqtop` 命令都记录命令、开始 / 结束、exit code、stdout/stderr 摘要和产物路径。
- `coqc-feedback-analysis`：阅读错误、定位失败原因、决定下一次修改。

## 会使哪些产物失效

- 任何 `*_proof_manual.v` 或 `common_case_formal_lib` 的改动，都会使旧的 final-check 结论失效。
- 若 proving 中暴露出 annotation 层问题，主 agent 必须退回 annotation，并按 orchestrator 规则使当前 proving 计划失效。

## 主 / 子 Agent 局部边界

- `vc-proving-subagent` 拥有 proving scratch `*_proof_manual.v` / `task_local_scratch_lib`、脚本化 worker workdir 以及相应 worker-local `coqc.exe` / `coqtop.exe` 的编译反馈使用权；若进入串行 fallback，则额外拥有 proving scratch / scratch-local manual 上的隔离 `coqc.exe` / `coqtop.exe` 循环使用权。Windows 下不得调用 `rocq-mcp`。
- `vc-proving-subagent` 默认通过 `scripts/` 启动隔离 Codex worker 分组证明；若已记录 Codex CLI / transport / backend / worker 会话不可恢复，则允许 phase subagent 自己在 proving scratch 上执行串行 fallback proof loop。
- 主 agent 独占正式 `*_proof_manual.v` / `common_case_formal_lib` 写入、symexec、coqc、`Admitted` / 额外 `Axiom` review 和最终 proof 集成。`common_case_formal_lib` 只能在当前 vc-proving 轮次所有目标 VC 都完成后，与 helper-free manual 一次性同步回填；不要为了单个 helper lemma 提前追加到正式 lib。
- `vc-proving-subagent` 不并发修改正式文件；脚本 worker 必须在各自 workdir 使用本地 `_CoqProject` 和 `coqc.exe` / `coqtop.exe`。进入串行 fallback 时也必须保持 workdir / scratch 隔离，不得把 main 线程复核混入当前 proving loop。
- worker-local 与 merged scratch `*_proof_manual.v` 可暂存当前 case 的 manual witness theorem 以及本轮 worker 合并来的 proved helper lemmas；helper-migration 之后的 handoff manual 必须只保留 witness proofs。
- `task_local_scratch_lib` 在 worker proving 阶段作为只读参考；`validate_and_merge.py` 成功后，`migrate_helpers_to_lib.py` 才能在保持冻结前缀不变的前提下，把 audited helper-suffix `Require Import` 行和 proved helper lemmas 迁入 `task_local_scratch_lib` 后缀。`task_local_scratch_lib` 是本轮 helper 的唯一汇总点；`common_case_formal_lib` 在整个 vc-proving round 内保持只读，避免反复触发依赖重编译。
- helper lemma 只允许是 proved `Lemma` / `Theorem` / `Fact` / `Remark` 等证明块；helper-suffix imports 只允许是脚本审计通过的 `Require Import` / `From ... Require Import` 行，禁止导入 `SimpleC.EE.*` 生成 case artifact；禁止新增顶层 `Definition` / `Fixpoint` / `Inductive` / `Notation` / `Axiom`。
- 如果证明推进需要改写 `common_case_formal_lib` 冻结前缀，或确实依赖新增上述顶层定义，则本轮必须返回 `blocked`。
- 一旦本轮 proving 交给 `vc-proving-subagent`，main 线程不得因等待较久而强行打断并自己继续证明。

## 参考文档

1. 先读 `../verification-orchestrator/SKILL.md`
2. `docs/use-notes.md`
3. `docs/separation-logic-whole-proof-tactics.md`
4. 目标涉及 `safeExec`、monad 或 refinement 时，再读 `docs/refinement-proof-tactics.md`
5. 目标涉及数组、字符数组、C 字符串或字符串字面量时，读 `../annotation-filling/docs/builtin-array-string-support.md`
6. 需要找风格对照时，读 `docs/reference-cases.md`
7. `../verification-orchestrator/docs/forbidden_lemma.md`（forbidden lemma 列表，validate/merge 与 verify 阶段必须参考）
7. `vc-proving` 默认使用 `scripts/split_manual_goals.py`、`prepare_agent_concurrent.py`、`run_agent_concurrent.py`、`validate_and_merge.py`、`migrate_helpers_to_lib.py`、`verify_manual_goals.py`、`checkpoint_round.py` 和 `apply_partial_proof_packet.py`；若本轮已记录 Codex worker 环境不可恢复，则允许改用 proving scratch 上的串行 fallback，但不得切回 main 接管 proof search。
8. 在执行 `validate_and_merge.py` 和 `verify_manual_goals.py` 时，必须参考 `../verification-orchestrator/docs/forbidden_lemma.md`，检查 worker 产出的 proof 是否使用了 forbidden lemma；若命中，必须在合并前修正，不得将含 forbidden lemma 的证明合并进 scratch manual 或 `task_local_scratch_lib`。

## 工作步骤

1. 读取当前 proving 轮次的 delegation ticket，确认目标 witness 集、`source_goal_version`、正式 proof 快照、本轮 proving scratch 路径、`protected_lib_prefix_end_line`、formal 写入合同、`timing_required` / `timing_log_path` / `activity_ledger_path`、`previous_vc_proving_checkpoint` / `checkpoint_reuse_policy`，以及是否附带 `Re-entry Brief`；立即向 `timing_log.md` 或 `activity_ledger_path` 写入本轮第一条 `subagent-start` 记录，并随后记录 `phase_started_at`。
2. 若存在 `Re-entry Brief`，先根据其中的失败 witness / 文件、上一轮失败原因和本轮变化点，决定当前 proving 的优先处理顺序。
3. 若旧的 proving scratch 仍存在，先删除；随后从最新正式 `*_proof_manual.v` / `common_case_formal_lib` 复制出 fresh proving scratch pair。若当前 case 尚无 `common_case_formal_lib`，则为本轮 scratch 创建最小 `task_local_scratch_lib` 搭档。若目标中出现 `IntArray` / `UIntArray` / `CharArray` / `store_string` / `store_stringLit` / `GlobalStrings` 等 builtin 谓词，先读 `../annotation-filling/docs/builtin-array-string-support.md` 查找对应 lemma、策略触发条件和参考 proof。
4. 在 proving scratch manual 上默认运行脚本化并发流水线，并对每条 pipeline 命令记录开始 / 结束时间、elapsed seconds、返回结果和 report 路径；同时记录 phase owner 等待 worker、fallback 切换、scratch 准备 / 清理、失败编译重跑和手工 proof 编辑的 wall-clock activity。
5. 所有非命令 proof activity 都必须通过 ledger 事件记录，至少包括 `scratch-prepare`、`overlay-prepare`、`worker-wait`、`fallback-switch`、`proof-planning`、`spatial-proof-generation`、`pure-proof-generation`、`helper-design`、`proof-script-edit`、`coqc-feedback-analysis`、`report-writing`。
6. 默认使用 `vc-checking` 输出的 `witness_group_plan` 创建 proof group：每个 group 一份 worker-local manual 和一份组内 `worker_helper_scratch_lib`，组内多个 witness 可共享 helper；只有在没有 group plan 时，才按 witness 名称排序后用 fallback chunk-size 分组。
7. `prepare_agent_concurrent.py` 必须为 base / group workdir 创建只读 `case_deps/` overlay、worker-local `_CoqProject` 和 `worker_helper_scratch_lib`，并把 proof pattern notes 写入 worker `AGENTS.md`。
8. `run_agent_concurrent.py` 在存在 checkpoint 或 reuse index 时，必须先执行 proof reuse prepass；direct reuse 只有在 hash / frozen-prefix / compile gate 全部通过时才可把 witness 从 worker scope 移除，否则只能退化为 proof-pattern reference 供 worker 学习。
9. `validate_and_merge.py` 负责合并 worker 结果并扫描 forbidden lemma（按 `../verification-orchestrator/docs/forbidden_lemma.md`），`migrate_helpers_to_lib.py` 负责把 audited helper imports / lemmas 迁入 `task_local_scratch_lib`；`verify_manual_goals.py` 负责最终结构检查、forbidden lemma 复查与必要的 compile gate。若 forbidden lemma 扫描命中，必须在合并前退回对应 worker 修正，不得将含 forbidden lemma 的 proof 合并进 scratch manual 或 `task_local_scratch_lib`。
10. 若 `run_agent_concurrent.py` 因 Codex CLI 缺失、认证失败、transport / backend 不可达或 worker 会话不可恢复而无法产出可用结果，应在同一轮记录阻塞证据和已消耗时间后切换到串行 fallback；fallback 仍需保持分粒度计时和 helper migration 约束。
11. 在整个 proving 过程中必须保持 formal 文件边界：witness proof 留在 scratch manual，reusable helper 先进入 `worker_helper_scratch_lib` 或 merged scratch，再迁入 `task_local_scratch_lib`；在所有目标 witness 完成之前不要改动正式 `common_case_formal_lib`。
12. 若证明推进暴露 annotation 层问题、要求改写冻结前缀、要求新增 forbidden top-level 定义、或要求导入不在 allowlist 内的依赖，必须返回 `blocked` 或回退到 annotation，而不是继续扩张证明文件职责。