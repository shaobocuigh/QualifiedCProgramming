# 使用注意

这个文件补充 `vc-proving` 的使用细节，优先级低于 `verification-orchestrator`，但高于临时推断。

- phase、ledger、delegation 和 stale 规则统一以 `verification-orchestrator` 为准；本文件只补充 proving 相关硬约束。
- `vc-proving-subagent` 必须从最新正式 `*_proof_manual.v` / `common_case_formal_lib` 创建 proving scratch pair，其中 lib 侧副本为本轮 `task_local_scratch_lib`。
- 默认使用 `scripts/` 中的并发 worker 流水线；只有在 Codex worker 环境已确认不可恢复时，才允许在同一 proving scratch 上进入串行 fallback。
- `vc-proving` 是长迭代 phase；一旦交给 `vc-proving-subagent`，就应持续推进到 `completed`、`blocked` 或 `stale`，而不是只给出第一版思路。
- 必须保留 timing 摘要和 activity ledger：pipeline 命令、worker / fallback proof search、`coqc` 编译、helper migration、verify gate 都要计时；返回时指出最慢 witness/helper 和主要 bottleneck。
- 正式与最终 handoff 的 `*_proof_manual.v` 只允许保留 witness theorem proofs；helper lemmas、helper definitions 或额外结构必须迁走。
- `common_case_formal_lib` 与 `task_local_scratch_lib` 都遵守冻结前缀合同；前缀不可改写，merged manual 完成后只允许向 `task_local_scratch_lib` 后缀追加 audited helper imports 和 proved helper lemmas。
- reusable helper lemma 先进入 `worker_helper_scratch_lib`，经 `validate_and_merge.py` 收集后再由 `migrate_helpers_to_lib.py` 迁入 `task_local_scratch_lib`；worker manual 只放 witness proof。
- `validate_and_merge.py` 和 `verify_manual_goals.py` 阶段必须扫描 forbidden lemma（列表见 `../verification-orchestrator/docs/forbidden_lemma.md`）。若 worker 产出的 proof 命中了 forbidden lemma，必须在合并前退回 worker 修正；不得将含 forbidden lemma 的 proof 合并进 scratch manual 或 `task_local_scratch_lib`。
- helper lemma 不允许新增顶层 `Definition` / `Fixpoint` / `Inductive` / `Notation` / `Axiom`。如需额外库，只能在 `worker_helper_scratch_lib` 中加入最小 `Require Import` / `From ... Require Import` 行；迁移脚本会拒绝 `SimpleC.EE.*` 生成 case imports。
- 如果证明推进必须修改冻结前缀，或必须新增上述顶层定义，则本轮应返回 `blocked`。