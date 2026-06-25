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
From SimpleC.EE.QCP_demos_LLM Require Import two_d_char_ptr_array_goal.
From SimpleC.EE.QCP_demos_LLM Require Import two_d_char_ptr_array_proof_auto.
Require Import Logic.LogicGenerator.demo932.Interface.
Local Open Scope Z_scope.
Local Open Scope sets.
Local Open Scope string_scope.
Local Open Scope list.
Import naive_C_Rules.
Require Import SimpleC.EE.QCP_demos_LLM.two_d_functional_spec_lib.
Local Open Scope sac.

Lemma proof_of_check_dict_case_safety_wit_39 : check_dict_case_safety_wit_39.
Proof.
  pre_process_default; try entailer!;
  try match goal with
  | Hrow : forall r : Z, _ -> _ |- _ =>
      pose proof (Hrow k ltac:(lia)) as Hk_row
  end;
  try lia.
Qed.

Lemma proof_of_check_dict_case_safety_wit_40 : check_dict_case_safety_wit_40.
Proof.
  pre_process_default; try entailer!;
  try match goal with
  | Hrow : forall r : Z, _ -> _ |- _ =>
      pose proof (Hrow k ltac:(lia)) as Hk_row
  end;
  try lia.
Qed.

Lemma proof_of_check_dict_case_entail_wit_1 : check_dict_case_entail_wit_1.
Proof.
  pre_process_default; try entailer!.
  apply dict_case_prefix_zero; lia.
Qed.

Lemma proof_of_check_dict_case_entail_wit_2 : check_dict_case_entail_wit_2.
Proof.
  pre_process_default.
  sep_apply_l_atomic (CharPtrArray2.full_split_to_missing_i
    keys_pre k dict_size_pre rows).
  - dump_pre_spatial; lia.
  - Intros row_ptr.
    Exists row_ptr.
    unfold StorePtrAsElement.storeA.
    rewrite sizeof_ptr.
    change (CharPtrArray2.ElemArray.full row_ptr
      (Zlength (Znth k rows nil)) (Znth k rows nil)) with
      (CharArray.full row_ptr
        (Zlength (Znth k rows nil)) (Znth k rows nil)).
    entailer!.
Qed.

Lemma proof_of_check_dict_case_entail_wit_3 : check_dict_case_entail_wit_3.
Proof.
  pre_process_default; try entailer!.
Qed.

Lemma proof_of_check_dict_case_entail_wit_4 : check_dict_case_entail_wit_4.
Proof.
  pre_process_default; try entailer!.
  - apply dict_case_prefix_to_scan_zero; try lia; assumption.
  - pose proof (PreH7 k ltac:(lia)) as Hrow; lia.
Qed.

Lemma proof_of_check_dict_case_entail_wit_5_1 : check_dict_case_entail_wit_5_1.
Proof.
  pre_process_default; try entailer!.
  - apply (dict_case_scan_step_lower
      rows dict_size_pre k i islower isupper); try assumption; try lia.
    + split; [lia | eapply dict_case_nonzero_before_terminator;
        try eassumption; try lia].
    + unfold is_lower_char; lia.
  - assert (Hcontent : i < key_content_len (Znth k rows nil)) by
      (eapply dict_case_nonzero_before_terminator; try eassumption; try lia).
    unfold key_content_len in Hcontent; lia.
Qed.

Lemma proof_of_check_dict_case_entail_wit_5_2 : check_dict_case_entail_wit_5_2.
Proof.
  pre_process_default; try entailer!.
  - apply (dict_case_scan_step_upper
      rows dict_size_pre k i islower isupper); try assumption; try lia.
    + split; [lia | eapply dict_case_nonzero_before_terminator;
        try eassumption; try lia].
    + unfold is_upper_char; lia.
  - assert (Hcontent : i < key_content_len (Znth k rows nil)) by
      (eapply dict_case_nonzero_before_terminator; try eassumption; try lia).
    unfold key_content_len in Hcontent; lia.
Qed.

Lemma proof_of_check_dict_case_entail_wit_6 : check_dict_case_entail_wit_6.
Proof.
  pre_process_default; try entailer!.
  rewrite sizeof_ptr.
  pose proof (CharPtrArray2.missing_i_merge_to_full
    keys_pre k dict_size_pre row_ptr rows (Znth k rows nil)) as Hmerge.
  unfold StorePtrAsElement.storeA in Hmerge.
  change (CharPtrArray2.ElemArray.full row_ptr
    (Zlength (Znth k rows nil)) (Znth k rows nil)) with
    (CharArray.full row_ptr
      (Zlength (Znth k rows nil)) (Znth k rows nil)) in Hmerge.
  sep_apply Hmerge; try lia.
  rewrite replace_Znth_Znth by lia.
  entailer!.
  apply (dict_case_scan_finish_prefix
    rows dict_size_pre k i islower isupper); try assumption; try lia.
Qed.

Lemma proof_of_check_dict_case_entail_wit_7 : check_dict_case_entail_wit_7.
Proof.
  pre_process_default; try entailer!.
Qed.

Lemma proof_of_check_dict_case_return_wit_1 : check_dict_case_return_wit_1.
Proof.
  pre_process_default; try entailer!.
  unfold CheckDictCaseResult.
  left; split; [reflexivity |].
  apply (dict_case_prefix_complete_ok
    rows dict_size_pre k islower isupper); try assumption; lia.
Qed.

Lemma proof_of_check_dict_case_return_wit_2 : check_dict_case_return_wit_2.
Proof.
  pre_process_default; try entailer!.
  rewrite sizeof_ptr.
  pose proof (CharPtrArray2.missing_i_merge_to_full
    keys_pre k dict_size_pre row_ptr rows (Znth k rows nil)) as Hmerge.
  unfold StorePtrAsElement.storeA in Hmerge.
  change (CharPtrArray2.ElemArray.full row_ptr
    (Zlength (Znth k rows nil)) (Znth k rows nil)) with
    (CharArray.full row_ptr
      (Zlength (Znth k rows nil)) (Znth k rows nil)) in Hmerge.
  sep_apply Hmerge; try lia.
  rewrite replace_Znth_Znth by lia.
  entailer!.
  unfold CheckDictCaseResult.
  right; split; [reflexivity |].
  apply (dict_case_scan_lower_conflict_not_ok
    rows dict_size_pre k i islower isupper); try assumption; try lia.
  - split; [lia | eapply dict_case_nonzero_before_terminator;
      try eassumption; try lia].
  - unfold is_lower_char; lia.
Qed.

Lemma proof_of_check_dict_case_return_wit_3 : check_dict_case_return_wit_3.
Proof.
  pre_process_default; try entailer!.
  rewrite sizeof_ptr.
  pose proof (CharPtrArray2.missing_i_merge_to_full
    keys_pre k dict_size_pre row_ptr rows (Znth k rows nil)) as Hmerge.
  unfold StorePtrAsElement.storeA in Hmerge.
  change (CharPtrArray2.ElemArray.full row_ptr
    (Zlength (Znth k rows nil)) (Znth k rows nil)) with
    (CharArray.full row_ptr
      (Zlength (Znth k rows nil)) (Znth k rows nil)) in Hmerge.
  sep_apply Hmerge; try lia.
  rewrite replace_Znth_Znth by lia.
  entailer!.
  unfold CheckDictCaseResult.
  right; split; [reflexivity |].
  apply (dict_case_scan_upper_conflict_not_ok
    rows dict_size_pre k i islower isupper); try assumption; try lia.
  - split; [lia | eapply dict_case_nonzero_before_terminator;
      try eassumption; try lia].
  - unfold is_upper_char; lia.
Qed.

Lemma proof_of_check_dict_case_return_wit_4 : check_dict_case_return_wit_4.
Proof.
  pre_process_default; try entailer!.
  rewrite sizeof_ptr.
  pose proof (CharPtrArray2.missing_i_merge_to_full
    keys_pre k dict_size_pre row_ptr rows (Znth k rows nil)) as Hmerge.
  unfold StorePtrAsElement.storeA in Hmerge.
  change (CharPtrArray2.ElemArray.full row_ptr
    (Zlength (Znth k rows nil)) (Znth k rows nil)) with
    (CharArray.full row_ptr
      (Zlength (Znth k rows nil)) (Znth k rows nil)) in Hmerge.
  sep_apply Hmerge; try lia.
  rewrite replace_Znth_Znth by lia.
  entailer!.
  unfold CheckDictCaseResult.
  right; split; [reflexivity |].
  apply (dict_case_bad_char_not_ok
    rows dict_size_pre k i islower isupper); try assumption; try lia.
  - split; [lia | eapply dict_case_nonzero_before_terminator;
      try eassumption; try lia].
  - unfold is_alpha_char, is_upper_char, is_lower_char; lia.
Qed.

Lemma proof_of_check_dict_case_return_wit_5 : check_dict_case_return_wit_5.
Proof.
  pre_process_default; try entailer!.
  rewrite sizeof_ptr.
  pose proof (CharPtrArray2.missing_i_merge_to_full
    keys_pre k dict_size_pre row_ptr rows (Znth k rows nil)) as Hmerge.
  unfold StorePtrAsElement.storeA in Hmerge.
  change (CharPtrArray2.ElemArray.full row_ptr
    (Zlength (Znth k rows nil)) (Znth k rows nil)) with
    (CharArray.full row_ptr
      (Zlength (Znth k rows nil)) (Znth k rows nil)) in Hmerge.
  sep_apply Hmerge; try lia.
  rewrite replace_Znth_Znth by lia.
  entailer!.
  unfold CheckDictCaseResult.
  right; split; [reflexivity |].
  apply (dict_case_bad_char_not_ok
    rows dict_size_pre k i islower isupper); try assumption; try lia.
  - split; [lia | eapply dict_case_nonzero_before_terminator;
      try eassumption; try lia].
  - unfold is_alpha_char, is_upper_char, is_lower_char; lia.
Qed.

Lemma proof_of_check_dict_case_return_wit_6 : check_dict_case_return_wit_6.
Proof.
  pre_process_default; try entailer!.
  rewrite sizeof_ptr.
  pose proof (CharPtrArray2.missing_i_merge_to_full
    keys_pre k dict_size_pre row_ptr rows (Znth k rows nil)) as Hmerge.
  unfold StorePtrAsElement.storeA in Hmerge.
  change (CharPtrArray2.ElemArray.full row_ptr
    (Zlength (Znth k rows nil)) (Znth k rows nil)) with
    (CharArray.full row_ptr
      (Zlength (Znth k rows nil)) (Znth k rows nil)) in Hmerge.
  sep_apply Hmerge; try lia.
  rewrite replace_Znth_Znth by lia.
  entailer!.
  unfold CheckDictCaseResult.
  right; split; [reflexivity |].
  apply (dict_case_bad_char_not_ok
    rows dict_size_pre k i islower isupper); try assumption; try lia.
  - split; [lia | eapply dict_case_nonzero_before_terminator;
      try eassumption; try lia].
  - unfold is_alpha_char, is_upper_char, is_lower_char; lia.
Qed.

Lemma proof_of_check_dict_case_return_wit_7 : check_dict_case_return_wit_7.
Proof.
  pre_process_default; try entailer!.
  unfold CheckDictCaseResult.
  right; split; [reflexivity |].
  subst; apply dict_case_zero_size_not_ok.
Qed.
