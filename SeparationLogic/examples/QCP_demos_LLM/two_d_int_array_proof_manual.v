Require Import Coq.ZArith.ZArith.
Require Import Coq.Bool.Bool.
Require Import Coq.Strings.String.
Require Import Coq.Strings.Ascii.
Require Import Coq.Lists.List.
Require Import Coq.Classes.RelationClasses.
Require Import Coq.Classes.Morphisms.
Require Import Coq.micromega.Psatz.
Require Import Coq.Sorting.Permutation.
From AUXLib Require Import int_auto Axioms Feq Idents ListLib VMap.
Require Import SetsClass.SetsClass. Import SetsNotation.
From SimpleC.SL Require Import Mem SeparationLogic.
From SimpleC.EE.QCP_demos_LLM Require Import two_d_int_array_goal.
From SimpleC.EE.QCP_demos_LLM Require Import two_d_int_array_proof_auto.
Require Import SimpleC.EE.QCP_demos_LLM.two_d_functional_spec_lib.
Require Import Logic.LogicGenerator.demo932.Interface.
Local Open Scope Z_scope.
Local Open Scope sets.
Local Open Scope string_scope.
Local Open Scope list.
Import naive_C_Rules.
Local Open Scope sac.


Lemma proof_of_max_fill_array2_safety_wit_6 : max_fill_array2_safety_wit_6.
Proof.
  pre_process_default; try entailer!;
  match goal with
  | Hlen : forall r : Z, _ -> Zlength (Znth r ?rs ?d) = ?m
    |- Zlength (Znth ?r ?rs ?d2) = ?m =>
      rewrite (Znth_indep rs r d2 d) by lia; apply Hlen; lia
  | _ => idtac
  end;
  match goal with
  | Hcell : forall r c : Z, _ -> _
    |- context[Znth ?c (Znth ?r ?rs ?d) 0] =>
      pose proof (Hcell r c ltac:(repeat split; lia))
  | _ => idtac
  end;
  match goal with
  | |- (IntArray.full (?p + ?i * ?m * sizeof ( INT )) ?m
          (replace_Znth ?j (Znth ?j (Znth ?i ?rows ?d) 0) (Znth ?i ?rows ?d)) **
        IntArray2.missing_i ?p ?i 0 ?n ?m ?rows |--
        IntArray2.full ?p ?n ?m ?rows)%sac =>
      rewrite replace_Znth_Znth by lia;
      sep_apply (IntArray2.missing_i_merge_to_full p i n m rows (Znth i rows d));
      try lia; rewrite replace_Znth_Znth by lia; cancel
  | _ => idtac
  end;  match goal with
  | |- context[Z.quot (?s - 1) ?cap] =>
      assert (0 <= Z.quot (s - 1) cap <= s - 1) by
        (split; [apply Z.quot_pos; lia | apply Z.quot_le_upper_bound; nia])
  | _ => idtac
  end;
  try lia; try nia.
Qed.

Lemma proof_of_max_fill_array2_safety_wit_7 : max_fill_array2_safety_wit_7.
Proof.
  pre_process_default; try entailer!;
  match goal with
  | Hlen : forall r : Z, _ -> Zlength (Znth r ?rs ?d) = ?m
    |- Zlength (Znth ?r ?rs ?d2) = ?m =>
      rewrite (Znth_indep rs r d2 d) by lia; apply Hlen; lia
  | _ => idtac
  end;
  match goal with
  | Hcell : forall r c : Z, _ -> _
    |- context[Znth ?c (Znth ?r ?rs ?d) 0] =>
      pose proof (Hcell r c ltac:(repeat split; lia))
  | _ => idtac
  end;
  match goal with
  | |- (IntArray.full (?p + ?i * ?m * sizeof ( INT )) ?m
          (replace_Znth ?j (Znth ?j (Znth ?i ?rows ?d) 0) (Znth ?i ?rows ?d)) **
        IntArray2.missing_i ?p ?i 0 ?n ?m ?rows |--
        IntArray2.full ?p ?n ?m ?rows)%sac =>
      rewrite replace_Znth_Znth by lia;
      sep_apply (IntArray2.missing_i_merge_to_full p i n m rows (Znth i rows d));
      try lia; rewrite replace_Znth_Znth by lia; cancel
  | _ => idtac
  end;  match goal with
  | |- context[Z.quot (?s - 1) ?cap] =>
      assert (0 <= Z.quot (s - 1) cap <= s - 1) by
        (split; [apply Z.quot_pos; lia | apply Z.quot_le_upper_bound; nia])
  | _ => idtac
  end;
  try lia; try nia.
Qed.

Lemma proof_of_max_fill_array2_safety_wit_9 : max_fill_array2_safety_wit_9.
Proof.
  pre_process_default; try entailer!;
  match goal with
  | Hlen : forall r : Z, _ -> Zlength (Znth r ?rs ?d) = ?m
    |- Zlength (Znth ?r ?rs ?d2) = ?m =>
      rewrite (Znth_indep rs r d2 d) by lia; apply Hlen; lia
  | _ => idtac
  end;
  match goal with
  | Hcell : forall r c : Z, _ -> _
    |- context[Znth ?c (Znth ?r ?rs ?d) 0] =>
      pose proof (Hcell r c ltac:(repeat split; lia))
  | _ => idtac
  end;
  match goal with
  | |- (IntArray.full (?p + ?i * ?m * sizeof ( INT )) ?m
          (replace_Znth ?j (Znth ?j (Znth ?i ?rows ?d) 0) (Znth ?i ?rows ?d)) **
        IntArray2.missing_i ?p ?i 0 ?n ?m ?rows |--
        IntArray2.full ?p ?n ?m ?rows)%sac =>
      rewrite replace_Znth_Znth by lia;
      sep_apply (IntArray2.missing_i_merge_to_full p i n m rows (Znth i rows d));
      try lia; rewrite replace_Znth_Znth by lia; cancel
  | _ => idtac
  end;  match goal with
  | |- context[Z.quot (?s - 1) ?cap] =>
      assert (0 <= Z.quot (s - 1) cap <= s - 1) by
        (split; [apply Z.quot_pos; lia | apply Z.quot_le_upper_bound; nia])
  | _ => idtac
  end;
  try lia; try nia.
Qed.

Lemma proof_of_max_fill_array2_safety_wit_10 : max_fill_array2_safety_wit_10.
Proof.
  pre_process_default; try entailer!;
  match goal with
  | Hlen : forall r : Z, _ -> Zlength (Znth r ?rs ?d) = ?m
    |- Zlength (Znth ?r ?rs ?d2) = ?m =>
      rewrite (Znth_indep rs r d2 d) by lia; apply Hlen; lia
  | _ => idtac
  end;
  match goal with
  | Hcell : forall r c : Z, _ -> _
    |- context[Znth ?c (Znth ?r ?rs ?d) 0] =>
      pose proof (Hcell r c ltac:(repeat split; lia))
  | _ => idtac
  end;
  match goal with
  | |- (IntArray.full (?p + ?i * ?m * sizeof ( INT )) ?m
          (replace_Znth ?j (Znth ?j (Znth ?i ?rows ?d) 0) (Znth ?i ?rows ?d)) **
        IntArray2.missing_i ?p ?i 0 ?n ?m ?rows |--
        IntArray2.full ?p ?n ?m ?rows)%sac =>
      rewrite replace_Znth_Znth by lia;
      sep_apply (IntArray2.missing_i_merge_to_full p i n m rows (Znth i rows d));
      try lia; rewrite replace_Znth_Znth by lia; cancel
  | _ => idtac
  end;  match goal with
  | |- context[Z.quot (?s - 1) ?cap] =>
      assert (0 <= Z.quot (s - 1) cap <= s - 1) by
        (split; [apply Z.quot_pos; lia | apply Z.quot_le_upper_bound; nia])
  | _ => idtac
  end;
  try lia; try nia.
Qed.
Lemma proof_of_max_fill_array2_entail_wit_1 : max_fill_array2_entail_wit_1.
Proof.
  pre_process_default; try entailer!;
  match goal with
  | Hlen : forall r : Z, _ -> Zlength (Znth r ?rs ?d) = ?m
    |- Zlength (Znth ?r ?rs ?d2) = ?m =>
      rewrite (Znth_indep rs r d2 d) by lia; apply Hlen; lia
  | _ => idtac
  end;
  match goal with
  | Hcell : forall r c : Z, _ -> _
    |- context[Znth ?c (Znth ?r ?rs ?d) 0] =>
      pose proof (Hcell r c ltac:(repeat split; lia))
  | _ => idtac
  end;
  match goal with
  | |- (IntArray.full (?p + ?i * ?m * sizeof ( INT )) ?m
          (replace_Znth ?j (Znth ?j (Znth ?i ?rows ?d) 0) (Znth ?i ?rows ?d)) **
        IntArray2.missing_i ?p ?i 0 ?n ?m ?rows |--
        IntArray2.full ?p ?n ?m ?rows)%sac =>
      rewrite replace_Znth_Znth by lia;
      sep_apply (IntArray2.missing_i_merge_to_full p i n m rows (Znth i rows d));
      try lia; rewrite replace_Znth_Znth by lia; cancel
  | _ => idtac
  end;  match goal with
  | |- context[Z.quot (?s - 1) ?cap] =>
      assert (0 <= Z.quot (s - 1) cap <= s - 1) by
        (split; [apply Z.quot_pos; lia | apply Z.quot_le_upper_bound; nia])
  | _ => idtac
  end;
  try lia; try nia.
Qed.

Lemma proof_of_max_fill_array2_entail_wit_2 : max_fill_array2_entail_wit_2.
Proof.
  pre_process_default; try entailer!;
  match goal with
  | Hlen : forall r : Z, _ -> Zlength (Znth r ?rs ?d) = ?m
    |- Zlength (Znth ?r ?rs ?d2) = ?m =>
      rewrite (Znth_indep rs r d2 d) by lia; apply Hlen; lia
  | _ => idtac
  end;
  match goal with
  | Hcell : forall r c : Z, _ -> _
    |- context[Znth ?c (Znth ?r ?rs ?d) 0] =>
      pose proof (Hcell r c ltac:(repeat split; lia))
  | _ => idtac
  end;
  match goal with
  | |- (IntArray.full (?p + ?i * ?m * sizeof ( INT )) ?m
          (replace_Znth ?j (Znth ?j (Znth ?i ?rows ?d) 0) (Znth ?i ?rows ?d)) **
        IntArray2.missing_i ?p ?i 0 ?n ?m ?rows |--
        IntArray2.full ?p ?n ?m ?rows)%sac =>
      rewrite replace_Znth_Znth by lia;
      sep_apply (IntArray2.missing_i_merge_to_full p i n m rows (Znth i rows d));
      try lia; rewrite replace_Znth_Znth by lia; cancel
  | _ => idtac
  end;  match goal with
  | |- context[Z.quot (?s - 1) ?cap] =>
      assert (0 <= Z.quot (s - 1) cap <= s - 1) by
        (split; [apply Z.quot_pos; lia | apply Z.quot_le_upper_bound; nia])
  | _ => idtac
  end;
  try lia; try nia.
Qed.


Lemma proof_of_max_fill_array2_entail_wit_3 : max_fill_array2_entail_wit_3.
Proof.
  pre_process_default; try entailer!.
  - pose proof (PreH12 i j ltac:(repeat split; lia)).
    rewrite replace_Znth_Znth by lia.
    change (IntArray.full (grid_pre + i * grid_cols_pre * sizeof ( INT ))
      grid_cols_pre (Znth i rows __default__List_Z)) with
      (IntArray2.ElemArray.full
        (IntArray2.row_addr grid_pre grid_cols_pre i) grid_cols_pre
        (Znth i rows __default__List_Z)).
    sep_apply_l_atomic (IntArray2.missing_i_merge_to_full
      grid_pre i grid_rows_pre grid_cols_pre rows
      (Znth i rows __default__List_Z)).
    + dump_pre_spatial; lia.
    + rewrite replace_Znth_Znth by lia.
      cancel.
  - rewrite (Znth_indep rows i __default__List_Z nil) by lia.
    apply RowPrefixSum_step; try lia.
    exact PreH18.
  - pose proof (PreH12 i j ltac:(repeat split; lia)); lia.
  - pose proof (PreH12 i j ltac:(repeat split; lia)); lia.
Qed.


Lemma proof_of_max_fill_array2_entail_wit_4 : max_fill_array2_entail_wit_4.
Proof.
  pre_process_default; try entailer!.
  all: try match goal with
  | Hprefix : RowPrefixSum ?row ?j0 ?acc |- RowPrefixSum ?row ?cols ?acc =>
      replace cols with j0 by lia; exact Hprefix
  end.
  all: try match goal with
  | Hcell : forall r c : Z, _ -> _ |- forall r c : Z, _ =>
      intros r c Hr; apply Hcell; lia
  end.
  all: try lia.
Qed.

Lemma proof_of_max_fill_array2_entail_wit_5_1 : max_fill_array2_entail_wit_5_1.
Proof.
  pre_process_default; try entailer!.
  all: try match goal with
  | Hrow : RowPrefixSum (Znth ?idx ?rs nil) ?cols ?row_sum,
    Hprefix : BucketRowsPrefixCount ?rs ?cap ?idx ?acc,
    Hlen : Zlength (Znth ?idx ?rs nil) = ?cols
    |- BucketRowsPrefixCount ?rs ?cap (?idx + 1)
          (?acc + (Z.quot (?row_sum - 1) ?cap + 1)) =>
      apply BucketRowsPrefixCount_step_pos; try lia;
      [ rewrite Hlen; exact Hrow | exact Hprefix ]
  end.
  all: try match goal with
  | |- context[Z.quot (?row_sum - 1) ?cap] =>
      assert (0 <= Z.quot (row_sum - 1) cap <= row_sum - 1) by
        (split; [apply Z.quot_pos; lia | apply Z.quot_le_upper_bound; nia]);
      lia
  end.
  all: try match goal with
  | Hcell : forall r c : Z, _ -> _ |- forall r c : Z, _ =>
      intros r c Hr; apply Hcell; lia
  end.
  all: try lia.
Qed.

Lemma proof_of_max_fill_array2_entail_wit_5_2 : max_fill_array2_entail_wit_5_2.
Proof.
  pre_process_default; try entailer!.
  apply BucketRowsPrefixCount_step_zero with (row_sum := sum); try lia.
  - rewrite PreH11; exact PreH16.
  - exact PreH17.
Qed.

Lemma proof_of_max_fill_array2_return_wit_1 : max_fill_array2_return_wit_1.
Proof.
  pre_process_default; try entailer!.
  all: try match goal with
  | Hprefix : BucketRowsPrefixCount ?rs ?cap ?idx ?acc
    |- ?acc = BucketRowsCount ?rs ?cap =>
      apply BucketRowsPrefixCount_complete with (i := idx); try lia; exact Hprefix
  end.
Qed.
