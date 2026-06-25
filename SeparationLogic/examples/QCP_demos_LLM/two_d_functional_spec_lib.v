Require Import Coq.ZArith.ZArith.
Require Import Coq.Lists.List.
Require Import Coq.micromega.Lia.
From AUXLib Require Import ListLib.

Local Open Scope Z_scope.
Local Open Scope list_scope.

Definition row_water (row : list Z) : Z :=
  sum row.

Definition row_bucket_count (row : list Z) (capacity : Z) : Z :=
  if Z.eq_dec (row_water row) 0
  then 0
  else Z.quot (row_water row - 1) capacity + 1.

Definition BucketRowsCount (rows : list (list Z)) (capacity : Z) : Z :=
  sum (map (fun row => row_bucket_count row capacity) rows).

Definition BucketRowsPrefixCount
           (rows : list (list Z)) (capacity upto acc : Z) : Prop :=
  acc = BucketRowsCount (sublist 0 upto rows) capacity.

Definition RowPrefixSum (row : list Z) (upto acc : Z) : Prop :=
  acc = sum (sublist 0 upto row).

Lemma RowPrefixSum_zero : forall row,
  RowPrefixSum row 0 0.
Proof.
  intros.
  unfold RowPrefixSum.
  rewrite Zsublist_nil by lia.
  reflexivity.
Qed.

Lemma RowPrefixSum_step : forall row j acc,
  0 <= j < Zlength row ->
  RowPrefixSum row j acc ->
  RowPrefixSum row (j + 1) (acc + Znth j row 0).
Proof.
  intros row j acc Hj Hprefix.
  unfold RowPrefixSum in *.
  rewrite (sublist_split 0 (j + 1) j row) by lia.
  rewrite (sublist_single 0 j row) by lia.
  rewrite sum_app.
  simpl.
  lia.
Qed.

Lemma RowPrefixSum_full_row_water : forall row upto acc,
  upto = Zlength row ->
  RowPrefixSum row upto acc ->
  acc = row_water row.
Proof.
  intros row upto acc Hupto Hprefix.
  subst.
  unfold RowPrefixSum, row_water in *.
  rewrite sublist_self in Hprefix by reflexivity.
  exact Hprefix.
Qed.

Lemma BucketRowsCount_prefix_snoc : forall rows capacity i,
  0 <= i < Zlength rows ->
  BucketRowsCount (sublist 0 (i + 1) rows) capacity =
  BucketRowsCount (sublist 0 i rows) capacity +
  row_bucket_count (Znth i rows nil) capacity.
Proof.
  intros rows capacity i Hi.
  unfold BucketRowsCount.
  rewrite (sublist_split 0 (i + 1) i rows) by lia.
  rewrite (sublist_single nil i rows) by lia.
  rewrite map_app.
  rewrite sum_app.
  simpl.
  lia.
Qed.

Lemma row_bucket_count_pos : forall row capacity upto acc,
  1 <= capacity ->
  0 < acc ->
  upto = Zlength row ->
  RowPrefixSum row upto acc ->
  row_bucket_count row capacity = Z.quot (acc - 1) capacity + 1.
Proof.
  intros row capacity upto acc Hcap Hpos Hupto Hprefix.
  pose proof (RowPrefixSum_full_row_water row upto acc Hupto Hprefix) as Hacc.
  unfold row_bucket_count.
  rewrite <- Hacc.
  destruct (Z.eq_dec acc 0); lia.
Qed.

Lemma row_bucket_count_zero : forall row capacity upto acc,
  acc <= 0 ->
  0 <= acc ->
  upto = Zlength row ->
  RowPrefixSum row upto acc ->
  row_bucket_count row capacity = 0.
Proof.
  intros row capacity upto acc Hle Hge Hupto Hprefix.
  pose proof (RowPrefixSum_full_row_water row upto acc Hupto Hprefix) as Hacc.
  unfold row_bucket_count.
  rewrite <- Hacc.
  destruct (Z.eq_dec acc 0); lia.
Qed.

Lemma BucketRowsPrefixCount_step_pos : forall rows capacity i out row_sum,
  0 <= i < Zlength rows ->
  1 <= capacity ->
  0 < row_sum ->
  RowPrefixSum (Znth i rows nil) (Zlength (Znth i rows nil)) row_sum ->
  BucketRowsPrefixCount rows capacity i out ->
  BucketRowsPrefixCount rows capacity (i + 1)
    (out + (Z.quot (row_sum - 1) capacity + 1)).
Proof.
  intros rows capacity i out row_sum Hi Hcap Hpos Hrow Hprefix.
  unfold BucketRowsPrefixCount in *.
  rewrite BucketRowsCount_prefix_snoc by lia.
  rewrite (row_bucket_count_pos (Znth i rows nil) capacity
             (Zlength (Znth i rows nil)) row_sum) by auto.
  lia.
Qed.

Lemma BucketRowsPrefixCount_step_zero : forall rows capacity i out row_sum,
  0 <= i < Zlength rows ->
  row_sum <= 0 ->
  0 <= row_sum ->
  RowPrefixSum (Znth i rows nil) (Zlength (Znth i rows nil)) row_sum ->
  BucketRowsPrefixCount rows capacity i out ->
  BucketRowsPrefixCount rows capacity (i + 1) out.
Proof.
  intros rows capacity i out row_sum Hi Hle Hge Hrow Hprefix.
  unfold BucketRowsPrefixCount in *.
  rewrite BucketRowsCount_prefix_snoc by lia.
  rewrite (row_bucket_count_zero (Znth i rows nil) capacity
             (Zlength (Znth i rows nil)) row_sum) by auto.
  lia.
Qed.

Lemma BucketRowsPrefixCount_complete : forall rows capacity i out,
  i = Zlength rows ->
  BucketRowsPrefixCount rows capacity i out ->
  out = BucketRowsCount rows capacity.
Proof.
  intros rows capacity i out Hi Hprefix.
  unfold BucketRowsPrefixCount in Hprefix.
  subst out.
  subst.
  f_equal.
  apply sublist_self; reflexivity.
Qed.

Definition is_upper_char (z : Z) : Prop := 65 <= z <= 90.

Definition is_lower_char (z : Z) : Prop := 97 <= z <= 122.

Definition is_alpha_char (z : Z) : Prop :=
  is_upper_char z \/ is_lower_char z.

Definition key_content_len (row : list Z) : Z :=
  Zlength row - 1.

Definition key_nonempty (row : list Z) : Prop :=
  1 < Zlength row.

Definition key_alphabetic (row : list Z) : Prop :=
  forall i, 0 <= i < key_content_len row ->
            is_alpha_char (Znth i row 0).

Definition key_all_upper (row : list Z) : Prop :=
  forall i, 0 <= i < key_content_len row ->
            is_upper_char (Znth i row 0).

Definition key_all_lower (row : list Z) : Prop :=
  forall i, 0 <= i < key_content_len row ->
            is_lower_char (Znth i row 0).

Definition DictCaseOK (rows : list (list Z)) (dict_size : Z) : Prop :=
  0 < dict_size /\
  Zlength rows = dict_size /\
  (forall k, 0 <= k < dict_size ->
     key_nonempty (Znth k rows nil) /\
     key_alphabetic (Znth k rows nil)) /\
  ((forall k, 0 <= k < dict_size -> key_all_upper (Znth k rows nil)) \/
   (forall k, 0 <= k < dict_size -> key_all_lower (Znth k rows nil))).

Definition CheckDictCaseResult
           (rows : list (list Z)) (dict_size ret : Z) : Prop :=
  (ret = 1 /\ DictCaseOK rows dict_size) \/
  (ret = 0 /\ ~ DictCaseOK rows dict_size).

Definition prefix_has_upper (rows : list (list Z)) (k : Z) : Prop :=
  exists r i,
    0 <= r < k /\
    0 <= i < key_content_len (Znth r rows nil) /\
    is_upper_char (Znth i (Znth r rows nil) 0).

Definition prefix_has_lower (rows : list (list Z)) (k : Z) : Prop :=
  exists r i,
    0 <= r < k /\
    0 <= i < key_content_len (Znth r rows nil) /\
    is_lower_char (Znth i (Znth r rows nil) 0).

Definition prefix_keys_valid (rows : list (list Z)) (k : Z) : Prop :=
  forall r, 0 <= r < k ->
    key_nonempty (Znth r rows nil) /\
    key_alphabetic (Znth r rows nil).

Definition DictCasePrefixState
           (rows : list (list Z)) (dict_size k islower isupper : Z) : Prop :=
  0 <= k <= dict_size /\
  Zlength rows = dict_size /\
  0 <= islower <= 1 /\
  0 <= isupper <= 1 /\
  prefix_keys_valid rows k /\
  (islower = 1 <-> prefix_has_lower rows k) /\
  (isupper = 1 <-> prefix_has_upper rows k) /\
  islower + isupper <= 1.

Definition current_prefix_has_upper
           (rows : list (list Z)) (k i : Z) : Prop :=
  prefix_has_upper rows k \/
  exists j, 0 <= j < i /\
            is_upper_char (Znth j (Znth k rows nil) 0).

Definition current_prefix_has_lower
           (rows : list (list Z)) (k i : Z) : Prop :=
  prefix_has_lower rows k \/
  exists j, 0 <= j < i /\
            is_lower_char (Znth j (Znth k rows nil) 0).

Definition current_prefix_valid
           (rows : list (list Z)) (k i : Z) : Prop :=
  prefix_keys_valid rows k /\
  key_nonempty (Znth k rows nil) /\
  (forall j, 0 <= j < i ->
     is_alpha_char (Znth j (Znth k rows nil) 0)).

Definition DictCaseScanState
           (rows : list (list Z)) (dict_size k i islower isupper : Z) : Prop :=
  0 <= k < dict_size /\
  0 <= i < Zlength (Znth k rows nil) /\
  Zlength rows = dict_size /\
  0 <= islower <= 1 /\
  0 <= isupper <= 1 /\
  current_prefix_valid rows k i /\
  (islower = 1 <-> current_prefix_has_lower rows k i) /\
  (isupper = 1 <-> current_prefix_has_upper rows k i) /\
  islower + isupper <= 1.

Lemma dict_case_nonzero_before_terminator : forall rows dict_size k i,
  0 <= k < dict_size ->
  (forall r, 0 <= r < dict_size ->
     (1 < Zlength (Znth r rows nil) /\
      Zlength (Znth r rows nil) <= 100) /\
     Znth (Zlength (Znth r rows nil) - 1) (Znth r rows nil) 0 = 0) ->
  0 <= i < Zlength (Znth k rows nil) ->
  Znth i (Znth k rows nil) 0 <> 0 ->
  i < key_content_len (Znth k rows nil).
Proof.
  intros rows dict_size k i Hk Hrows Hi Hnz.
  unfold key_content_len.
  pose proof (Hrows k Hk) as [[_ _] Hlast].
  destruct (Z.eq_dec i (Zlength (Znth k rows nil) - 1)); subst; lia.
Qed.

Lemma dict_case_prefix_zero : forall rows dict_size,
  0 <= dict_size ->
  Zlength rows = dict_size ->
  DictCasePrefixState rows dict_size 0 0 0.
Proof.
  intros rows dict_size Hnonneg Hlen.
  unfold DictCasePrefixState, prefix_keys_valid,
    prefix_has_lower, prefix_has_upper.
  repeat split; try lia.
  - destruct 1 as [r [i [Hr _]]]; lia.
  - destruct 1 as [r [i [Hr _]]]; lia.
Qed.

Lemma dict_case_prefix_to_scan_zero : forall rows dict_size k islower isupper,
  0 <= k < dict_size ->
  (forall r, 0 <= r < dict_size ->
     (1 < Zlength (Znth r rows nil) /\
      Zlength (Znth r rows nil) <= 100) /\
     Znth (Zlength (Znth r rows nil) - 1) (Znth r rows nil) 0 = 0) ->
  DictCasePrefixState rows dict_size k islower isupper ->
  DictCaseScanState rows dict_size k 0 islower isupper.
Proof.
  intros rows dict_size k islower isupper Hk Hrows Hprefix_state.
  unfold DictCasePrefixState in Hprefix_state.
  unfold DictCaseScanState, current_prefix_valid,
    current_prefix_has_lower, current_prefix_has_upper in *.
  destruct Hprefix_state as
    [Hk_bounds [Hlen [Hlower_bound [Hupper_bound
       [Hvalid [Hlower [Hupper Hsum]]]]]]].
  split; [lia |].
  split.
  - pose proof (Hrows k Hk) as [[Hrow_len _] _]; lia.
  - split; [exact Hlen |].
    split; [exact Hlower_bound |].
    split; [exact Hupper_bound |].
    split.
    + split; [exact Hvalid |].
      split.
      * unfold key_nonempty.
        pose proof (Hrows k Hk) as [[Hrow_len _] _].
        lia.
      * intros j Hj; lia.
    + split.
      * split.
        -- intro Hflag; left; apply Hlower; exact Hflag.
        -- intros [Hpref | [j [Hj _]]].
           ++ apply Hlower; exact Hpref.
           ++ lia.
      * split.
        -- split.
           ++ intro Hflag; left; apply Hupper; exact Hflag.
           ++ intros [Hpref | [j [Hj _]]].
              ** apply Hupper; exact Hpref.
              ** lia.
        -- exact Hsum.
Qed.

Lemma dict_case_scan_step_lower : forall rows dict_size k i islower isupper,
  0 <= i < key_content_len (Znth k rows nil) ->
  is_lower_char (Znth i (Znth k rows nil) 0) ->
  isupper <> 1 ->
  DictCaseScanState rows dict_size k i islower isupper ->
  DictCaseScanState rows dict_size k (i + 1) 1 isupper.
Proof.
  intros rows dict_size k i islower isupper Hi_content Hlower_char Hupper_ne Hscan.
  unfold DictCaseScanState in *.
  unfold current_prefix_valid, current_prefix_has_lower,
    current_prefix_has_upper in *.
  destruct Hscan as
    [Hk [Hi_len [Hrows [Hlower_bound [Hupper_bound
       [Hvalid [Hlower_flag [Hupper_flag Hsum]]]]]]]].
  destruct Hvalid as [Hprefix_valid [Hkey_nonempty Halpha_prefix]].
  assert (Hisupper0 : isupper = 0) by lia.
  split; [exact Hk |].
  split; [unfold key_content_len in Hi_content; lia |].
  split; [exact Hrows |].
  split; [lia |].
  split; [exact Hupper_bound |].
  split.
  - split; [exact Hprefix_valid |].
    split; [exact Hkey_nonempty |].
    intros j Hj.
      destruct (Z.eq_dec j i) as [-> | Hneq].
      * unfold is_alpha_char; right; exact Hlower_char.
      * apply Halpha_prefix; lia.
  - split.
    + split.
      * intros _; right; exists i; split; [lia | exact Hlower_char].
      * intros _; reflexivity.
    + split.
      * split.
        -- intro Hflag; exfalso; apply Hupper_ne; exact Hflag.
        -- intros [Hprev | [j [Hj Hupper_char]]].
           ++ apply Hupper_flag; left; exact Hprev.
           ++ destruct (Z.eq_dec j i) as [-> | Hneq].
              ** unfold is_upper_char in Hupper_char.
                 unfold is_lower_char in Hlower_char.
                 lia.
              ** apply Hupper_flag.
                 right; exists j; split; [lia | exact Hupper_char].
      * lia.
Qed.

Lemma dict_case_scan_step_upper : forall rows dict_size k i islower isupper,
  0 <= i < key_content_len (Znth k rows nil) ->
  is_upper_char (Znth i (Znth k rows nil) 0) ->
  islower <> 1 ->
  DictCaseScanState rows dict_size k i islower isupper ->
  DictCaseScanState rows dict_size k (i + 1) islower 1.
Proof.
  intros rows dict_size k i islower isupper Hi_content Hupper_char Hlower_ne Hscan.
  unfold DictCaseScanState in *.
  unfold current_prefix_valid, current_prefix_has_lower,
    current_prefix_has_upper in *.
  destruct Hscan as
    [Hk [Hi_len [Hrows [Hlower_bound [Hupper_bound
       [Hvalid [Hlower_flag [Hupper_flag Hsum]]]]]]]].
  destruct Hvalid as [Hprefix_valid [Hkey_nonempty Halpha_prefix]].
  assert (Hislower0 : islower = 0) by lia.
  split; [exact Hk |].
  split; [unfold key_content_len in Hi_content; lia |].
  split; [exact Hrows |].
  split; [exact Hlower_bound |].
  split; [lia |].
  split.
  - split; [exact Hprefix_valid |].
    split; [exact Hkey_nonempty |].
    intros j Hj.
      destruct (Z.eq_dec j i) as [-> | Hneq].
      * unfold is_alpha_char; left; exact Hupper_char.
      * apply Halpha_prefix; lia.
  - split.
    + split.
      * intro Hflag; exfalso; apply Hlower_ne; exact Hflag.
      * intros [Hprev | [j [Hj Hlower_char]]].
        -- apply Hlower_flag; left; exact Hprev.
        -- destruct (Z.eq_dec j i) as [-> | Hneq].
           ++ unfold is_upper_char in Hupper_char.
              unfold is_lower_char in Hlower_char.
              lia.
           ++ apply Hlower_flag.
              right; exists j; split; [lia | exact Hlower_char].
    + split.
      * split.
        -- intros _; right; exists i; split; [lia | exact Hupper_char].
        -- intros _; reflexivity.
      * lia.
Qed.

Lemma dict_case_scan_finish_prefix : forall rows dict_size k i islower isupper,
  0 <= i < Zlength (Znth k rows nil) ->
  Znth i (Znth k rows nil) 0 = 0 ->
  (forall r, 0 <= r < dict_size ->
     (1 < Zlength (Znth r rows nil) /\
      Zlength (Znth r rows nil) <= 100) /\
     Znth (Zlength (Znth r rows nil) - 1) (Znth r rows nil) 0 = 0) ->
  (forall r i0,
     (0 <= r < dict_size /\ 0 <= i0) /\
     i0 < Zlength (Znth r rows nil) - 1 ->
     Znth i0 (Znth r rows nil) 0 <> 0) ->
  DictCaseScanState rows dict_size k i islower isupper ->
  DictCasePrefixState rows dict_size (k + 1) islower isupper.
Proof.
  intros rows dict_size k i islower isupper Hi Hzero Hrows Hnonzero Hscan.
  unfold DictCaseScanState in Hscan.
  destruct Hscan as
    [Hk [Hi_len [Hlen [Hlower_bound [Hupper_bound
       [Hvalid [Hlower_flag [Hupper_flag Hsum]]]]]]]].
  destruct Hvalid as [Hprefix_valid [Hkey_nonempty Halpha_prefix]].
  assert (Hi_content_eq : i = key_content_len (Znth k rows nil)).
  {
    unfold key_content_len.
    assert (~ i < Zlength (Znth k rows nil) - 1).
    {
      intro Hlt.
      pose proof (Hnonzero k i (conj (conj Hk (proj1 Hi)) Hlt)) as Hnz.
      congruence.
    }
    lia.
  }
  unfold DictCasePrefixState.
  unfold prefix_has_lower, prefix_has_upper,
    current_prefix_has_lower, current_prefix_has_upper in *.
  split; [lia |].
  split; [exact Hlen |].
  split; [exact Hlower_bound |].
  split; [exact Hupper_bound |].
  split.
  - unfold prefix_keys_valid.
    intros r Hr.
    destruct (Z.eq_dec r k) as [-> | Hneq].
    + split.
      * exact Hkey_nonempty.
      * unfold key_alphabetic.
        intros j Hj.
        apply Halpha_prefix.
        rewrite Hi_content_eq.
        exact Hj.
    + apply Hprefix_valid; lia.
  - split.
    + split.
      * intro Hflag.
        apply Hlower_flag in Hflag.
        destruct Hflag as [Hpref | [j [Hj Hlower_char]]].
        -- destruct Hpref as [r [j [Hr [Hj' Hchar]]]].
           exists r, j; split; [lia | split; [exact Hj' | exact Hchar]].
        -- exists k, j; split; [lia | split; [rewrite <- Hi_content_eq; exact Hj | exact Hlower_char]].
      * intros [r [j [Hr [Hj Hchar]]]].
        apply Hlower_flag.
        destruct (Z.eq_dec r k) as [-> | Hneq].
        -- right; exists j; split; [rewrite Hi_content_eq; exact Hj | exact Hchar].
        -- left; exists r, j; split; [lia | split; [exact Hj | exact Hchar]].
    + split.
      * split.
        -- intro Hflag.
           apply Hupper_flag in Hflag.
           destruct Hflag as [Hpref | [j [Hj Hupper_char]]].
           ++ destruct Hpref as [r [j [Hr [Hj' Hchar]]]].
              exists r, j; split; [lia | split; [exact Hj' | exact Hchar]].
           ++ exists k, j; split; [lia | split; [rewrite <- Hi_content_eq; exact Hj | exact Hupper_char]].
        -- intros [r [j [Hr [Hj Hchar]]]].
           apply Hupper_flag.
           destruct (Z.eq_dec r k) as [-> | Hneq].
           ++ right; exists j; split; [rewrite Hi_content_eq; exact Hj | exact Hchar].
           ++ left; exists r, j; split; [lia | split; [exact Hj | exact Hchar]].
      * exact Hsum.
Qed.

Lemma dict_case_prefix_complete_ok : forall rows dict_size k islower isupper,
  k >= dict_size ->
  k <= dict_size ->
  0 < dict_size ->
  Zlength rows = dict_size ->
  DictCasePrefixState rows dict_size k islower isupper ->
  DictCaseOK rows dict_size.
Proof.
  intros rows dict_size k islower isupper Hge Hle Hpos Hlen Hprefix.
  assert (Hk : k = dict_size) by lia.
  subst k.
  unfold DictCasePrefixState in Hprefix.
  destruct Hprefix as
    [_ [Hlen_state [Hlower_bound [Hupper_bound
       [Hvalid [Hlower_flag [Hupper_flag Hsum]]]]]]].
  unfold DictCaseOK.
  split; [exact Hpos |].
  split; [exact Hlen |].
  split; [exact Hvalid |].
  destruct (Z.eq_dec islower 1) as [Hislower | Hislower].
    + right.
      assert (Hno_upper : ~ prefix_has_upper rows dict_size).
      {
        intro Hupper_exists.
        apply Hupper_flag in Hupper_exists.
        lia.
      }
      intros r Hr.
      unfold key_all_lower.
      intros i Hi.
      pose proof (Hvalid r Hr) as [_ Halpha].
      destruct (Halpha i Hi) as [Hupper_char | Hlower_char].
      * exfalso; apply Hno_upper.
        exists r, i; split; [exact Hr | split; [exact Hi | exact Hupper_char]].
      * exact Hlower_char.
    + left.
      assert (Hno_lower : ~ prefix_has_lower rows dict_size).
      {
        intro Hlower_exists.
        apply Hlower_flag in Hlower_exists.
        contradiction.
      }
      intros r Hr.
      unfold key_all_upper.
      intros i Hi.
      pose proof (Hvalid r Hr) as [_ Halpha].
      destruct (Halpha i Hi) as [Hupper_char | Hlower_char].
      * exact Hupper_char.
      * exfalso; apply Hno_lower.
        exists r, i; split; [exact Hr | split; [exact Hi | exact Hlower_char]].
Qed.

Lemma dict_case_scan_lower_conflict_not_ok : forall rows dict_size k i islower isupper,
  0 <= i < key_content_len (Znth k rows nil) ->
  is_lower_char (Znth i (Znth k rows nil) 0) ->
  isupper = 1 ->
  DictCaseScanState rows dict_size k i islower isupper ->
  ~ DictCaseOK rows dict_size.
Proof.
  intros rows dict_size k i islower isupper Hi Hlower_char Hupper_one Hscan Hok.
  unfold DictCaseScanState in Hscan.
  unfold current_prefix_has_upper in Hscan.
  destruct Hscan as
    [Hk [_ [_ [_ [_ [_ [_ [Hupper_flag _]]]]]]]].
  unfold DictCaseOK in Hok.
  destruct Hok as [_ [_ [Hkeys [Hall_upper | Hall_lower]]]].
  - pose proof (Hall_upper k Hk i Hi) as Hupper_char.
    unfold is_upper_char in Hupper_char.
    unfold is_lower_char in Hlower_char.
    lia.
  - pose proof (proj1 Hupper_flag Hupper_one) as Hhas_upper.
    destruct Hhas_upper as [Hprefix | [j [Hj Hupper_char]]].
    + destruct Hprefix as [r [j [Hr [Hj Hupper_char]]]].
      pose proof (Hall_lower r ltac:(lia) j Hj) as Hlower_seen.
      unfold is_upper_char in Hupper_char.
      unfold is_lower_char in Hlower_seen.
      lia.
    + pose proof (Hall_lower k Hk j ltac:(lia)) as Hlower_seen.
      unfold is_upper_char in Hupper_char.
      unfold is_lower_char in Hlower_seen.
      lia.
Qed.

Lemma dict_case_scan_upper_conflict_not_ok : forall rows dict_size k i islower isupper,
  0 <= i < key_content_len (Znth k rows nil) ->
  is_upper_char (Znth i (Znth k rows nil) 0) ->
  islower = 1 ->
  DictCaseScanState rows dict_size k i islower isupper ->
  ~ DictCaseOK rows dict_size.
Proof.
  intros rows dict_size k i islower isupper Hi Hupper_char Hlower_one Hscan Hok.
  unfold DictCaseScanState in Hscan.
  unfold current_prefix_has_lower in Hscan.
  destruct Hscan as
    [Hk [_ [_ [_ [_ [_ [Hlower_flag [_ _]]]]]]]].
  unfold DictCaseOK in Hok.
  destruct Hok as [_ [_ [Hkeys [Hall_upper | Hall_lower]]]].
  - pose proof (proj1 Hlower_flag Hlower_one) as Hhas_lower.
    destruct Hhas_lower as [Hprefix | [j [Hj Hlower_char]]].
    + destruct Hprefix as [r [j [Hr [Hj Hlower_char]]]].
      pose proof (Hall_upper r ltac:(lia) j Hj) as Hupper_seen.
      unfold is_upper_char in Hupper_seen.
      unfold is_lower_char in Hlower_char.
      lia.
    + pose proof (Hall_upper k Hk j ltac:(lia)) as Hupper_seen.
      unfold is_upper_char in Hupper_seen.
      unfold is_lower_char in Hlower_char.
      lia.
  - pose proof (Hall_lower k Hk i Hi) as Hlower_seen.
    unfold is_upper_char in Hupper_char.
    unfold is_lower_char in Hlower_seen.
    lia.
Qed.

Lemma dict_case_bad_char_not_ok : forall rows dict_size k i islower isupper,
  0 <= i < key_content_len (Znth k rows nil) ->
  ~ is_alpha_char (Znth i (Znth k rows nil) 0) ->
  DictCaseScanState rows dict_size k i islower isupper ->
  ~ DictCaseOK rows dict_size.
Proof.
  intros rows dict_size k i islower isupper Hi Hnot_alpha Hscan Hok.
  unfold DictCaseScanState in Hscan.
  destruct Hscan as [Hk _].
  unfold DictCaseOK in Hok.
  destruct Hok as [_ [_ [Hkeys _]]].
  pose proof (Hkeys k Hk) as [_ Halpha].
  exact (Hnot_alpha (Halpha i Hi)).
Qed.

Lemma dict_case_zero_size_not_ok : forall rows,
  ~ DictCaseOK rows 0.
Proof.
  intros rows Hok.
  unfold DictCaseOK in Hok.
  lia.
Qed.
