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
From SimpleC.EE.QCP_demos_human Require Import sll_merge_rel_goal.
Require Import Logic.LogicGenerator.demo932.Interface.
Local Open Scope Z_scope.
Local Open Scope sets.
Local Open Scope string.
Local Open Scope list.
Import naive_C_Rules.
From SimpleC.EE.QCP_demos_human Require Import sll_lib.
From SimpleC.EE.QCP_demos_human Require Import sll_merge_rel_lib.
Local Open Scope monad.
Local Open Scope sac.

Lemma proof_of_merge_entail_wit_1 : merge_entail_wit_1.
Proof.
  pre_process.
  Exists s1 s2 nil.
  unfold sllbseg.
  entailer!.
Qed.

Lemma proof_of_merge_entail_wit_2_1 : merge_entail_wit_2_1.
Proof.
  pre_process.
  Exists l1_new (y_data :: l2_new) (l3_2 ++ (x_data :: nil))%list.
  simpl sll. Exists y_next.
  entailer!.
  + sep_apply (sllbseg_len1 t); [ | tauto].
    sep_apply (sllbseg_sllbseg (&( "ret" ))).
    entailer!.
    sep_apply store_ptr_undef_store_ptr.
    entailer!.
  + subst.
    clear - PreH6 PreH1.
    unfold merge_from_mid_rel in *.
    rewrite (repeat_break_unfold _ _) in PreH6.
    prove_by_one_abs_step (by_continue (l1_new, y_data :: l2_new, l3_2 ++ x_data :: nil)).
    unfold merge_body.
    abs_choice_left.
    abs_test_step; [ lia | ].
    abs_ret_step.
Qed.

Lemma proof_of_merge_entail_wit_2_2 : merge_entail_wit_2_2.
Proof.
  pre_process.
  Exists (x_data :: l1_new) l2_new (l3_2 ++ (y_data :: nil))%list.
  simpl sll. Exists x_next.
  entailer!.
  + sep_apply (sllbseg_len1 t); [ | tauto].
    sep_apply (sllbseg_sllbseg (&( "ret" ))).
    entailer!.
    sep_apply store_ptr_undef_store_ptr.
    entailer!.
  + subst.
    clear - PreH6 PreH1.
    unfold merge_from_mid_rel in *.
    rewrite (repeat_break_unfold _ _) in PreH6.
    prove_by_one_abs_step (by_continue (x_data :: l1_new, l2_new, l3_2 ++ y_data :: nil)).
    unfold merge_body.
    abs_choice_right.
    abs_test_step; [ lia | ].
    abs_ret_step.
Qed.

Lemma proof_of_merge_return_wit_1 : merge_return_wit_1.
Proof.
  pre_process.
  sep_apply (sll_zero x); [ | exact PreH1].
  sep_apply sllseg_sll.
  Exists (l3 ++ l2).
  entailer!.
  subst.
  clear - PreH2.
  unfold merge_from_mid_rel in PreH2.
  rewrite (repeat_break_unfold _ _) in PreH2.
  prove_by_one_abs_step (by_break (l3 ++ l2)).
  unfold merge_body.
  destruct l2; abs_ret_step.
Qed.

Lemma proof_of_merge_return_wit_2 : merge_return_wit_2.
Proof.
  pre_process.
  sep_apply (sll_zero y); [ | exact PreH1].
  sep_apply sllseg_sll.
  Exists (l3 ++ l1).
  entailer!.
  subst; clear - PreH3.
  unfold merge_from_mid_rel in PreH3.
  rewrite (repeat_break_unfold _ _) in PreH3.
  prove_by_one_abs_step (by_break (l3 ++ l1)).
  unfold merge_body.
  destruct l1; abs_ret_step.
Qed.

Lemma proof_of_merge_which_implies_wit_3 : merge_which_implies_wit_3.
Proof.
  pre_process.
  sep_apply sllbseg_2_sllseg.
  Intros ret'.
  Exists ret'.
  entailer!.
Qed.

Lemma proof_of_split_rec_return_wit_1 : split_rec_return_wit_1.
Proof. 
  pre_process.
  sep_apply sll_zero;auto.
  Intros.
  unfold maketuple in *.
  subst l_low_level_spec.
  Exists q_pre_v_2 p_pre_v_2 l1_low_level_spec l2_low_level_spec.
  entailer!.
  unfold split_rec_rel in PreH2.
  rewrite (split_rec_rel_unfold (nil, l1_low_level_spec, l2_low_level_spec)) in PreH2.
  simpl in PreH2.
  auto.
Qed. 

Lemma proof_of_split_rec_return_wit_2 : split_rec_return_wit_2.
Proof. 
  pre_process.
  clear PreH2.
  unfold maketuple, applyf, reversepair in *;
  Exists p_callee_v q_callee_v s2_2 s1_2.
  entailer!. 
Qed. 

Lemma proof_of_split_rec_which_implies_wit_2 : split_rec_which_implies_wit_2.
Proof.
  pre_process.
  subst l_low_level_spec.
  entailer!.
  cbn [sll].
  entailer!.
  Exists p_v_next.
  entailer!.
  unfold split_rec_rel in PreH1.
  rewrite (split_rec_rel_unfold (x_data :: l_new, l1_low_level_spec, l2_low_level_spec)) in PreH1.
  simpl in PreH1.
  tauto.
Qed. 

Lemma proof_of_merge_sort_entail_wit_1 : merge_sort_entail_wit_1.
Proof.
  pre_process.
  simpl sll.
  entailer!.
  unfold mergesortrec_loc0.
  rewrite (mergesortrec_unfold l_low_level_spec) in PreH1.
  unfold mergesortrec_f in PreH1.
  tauto.
Qed.

Lemma proof_of_merge_sort_entail_wit_2 : merge_sort_entail_wit_2.
Proof.
  pre_process.
  Exists s1 s2.
  prop_apply (sll_not_zero' q_callee_v); [ | tauto].
  entailer!.
  + unfold applyf, mergesortrec_loc0, maketuple in PreH2.
    unfold mergesortrec_loc1.
    destruct s2; [ congruence | ].
    tauto.
Qed.

Lemma proof_of_merge_sort_entail_wit_3 : merge_sort_entail_wit_3.
Proof.
  pre_process.
  Exists l2_2 l0.
  entailer!.
Qed.

Lemma proof_of_merge_sort_entail_wit_4 : merge_sort_entail_wit_4.
Proof.
  pre_process.
  Exists l1_2 l0.
  entailer!.
Qed.

Lemma proof_of_merge_sort_return_wit_2 : merge_sort_return_wit_2.
Proof.
  pre_process.
  sep_apply (sll_zero q_callee_v); [ | tauto].
  Exists s1.
  entailer!.
  unfold applyf, mergesortrec_loc0, maketuple in PreH2.
  subst s2.
  tauto.
Qed.

Lemma proof_of_merge_sort_partial_solve_wit_3_pure : merge_sort_partial_solve_wit_3_pure.
Proof.
  pre_process.
Qed.


Lemma proof_of_merge_sort3_entail_wit_1 : merge_sort3_entail_wit_1.
Proof.
  pre_process.
  simpl.
  entailer!.
  unfold gmergesortrec_loc0.
  rewrite (gmergesortrec_unfold l_low_level_spec) in PreH4.
  unfold gmergesortrec_f in PreH4.
  apply safeExec_choice_r in PreH4.
  unfold seq in PreH4.
  rewrite (split_rel_refine_ext_split l_low_level_spec).
  prove_by_one_abs_step tt.
  abs_test_step.
  lia.
Qed.

Lemma proof_of_merge_sort3_entail_wit_2 : merge_sort3_entail_wit_2.
Proof.
  pre_process.
  Exists s1 s2.
  entailer!.
Qed.

Lemma proof_of_merge_sort3_entail_wit_3 : merge_sort3_entail_wit_3.
Proof.
  pre_process.
  Exists l2_2 l0.
  entailer!.
Qed.

Lemma proof_of_merge_sort3_entail_wit_4 : merge_sort3_entail_wit_4.
Proof.
  pre_process.
  Exists l1_2 l0.
  entailer!.
Qed.

Lemma proof_of_merge_sort3_return_wit_2 : merge_sort3_return_wit_2.
Proof.
  pre_process.
  rewrite (gmergesortrec_unfold l_low_level_spec) in PreH6.
  unfold gmergesortrec_f in PreH6.
  apply safeExec_choice_l in PreH6.
  Exists l0_2.
  entailer!.
  revert PreH6; apply (highstependret_derive _ _ _ (fun _ => ATrue)).
  hnf.
  intros ? _; exists tt.
  split; [ | exact I].
  hnf.
  tauto.
Qed.

Lemma proof_of_merge_sort3_partial_solve_wit_5_pure : merge_sort3_partial_solve_wit_5_pure.
Proof.
  pre_process. 
Qed. 

Lemma proof_of_merge_sort3_derive_low_level_spec_aux_by_low_level_spec : merge_sort3_derive_low_level_spec_aux_by_low_level_spec.
Proof.
  pre_process.
  Exists l_low_level_spec_aux.
  eapply safeExec_bind in H0 as (X' & ? & ?).
  Exists X'.
  entailer!.
  apply derivable1_wand_sepcon_adjoint.
  Intros l' ret.
  Exists l' ret.
  unfold applyf.
  entailer!.
Qed.

Lemma proof_of_merge_sort3_derive_high_level_spec_by_low_level_spec : merge_sort3_derive_high_level_spec_by_low_level_spec.
Proof.
  pre_process.
  Exists l_high_level_spec.
  eExists.
  entailer!.
  2: apply safeExec_monad_Atrue_finnal.
  apply derivable1_wand_sepcon_adjoint.
  entailer!.
  Intros retl retaddr.
  Exists retl retaddr.
  pose proof functional_correctness_gmergesort.
  unfold safeExec, safe in H0.
  unfold Hoare in H1.
  my_destruct H0.
  assert (ATrue tt).
  { hnf. auto. }
  specialize (H1 l_high_level_spec tt retl x H3).
  assert ((return retl) x retl x).
  {
    hnf. split; auto.  
  }
  specialize (H2 _ _ H4).
  specialize (H1 H2).
  entailer!.
Qed.

Lemma proof_of_merge_sort2_derive_low_level_spec_aux_by_low_level_spec : merge_sort2_derive_low_level_spec_aux_by_low_level_spec.
Proof.
  pre_process.
  Exists l_low_level_spec_aux.
  eapply safeExec_bind in H as (X' & ? & ?).
  Exists X'.
  entailer!.
  apply derivable1_wand_sepcon_adjoint.
  Intros l' ret.
  Exists l' ret.
  unfold applyf.
  entailer!.
Qed.

Lemma proof_of_merge_sort2_derive_high_level_spec_by_low_level_spec : merge_sort2_derive_high_level_spec_by_low_level_spec.
Proof.
  pre_process.
  Exists l_high_level_spec.
  Exists (gmergesortrec l_high_level_spec tt).
  rewrite logic_equiv_coq_prop_andp_sepcon.
  entailer!.
  2: apply safeExec_monad_Atrue_finnal.
  apply derivable1_wand_sepcon_adjoint.
  entailer!.
  Intros retl retaddr.
  Exists retl retaddr.
  eapply safeExec_ret_Atrue_finnal in H as [? ? ].
  pose proof functional_correctness_gmergesort.
  unfold Hoare in H0.
  assert (ATrue tt).
  { hnf. auto. }
  specialize (H0 l_high_level_spec tt retl x H1 H).
  entailer!.
Qed.

Lemma proof_of_merge_sort_derive_low_level_spec_aux_by_low_level_spec : merge_sort_derive_low_level_spec_aux_by_low_level_spec.
Proof.
  pre_process.
  Exists l_low_level_spec_aux.
  eapply safeExec_bind in H as (X' & ? & ?).
  Exists X'.
  entailer!.
  apply derivable1_wand_sepcon_adjoint.
  Intros l' ret.
  Exists l' ret.
  unfold applyf.
  entailer!.
Qed.

Lemma proof_of_merge_sort_derive_high_level_spec_by_low_level_spec : merge_sort_derive_high_level_spec_by_low_level_spec.
Proof.
  pre_process.
  Exists l_high_level_spec.
  Exists (mergesortrec l_high_level_spec tt).
  rewrite logic_equiv_coq_prop_andp_sepcon.
  entailer!.
  2: apply safeExec_monad_Atrue_finnal.
  apply derivable1_wand_sepcon_adjoint.
  entailer!.
  Intros retl retaddr.
  Exists retl retaddr.
  eapply safeExec_ret_Atrue_finnal in H as [? ? ].
  pose proof functional_correctness_mergesort.
  unfold Hoare in H0.
  assert (ATrue tt).
  { hnf. auto. }
  specialize (H0 l_high_level_spec tt retl x H1 H).
  entailer!.
Qed.

Lemma proof_of_split_rec_derive_low_level_spec_aux_by_low_level_spec : split_rec_derive_low_level_spec_aux_by_low_level_spec.
Proof. 
  pre_process.
  Intros qptr pptr.
  Exists l_low_level_spec_aux l1_low_level_spec_aux l2_low_level_spec_aux.
  eapply safeExec_bind in H as (X' & ? & ?).
  Exists X'.
  entailer!.
  Exists qptr.
  entailer!.
  Exists pptr.
  entailer!.
  clear - H0.
  apply derivable1_wand_sepcon_adjoint.
  Intros qptr pptr pl ql.
  Exists qptr pptr pl ql.
  entailer!.
Qed. 

Lemma proof_of_split_rec_derive_high_level_spec_by_low_level_spec : split_rec_derive_high_level_spec_by_low_level_spec.
Proof. 
  pre_process.
  Intros qptr pptr.
  Exists l_high_level_spec nil nil X_high_level_spec.
  entailer!.
  Exists qptr.
  entailer!.
  Exists pptr.
  entailer!.
  clear.
  apply derivable1_wand_sepcon_adjoint.
  Intros qptr pptr pl ql.
  Exists qptr pptr pl ql.
  entailer!.
Qed. 
