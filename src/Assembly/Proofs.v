Require Import Coq.Lists.List.
Require Import Coq.micromega.Lia.
Require Import Coq.NArith.NArith.
Require Import Coq.ZArith.ZArith.
Require Import Crypto.Language.API.
Require Import Crypto.Language.APINotations.
Require Import Crypto.AbstractInterpretation.ZRange.
Require Import Crypto.Util.ErrorT.
Require Import Crypto.Assembly.Syntax.
Require Import Crypto.Assembly.Semantics.
Require Import Crypto.Assembly.Symbolic.
Require Import Crypto.Assembly.Equivalence.
Require Import Crypto.Util.Option.
Require Import Crypto.Util.Prod.
Require Import Crypto.Util.Sigma.
Require Import Crypto.Util.Notations.
Require Import Crypto.Util.Sum.
Require Import Crypto.Util.Bool.Reflect.
Require Import Crypto.Util.Bool.
Require Import Crypto.Util.ListUtil.
Require Import Crypto.Util.Tactics.BreakMatch.
Require Import Crypto.Util.Tactics.SpecializeBy.
Require Import Crypto.Util.Tactics.HasBody.
Require Import Crypto.Util.Tactics.DestructHead.
Import API.Compilers APINotations.Compilers AbstractInterpretation.ZRange.Compilers.
Import ListNotations.
Local Open Scope list_scope.

Fixpoint eval_base_var (dag : dag) {t : base.type} : base_var t -> API.interp_type (type.base t) -> Prop :=
  match t with
  | base.type.unit => fun _ _ => True
  | base.type.type_base base.type.Z => fun idx v => exists n, Z.of_N n = v /\ eval dag (ExprRef idx) n
  | base.type.prod _ _ => fun a b => eval_base_var dag (fst a) (fst b) /\ eval_base_var dag (snd a) (snd b)
  | base.type.list _ => List.Forall2 (eval_base_var dag)
  | base.type.type_base base.type.nat => @eq _
  | base.type.type_base base.type.zrange => @eq _
  | _ => fun _ _ => False
  end%bool.

Definition eval_var (dag : dag) {t : API.type} : var t -> API.interp_type t -> Prop
  := match t with
     | type.base _ => eval_base_var dag
     | type.arrow _ _ => fun _ _ => False
     end.

Local Lemma ex_Z_of_N_iff P v
  : (exists n, Z.of_N n = v /\ P n) <-> (0 <= v /\ P (Z.to_N v))%Z.
Proof.
  split; [ intros [n [H1 H2] ] | intros [H1 H2]; exists (Z.to_N v) ]; subst; rewrite ?N2Z.id, ?Z2N.id by lia.
  all: split; eauto; lia.
Qed.

Local Lemma ex_Z_of_N_iff' P v (H : (0 <= v)%Z)
  : (exists n, Z.of_N n = v /\ P n) <-> P (Z.to_N v).
Proof. rewrite ex_Z_of_N_iff; intuition lia. Qed.

Lemma symex_T_app_curried_symex_T_error {t} err v d
  : @symex_T_app_curried t (symex_T_error err) v d = Error err.
Proof. induction t; cbn in *; break_innermost_match; try reflexivity; eauto. Qed.

Lemma symex_T_app_curried_symex_T_bind_base_split T t v1 v2 v3 d rets d''
      (H : symex_T_app_curried (@symex_T_bind_base T t v1 v2) v3 d = Success (rets, d''))
  : exists rets' d',
    v1 d = Success (rets', d')
    /\ symex_T_app_curried (v2 rets') v3 d' = Success (rets, d'').
Proof.
  induction t; cbn [symex_T symex_T_bind_base symex_T_app_curried] in *.
  all: cbv [symex_bind ErrorT.bind] in *.
  all: break_innermost_match_hyps; try discriminate; eauto.
Qed.

Lemma symex_T_app_curried_symex_T_bind_base_split_err T t v1 v2 v3 d err
      (H : symex_T_app_curried (@symex_T_bind_base T t v1 v2) v3 d = Error err)
  : v1 d = Error err
    \/ exists rets' d',
      v1 d = Success (rets', d')
      /\ symex_T_app_curried (v2 rets') v3 d' = Error err.
Proof.
  induction t; cbn [symex_T symex_T_bind_base symex_T_app_curried] in *.
  all: cbv [symex_bind ErrorT.bind] in *.
  all: break_innermost_match_hyps; try discriminate; eauto.
  left; congruence.
Qed.

Lemma lift_eval_base_var_impl d1 d2
      (H : forall v n, eval d1 v n -> eval d2 v n)
  : forall t v n, @eval_base_var d1 t v n -> @eval_base_var d2 t v n.
Proof.
  induction t; cbn [base_var eval_base_var]; break_innermost_match; intros; destruct_head'_ex; destruct_head'_and; subst; eauto using Forall2_weaken.
Qed.
Lemma lift_eval_var_impl d1 d2
      (H : forall v n, eval d1 v n -> eval d2 v n)
  : forall t v n, @eval_var d1 t v n -> @eval_var d2 t v n.
Proof.
  induction t; cbn [var eval_var]; eauto using lift_eval_base_var_impl.
Qed.

Theorem symex_ident_correct
        {t} (idc : ident t)
        (d : dag)
        (input_var_data : type.for_each_lhs_of_arrow var t)
        (input_runtime_var : type.for_each_lhs_of_arrow API.interp_type t)
        (* N.B. We need [Hinput] for the [dag_ok] conclusion, because
            we need to know that we can evaluate the indices in the
            arguments w.r.t. the dag for, e.g., [eval_merge_node] *)
        (Hinput : type.and_for_each_lhs_of_arrow (@eval_var d) input_var_data input_runtime_var)
        (rets : base_var (type.final_codomain t))
        (d' : dag)
        (H : symex_T_app_curried (symex_ident idc) input_var_data d = Success (rets, d'))
        (d_ok : dag_ok d)
  : eval_base_var d' rets (type.app_curried (Compilers.ident_interp idc) input_runtime_var)
    /\ dag_ok d'
    /\ (forall e n, eval d e n -> eval d' e n).
Proof.
  cbv [symex_ident] in H; break_innermost_match_hyps.
  all: cbn [type.app_curried type.and_for_each_lhs_of_arrow Compilers.ident_interp symex_T_app_curried type.for_each_lhs_of_arrow] in *.
  all: cbn [API.interp_type base_var type.final_codomain var] in *.
  all: destruct_head'_prod; destruct_head'_unit.
  all: cbv [symex_T_error symex_error symex_return symex_bind App ErrorT.bind ident.eagerly ident.literal] in *.
  all: break_innermost_match_hyps.
  all: match goal with
       | [ H : Success _ = Success _ |- _ ] => inversion H; clear H
       | [ H : Error _ = Success _ |- _ ] => exfalso; clear -H; now inversion H
       | _ => let T := type of H in fail 0 T
       end.
  all: try solve [ repeat first [ progress subst
                                | progress inversion_prod
                                | progress cbn [fst snd] in *
                                | progress cbn [eval_var eval_base_var] in *
                                | progress cbn [Language.Compilers.base.interp Compilers.base_interp] in *
                                | reflexivity
                                | repeat apply conj; [ | assumption | exact (fun _ _ x => x) ]
                                | progress intros
                                | progress destruct_head'_and
                                | progress destruct_head'_ex
                                | progress cbv [Definitions.Z.value_barrier]
                                | solve [ eauto using length_Forall2, Forall.Forall2_firstn, Forall.Forall2_skipn, Forall.Forall2_combine, Forall2_app, Forall2_rev ]
                                | rewrite Forall2_eq
                                | rewrite Forall.Forall2_repeat_iff
                                | now apply Forall.Forall2_forall_iff'' ] ].
  (** TODO(Andres): Finish this proof.  What follows is Jason's stab at making progress on it; feel free to remove any/all of it *)
  all: repeat first [ progress subst
                    | progress inversion_prod
                    | progress cbn [fst snd] in *
                    | progress cbn [eval_var eval_base_var] in *
                    | progress cbn [Language.Compilers.base.interp Compilers.base_interp] in *
                    | reflexivity
                    | repeat apply conj; [ | assumption | exact (fun _ _ x => x) ]
                    | progress intros
                    | progress destruct_head'_and
                    | progress destruct_head'_ex
                    | progress cbv [Definitions.Z.value_barrier]
                    | solve [ eauto using length_Forall2, Forall.Forall2_firstn, Forall.Forall2_skipn, Forall.Forall2_combine, Forall2_app, Forall2_rev ]
                    | rewrite Forall2_eq
                    | rewrite Forall.Forall2_repeat_iff
                    | now apply Forall.Forall2_forall_iff'' ].
  all: rewrite ?ex_Z_of_N_iff'.
  all: repeat first [ assumption
                    | match goal with
                      | [ |- context[eval _ (ExprRef (fst (merge_node (@pair ?A ?B ?op ?args) ?d))) ?n] ]
                        => let T := open_constr:(_) in
                           cut T;
                           [ let H := fresh in
                             intro H;
                             let H' := fresh in
                             pose proof (eval_merge_node d ltac:(assumption) op args n H) as H'; cbv beta zeta in *;
                             progress change (op, args) with (@pair A B op args) in H';
                             let k := fresh in
                             set (k := merge_node (@pair A B op args) d) in *; clearbody k
                           | ]
                      | [ |- context[eval _ (ExprRef (fst (merge ?e ?d))) ?n] ]
                        => let T := open_constr:(_) in
                           cut T;
                           [ let H := fresh in
                             intro H;
                             pose proof (eval_merge e n d ltac:(assumption) H);
                             let k := fresh in
                             set (k := merge e d) in *; clearbody k
                           | ]
                      end
                    | progress destruct_head'_and
                    | solve [ auto ]
                    | repeat apply conj ].
  (* misc processing *)
  all: repeat first [ progress cbn [fst snd List.map] in *
                    | progress subst
                    | progress split_andb
                    | progress reflect_hyps
                    | progress cbv [PreExtra.ident.cast2]
                    | match goal with
                      | [ H : _ = fst ?x |- _ ] => is_var x; destruct x
                      | [ H : _ = snd ?x |- _ ] => is_var x; destruct x
                      end ].
  all: try lia.
  all: lazymatch goal with
       | [ |- (0 <= ?x mod ?y)%Z ]
         => let H := fresh in
            destruct (Z_zerop y) as [H|H]; [ rewrite H; destruct x eqn:?; cbv -[Z.le]; lia | pose proof (Z_mod_lt x y); lia ]
       | _ => idtac
       end.
Admitted.
Theorem symex_expr_correct
        {t} (expr1 : API.expr (var:=var) t) (expr2 : API.expr (var:=API.interp_type) t)
        (d : dag)
        (input_var_data : type.for_each_lhs_of_arrow var t) (input_runtime_var : type.for_each_lhs_of_arrow API.interp_type t)
        (Hinputs : type.and_for_each_lhs_of_arrow (@eval_var d) input_var_data input_runtime_var)
        (rets : base_var (type.final_codomain t))
        (d' : dag)
        G
        (HG : forall t v1 v2, List.In (existT _ t (v1, v2)) G -> eval_var d v1 v2)
        (Hwf : API.wf G expr1 expr2)
        (H : symex_T_app_curried (symex_expr expr1) input_var_data d = Success (rets, d'))
        (d_ok : dag_ok d)
  : eval_base_var d' rets (type.app_curried (API.interp expr2) input_runtime_var)
    /\ dag_ok d'
    /\ (forall e n, eval d e n -> eval d' e n).
Proof.
  revert dependent d; revert dependent d'; revert dependent input_var_data; revert dependent input_runtime_var.
  induction Hwf; intros; cbn [symex_expr] in *.
  all: repeat first [ match goal with
                      (* ident case *)
                      | [ |- context[expr.Ident] ] => eapply symex_ident_correct; eassumption
                      (* var case *)
                      | [ HIn : List.In (existT _ ?t (?v1, ?v2)) _ |- context[expr.Var] ]
                        => is_var t; specialize (HG t _ _ HIn); destruct t
                      (* abs case, eventually *)
                      | [ H : context[_ /\ dag_ok _ /\ (forall e n, _ -> _)] |- context[expr.Abs] ]
                        => eapply H; try eassumption; clear H; []
                      end
                    | match goal with
                      | [ H : Success _ = Success _ |- _ ] => inversion H; clear H
                      | [ H : Error _ = Success _ |- _ ] => now inversion H
                      | [ H : symex_T_app_curried (symex_T_bind_base _ _) _ _ = Success _ |- _ ]
                        => apply symex_T_app_curried_symex_T_bind_base_split in H
                      end
                    | match goal with
                      | [ IH : forall rets d' d, _ -> symex_expr ?x d = Success (rets, d') -> _, H : symex_expr ?x _ = Success (_, _) |- _ ]
                        => specialize (fun H' => IH _ _ _ H' H)
                      | [ IH : forall rets irv c ivd e d' d0, _ -> _ -> _ -> symex_T_app_curried (symex_expr ?f ivd) e d0 = Success (rets, d') -> _,
                            H : symex_T_app_curried (symex_expr ?f _) _ _ = Success (_, _) |- _ ]
                        => specialize (fun irv c H1 H2 H3 => IH _ irv c _ _ _ _ H1 H2 H3 H)
                      | [ IH : forall v1 v2 rets irv ivd d' d, _ -> _ -> symex_T_app_curried (symex_expr (?f v1)) ivd d = Success (rets, d') -> _,
                            H : symex_T_app_curried (symex_expr (?f _)) _ _ = Success (_, _) |- _ ]
                        => specialize (fun v2 irv H1 H2 => IH _ v2 _ irv _ _ _ H1 H2 H)
                      | [ IH : forall irv c, eval_base_var ?a ?b irv -> _, H : eval_base_var ?a ?b _ |- _ ]
                        => specialize (fun c => IH _ c H)
                      | [ IH : forall c, type.and_for_each_lhs_of_arrow ?x ?ivd c -> _, H : type.and_for_each_lhs_of_arrow ?y ?ivd ?cv |- _ ]
                        => specialize (fun H' => IH cv ltac:(eapply Wf.Compilers.type.and_for_each_lhs_of_arrow_Proper_impl; [ .. | eexact H ]; try reflexivity; cbv [Morphisms.forall_relation Morphisms.pointwise_relation Basics.impl]; eapply lift_eval_var_impl; eassumption))
                      | [ IH : forall v2 c, type.and_for_each_lhs_of_arrow ?x ?ivd c -> _, H : type.and_for_each_lhs_of_arrow ?y ?ivd ?cv |- _ ]
                        => specialize (fun v2 H' => IH v2 cv ltac:(eapply Wf.Compilers.type.and_for_each_lhs_of_arrow_Proper_impl; [ .. | eexact H ]; try reflexivity; cbv [Morphisms.forall_relation Morphisms.pointwise_relation Basics.impl]; eapply lift_eval_var_impl; eassumption))
                      | [ H : forall v, ?T -> (forall t v1 v2, existT _ _ _ = _ \/ _ -> _) -> _ |- _ ]
                        => specialize (fun H1 H3 v H2 => H v H1 (fun t v1 v2 pf => match pf with
                                                                                   | or_introl pf => H2 t v1 v2 pf
                                                                                   | or_intror pf => H3 t v1 v2 pf
                                                                                   end))
                      | [ H : forall v, (forall t v1 v2, existT _ _ _ = existT _ t (v1, v2) -> _) -> _ |- _ ]
                        => specialize (H _ ltac:(intros; inversion_sigma; subst; cbn [eq_rect] in *; inversion_prod; subst; eassumption))
                      end
                    | match goal with
                      | [ H : forall a (b : unit), _ |- _ ] => specialize (fun a => H a tt)
                      | [ H : forall a b, True -> _ |- _ ] => specialize (fun a b => H a b I)
                      | [ H : forall a b c, True -> _ |- _ ] => specialize (fun a b c => H a b c I)
                      | [ H : forall a (b : _ * _), _ |- _ ] => specialize (fun a b c => H a (b, c))
                      | [ H : forall a b c (d : _ * _), _ |- _ ] => specialize (fun a b c d e => H a b c (d, e))
                      | [ H : forall a b c d e f, _ /\ _ -> _ |- _ ] => specialize (fun a b c d e f g h => H a b c d e f (conj g h))
                      | [ H : forall a b c d e f g, _ /\ _ -> _ |- _ ] => specialize (fun a b c d e f g h i => H a b c d e f g (conj h i))
                      end
                    | exfalso; assumption
                    | progress subst
                    | progress destruct_head_hnf' unit
                    | progress destruct_head_hnf' True
                    | progress destruct_head_hnf' prod
                    | progress destruct_head'_and
                    | progress destruct_head'_ex
                    | progress cbn [symex_T_app_curried symex_T_return eval_var type.app_curried] in *
                    | progress cbn [type.and_for_each_lhs_of_arrow type.for_each_lhs_of_arrow fst snd List.In eq_rect] in *
                    | progress cbn [type.final_codomain base_var] in *
                    | progress cbv [symex_return] in *
                    | rewrite @symex_T_app_curried_symex_T_error in *
                    | solve [ auto ]
                    | progress inversion_sigma
                    | progress inversion_prod
                    | progress break_innermost_match_hyps
                    | progress destruct_head'_or
                    | progress intros
                    | progress specialize_by_assumption
                    | progress specialize_by (eauto using lift_eval_var_impl) ].
Qed.

Lemma symex_expr_App_curried {t} (e : API.expr t) input_var_data d
  : symex_expr (invert_expr.App_curried e (type.map_for_each_lhs_of_arrow (fun t v => ($v)%expr) input_var_data)) d
    = symex_T_app_curried (symex_expr e) input_var_data d.
Proof.
  induction t; cbn [invert_expr.App_curried symex_T_app_curried type.map_for_each_lhs_of_arrow];
    destruct_head_hnf' prod; destruct_head_hnf' unit; cbn [fst snd]; try reflexivity.
  match goal with H : _ |- _ => rewrite H; clear H end.
  repeat first [ progress cbn [symex_expr var] in *
               | progress break_innermost_match
               | solve [ destruct_head'_Empty_set ] ].
  cbv [symex_T_return symex_return] in *.
  let LHS := match goal with |- ?LHS = _ => LHS end in
  destruct LHS as [ [? ?] | ? ] eqn:H;
    [ apply symex_T_app_curried_symex_T_bind_base_split in H | apply symex_T_app_curried_symex_T_bind_base_split_err in H ].
  all: destruct_head'_or; destruct_head'_ex; destruct_head'_and; congruence.
Qed.

Lemma symex_expr_smart_App_curried {t} (e : API.expr t) input_var_data d
  : symex_expr (invert_expr.smart_App_curried e input_var_data) d
    = symex_T_app_curried (symex_expr e) input_var_data d.
Proof.
  induction e; cbn [invert_expr.smart_App_curried];
    rewrite ?symex_expr_App_curried; try reflexivity.
  match goal with H : _ |- _ => rewrite H; clear H end.
  cbn [symex_expr symex_T_app_curried]; break_innermost_match; cbn [fst snd]; reflexivity.
Qed.

Theorem symex_PHOAS_PHOAS_correct
        {t} (expr : API.Expr t)
        (d : dag)
        (input_var_data : type.for_each_lhs_of_arrow var t) (input_runtime_var : type.for_each_lhs_of_arrow API.interp_type t)
        (Hinputs : type.and_for_each_lhs_of_arrow (@eval_var d) input_var_data input_runtime_var)
        (rets : base_var (type.final_codomain t))
        (d' : dag)
        (Hwf : API.Wf expr)
        (H : symex_PHOAS_PHOAS expr input_var_data d = Success (rets, d'))
        (d_ok : dag_ok d)
  : eval_base_var d' rets (type.app_curried (API.Interp expr) input_runtime_var)
    /\ dag_ok d'
    /\ (forall e n, eval d e n -> eval d' e n).
Proof.
  cbv [symex_PHOAS_PHOAS] in H.
  rewrite symex_expr_smart_App_curried in H.
  eapply symex_expr_correct with (G:=[]); try eassumption; cbn [List.In]; try eapply Hwf; try now intros; exfalso.
Qed.

Definition eval_idx_Z (dag : dag) (idx : idx) (v : Z) : Prop
  := exists n, Z.of_N n = v /\ eval dag (ExprRef idx) n.
Definition eval_idx_or_list_idx (d : dag) (v1 : idx + list idx) (v2 : Z + list Z)
  : Prop
  := match v1, v2 with
     | inl idx, inl v => eval_idx_Z d idx v
     | inr idxs, inr vs => Forall2 (eval_idx_Z d) idxs vs
     | inl _, inr _ | inr _, inl _ => False
     end.

Fixpoint build_base_runtime (t : base.type) (values : list (Z + list Z))
  : option (base.interp t * list (Z + list Z))
  := match t, values return option (base.interp t * list (Z + list Z)) with
     | base.type.unit, _
       => Some (tt, values)
     | base.type.type_base base.type.Z, inl val :: values
       => Some (val, values)
     | base.type.prod A B, _
       => (vA <- build_base_runtime A values;
          let '(vA, values) := vA in
          vB <- build_base_runtime B values;
          let '(vB, values) := vB in
          Some ((vA, vB), values))
     | base.type.list (base.type.type_base base.type.Z), inr value :: values
       => Some (value, values)
     | base.type.type_base base.type.Z, inr _ :: _
     | base.type.list (base.type.type_base base.type.Z), inl _ :: _
     | base.type.type_base _, []
     | base.type.list _, []
     | base.type.type_base _, _
     | base.type.option _, _
     | base.type.list _, _ :: _
       => None
     end%option.
Definition build_runtime (t : API.type) (values : list (Z + list Z))
  : option (API.interp_type t * list (Z + list Z))
  := match t with
     | type.base t => build_base_runtime t values
     | type.arrow _ _ => None
     end.
Fixpoint build_input_runtime (t : API.type) (values : list (Z + list Z))
  : option (type.for_each_lhs_of_arrow API.interp_type t * list (Z + list Z))
  := match t with
     | type.base _ => Some (tt, values)
     | type.arrow A B
       => (vA <- build_runtime A values;
          let '(vA, values) := vA in
          vB <- build_input_runtime B values;
          let '(vB, values) := vB in
          Some ((vA, vB), values))
     end%option.

Fixpoint simplify_base_runtime {t : base.type} : base.interp t -> option (list (Z + list Z))
  := match t return base.interp t -> option (list (Z + list Z)) with
     | base.type.unit
       => fun 'tt => Some []
     | base.type.type_base base.type.Z => fun val => Some [inl val]
     | base.type.prod A B => fun ab => (a <- simplify_base_runtime (fst ab); b <- simplify_base_runtime (snd ab); Some (a ++ b))
     | base.type.list (base.type.type_base base.type.Z)
       => fun ls : list Z => Some (List.map inl ls)
     | base.type.list _
     | base.type.type_base _
     | base.type.option _
       => fun _ => None
     end%option.

Lemma build_base_var_runtime_gen
      d
      (inputs : list (idx + list idx)) (runtime_inputs : list (Z + list Z))
      (Hinputs : Forall2 (eval_idx_or_list_idx d) inputs runtime_inputs)
      t
  : match build_base_var t inputs, build_base_runtime t runtime_inputs with
    | Success (v1, ls1), Some (v2, ls2)
      => eval_base_var d v1 v2
         /\ Forall2 (eval_idx_or_list_idx d) ls1 ls2
    | Success _, None | Error _, Some _ => False
    | Error _, None => True
    end.
Proof.
  revert inputs runtime_inputs Hinputs; induction t; cbn [build_base_var build_base_runtime]; intros; break_innermost_match.
  all: repeat first [ exact I
                    | progress subst
                    | progress cbn [eval_idx_or_list_idx eval_base_var] in *
                    | progress cbv [Crypto.Util.Option.bind Rewriter.Util.Option.bind ErrorT.bind] in *
                    | exfalso; assumption
                    | solve [ auto ]
                    | match goal with
                      | [ H : Forall2 _ [] _ |- _ ] => inversion H; clear H
                      | [ H : Forall2 _ _ [] |- _ ] => inversion H; clear H
                      | [ H : Forall2 _ (_ :: _) _ |- _ ] => inversion H; clear H
                      | [ H : Forall2 _ _ (_ :: _) |- _ ] => inversion H; clear H
                      end
                    | progress break_innermost_match_hyps
                    | progress specialize_by_assumption
                    | progress destruct_head'_and
                    | match goal with
                      | [ H : context[match build_base_var ?t1 _ with _ => _ end] |- context[build_base_var ?t1 ?inputs] ]
                        => specialize (H inputs)
                      | [ H : context[match build_base_runtime ?t1 _ with _ => _ end] |- context[build_base_runtime ?t1 ?inputs] ]
                        => specialize (H inputs)
                      end ].
Qed.

Lemma build_var_runtime_gen
      d
      (inputs : list (idx + list idx)) (runtime_inputs : list (Z + list Z))
      (Hinputs : Forall2 (eval_idx_or_list_idx d) inputs runtime_inputs)
      t
  : match build_var t inputs, build_runtime t runtime_inputs with
    | Success (v1, ls1), Some (v2, ls2)
      => eval_var d v1 v2
         /\ Forall2 (eval_idx_or_list_idx d) ls1 ls2
    | Success _, None | Error _, Some _ => False
    | Error _, None => True
    end.
Proof.
  destruct t as [t|s d']; [ pose proof (build_base_var_runtime_gen _ _ _ Hinputs t) | ].
  all: cbv [build_var build_runtime]; break_innermost_match; try assumption; try exact I.
Qed.

Lemma build_input_var_runtime_gen
      d
      (inputs : list (idx + list idx)) (runtime_inputs : list (Z + list Z))
      (Hinputs : Forall2 (eval_idx_or_list_idx d) inputs runtime_inputs)
      t
  : match build_input_var t inputs, build_input_runtime t runtime_inputs with
    | Success (v1, ls1), Some (v2, ls2)
      => type.and_for_each_lhs_of_arrow (@eval_var d) v1 v2
         /\ Forall2 (eval_idx_or_list_idx d) ls1 ls2
    | Success _, None | Error _, Some _ => False
    | Error _, None => True
    end.
Proof.
  revert inputs runtime_inputs Hinputs; induction t as [|s _ d' IHd];
    cbn [build_input_runtime build_input_var build_var type.and_for_each_lhs_of_arrow] in *; intros; auto; [].
  cbv [Crypto.Util.Option.bind Rewriter.Util.Option.bind ErrorT.bind].
  pose proof (build_var_runtime_gen _ _ _ Hinputs s).
  break_innermost_match_hyps; try exact I; try (now exfalso); [].
  destruct_head'_and.
  let l := match goal with |- context[build_input_var _ ?l] => l end in
  specialize (IHd l _ ltac:(eassumption)).
  break_innermost_match_hyps; try exact I; try (now exfalso); [].
  destruct_head'_and; auto.
Qed.

Lemma simplify_base_var_runtime_gen {t} d b v
      (H : eval_base_var d b v)
  : match @simplify_base_var t b, @simplify_base_runtime t v with
    | Success rets, Some val => Forall2 (eval_idx_or_list_idx d) rets val
    | Success _, None | Error _, Some _ => False
    | Error _, None => True
    end.
Proof.
  induction t; cbn [eval_base_var simplify_base_var simplify_base_runtime] in *; break_innermost_match.
  all: repeat first [ assumption
                    | exact I
                    | match goal with
                      | [ |- Forall2 _ _ _ ] => constructor
                      end
                    | progress destruct_head'_and
                    | progress destruct_head_hnf' prod
                    | progress cbn [fst snd] in *
                    | progress cbv [Crypto.Util.Option.bind Rewriter.Util.Option.bind ErrorT.bind] in *
                    | match goal with
                      | [ IH : context[simplify_base_var _] |- context[simplify_base_var ?b] ]
                        => specialize (IH b _ ltac:(eassumption))
                      end
                    | progress break_innermost_match_hyps
                    | rewrite Forall.Forall2_map_map_iff
                    | solve [ eauto using Forall2_app ] ].
Qed.

Theorem symex_PHOAS_correct
        {t} (expr : API.Expr t)
        (d : dag)
        (inputs : list (idx + list idx)) (runtime_inputs : list (Z + list Z))
        (Hinputs : List.Forall2 (eval_idx_or_list_idx d) inputs runtime_inputs)
        (rets : list (idx + list idx))
        (d' : dag)
        (Hwf : API.Wf expr)
        (H : symex_PHOAS expr inputs d = Success (rets, d'))
        (d_ok : dag_ok d)
  : (exists (input_runtime_var : type.for_each_lhs_of_arrow API.interp_type t)
            (runtime_rets : list (Z + list Z)),
        build_input_runtime t runtime_inputs = Some (input_runtime_var, [])
        /\ simplify_base_runtime (type.app_curried (API.Interp expr) input_runtime_var) = Some runtime_rets
        /\ List.Forall2 (eval_idx_or_list_idx d') rets runtime_rets)
    /\ dag_ok d'
    /\ (forall e n, eval d e n -> eval d' e n).
Proof.
  cbv [symex_PHOAS ErrorT.bind] in H; break_innermost_match_hyps; try discriminate.
  destruct (build_input_runtime t runtime_inputs) as [ [input_runtime_var [|] ] | ] eqn:H'; [ | exfalso.. ].
  all: lazymatch goal with
       | [ H : symex_PHOAS_PHOAS _ _ _ = Success _,
               input_runtime_var : type.for_each_lhs_of_arrow API.interp_type _
           |- _ ] => apply (@symex_PHOAS_PHOAS_correct _ _ _ _ input_runtime_var) in H; try assumption; [ | clear H .. ]
       | [ |- False ] => idtac
       end.
  all: repeat first [ progress break_innermost_match_hyps
                    | progress destruct_head'_and
                    | progress subst
                    | progress inversion_option
                    | progress inversion_prod
                    | discriminate
                    | assumption
                    | apply (f_equal (@Some _))
                    | apply (f_equal2 (@pair _ _))
                    | reflexivity
                    | progress reflect_hyps
                    | match goal with
                      | [ H : Success _ = Success _ |- _ ] => inversion H; clear H
                      | [ H : symex_PHOAS_PHOAS _ _ _ = _ |- _ ] => apply symex_PHOAS_PHOAS_correct in H; [ | assumption.. ]
                      | [ |- exists a b, ?v = Some (a, _) /\ _ = Some b /\ _ ]
                        => let av := fresh in destruct v as [ [av ?] |] eqn:?; [ exists av | exfalso ]
                      | [ |- exists a, _ /\ ?v = Some a /\ _ ]
                        => let av := fresh in destruct v as [ av |] eqn:?; [ exists av | exfalso ]
                      | [ H : List.length ?l = 0%nat |- _ ] => is_var l; destruct l; cbn in H
                      | [ H : Forall2 _ [] _ |- _ ] => inversion H; clear H
                      | [ H : Forall2 _ _ [] |- _ ] => inversion H; clear H
                      | [ H : Forall2 _ (_ :: _) _ |- _ ] => inversion H; clear H
                      | [ H : Forall2 _ _ (_ :: _) |- _ ] => inversion H; clear H
                      end
                    | apply conj
                    | progress intros
                    | match goal with
                      | [ H : build_input_runtime ?t ?ri = _, H' : build_input_var ?t ?i = _ |- _ ]
                        => let H'' := fresh in
                           pose proof (build_input_var_runtime_gen _ i ri ltac:(eassumption) t) as H'';
                           rewrite H, H' in H''; clear H H'
                      | [ H : simplify_base_var ?b = _, H' : simplify_base_runtime ?v = _ |- _ ]
                        => let H'' := fresh in
                           pose proof (simplify_base_var_runtime_gen _ b v ltac:(eassumption)) as H'';
                           rewrite H, H' in H''; clear H H'
                      end ].
Qed.

Theorem symex_asm_func_correct
        (d : dag) (gensym_st : gensym_state) (output_types : type_spec) (stack_size : nat)
        (inputs : list (idx + list idx)) (reg_available : list REG) (asm : Lines)
        (rets : list (idx + list idx))
        (s : symbolic_state)
        (H : symex_asm_func d gensym_st output_types stack_size inputs reg_available asm = Success (rets, s))
        (d' := s.(dag_state))
  : (forall (st : machine_state)
            (runtime_inputs : list (Z + list Z)),
        List.Forall2 (eval_idx_or_list_idx d) inputs runtime_inputs
        -> exists st'
                  (* ??? *) (*(input_runtime_var : type.for_each_lhs_of_arrow API.interp_type t)*)
                  (runtime_rets : list (Z + list Z)),
          DenoteLines st asm = Some st'
          (*/\ build_input_runtime t runtime_inputs = Some (input_runtime_var, [])*)
          (*/\ simplify_base_runtime (type.app_curried (API.Interp expr) input_runtime_var) = Some runtime_rets*)
          /\ List.Forall2 (eval_idx_or_list_idx d') rets runtime_rets)
    /\ dag_ok d'
    /\ (forall e n, eval d e n -> eval d' e n).
Proof.
Admitted.

Lemma build_inputs_ok d gensym_st v inputs d' gensym_st'
      (d_ok : dag_ok d)
      (H : build_inputs (d, gensym_st) v = (inputs, (d', gensym_st')))
  : True (* Something about inputs *)
    /\ dag_ok d'
    /\ True (* something about gensym_st' *).
Proof.
Admitted.

Axiom empty_dag_ok : dag_ok empty_dag.

Check @check_equivalence.
Theorem check_equivalence_correct
        {assembly_calling_registers' : assembly_calling_registers_opt}
        {assembly_stack_size' : assembly_stack_size_opt}
        {assembly_output_first : assembly_output_first_opt}
        {assembly_argument_registers_left_to_right : assembly_argument_registers_left_to_right_opt}
        {t}
        (asm : Lines)
        (expr : API.Expr t)
        (arg_bounds : type.for_each_lhs_of_arrow ZRange.type.option.interp t)
        (out_bounds : ZRange.type.base.option.interp (type.final_codomain t))
        (Hwf : API.Wf expr)
        (H : check_equivalence asm expr arg_bounds out_bounds = Success tt)
        (st : machine_state)
        (PHOAS_args : type.for_each_lhs_of_arrow API.interp_type t)
        (args : list (Z + list Z))
        (Hargs : build_input_runtime t args = Some (PHOAS_args, []))
        (HPHOAS_args : type.andb_bool_for_each_lhs_of_arrow (@ZRange.type.option.is_bounded_by) arg_bounds PHOAS_args = true)
  (* TODO(Andres): write down something that relates [st] to args *)
  : exists st'
           (retvals : list (Z + list Z)),
    DenoteLines st asm = Some st'
    /\ simplify_base_runtime (type.app_curried (API.Interp expr) PHOAS_args) = Some retvals
    /\ True (* TODO(andres): write down something that relates st' to retvals *).
Proof.
  cbv beta delta [check_equivalence ErrorT.bind] in H.
  repeat match type of H with
         | (let n := ?v in _) = _
           => set v as n in H;
                lazymatch type of H with
                | (let n := ?v in ?rest) = ?rhs
                  => change (match v with n => rest end = rhs) in H
                end
         | match ?v with Success n => @?S n | Error e => @?E e end = ?rhs
           => let n := fresh n in
              let e := fresh e in
              destruct v as [n|e] eqn:?; [ change (S n = rhs) in H | change (E e = rhs) in H ];
                cbv beta in H
         | match ?v with pair a b => @?P a b end = ?rhs
           => let a := fresh a in
              let b := fresh b in
              destruct v as [a b] eqn:?; change (P a b = rhs) in H;
                cbv beta in H
         | match ?v with true => ?T | false => ?F end = ?rhs
           => let a := fresh a in
              let b := fresh b in
              destruct v eqn:?; [ change (T = rhs) in H | change (F = rhs) in H ];
                cbv beta in H
         end; try discriminate; [].
  reflect_hyps.
  subst.
  pose proof empty_dag_ok.
  repeat first [ assumption
               | match goal with
                 | [ H : build_inputs _ _ = _ |- _ ] => move H at bottom; apply build_inputs_ok in H; [ | assumption.. ]
                 | [ H : symex_PHOAS _ _ _ = Success _, H' : build_input_runtime _ ?ri = Some _ |- _ ]
                   => move H at bottom; apply symex_PHOAS_correct with (runtime_inputs:=ri) in H; [ | clear H; try assumption.. ]
                 | [ H : _ /\ _ |- _ ] => move H at bottom; destruct H
                 end ].
  (*2: {
  lazymatch goal with
  | [ H : symex_PHOAS _ _ _ = Success _, H' : build_input_runtime _ _ = Some (?ri, _) |- _ ]
    => move H at bottom; apply symex_PHOAS_correct with (runtime_inputs:=ri) in H; [ | assumption.. ]
  end.*)
  epose (DenoteLines st asm).
Admitted.

Theorem generate_assembly_of_hinted_expr_correct
        {assembly_calling_registers' : assembly_calling_registers_opt}
        {assembly_stack_size' : assembly_stack_size_opt}
        {assembly_output_first : assembly_output_first_opt}
        {assembly_argument_registers_left_to_right : assembly_argument_registers_left_to_right_opt}
        {t}
        (asm : Lines)
        (expr : API.Expr t)
        (f : type.interp _ t)
        (arg_bounds : type.for_each_lhs_of_arrow ZRange.type.option.interp t)
        (out_bounds : ZRange.type.base.option.interp (type.final_codomain t))
        (asm_out : Lines)
        (* Phrased this way to line up with the bounds pipeline exactly *)
        (Hbounded
         : (forall arg1 arg2
                   (Harg12 : type.and_for_each_lhs_of_arrow (@type.eqv) arg1 arg2)
                   (Harg1 : type.andb_bool_for_each_lhs_of_arrow (@ZRange.type.option.is_bounded_by) arg_bounds arg1 = true),
               ZRange.type.base.option.is_bounded_by out_bounds (type.app_curried (API.Interp expr) arg1) = true
               /\ type.app_curried (API.Interp expr) arg1 = type.app_curried f arg2)
           /\ API.Wf expr)
        (H : generate_assembly_of_hinted_expr asm expr arg_bounds out_bounds = Success asm_out)
  : asm = asm_out
    /\ True (* ??? Something about equivalence of [API.Interp expr] and [asm] *).
Proof.
  cbv [generate_assembly_of_hinted_expr] in H.
  break_innermost_match_hyps; inversion H; subst; repeat apply conj; try reflexivity.
Qed.

(* Some theorems about the result of calling generate_assembly_of_hinted_expr_correct on various Pipeline functions *)