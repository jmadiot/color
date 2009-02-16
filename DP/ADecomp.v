(**
CoLoR, a Coq library on rewriting and termination.
See the COPYRIGHTS and LICENSE files.

- Frederic Blanqui, 2008-05-19

decomposition of an over DP graph
*)

Set Implicit Arguments.

Require Import AGraph.
Require Import Union.
Require Import ATrs.
Require Import ListUtil.
Require Import RelUtil.
Require Import LogicUtil.
Require Import SN.
Require Import ListForall.
Require Import BoolUtil.

Section S.

Variable Sig : Signature.

Notation term := (term Sig). Notation terms := (vector term).
Notation rule := (rule Sig). Notation rules := (list rule).

(***********************************************************************)
(** we consider the relation (hd_red_Mod S R) *)

Variable S : relation term.
Variable D : rules.

(***********************************************************************)
(** a decomposition of a list of rules is a list of list of rules *)

Notation decomp := (list rules).

(***********************************************************************)
(** we assume given a decidable graph on rules *)

Variable approx : rule -> rule -> bool.

Definition Graph x y := approx x y = true.

(***********************************************************************)
(** we assume that Graph is an over graph of (hd_rules_graph S D) *)

Variable approx_correct : hd_rules_graph S D << Graph.

(***********************************************************************)
(** a decomposition cs = [c1; ..; cn] is valid wrt D if for all i, for
all rule b in ci, for all j > i, and for all rule c in cj, there is no
edge from b to c *)

Fixpoint valid_decomp (cs : decomp) : bool :=
  match cs with
    | nil => true
    | ci :: cs' => valid_decomp cs' &&
      forallb (fun b =>
        forallb (fun cj =>
          forallb (fun c => negb (approx b c)) cj)
        cs')
      ci
  end.

(***********************************************************************)
(** relation corresponding to a decomposition *)

Fixpoint Union (cs : decomp) : relation term :=
  match cs with
    | nil => @empty_rel term
    | ci :: cs' => hd_red_Mod S ci U Union cs'
  end.

Lemma decomp_incl :
  forall cs (hyp1 : incl D (flat cs)), hd_red_Mod S D << Union cs.

Proof.
intros. intros x y h. redtac. ded (hyp1 _ H0). gen H3.
elim cs; simpl; intros. contradiction. destruct (in_app_or H4).
left. exists t. intuition. subst. apply hd_red_rule. hyp.
right. apply H3. hyp.
Qed.

Lemma In_Union_elim : forall cs x y, Union cs x y ->
  exists ci, In ci cs /\ hd_red_Mod S ci x y.

Proof.
induction cs; simpl; intros. contradiction. destruct H.
exists a. intuition. destruct (IHcs _ _ H). exists x0. intuition.
Qed.

Implicit Arguments In_Union_elim [cs x y].

(***********************************************************************)
(** main theorem *)

Lemma WF_hd_red_Mod_decomp :
  forall (hypD : rules_preserv_vars D)
    (cs : decomp)
    (hyp1 : incl (flat cs) D)
    (hyp2 : valid_decomp cs = true)
    (hyp3 : lforall (fun ci => WF (hd_red_Mod S ci)) cs),
    WF (Union cs).

Proof.
induction cs; simpl; intros. apply WF_empty_rel.
ded (andb_elim hyp2). clear hyp2. destruct H. destruct hyp3. apply WF_union.
2: hyp. Focus 2. apply IHcs; try hyp. apply incl_appl_incl with a. hyp.
clear IHcs H H1 H2. intros t v h. destruct h. destruct H. redtac.
rewrite forallb_forall in H0. ded (H0 _ H2). clear H0.
destruct (In_Union_elim H1). destruct H0. redtac.
rewrite forallb_forall in H5. ded (H5 _ H0). clear H5.
rewrite forallb_forall in H10. ded (H10 _ H7). clear H10.
rewrite negb_lr in H5. simpl in H5.
absurd (Graph (mkRule l r) (mkRule l0 r0)). unfold Graph. rewrite H5. discr.
apply approx_correct. apply hd_red_Mod_rule2_hd_rules_graph
  with (t := t) (u := x) (v := v); unfold hd_red_Mod_rule; subst; intuition.
exists s. intuition. eapply incl_flat_In. apply H7. apply H0.
apply incl_appl_incl with a. hyp. exists s0. intuition.
Qed.

Lemma WF_decomp :
  forall (hypD : rules_preserv_vars D)
    (cs : decomp)
    (hyp1 : incl D (flat cs))
    (hyp2 : incl (flat cs) D)
    (hyp3 : valid_decomp cs = true)
    (hyp4 : lforall (fun ci => WF (hd_red_Mod S ci)) cs),
    WF (hd_red_Mod S D).

Proof.
intros. apply WF_incl with (Union cs). apply decomp_incl. hyp.
apply WF_hd_red_Mod_decomp; hyp.
Qed.

(***********************************************************************)
(** improvement *)

Definition co_scc ci :=
  forallb (fun r => forallb (fun s => negb (approx r s)) ci) ci.

Lemma WF_co_scc : forall (hypD : rules_preserv_vars D) ci,
  incl ci D -> co_scc ci = true -> WF (hd_red_Mod S ci).

Proof.
unfold WF. intros. apply SN_intro. intros. apply SN_intro. intros.
assert (h : rules_preserv_vars ci). eapply rules_preserv_vars_incl. apply H.
hyp. destruct (hd_red_Mod2_hd_rules_graph h H1 H2). destruct H3.
assert (hd_rules_graph S D x0 x1). eapply hd_rules_graph_incl. apply H. hyp.
unfold hd_rules_graph in H3. intuition. clear H7.
ded (approx_correct H4). unfold Graph in H6.
unfold co_scc in H0. rewrite forallb_forall in H0. ded (H0 _ H5). clear H0.
rewrite forallb_forall in H7. ded (H7 _ H3). rewrite H6 in H0. discr.
Qed.

Lemma WF_decomp_co_scc :
  forall (hypD : rules_preserv_vars D)
    (cs : decomp)
    (hyp4 : incl D (flat cs))
    (hyp1 : incl (flat cs) D)
    (hyp2 : valid_decomp cs = true)
    (hyp3 : lforall (fun ci => co_scc ci = true \/ WF (hd_red_Mod S ci)) cs),
    WF (hd_red_Mod S D).

Proof.
intros. apply WF_decomp with cs; try hyp. clear hyp4 hyp2 approx_correct.
rewrite lforall_eq. intros. rewrite lforall_eq in hyp3. ded (hyp3 _ H).
destruct H0. apply WF_co_scc; try hyp. apply incl_tran with (flat cs).
apply In_incl_flat. hyp. hyp. hyp.
Qed.

End S.

(***********************************************************************)
(** tactics *)

Ltac incl_flat := unfold incl, dp; simpl; intuition.

Ltac graph_decomp f d :=
  apply WF_decomp_co_scc with (approx := f) (cs := d);
  [idtac
    | rules_preserv_vars
    | incl_flat
    | incl_flat
    | vm_compute; refl
    | unfold lforall; repeat split ].
