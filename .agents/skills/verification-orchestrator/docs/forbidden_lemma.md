# Forbidden Lemma 列表

这个文件列出了在 manual proof 中**禁止使用**的 lemma。`vc-proving` 环节和 `final-check` 环节都必须参考此列表。

## 规则

- 在 `*_proof_manual.v` 和 `common_case_formal_lib` 的任意证明中，**不得使用**以下列出的任何 lemma。
- 这些 lemma 通常属于以下类别之一，直接使用它们会绕过分离逻辑证明的核心推理步骤：
  - **逻辑等价性重排**（如交换律、结合律）：应通过结构化改写目标来避免依赖这些 lemma。
  - **自反/传递/对称闭包**：`derivable1_refl`、`derivable1_trans`、`logic_equiv_refl`、`logic_equiv_symm`、`logic_equiv_trans` 等会掩盖推导的结构性问题。
  - **emp / truep 简化**：`elim_wand_emp_emp`、`sepcon_emp_logic_equiv'`、`logic_equiv_sepcon_emp`、`logic_equiv_andp_truep`、`logic_equiv_truep_andp`、`truep_andp_right_equiv` 等属于不应在证明中直接调用的基础简化。
  - **单调性**：`derivable1_sepcon_mono` 属于结构性推理，不应用于 direct proof。
- 若 `vc-proving` 产出的证明中使用了这些 lemma，必须在 `vc-proving` 阶段内修正。
- 若 `final-check` 扫描发现使用了这些 lemma，必须判定 final-check **失败**，并**回退到 `vc-proving`** 阶段，附带具体命中列表和原因说明。

## Forbidden Lemma 列表

| # | Lemma 名称 | 说明 |
|---|-----------|------|
| 1 | `logic_equiv_refl` | 逻辑等价自反性 |
| 2 | `elim_wand_emp_emp` | wand-emp-emp 消除 |
| 3 | `logic_equiv_symm` | 逻辑等价对称性 |
| 4 | `sepcon_emp_logic_equiv'` | sepcon emp 逻辑等价变体 |
| 5 | `logic_equiv_andp_comm` | andp 交换律 |
| 6 | `logic_equiv_sepcon_comm` | sepcon 交换律 |
| 7 | `logic_equiv_sepcon_emp` | sepcon emp 等价 |
| 8 | `logic_equiv_andp_truep` | andp truep 等价 |
| 9 | `logic_equiv_truep_andp` | truep andp 等价 |
| 10 | `truep_andp_right_equiv` | truep andp 右侧等价 |
| 11 | `logic_equiv_orp_comm` | orp 交换律 |
| 12 | `logic_equiv_trans` | 逻辑等价传递性 |
| 13 | `logic_equiv_orp_assoc` | orp 结合律 |
| 14 | `logic_equiv_sepcon_assoc` | sepcon 结合律 |
| 15 | `logic_equiv_andp_assoc` | andp 结合律 |
| 16 | `logic_equiv_sepcon_orp` | sepcon-orp 分配律 |
| 17 | `logic_equiv_sepcon_orp_distr` | sepcon-orp 分配律变体 |
| 18 | `logic_equiv_orp_sepcon` | orp-sepcon 分配律 |
| 19 | `derivable1_trans` | derivable 传递性 |
| 20 | `derivable1_refl` | derivable 自反性 |
| 21 | `derivable1_sepcon_comm` | derivable sepcon commutativity |
| 22 | `coq_prop_andp_right` | Coq prop andp 右侧引理 |
| 23 | `derivable1_sepcon_mono` | derivable sepcon 单调性 |

## 检查方式

### vc-proving 环节

- 在 `vc-proving` 的 `validate_and_merge.py` 和 `verify_manual_goals.py` 阶段，应对 worker 产出的 proof 进行 forbidden lemma 扫描。
- 若 worker 产出的 proof 命中了 forbidden lemma，必须在合并前修正，不得将含 forbidden lemma 的证明合并进 scratch manual。
- 若修正需要重写证明策略，worker 应在自己的 workdir 内完成修正后重新提交。

### final-check 环节

- 在 `final-check` 的 Admitted / Axiom review 步骤之后，必须对 `*_proof_manual.v` 和 `common_case_formal_lib` 执行 forbidden lemma 扫描。
- 扫描方式：在目标文件中搜索上述每个 forbidden lemma 名称的出现（使用 grep 或等价方式）。
- 若命中任何 forbidden lemma：
  1. 记录所有命中位置（文件名、行号、匹配的 lemma 名称）。
  2. 判定 `final-check` **失败**。
  3. 在失败报告中列出所有命中项及其位置。
  4. 将 case **回退到 `vc-proving`** 阶段，并在 `Re-entry Brief` 中附上 forbidden lemma 命中清单。
  5. 回退原因：manual proof 中使用了禁止的 lemma，需要在 vc-proving 中重写相关证明以消除对这些 lemma 的依赖。
- 若未命中任何 forbidden lemma，继续 final-check 的后续步骤。
