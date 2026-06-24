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
From SimpleC.EE.QCP_demos_human Require Import sll_insert_sort_goal.
Require Import Logic.LogicGenerator.demo932.Interface.
Local Open Scope Z_scope.
Local Open Scope sets.
Local Open Scope string.
Local Open Scope list.
Import naive_C_Rules.
From SimpleC.EE.QCP_demos_human Require Import sll_lib.
From SimpleC.EE.QCP_demos_human Require Import sll_insert_sort_lib.
Local Open Scope sac.

Lemma proof_of_insertion_entail_wit_1 : insertion_entail_wit_1.
Proof. 
  pre_process.
  Exists nil l.
  entailer!. simpl. entailer!.
Qed.

Lemma proof_of_insertion_entail_wit_2 : insertion_entail_wit_2.
Proof.
  pre_process.
  Exists p2_v_next (l1_2 ++ p2_v_data::nil) l3.
  Intros.
  entailer!.
  - sep_apply sllbseg_len1; try easy.
    sep_apply (sllbseg_sllbseg (&( "res")) p2); easy.
  - inversion PreH1; subst.
    apply upperbound_app; easy.
  - inversion PreH1; subst. 
    rewrite <- app_assoc. reflexivity.
Qed.

Lemma proof_of_insertion_return_wit_1 : insertion_return_wit_1.
Proof.
  pre_process.
  sep_apply sll_zero; try easy. 
  Intros. subst. 
  Exists (l1 ++ a::nil). entailer!.
  - sep_apply sllseg_len1; try easy.
    sep_apply (sllseg_sllseg res node_pre); try easy.
    apply sllseg_0_sll.
  - rewrite app_nil_r. symmetry. 
    apply upperbound_insert_nil; easy.
Qed. 

Lemma proof_of_insertion_return_wit_2 : insertion_return_wit_2.
Proof. 
  pre_process.
  Exists (l1 ++ a::l2).
  subst. entailer!.
  - sep_apply sllseg_len1; try easy.
    sep_apply sllseg_len1; try easy.
    sep_apply sllseg_sllseg. simpl app.
    sep_apply (sllseg_sllseg res node_pre); try easy.
    sep_apply sllseg_sll.
    rewrite <- app_assoc. reflexivity.
  - symmetry. 
    apply upperbound_insert_cons; [easy | lia].
Qed.

Lemma proof_of_insertion_which_implies_wit_2 : insertion_which_implies_wit_2.
Proof.
  pre_process. subst.
  sep_apply sllbseg_2_sllseg.
  Intros y'. Exists y'.
  cancel.
Qed. 

Lemma proof_of_insertion_sort_entail_wit_1 : insertion_sort_entail_wit_1.
Proof. 
  pre_process.
  Exists nil nil l. entailer!.
  simpl. entailer!.
Qed.

Lemma proof_of_insertion_sort_entail_wit_2 : insertion_sort_entail_wit_2.
Proof. 
  pre_process. subst l2_2 l.
  Exists l0_3 (l1_2 ++ p_data::nil) l3.
  entailer!; subst.
  - sep_apply store_ptr_undef_store_ptr. easy.
  - apply increasing_insert. easy.
  - rewrite <- perm_insert. rewrite PreH5. reflexivity. 
  - rewrite <- app_assoc. easy. 
Qed.

Lemma proof_of_insertion_sort_return_wit_1 : insertion_sort_return_wit_1.
Proof. 
  pre_process. subst p.
  sep_apply (sll_zero 0); try easy.
  Intros. subst. rewrite app_nil_r.
  Exists l0_2. entailer!.
Qed.
