Require Import TraceBasic TraceLogic.
Require Import SetsClass.SetsClass.
Require Import Coq.Lists.List.
From MonadLib.StateRelMonad Require Import StateRelBasic StateRelHoare.
Require Import Coq.Logic.Classical_Prop.
Require Import Coq.micromega.Lia.
Require Import Coq.Arith.Arith.
Import MonadNotation.
Local Open Scope list.
Local Open Scope monad.
Local Open Scope sets.

(** A canonical Tag Type for recursive funtions *)
Inductive Tag {X: Type}: Type :=
| Entry: X -> Tag
| Exit: X -> Tag.

Section TraceLoop.
(** A: argument, Σ: state *) 
Context {A Σ: Type}.

Notation programT := (programT Σ (@Tag A)) (only parsing).
Notation TR := (TR (@Tag A) Σ) (only parsing).

(** f: the lifted function body *)

Definition forset_f'
    (body: A -> programT unit)
    (W: (A -> Prop) -> programT unit) (universe: A -> Prop):
    programT unit :=
    choice (a <- get (fun _ a => a ∈ universe);;
            track (Entry a);;
            body a;;
            track (Exit a);;
            W (fun x => x ∈ universe /\ x <> a))
            (assume!! (universe == ∅) ;;
            ret tt).

Definition forset'
    (universe: A -> Prop)
    (body: A -> programT unit) : programT unit :=
    Lfix (forset_f' body) universe.

End TraceLoop.

Section SnapshotLoop.
Context {Σ: Type} (default: Σ).
Local Open Scope trace_scope.

  (* State-trace specialization: record only states. *)
  Definition snapshot_loop (cond: Σ -> Prop) (body: program Σ unit) : programTS Σ unit :=
  trackS;;
  whileP (fun '(s, _) => cond s)
    (liftG body;; trackS).

Definition snapshot_inv (cond P0: Σ -> Prop) (s: Σ) (tr: list Σ) : Prop :=
  tr <> nil /\
  P0 (hd default tr) /\
  last tr default = s /\
  forall i, i < length tr -> cond (nth i tr default) \/ i = length tr - 1.

Theorem snapshot_loop_trace_shape
  (cond P0: Σ -> Prop) (body: program Σ unit):
    Hoare
      (fun '(s1, tr) => P0 s1 /\ tr = nil)
      (snapshot_loop cond body)
      (fun _ '(s2, tr) =>
          P0 (hd default tr) /\
          last tr default = s2 /\
          ~ cond s2 /\
          forall i, i >= 0 -> i < length tr - 1 -> cond (nth i tr default)).
Proof.
  unfold snapshot_loop.
  eapply Hoare_bind with
    (Q := fun _ '(s, tr) => snapshot_inv cond P0 s tr).
  - eapply Hoare_conseq_post with
      (Q2 := fun _ '(s, tr) => exists tr', tr = tr' ++ s :: nil /\ P0 s /\ tr' = nil).
    2: apply (@Hoare_trackS Σ (fun '(s, tr) => P0 s /\ tr = nil)).
    intros _ (s, tr) H.
    destruct H as [tr' [Htr' [HP0 Hnil]]].
    subst tr'.
    simpl in Htr'.
    subst tr.
    unfold snapshot_inv.
    split.
    + discriminate.
    + split.
      * simpl. exact HP0.
      * split.
        -- simpl. reflexivity.
        -- intros i Hi.
           right.
            simpl in Hi |- *.
            destruct i; [reflexivity | lia].
  - intros _.
    eapply Hoare_conseq_post with
      (Q2 := fun _ st =>
        (let '(s, tr) := st in snapshot_inv cond P0 s tr) /\
        ~ (let '(s, _) := st in cond s)).
    2: {
      eapply Hoare_whileP with
        (P := fun '(s, tr) => snapshot_inv cond P0 s tr)
        (cond := fun '(s, _) => cond s)
        (body := liftG body;; trackS).
      eapply Hoare_bind with
        (Q := fun _ '(s', tr0) => exists sold, cond sold /\ snapshot_inv cond P0 sold tr0).
      + eapply Hoare_liftG'.
        intros tr.
        unfold Hoare; sets_unfold.
        intros s1 a s2 Hpre _.
        destruct Hpre as [Hcond Hinv].
        exists s1.
        split; auto.
      + intros _.
        eapply Hoare_conseq_post with
          (Q2 := fun _ '(s', tr1) =>
             exists tr0,
               tr1 = tr0 ++ s' :: nil /\
               (exists sold, cond sold /\ snapshot_inv cond P0 sold tr0)).
             2: apply (@Hoare_trackS Σ (fun '(s', tr0) => exists sold, cond sold /\ snapshot_inv cond P0 sold tr0)).
        intros _ (s', tr1) H.
        destruct H as [tr0 [Htr1 Hex]].
        destruct Hex as [sold [Hcond_sold HInv0]].
        subst tr1.
        unfold snapshot_inv in *.
        destruct HInv0 as [Hnn [HP0_hd [Hlast Hall]]].
        repeat split.
        * destruct tr0; simpl; discriminate.
        * destruct tr0 as [|x xs].
          { exfalso; apply Hnn; reflexivity. }
          simpl in *.
          exact HP0_hd.
        * assert (Hlast_app_single: forall (l: list Σ) d x0, last (l ++ x0 :: nil) d = x0).
          {
            intros l d x0.
            revert d.
            induction l as [|a l IH]; intros d; simpl.
            - reflexivity.
            - destruct (l ++ x0 :: nil) as [|b tl] eqn:Hl.
              + apply app_eq_nil in Hl.
                destruct Hl as [_ Hnil].
                discriminate.
              + apply IH.
          }
          exact (Hlast_app_single tr0 default s').
        * intros i Hi.
          assert (Hnth_app_left: forall (l1 l2: list Σ) i d,
                i < length l1 -> nth i (l1 ++ l2) d = nth i l1 d).
          {
            intros l1.
            induction l1 as [|a l1 IH]; intros l2 j d Hi0.
            - simpl in Hi0. lia.
            - destruct j as [|j].
              + reflexivity.
              + simpl.
                apply IH.
                simpl in Hi0.
                lia.
          }
          assert (Hnth_last: forall (l: list Σ) dn dl,
                l <> nil -> nth (length l - 1) l dn = last l dl).
          {
            intros l.
            induction l as [|a l IH]; intros dn dl Hnn0.
            - contradiction.
            - destruct l as [|b l'].
              + simpl. reflexivity.
              + destruct l' as [|c l''].
                * simpl. reflexivity.
                * simpl.
                  apply IH.
                  discriminate.
          }
          destruct (classic (i < length tr0)) as [Hlt | Hnlt].
          { specialize (Hall i Hlt).
            destruct Hall as [Hcond_i | Hi_last].
            - left.
              rewrite (Hnth_app_left tr0 (s' :: nil) i default); [exact Hcond_i | lia].
            - left.
              rewrite (Hnth_app_left tr0 (s' :: nil) i default); [|lia].
              subst i.
              rewrite (Hnth_last tr0 default default Hnn).
              rewrite Hlast.
              exact Hcond_sold.
          }
          { right.
            rewrite length_app in *.
            simpl in *.
            lia.
          }
    }
    intros _ (s2, tr) Hpost.
    destruct Hpost as [HInv Hncond].
    unfold snapshot_inv in HInv.
    destruct HInv as [_ [HP0_hd [Hlast Hall]]].
    repeat split; auto.
    intros i _ Hi.
    assert (Hi_len: i < length tr) by lia.
    specialize (Hall i Hi_len).
    destruct Hall as [Hc | Hi_last]; auto.
    lia.
  Qed.

(** Abstract binary relation, `L` is the type of logical variables while `St` is the type of program states. *)
Definition AbsRel {L St: Type} 
    (P: nat -> L -> St -> Prop)
    (Q: nat -> L -> St -> Prop)
	(n: nat) (s1 s2: St) : Prop :=
  forall l, P n l s1 -> Q n l s2.

Lemma snapshot_loop_AbsRel {L: Type}
  (cond: Σ -> Prop) 
  (P Q: nat -> L -> Σ -> Prop) 
  (body: program Σ unit)
  (h: forall l, Hoare (P 1 l) body (fun _ => Q 1 l)):
    Hoare
      (fun '(_, tr) => tr = nil)
      (snapshot_loop cond body)
      (fun _ '(_, tr) =>
          forall i, i < length tr - 1 -> 
          AbsRel P Q 1 (nth i tr default) (nth (S i) tr default)).
Proof.
  unfold snapshot_loop.
  eapply Hoare_bind with
    (Q := fun _ '(s, tr) => 
      tr <> nil /\
      last tr default = s /\
      forall i, i >= 0 -> i < length tr - 1 -> 
      AbsRel P Q 1 (nth i tr default) (nth (S i) tr default)).
  - eapply Hoare_conseq_post.
    2: apply (@Hoare_trackS Σ (fun '(_, tr) => tr = nil)).
    intros _ (s, tr) [tr' [Htr' Hnil]].
    subst tr'. simpl in Htr'. subst tr.
    split; [discriminate | ].
    split; [reflexivity | ].
    intros i Hi0 Hi. simpl in *; lia.
  - intros _.
    eapply Hoare_conseq_post.
    2: {
      eapply Hoare_whileP with
        (P := fun '(s, tr) => 
          tr <> nil /\
          last tr default = s /\
          forall i, i >= 0 -> i < length tr - 1 -> 
          AbsRel P Q 1 (nth i tr default) (nth (S i) tr default))
        (cond := fun '(s, _) => cond s)
        (body := liftG body;; trackS).
      + eapply Hoare_bind with
          (Q := fun _ '(s', tr0) => exists sold, AbsRel P Q 1 sold s' /\
            tr0 <> nil /\ last tr0 default = sold /\
            forall i, i >= 0 -> i < length tr0 - 1 -> 
            AbsRel P Q 1 (nth i tr0 default) (nth (S i) tr0 default)).
        * eapply Hoare_liftG'.
          intros tr. unfold Hoare; sets_unfold.
          intros s1 a s2 Hpre Heval.
          destruct Hpre as [Hcond [Hnn [Hlast Hforall]]].
          exists s1. split; [ | repeat split; auto ].
          intros l Hl. specialize (h l s1 a s2 Hl Heval). exact h.
        * intros _.
          eapply Hoare_conseq_post.
          2: apply (@Hoare_trackS Σ).
          intros _ (s''', tr2) [tr0' [Htr2 [sold [Hrel [Hnn [Hlast Hforall]]]]]].
          subst tr2.
          repeat split.
          -- destruct tr0'; simpl; discriminate.
          -- apply last_last.
          -- intros i Hi0 Hi.
             rewrite length_app in Hi; simpl in Hi.
             destruct (Nat.lt_ge_cases i (length tr0' - 1)) as [Hlt | Hnle].
             ++ rewrite (app_nth1 _ (s''' :: nil) default); [|lia].
                rewrite (app_nth1 _ (s''' :: nil) default); [|lia].
                apply Hforall; auto.
             ++ assert (Heq: i = length tr0' - 1).
                { clear - Hi Hnle Hnn. destruct tr0'; [contradiction | simpl in *; lia]. }
                subst i.
                rewrite (app_nth1 _ (s''' :: nil) default); [|lia].
             replace (S (length tr0' - 1)) with (length tr0') by lia.
             rewrite (app_nth2 _ _ default); [|lia].
             replace (length tr0' - length tr0') with 0 by lia.
             simpl.
              assert (H_nth_last_gen: forall (l: list Σ) dn dl, l <> nil -> nth (length l - 1) l dn = last l dl).
              { intros lst. induction lst as [| a l IH].
                - intros; contradiction.
                - destruct l as [| b l'].
                  + intros; reflexivity.
                  + intros dn' dl' Hnn_l.
                    simpl in *.
                    assert (Heq: forall n, n - 0 = n) by (intros; lia).
                    rewrite Heq in IH.
                    apply IH. discriminate.
              }
              rewrite (H_nth_last_gen tr0' default default); [|exact Hnn].
              rewrite Hlast. exact Hrel.
    }
    intros _ (s2, tr) [HInv Hncond].
    destruct HInv as [Hnn [Hlast Hforall]].
    intros i Hi0 Hi.
    apply Hforall; lia.
Qed.

Theorem snapshot_loop_AbsRel_trace {L: Type}
  (cond: Σ -> Prop) 
  (P Q: nat -> L -> Σ -> Prop) 
  (body: program Σ unit)
  (h: forall l, Hoare (P 1 l) body (fun _ => Q 1 l))
  (hassoc: forall s1 s2 s3 m n, AbsRel P Q m s1 s2 -> AbsRel P Q n s2 s3 -> AbsRel P Q (m+n) s1 s3):
    Hoare
      (fun '(_, tr) => tr = nil)
      (snapshot_loop cond body)
      (fun _ '(_, tr) =>
          forall i j, i < j -> j < length tr -> 
          AbsRel P Q (j-i) (nth i tr default) (nth j tr default)).
Proof.
  eapply Hoare_conseq_post.
  2: { apply (snapshot_loop_AbsRel cond P Q body). exact h. }
  intros _ (st, tr) Hforall i j Hij Hj.
  remember (j - i) as n.
  revert i j Hij Hj Heqn.
  induction n as [| n IH].
  + intros i j Hij Hj Heqn.
    lia.
  + intros i j Hij Hj Heqn.
    destruct n as [| n'].
    * assert (Heqj: j = S i) by lia.
      subst j.
      replace (S i - i) with 1 by lia.
      apply Hforall. lia.
    * assert (Hij': i < j - 1) by lia.
      assert (Hj': j - 1 < length tr - 1) by lia.
      specialize (IH i (j - 1) ltac:(lia) ltac:(lia) ltac:(lia)).
      assert (Htemp: AbsRel P Q (S n' + 1) (nth i tr default) (nth j tr default)).
      { apply (hassoc _ (nth (j - 1) tr default) _ (S n') 1); [exact IH | ].
        specialize (Hforall (j - 1) Hj').
        replace (S (j - 1)) with j in Hforall by lia.
        exact Hforall.
      }
      replace (j - i) with (S n' + 1) by lia.
      replace (S (S n')) with (S n' + 1) by lia.
      exact Htemp.
Qed.

End SnapshotLoop.
