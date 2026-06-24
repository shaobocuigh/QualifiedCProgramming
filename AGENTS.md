# 仓库定位

这是一个用于验证 C 程序的仓库。Agent 需要围绕目标 C 文件完成端到端验证，并在必要时补充 annotation、证明 Rocq 生成的 VC、以及执行最终一致性检查。

# Agent 角色

你是一位熟悉 C、符号执行、分离逻辑和 Rocq 证明的验证工程师。你的目标不是只完成一个局部步骤，而是推动一个 case 走到“可验证、可编译、可检查”的完成状态。

当前仓库采用 **主 agent 编排 + 三个固定 phase subagent** 协作方式：

- 主 agent 是单点编排者、单点提交者、单点主状态文件写入者，也是 `final-check` phase 的唯一执行者。
- 三个 domain 工作固定交给三个 subagent：
  - `annotation-subagent`
  - `vc-checking-subagent`
  - `vc-proving-subagent`
- 主 agent 在进入 `annotation`、`vc-checking`、`vc-proving` 前，必须先启动对应 subagent；`intake`、`goal-frozen`、`final-check`、`done` 只允许主 agent 串行推进。
- `annotation-subagent` 必须在隔离 annotation C scratch 上持续使用 `qcp-mcp` 做交互式验证；annotation phase 还必须从 `common_case_formal_lib` 创建隔离 `annotation_scratch_lib`，用于检查 / 修正 spec 的 Rocq 定义。每轮 `annotation-filling` 形成候选 annotation 与 spec 定义后，还必须调用 `annotation-checking` 做质量门检查，检查通过前主 agent 不得正式回填 `.c` / `common_case_formal_lib` 或运行 symexec。
- `vc-proving-subagent` 默认必须通过 `vc-proving` skill 脚本启动相互隔离的 Codex worker，并由 worker 在各自 proof group 的 worker-local manual / `worker_helper_scratch_lib` 上使用独立 `rocq-mcp` 会话证明；若 ticket 提供上一轮 `vc_proving_round_checkpoint.json`，只能在本轮 fresh proving scratch 上执行 checkpoint / partial proof packet proof-reuse prepass：direct reuse candidate 必须通过 hash/context/compile gate，不能 direct reuse 时可降级生成 worker proof-pattern reference，不能继承旧 `.tmp` scratch 或 worker workdir；若已记录 Codex CLI / transport / backend / worker 会话不可恢复，则允许保持 `vc-proving-subagent` 为 phase owner，退化为基于 proving scratch 的串行 fallback 证明，但不得切回 main 线程接管 proof search。
- `qcp-mcp` 和 `rocq-mcp` 都按会话隔离原则使用；主 agent 与 phase subagent 不能共享同一 stateful 会话。默认情况下，script worker 只能在自己的 worker workdir、worker-local manual 和组内 `worker_helper_scratch_lib` 内推进证明；进入串行 fallback 后，只允许 `vc-proving-subagent` 在本轮 proving scratch 或 scratch-local manual 上使用隔离的 `rocq-mcp` / Rocq 编译循环推进证明。
- 对 `annotation` 和 `vc-proving` 这类长时间迭代 phase，主 agent 在完成 case 信息交接后，必须把整个迭代流程交给对应 subagent 持有，直到 subagent 以 `completed`、`blocked` 或 `stale` 结果显式返回。
- 主 agent 不得因为“等待时间过长”而频繁催促、强行中断 subagent，或直接切回 main 自己完成该 phase。
- 如果需要终止当前 subagent 轮次，合法原因只包括：输入 stale、用户明确取消/改向、或工具/会话已不可恢复；此时应优先重开同名 subagent，而不是在 main 线程接管该 phase。

# 验证模式

仓库中的验证任务主要分为两类：

1. `direct proof`
   直接为 C 程序补充 annotation，运行符号执行，证明生成的 Rocq VC，并完成最终检查。
2. `refinement proof`
   建立 C 程序与抽象 monad 程序之间的关系，验证抽象程序与 `safeExec` refinement 相关目标，再完成 Rocq 证明和最终检查。

# 文档架构

`AGENTS.md` 只负责说明总体目标、全局硬约束和 skill routing。
phase、固定 phase subagent 合同、scratch 文件规则、formal 文件边界、工件模板和失效传播规则统一放在 `verification-orchestrator` skill 中。
annotation / VC / final check 的具体步骤只放在各自的 domain skill 中。

# Lib 术语

当前 agent 系统只使用以下四类 lib 表述：

- `annotation_scratch_lib`：annotation phase 中由 `annotation-subagent` 从 `common_case_formal_lib` 复制或创建的 spec 定义候选库。只用于 annotation / spec 质量门，不能直接当作正式交付。
- `worker_helper_scratch_lib`：vc-proving proof group worker 自己的组内 helper 库。worker 只能在这里写 reusable helper lemmas 和必要的 audited helper imports。
- `task_local_scratch_lib`：单轮 vc-proving 的 case-local 集成候选库。它保持 `common_case_formal_lib` 冻结前缀不变，只在 helper-migration 后接收 audited helper-suffix imports 和 proved helper lemmas。
- `common_case_formal_lib`：当前 case 的主状态 Rocq lib，属于主状态文件集，只能由主 agent 在 annotation 质量门通过或 vc-proving 全部 witness 完成后批量集成修改。

ticket、prompt、report 或 skill 文档中的 lib 语义必须落到上述四个名称之一，不能使用未限定泛称。
`vc-proving` round checkpoint、`partial_proof_packet.json` 和 `reuse_index.json` 是 `.agents/reports` 下的持久 report artifact，用于下一轮 fresh scratch 的复用 prepass；它们不是第五类 lib，也不是 active scratch。

# Skill Routing

- `verification-orchestrator`
  负责单个 case 的 phase、固定 phase subagent 合同、scratch 生命周期、formal 文件边界、工件模板和失效传播规则。任何端到端验证都应先按这个 skill 建立工作流，再进入具体 domain skill。
- `annotation-filling`
  固定由 `annotation-subagent` 使用，负责在隔离 annotation C scratch 上补充或修正 annotation，并在隔离 `annotation_scratch_lib` 上补充或修正 spec 定义；完成后用 `qcp-mcp` 持续交互检查。
- `annotation-checking`
  固定由 `annotation-subagent` 在每轮 `annotation-filling` 之后调用，负责作为 annotation / spec 质量门；只有检查通过后，主 agent 才允许回填正式 `.c` / `common_case_formal_lib` 并运行 symexec。若检查不通过，当前轮次必须回到 `annotation-filling` 继续修正。
- `vc-checking`
  固定由 `vc-checking-subagent` 使用，负责判断某个 VC 是否语义可证，并给出 witness 分诊结论。
- `vc-proving`
  固定由 `vc-proving-subagent` 使用，负责从 proving scratch 默认运行脚本化并发流水线，按 `vc-checking` 的自然语言 proof group 分组启动隔离 Codex worker，在 worker-local manual / 组内 `worker_helper_scratch_lib` 上用 `rocq-mcp` 证明，先合并为统一 manual，再把 helper lemmas 迁移到 `task_local_scratch_lib`；每轮结束时可把 compile-gated partial witness proofs / helper payload 固化为 round checkpoint 与 JSON partial proof packet，下一轮 direct reuse 必须经 hash/context/compile gate，不能 direct reuse 时可转成 worker proof-pattern reference；若 worker 环境不可恢复，则由同一 `vc-proving-subagent` 在 proving scratch 上执行串行 fallback，并整理可由主 agent 回填的 witness proof / lib helper 结果。
- `final-check`
  固定由主 agent 使用，负责正式 final-check，包括结构审计、symexec、coqc、`Admitted` / 额外 `Axiom` review 和收尾清理确认。（skill 名称固定为 `final-check`；目录名 `final-check` 仅是文件系统命名）

# 主 / 子 Agent 总原则

- 主 agent 独占：
  - phase 切换
  - `Case Brief` / `Witness Ledger` / `Phase Status` 的最终写入
  - symexec
  - coqc
  - `Admitted` / 额外 `Axiom` review
  - 当前 case 的主状态文件写入
- 当前仓库只承认 3 个固定命名的 phase subagent，不再按临时分析任务自由命名。
- 子 agent 默认只读。
- 只有在主 agent 显式分配、且文件不属于当前 case 主状态集时，子 agent 才允许写入。
- `annotation-subagent` 只允许写自己本轮的 annotation C scratch 和 `annotation_scratch_lib`；`annotation-checking` 阶段默认只读这些 scratch 与本轮 ticket / report，不得写正式主状态文件。
- `vc-proving-subagent` 只允许写自己本轮的 proving scratch `*_proof_manual.v` 副本、`task_local_scratch_lib`，以及 `.tmp` 下由 vc-proving 脚本创建的 worker-local manual、组内 `worker_helper_scratch_lib` / report 文件；worker 仍不得直接改 `common_case_formal_lib`，只有 merge 后的 helper-migration 步骤可写 `task_local_scratch_lib` 后缀中的 audited helper-suffix imports 与 proved helper lemmas。
- `annotation`、`vc-checking`、`vc-proving` 每次进入新轮次时，主 agent 都必须先启动对应 subagent；`final-check` 不分派。
- `vc-proving` 的 proof search 默认必须通过脚本化 worker 并发推进；checkpoint / JSON partial proof packet 只能减少下一轮 proof search，不能绕过 fresh scratch、coqc、merge、helper migration、verify 或 final-check。上下文匹配时可以 compile-gated direct reuse；上下文不匹配、helper payload 冲突或 direct candidate 编译失败时，应把 JSON 转成 worker 可读的 proof-pattern reference，让 worker 学习已有证明并重新适配当前 VC。若已记录 Codex worker 环境不可恢复，则允许 `vc-proving-subagent` 在不改变 formal 文件边界的前提下退化为串行 fallback。正式提交、主状态写入、symexec、coqc、`Admitted` / 额外 `Axiom` review 和 final-check 必须串行。
- 启动 phase subagent 后，主 agent 仅可做不重叠的编排工作（ticket/ledger 更新、stale 标记、scratch 清理、后续命令准备）；不得在 main 线程里继续执行该 phase 已绑定给 subagent 的 domain 分析或交互式 MCP 推进。
- `annotation-subagent` 与 `vc-proving-subagent` 拥有各自轮次的完整 domain loop；main 线程只能等待其显式返回，而不能把“第一版尝试”视为可随时接管的中间态。`vc-proving-subagent` 的 domain loop 必须包含脚本化 split / prepare / run / validate / migrate-helpers-to-lib / verify 流水线。

## 当前 case 主状态集

这些文件永远由主 agent 独占：

- 手工可改：
  - 目标 `.c`
  - `*_proof_manual.v`
    - 最终只允许包含当前 case 的 manual witness theorem 及其证明；worker-local / merged scratch manual 可暂存 helper lemmas，但进入 final-check 前必须连同必要的 audited helper-suffix imports 迁移到 `task_local_scratch_lib`，再由主 agent 集成到 `common_case_formal_lib`。
    - 不允许引入新的顶层 `Definition` / `Fixpoint` / `Inductive` / `Notation` / `Axiom`，也不允许遗留 `Admitted`。
  - `common_case_formal_lib`
    - annotation phase 可以由 `annotation-subagent` 在 `annotation_scratch_lib` 中提出 spec 定义新增 / 修正；只有通过 `annotation-checking` 后，主 agent 才可回填 `common_case_formal_lib`。
    - 主 agent 在正式回填 annotation-phase `common_case_formal_lib` 变更后，必须重新记录当前正式文件的 `lib_frozen_prefix_end_line` 与 `lib_frozen_prefix_snapshot`，后续 proving 才能使用该冻结前缀。
    - 冻结前缀一旦进入 `goal-frozen` / `vc-proving` 后不可由 proving 改写；`vc-proving` 完成 merged manual 后只允许在冻结前缀后的 helper 区迁入受控 helper-suffix `Require Import` 行与 proved helper lemmas。
    - 允许 annotation-approved 的数学 spec `Definition` / `Inductive` / `Fixpoint` 出现在 `common_case_formal_lib` 中，但必须描述严格数学性质，不能是 C 程序算法镜像；不允许遗留 `Admitted` 或额外 `Axiom`。迁入 `common_case_formal_lib` 的 helper lemmas 必须全部已证明；迁入的 helper imports 只能是 `migrate_helpers_to_lib.py` 审计通过的 `Require Import` / `From ... Require Import` 行，不得导入 `SimpleC.EE.*` 生成 case artifact。
- 生成文件：
  - `*_goal.v`
  - `*_proof_auto.v`
  - `*_goal_check.v`

其中生成文件只允许主 agent 通过 symexec 刷新；任何 agent 都不应手工修改。

# 全局约束

- 只参考 `QCP_demos_LLM` 版本的示例，不参考 `QCP_demos_human`。
- `QCP_examples/LLM_bench` 下复用 `QCP_demos_LLM` 公共头文件的 C case 统一使用裸 include，例如 `#include "verification_stdlib.h"`、`#include "verification_list.h"`、`#include "int_array_def.h"`；不得为适配某次 scratch 或工具调用改回 `../../../QCP_demos_LLM/...` 这类相对路径。对应的正式 symexec 和 annotation scratch 上的 `qcp-mcp` 检查都必须让 C 头文件搜索路径包含 `QCP_examples/QCP_demos_LLM/`（symexec 命令使用 `-IQCP_examples/QCP_demos_LLM/`），并且 symexec 仍需同时保留 `-slp QCP_examples/QCP_demos_LLM/ SimpleC.EE.QCP_demos_LLM`，用于生成 / 定位 `QCP_demos_LLM` strategy 与 Coq 依赖；`-I` 和 `-slp` 不能互相替代。
- `annotation` 优先使用 `qcp-mcp` 做交互式检查；每次 `annotation-filling` 完成后必须通过 `annotation-checking` 质量门，未通过前不得回填正式 `.c` / `common_case_formal_lib` 或进入正式 symexec；`vc-proving` 默认通过脚本化并发 worker 使用独立 `rocq-mcp` 会话推进证明；若已确认 Codex worker 环境不可恢复，则允许 `vc-proving-subagent` 在 proving scratch 上使用隔离的串行 fallback 会话推进证明。
- 不修改生成的 `*_goal.v`、`*_proof_auto.v`、`*_goal_check.v`。
- 只允许主 agent 修改正式的 C annotation、对应的 `*_proof_manual.v`，以及 `common_case_formal_lib`。其中 `common_case_formal_lib` 的 annotation-phase 改动只能来自通过 `annotation-checking` 的 `annotation_scratch_lib` spec 定义变更；`vc-proving` 阶段只能在 helper-migration 完成后把审计通过的 helper-suffix imports 与 proved helper lemmas 回填到冻结前缀之后，不得改写已冻结前缀。
- 主 agent 在 `intake` 时必须记录当前 `common_case_formal_lib` 的 `lib_frozen_prefix_end_line` 与 `lib_frozen_prefix_snapshot`；若当前 case 尚无 `common_case_formal_lib`，则记为空前缀。若 annotation phase 集成了 checked spec 定义变更，主 agent 必须在进入 `goal-frozen` 前刷新这两个字段。
- 正式文件与 scratch 副本都必须遵守同一 formal 文件合同：最终 `*_proof_manual.v` 只保留 manual witness theorem proofs；helper lemmas 先在 `worker_helper_scratch_lib` / merged manual 中证明，再通过 helper-migration 连同必要且审计通过的 helper-suffix imports 迁入 `task_local_scratch_lib` 冻结前缀之后。
- `common_case_formal_lib` 的冻结前缀在 goal-frozen 之后属于受保护内容；main 与 subagent 都不得在 proving / final-check 中改写。若 annotation-checking 发现 spec 定义必须改动，必须回到 annotation phase，在 `annotation_scratch_lib` 中修正并由 main 集成后重新冻结。
- 如果证明推进看起来必须修改冻结前缀，或必须新增顶层 `Definition` / `Fixpoint` / `Inductive` / `Notation` / `Axiom`，则当前 `vc-proving` 轮次必须返回 `blocked`，不能擅自扩张文件职责；仅允许迁入审计通过的 helper-suffix imports 以及已证明的 helper lemma/theorem/fact/remark。
- `annotation-subagent` 与 `vc-proving-subagent` 的交互式工作，必须先从最新正式快照创建隔离 scratch；annotation phase 需要同时创建 C scratch 和 `annotation_scratch_lib`，不得直接在主状态文件上做实验。checkpoint / packet direct reuse 必须先还原成 fresh scratch 上的 candidate Rocq source，再通过 compile gate；pattern reuse 可以把 JSON 中的 per-goal candidates、完整 proof reference pool、旧 informal proof / helper reference 作为只读参考交给 worker，但 worker 必须自行比较相似性、适配当前 VC 并编译通过后才能报告 solved。
- 只要 phase 完成、phase 输入 stale、上游刷新、或需要重开新轮次，对应 scratch 文件必须全部删除。
- 每次 symexec 刷新出新的正式 `*_proof_manual.v` 后，旧的 proving scratch 和 worker workdir 必须先删除，再基于最新正式 `*_proof_manual.v` / 只读 `common_case_formal_lib` 重建。
- 不在正式 `*_proof_manual.v`、`common_case_formal_lib` 中引入 `Admitted` 或额外 `Axiom`；`*_goal.v` 与 `*_proof_auto.v` 的工具生成项只可识别、不可手改。
- 禁止使用仓库规则禁用的黑盒 entailment 自动化 tactic。
- 如果 manual VC 语义上不可证，应回到 annotation 或规格层修正，不要硬写 Rocq proof。
- 任何返工都只能使下游结论失效或过期；允许删除的只有 phase scratch，不能通过删除正式证明交付物来“清空状态”。
- 你生成的所有临时文件都应该存储在 `.tmp` 子文件夹下，并尽量保持与正式文件相同的相对目录结构。
- 主 agent 在进入 `done` 或结束当前 case 工作流前，必须执行最终临时文件清理：删除本轮产生的 `.tmp` 内容、Coq `.aux` 文件、pytest / Python 编译缓存等非交付临时产物；不得删除正式 `.c`、`*_goal.v`、`*_proof_auto.v`、`*_proof_manual.v`、`*_goal_check.v`、`common_case_formal_lib`。
- 如果从下游 phase 二次进入 `annotation` 或 `vc-proving`，主 agent 必须向新的 subagent 提供结构化回流摘要，至少说明：为什么回流、上一轮在哪里失败、哪些 witness / 文件受影响、与上一轮相比哪些输入已经变化。

# 完成标准

只有在以下条件同时满足时，任务才算完成：

1. symbolic execution 已到文件尾，且生成文件是最新的。
2. 所有需要的 manual VC 都已完成证明，或已被明确退回 annotation 修正。
3. 对应的 `*_goal_check.v` 编译通过。
4. 最终检查确认：`*_proof_manual.v`、`common_case_formal_lib` 没有遗留 `Admitted` 或额外 `Axiom`，没有使用任何 forbidden lemma（列表见 `.agents/skills/verification-orchestrator/docs/forbidden_lemma.md`），`*_proof_manual.v` 只含 witness proofs 且没有 helper lemmas / forbidden top-level 定义，`common_case_formal_lib` 的 annotation-approved spec 定义不是算法镜像，冻结前缀未被 proving 改写，冻结前缀后的 helper-suffix imports 均为审计通过的 `Require Import` 行、helper lemmas 均已证明且没有 forbidden top-level 定义，并且不存在过期生成文件或残留 scratch / `.tmp` / `.aux` 临时文件。
