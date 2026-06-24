# 使用注意

这个文件用于说明应用 `final-check` 时必须优先遵守的细节。

- phase、回退点和 stale 规则统一以 `verification-orchestrator` 为准；本文件只保留 final-check 相关硬规则。
- 最终检查的前提是：annotation、manual proof 已经完成；这里不负责重新设计证明策略。
- `final-check` 是 main-owned phase；不创建 subagent，也不使用 delegation ticket。
- 重新运行 symexec 的目的是验证“当前生成文件是否仍然对应当前 C 程序”。
- 编译顺序要尊重依赖关系，避免先检查 `goal_check` 再发现基础文件未更新。
- 在跑命令之前，先确认 `common_case_formal_lib` 的冻结前缀和 `Case Brief` 一致。
- 在跑命令之前，也要确认 `*_proof_manual.v` 不再含 helper lemmas，`common_case_formal_lib` 冻结前缀后的 migrated helper-suffix imports 均为审计通过的 `Require Import` 行，migrated helper lemmas 都已证明，且没有混入 helper definitions、`Admitted` 或额外 `Axiom`。冻结前缀内允许 annotation-checking 已通过的数学 spec 定义，但 Case Brief 必须记录最新冻结快照。
- 不要删除任何 `.v` 交付文件。
- 清理时既要删除这次验证过程中新增的编译临时文件，例如对应的 `.aux` 文件，也要确认 annotation / proving phase 的 scratch、`.tmp` worker workdir、kept manual-goals 副本、merged scratch artifact 和本轮产生的测试 / Python 缓存已经删除。
- 请注意：`*_proof_auto.v` 中的 `Admitted` 与 `*_goal.v` 中的 `Axiom` 属工具生成特性，允许存在且不应手改。
- 最终检查时需要判定：`*_proof_manual.v`、`common_case_formal_lib` 中是否存在 `Admitted`，是否引入了额外 `Axiom`，以及 `*_proof_manual.v` 是否仍残留 helper lemmas。
- 在 Admitted / Axiom review 之后，还必须执行 **forbidden lemma 扫描**：按 `../verification-orchestrator/docs/forbidden_lemma.md` 中的列表，在 `*_proof_manual.v` 和 `common_case_formal_lib` 中搜索每个 forbidden lemma 名称。若命中任何 forbidden lemma，必须判定 final-check 失败并回退到 `vc-proving`，在 `Re-entry Brief` 中附上完整的 forbidden lemma 命中清单（文件名、行号、lemma 名称）。
- 最终 `Timing Summary` 不能只汇总命令输出时间；还必须纳入本轮 wall-clock activity：人工分析、等待 subagent、annotation/proof 正式回填、proof 修改、helper lemma / 冗余 lemma 清理、Makefile/依赖维护和 review/cleanup。若前序没有逐段计时，应把缺失项列入 `timing_gaps`。
- 如果冻结前缀漂移、`*_proof_manual.v` 结构越界，或 `common_case_formal_lib` 后缀 helper imports 未审计 / helper lemma 未证明 / 引入 forbidden top-level declaration，应回退到正确上游 phase，而不是带着结构问题继续进入 `done`；spec 定义未重新冻结时回退 annotation / goal-frozen，proving helper 后缀问题回退 `vc-proving`。
