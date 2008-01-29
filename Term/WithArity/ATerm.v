(**
CoLoR, a Coq library on rewriting and termination.
See the COPYRIGHTS and LICENSE files.

- Sebastien Hinderer, 2004-02-09
- Frederic Blanqui, 2005-02-17

algebraic terms with fixed arity
*)

(* $Id: ATerm.v,v 1.15 2008-01-29 18:07:58 blanqui Exp $ *)

Set Implicit Arguments.

Require Export ASignature.
Require Export ListUtil.
Require Export LogicUtil.

Notation variables := (list variable).

Section S.

Variable Sig : Signature.

(***********************************************************************)
(** terms *)

Require Export VecUtil.

Inductive term : Set :=
  | Var : variable -> term
  | Fun : forall f : Sig, vector term (arity f) -> term.

(* we delete the induction principle generated by coq since it is not good
because the argument of Fun is a vector *)

Reset term_rect.

Notation terms := (vector term).

Notation "'args' f" := (terms (arity f)) (at level 70).

(***********************************************************************)
(** induction principles *)

Section term_rect.

Variables
  (P : term -> Type)
  (Q : forall n, terms n -> Type).

Hypotheses
  (H1 : forall x, P (Var x))
  (H2 : forall f (v : args f), Q v -> P (Fun f v))
  (H3 : Q Vnil)
  (H4 : forall t n (v : terms n), P t -> Q v -> Q (Vcons t v)).

Fixpoint term_rect t : P t :=
  match t as t return P t with
    | Var x => H1 x
    | Fun f v =>
      let fix terms_rect n (v : terms n) {struct v} : Q v :=
        match v as v return Q v with
          | Vnil => H3
          | Vcons t' n' v' => H4 (term_rect t') (terms_rect n' v')
        end
	in H2 f (terms_rect (arity f) v)
  end.

End term_rect.

Definition term_ind (P : term -> Prop) (Q : forall n, terms n -> Prop) :=
  term_rect P Q.

Definition term_rec (P : term -> Set) (Q : forall n, terms n -> Set) :=
  term_rect P Q.

Lemma term_ind_forall : forall (P : term -> Prop)
  (H1 : forall v, P (Var v))
  (H2 : forall f (v : args f), Vforall P v -> P (Fun f v)),
  forall t, P t.

Proof.
intros. apply term_ind with (Q := Vforall P). exact H1. exact H2.
exact I. intros. simpl. split; assumption.
Qed.

Lemma term_ind_forall2 : forall (P : term -> Prop)
  (H1 : forall v, P (Var v))
  (H2 : forall f (v : args f), (forall t, Vin t v -> P t) -> P (Fun f v)),
  forall t, P t.

Proof.
intros. apply term_ind
with (Q := fun n (ts : terms n) => forall t, Vin t ts -> P t).
exact H1. exact H2. contradiction. simpl. intuition. subst t1. exact H.
Qed.

(***********************************************************************)
(** equality *)

Lemma var_eq : forall x x', x = x' -> Var x = Var x'.

Proof.
intros. rewrite H. refl.
Qed.

Lemma args_eq : forall f (v v' : args f), v = v' -> Fun f v = Fun f v'.

Proof.
intros. rewrite H. refl.
Qed.

Lemma fun_eq : forall f v w, Fun f v = Fun f w -> v = w.

Proof.
intros. inversion H.
apply (inj_pairT2 (U := symbol Sig) (@eq_symbol_dec _) H1).
Qed.

(***********************************************************************)
(** decidability of equality *)

Section beq.

Variable beq_var : variable -> variable -> bool.
Variable beq_var_ok : forall x y, beq_var x y = true <-> x = y.

Variable beq_symb : Sig -> Sig -> bool.
Variable beq_symb_ok : forall f g, beq_symb f g = true <-> f = g.

Fixpoint beq (t u : term) {struct t} :=
  match t, u with
    | Var x, Var y => beq_var x y
    | Fun f ts, Fun g us =>
      let fix beq_terms n (ts : terms n) p (us : terms p) {struct ts} :=
        match ts, us with
          | Vnil, Vnil => true
          | Vcons t _ ts', Vcons u _ us' => beq t u && beq_terms _ ts' _ us'
          | _, _ => false
        end
        in beq_symb f g && beq_terms _ ts _ us
    | _, _ => false
  end.

Lemma beq_terms : forall n (ts : terms n) p (us : terms p),
  (fix beq_terms n (ts : terms n) p (us : terms p) {struct ts} :=
    match ts, us with
      | Vnil, Vnil => true
      | Vcons t _ ts', Vcons u _ us' => beq t u && beq_terms _ ts' _ us'
      | _, _ => false
    end) _ ts _ us = beq_vec beq ts us.

Proof.
induction ts; destruct us; refl.
Qed.

Lemma beq_fun : forall f ts g us,
  beq (Fun f ts) (Fun g us) = beq_symb f g && beq_vec beq ts us.

Proof.
intros. rewrite <- beq_terms. refl.
Qed.

Lemma beq_ok : forall t u, beq t u = true <-> t = u.

Proof.
intro t. pattern t. apply term_ind_forall2; destruct u.
simpl. rewrite beq_var_ok. intuition. inversion H. refl.
intuition; discriminate. intuition; discriminate.
rewrite beq_fun. split; intro. destruct (andb_elim H0).
rewrite beq_symb_ok in H1. subst f0. apply args_eq.
deduce (beq_vec_ok_in1 H H2). rewrite <- H1. rewrite Vcast_refl_eq. refl.
inversion H0 as [[h0 h1]]. clear h1. subst f0. simpl.
apply andb_intro. apply (beq_refl beq_symb_ok).
apply beq_vec_ok_in2. exact H. refl.
Qed.

End beq.

Implicit Arguments beq_ok [beq_var beq_symb].

Definition beq_symb := beq_dec (@eq_symbol_dec Sig).

Lemma beq_symb_ok : forall f g, beq_symb f g = true <-> f = g.

Proof.
exact (beq_dec_ok (@eq_symbol_dec Sig)).
Qed.

Definition beq_term := beq beq_nat beq_symb.

Lemma beq_term_ok : forall t u, beq_term t u = true <-> t = u.

Proof.
exact (beq_ok beq_nat_ok beq_symb_ok).
Qed.

(* FIXME: Definition eq_term_dec := dec_beq beq_term_ok.*)

(* old version using Eqdep's axiom: *)

Lemma eq_term_dec : forall t u : term, {t=u}+{~t=u}.

Proof.
intro. pattern t. apply term_rec with
  (Q := fun n (ts : terms n) => forall u, {ts=u}+{~ts=u}); clear t.
(* var *)
intros. destruct u. case (eq_nat_dec x n); intro. subst n. auto.
right. unfold not. intro. injection H. auto.
right. unfold not. intro. discriminate.
(* fun *)
intros f ts H u. destruct u. right. unfold not. intro. discriminate.
case (eq_symbol_dec f f0); intro. subst f0. case (H v); intro. subst ts. auto.
right. intro. injection H0. intro. assert (ts=v).
Require Import Eqdep. apply (inj_pair2 Sig (fun f => args f)). assumption. auto.
right. unfold not. intro. injection H0. intros. auto.
(* nil *)
intro. VOtac. auto.
(* cons *)
intros. VSntac u. case (H (Vhead u)); intro. rewrite e.
case (H0 (Vtail u)); intro. rewrite e0. auto.
right. unfold not. intro. injection H2. intro. assert (v = Vtail u).
apply (inj_pair2 nat (fun n => terms n)). assumption. auto.
right. unfold not. intro. injection H2. intros. auto.
Defined.

(***********************************************************************)
(** maximal variable index in a term *)

Require Export VecMax.

Fixpoint maxvar (t : term) : nat :=
  match t with
    | Var x => x
    | Fun f v =>
      let fix maxvars (n : nat) (v : terms n) {struct v} : nats n :=
        match v in vector _ n return nats n with
          | Vnil => Vnil
          | Vcons t' n' v' => Vcons (maxvar t') (maxvars n' v')
        end
      in Vmax (maxvars (arity f) v)
  end.

Lemma maxvar_fun : forall f ts, maxvar (Fun f ts) = Vmax (Vmap maxvar ts).

Proof.
intros. simpl. apply (f_equal (@Vmax (arity f))).
induction ts. auto. rewrite IHts. auto.
Qed.

Lemma maxvar_var : forall k x, maxvar (Var x) <= k -> x <= k.

Proof.
intros. simpl. intuition.
Qed.

Definition maxvar_le k t := maxvar t <= k.

Lemma maxvar_le_fun : forall m f ts,
  maxvar (Fun f ts) <= m -> Vforall (maxvar_le m) ts.

Proof.
intros until ts. rewrite maxvar_fun. intro. generalize (Vmax_forall H).
clear H. intro H. generalize (Vforall_map_elim H). intuition.
Qed.

Lemma maxvar_le_arg : forall f ts m t,
  maxvar (Fun f ts) <= m -> Vin t ts -> maxvar t <= m.

Proof.
intros. assert (Vforall (maxvar_le m) ts). apply maxvar_le_fun. assumption.
change (maxvar_le m t). eapply Vforall_in with (n := arity f). apply H1.
assumption.
Qed.

(***********************************************************************)
(** list of variables in a term:
a variable occurs in the list as much as it has occurrences in t *)

Fixpoint vars (t : term) : variables :=
  match t with
    | Var x => x :: nil
    | Fun f v =>
      let fix vars_vec n (ts : terms n) {struct ts} : variables :=
        match ts with
          | Vnil => nil
          | Vcons t' n' ts' => vars t' ++ vars_vec n' ts'
        end
      in vars_vec (arity f) v
  end.

Fixpoint vars_vec n (ts : terms n) {struct ts} : variables :=
  match ts with
    | Vnil => nil
    | Vcons t' _ ts' => vars t' ++ vars_vec ts'
  end.

Lemma vars_fun : forall f (ts : args f), vars (Fun f ts) = vars_vec ts.

Proof.
auto.
Qed.

Lemma vars_vec_cast : forall n (ts : terms n) m (h : n=m),
  vars_vec (Vcast ts h) = vars_vec ts.

Proof.
induction ts; intros; destruct m; simpl; try (refl || discriminate).
apply (f_equal (fun l => vars a ++ l)). apply IHts.
Qed.

Lemma vars_vec_app : forall n1 (ts1 : terms n1) n2 (ts2 : terms n2),
  vars_vec (Vapp ts1 ts2) = vars_vec ts1 ++ vars_vec ts2.

Proof.
induction ts1; intros; simpl. refl. rewrite app_ass.
apply (f_equal (fun l => vars a ++ l)). apply IHts1.
Qed.

Lemma vars_vec_cons : forall t n (ts : terms n),
  vars_vec (Vcons t ts) = vars t ++ vars_vec ts.

Proof.
intros. refl.
Qed.

Lemma in_vars_vec_elim : forall x n (ts : terms n),
  In x (vars_vec ts) -> exists t, Vin t ts /\ In x (vars t).

Proof.
induction ts; simpl; intros. contradiction. generalize (in_app_or H). intro.
destruct H0. exists a. intuition. generalize (IHts H0). intro.
destruct H1 as [t].
exists t. intuition.
Qed.

Lemma in_vars_vec_intro : forall x t n (ts : terms n),
  In x (vars t) -> Vin t ts -> In x (vars_vec ts).

Proof.
intros. deduce (Vin_elim H0). do 5 destruct H1. subst ts.
rewrite vars_vec_cast. rewrite vars_vec_app. simpl.
apply in_appr. apply in_appl. exact H.
Qed.

Require Export ListUtil.

Lemma vars_vec_in : forall x t n (ts : terms n),
  In x (vars t) -> Vin t ts -> In x (vars_vec ts).

Proof.
induction ts; simpl; intros. contradiction. destruct H0. subst t.
apply in_appl. assumption. apply in_appr. apply IHts; assumption.
Qed.

Lemma vars_max : forall x t, In x (vars t) -> x <= maxvar t.

Proof.
intro.
set (Q := fun n (ts : terms n) =>
  In x (vars_vec ts) -> x <= Vmax (Vmap maxvar ts)).
intro. pattern t. apply term_ind with (Q := Q); clear t; unfold Q; simpl; intros.
intuition. apply H. assumption. contradiction. generalize (in_app_or H1).
intro. destruct H2. apply elim_max_l. apply H. assumption.
apply elim_max_r. apply H0. assumption.
Qed.

Lemma maxvar_in : forall x t n (v : terms n),
  x <= maxvar t -> Vin t v -> x <= Vmax (Vmap maxvar v).

Proof.
induction v; simpl; intros. contradiction. destruct H0. subst t.
apply elim_max_l. assumption. apply elim_max_r. apply IHv; assumption.
Qed.

Require Export ListMax.

Lemma maxvar_lmax : forall t, maxvar t = lmax (vars t).

Proof.
intro t. pattern t.
set (Q := fun n (ts : terms n) => Vmax (Vmap maxvar ts) = lmax (vars_vec ts)).
apply term_ind with (Q := Q); clear t.
intro. simpl. apply (sym_equal (max_l (le_O_n x))).
intros f ts H. rewrite maxvar_fun. rewrite vars_fun. assumption.
unfold Q. auto.
intros t n ts H1 H2. unfold Q. simpl. rewrite lmax_app.
unfold Q in H2. rewrite H1. rewrite H2. refl.
Qed.

(***********************************************************************)
(** boolean function testing if a variable occurs in a term *)

Section var_occurs_in.

Variable x : variable.

Fixpoint var_occurs_in t :=
  match t with
    | Var y => beq_nat x y
    | Fun f ts =>
      let fix var_occurs_in_terms n (ts : terms n) :=
        match ts with
          | Vnil => false
          | Vcons t _ ts' => var_occurs_in t || var_occurs_in_terms _ ts'
        end
        in var_occurs_in_terms _ ts
  end.

End var_occurs_in.

(***********************************************************************)
(** number of symbol occurrences in a term *)

Fixpoint nb_symb_occs t :=
  match t with
    | Var x => 0
    | Fun f ts =>
      let fix nb_symb_occs_terms n (ts : terms n) {struct ts} :=
        match ts with
          | Vnil => 0
          | Vcons u p us => nb_symb_occs u + nb_symb_occs_terms p us
        end
        in nb_symb_occs_terms _ ts
  end.

End S.

(***********************************************************************)
(** implicit arguments *)

Implicit Arguments Var [Sig].
Implicit Arguments maxvar_var [Sig k x].
Implicit Arguments maxvar_le_fun [Sig m f ts].
Implicit Arguments maxvar_le_arg [Sig f ts m t].
Implicit Arguments in_vars_vec_elim [Sig x n ts].
Implicit Arguments in_vars_vec_intro [Sig x t n ts].
Implicit Arguments vars_vec_in [Sig x t n ts].
Implicit Arguments vars_max [Sig x t].

(***********************************************************************)
(** tactics *)

Ltac Funeqtac :=
  match goal with
    | H : @Fun ?Sig ?f ?ts = @Fun _ ?f ?us |- _ =>
      deduce (fun_eq H); clear H
    | H : @Fun ?Sig ?f ?ts = @Fun _ ?g ?us |- _ =>
      let H0 := fresh in let H1 := fresh in
        (inversion H as [[H0 H1]]; clear H1; subst g;
          deduce (fun_eq H); clear H)
  end.
