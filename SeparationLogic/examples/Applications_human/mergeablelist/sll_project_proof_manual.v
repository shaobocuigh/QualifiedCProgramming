Require Import Coq.ZArith.ZArith.
Require Import Coq.Bool.Bool.
Require Import Coq.Strings.String.
Require Import Coq.Lists.List.
Require Import Coq.Classes.RelationClasses.
Require Import Coq.Classes.Morphisms.
Require Import Coq.micromega.Psatz.
Require Import Coq.Sorting.Permutation.
From AUXLib Require Import int_auto Axioms Feq Idents ListLib VMap.
Require Import SetsClass.SetsClass. Import SetsNotation.
From SimpleC.SL Require Import Mem SeparationLogic.
From SimpleC.EE.Applications_human.mergeablelist Require Import sll_project_goal.
Require Import Logic.LogicGenerator.demo932.Interface.
Local Open Scope Z_scope.
Local Open Scope sets.
Local Open Scope string.
Local Open Scope list.
From SimpleC.EE.Applications_human.mergeablelist Require Import sll_project_lib.
Import naive_C_Rules.
Local Open Scope sac.

Lemma proof_of_cons_list_return_wit_1 : cons_list_return_wit_1.
Proof.
  pre_process.
  unfold sll_pt.
  destruct l.
  - Intros. subst next_pre.
    Right.
    Exists (&(retval # "sll" ->ₛ"next")).
    simpl sllbseg.
    entailer!.
  - Intros.
    Left.
    Exists pt.
    simpl sllbseg.
    Exists next_pre.
    entailer!.
    discriminate.
Qed.

Lemma proof_of_free_list_return_wit_1 : free_list_return_wit_1.
Proof.
  pre_process.
  subst head.
  sep_apply sll_zero.
  - entailer!.
  - entailer!.
Qed.

Lemma proof_of_free_list_which_implies_wit_1 : free_list_which_implies_wit_1.
Proof.
  pre_process.
  destruct l_rest as [ | a l0].
  - simpl sll. Intros. tauto.
  - simpl sll. Intros. Intros y.
    Exists y a l0. entailer!.
Qed.

Lemma proof_of_map_list_entail_wit_1 : map_list_entail_wit_1.
Proof.
  pre_process.
  Exists (@nil Z) l.
  simpl sllseg. simpl app. simpl map_mult. entailer!.
Qed.

Lemma proof_of_map_list_entail_wit_2 : map_list_entail_wit_2.
Proof.
  pre_process.
  Exists (l1_2 ++ (p_data :: nil)) l2_new.
  entailer!.
  - sep_apply sllseg_len1; try easy.
    sep_apply (sllseg_sllseg head_pre).
    assert (H_eq: map_mult x_pre (l1_2 ++ p_data :: nil) = map_mult x_pre l1_2 ++ unsigned_last_nbits (x_pre * p_data) 32 :: nil).
    { unfold map_mult. rewrite map_app. simpl. reflexivity. }
    rewrite H_eq. entailer!.
  - rewrite PreH3, PreH1. rewrite <- app_assoc. simpl. reflexivity.
Qed.

Lemma proof_of_map_list_return_wit_1 : map_list_return_wit_1.
Proof.
  pre_process.
  subst p.
  sep_apply sll_zero; try tauto.
  Intros. subst l2.
  sep_apply sllseg_0_sll.
  rewrite app_nil_r in PreH2. subst l. entailer!.
Qed.

Lemma proof_of_map_list_which_implies_wit_1 : map_list_which_implies_wit_1.
Proof.
  pre_process.
  destruct l2 as [ | a l0].
  - simpl sll. Intros. tauto.
  - simpl sll. Intros. Intros y.
    Exists y a l0. entailer!.
Qed.

Lemma proof_of_cons_list_box_return_wit_1 : cons_list_box_return_wit_1.
Proof.
  pre_process.
  simpl sll_pt.
  Intros.
  Exists pt_new_2.
  simpl sllbseg.
  Exists retval.
  entailer!.
  subst pt_new_2.
  entailer!.
Qed. 

Lemma proof_of_cons_list_box_return_wit_2 : cons_list_box_return_wit_2.
Proof.
  pre_process.
  simpl sll_pt.
  Intros.
  Exists pt.
  simpl sllbseg.
  Exists retval.
  simpl sllbseg.
  entailer!.
  subst pt_new_2.
  entailer!.
Qed. 
Lemma proof_of_cons_list_box_which_implies_wit_1 : cons_list_box_which_implies_wit_1.
Proof.
  pre_process.
  sep_apply (sllbseg_0_sll_pt (&(box # "sllb" ->ₛ"head")) pt l).
  Intros h.
  Exists h.
  entailer!.
Qed. 

Lemma proof_of_app_list_box_return_wit_2 : app_list_box_return_wit_2.
Proof.
  pre_process.
  unfold sll_pt.
  destruct l2.
  + Intros. subst h2.
    rewrite app_nil_r.
    sep_apply (sllbseg_2_sllb b1_pre pt1 l1).
    entailer!.
    tauto.
  + Intros. tauto.
Qed.

Lemma proof_of_app_list_box_return_wit_1 : app_list_box_return_wit_1.
Proof.
  pre_process.
  unfold sll_pt.
  destruct l2.
  + Intros. tauto.
  + Intros.
    clear H.
    assert (h2 <> 0) as H by exact PreH1.
    sep_apply (sllbseg_append_sllbseg (&(b1_pre # "sllb" ->ₛ"head")) pt1 l1 h2 pt2 z l2 H).
    sep_apply (sllbseg_2_sllb b1_pre pt2 (l1 ++ z :: l2) PreH2).
    entailer!.
Qed.

Lemma proof_of_app_list_box_which_implies_wit_1 : app_list_box_which_implies_wit_1.
Proof.
  pre_process.
  sep_apply (sllb_2_sllbseg b1 l1).
  Intros pt1.
  sep_apply (sllb_2_sll_pt b2 l2).
  Intros h2 pt2.
  Exists pt2 h2 pt1.
  entailer!.
Qed. 

Lemma proof_of_sll_length_entail_wit_1 : sll_length_entail_wit_1.
Proof.
  pre_process.
  Exists (@nil Z) l.
  simpl sllseg. simpl app. simpl Zlength. entailer!.
Qed.

Lemma proof_of_sll_length_entail_wit_2 : sll_length_entail_wit_2.
Proof.
  pre_process.
  Exists (l1_2 ++ (head_data :: nil)) l3.
  simpl.
  entailer!.
  sep_apply sllseg_len1.
  - sep_apply (sllseg_sllseg head_pre). entailer!.
  - entailer!.
  - rewrite Zlength_app. rewrite Zlength_cons, Zlength_nil.
    rewrite PreH3.
    apply unsigned_last_nbits_eq.
    rewrite PreH2, PreH1 in PreH4.
    rewrite Zlength_app, Zlength_cons in PreH4.
    pose proof (Zlength_nonneg l1_2).
    pose proof (Zlength_nonneg l3). lia.
  - rewrite PreH2, PreH1. rewrite <- app_assoc. simpl. reflexivity.
Qed.

Lemma proof_of_sll_length_return_wit_1 : sll_length_return_wit_1.
Proof.
  pre_process.
  rewrite PreH4.
  sep_apply sll_zero.
  Intros.
  subst l2.
  entailer!.
  - rewrite PreH1, app_nil_r. sep_apply sllseg_0_sll. entailer!.
  - rewrite PreH1, app_nil_r. assumption.
  - reflexivity.
Qed.

Lemma proof_of_sll_length_which_implies_wit_1 : sll_length_which_implies_wit_1.
Proof.
  pre_process.
  destruct l2 as [ | a l0].
  - simpl sll. Intros. tauto.
  - simpl sll. Intros. Intros x.
    Exists x a l0. entailer!.
Qed.

Lemma proof_of_sll2array_entail_wit_1 : sll2array_entail_wit_1.
Proof.
  pre_process.
  Exists (@nil Z) l.
  simpl sllseg. simpl Zlength. simpl app.
  rewrite (UIntArray.seg_shape_empty retval_2 0).
  entailer!.
  pose proof (Zlength_nonneg l).
  lia.
Qed.

Lemma proof_of_sll2array_entail_wit_2 : sll2array_entail_wit_2.
Proof.
  pre_process.
  Exists (l1_2 ++ p_data :: nil) l3.
  entailer!.
  - sep_apply sllseg_len1; try easy.
    sep_apply (sllseg_sllseg head_pre).
    entailer!.
  - rewrite Zlength_app, Zlength_cons, Zlength_nil. lia.
  - rewrite PreH3, PreH1. rewrite <- app_assoc. simpl. reflexivity.
Qed.

Lemma proof_of_sll2array_return_wit_1 : sll2array_return_wit_1.
Proof.
  pre_process.
  subst p.
  sep_apply sll_zero; try tauto.
  Intros. subst l2.
  rewrite app_nil_r in PreH1.
  subst l.
  Exists arr.
  sep_apply sllseg_0_sll.
  rewrite PreH2.
  rewrite PreH3.
  rewrite (UIntArray.undef_seg_empty arr (Zlength l1)).
  sep_apply (UIntArray.seg_shape_to_full_shape arr 0 (Zlength l1)).
  replace (arr + 0 * sizeof(UINT)) with arr by lia.
  replace (Zlength l1 - 0) with (Zlength l1) by lia.
  entailer!.
Qed.

Lemma proof_of_sll2array_partial_solve_wit_3_pure : sll2array_partial_solve_wit_3_pure.
Proof.
  pre_process.
  prop_apply (sll_not_null_length p l2 PreH8).
  Intros.
  entailer!.
  rewrite PreH2.
  rewrite PreH3.
  rewrite PreH1.
  rewrite Zlength_app.
  lia.
Qed.

Lemma proof_of_sll2array_which_implies_wit_1 : sll2array_which_implies_wit_1.
Proof.
  pre_process.
  destruct l2 as [ | a l0].
  - simpl sll. Intros. tauto.
  - simpl sll. Intros. Intros y.
    Exists y a l0.
    entailer!.
Qed.
