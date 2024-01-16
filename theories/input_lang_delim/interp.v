(* From Equations Require Import Equations. *)
From gitrees Require Import gitree.
From gitrees.input_lang_delim Require Import lang.
Require Import gitrees.lang_generic_sem.

Require Import Binding.Lib.
Require Import Binding.Set.

Notation stateO := (leibnizO state).

Program Definition inputE : opInterp :=
  {|
    Ins := unitO;
    Outs := natO;
  |}.
Program Definition outputE : opInterp :=
  {|
    Ins := natO;
    Outs := unitO;
  |}.

Program Definition shiftE : opInterp :=
  {|
    Ins := ((▶ ∙ -n> ▶ ∙) -n> ▶ ∙);
    Outs := (▶ ∙);
  |}.

Program Definition resetE : opInterp :=
  {|
    Ins := (▶ ∙);
    Outs := (▶ ∙);
  |}.

Definition ioE := @[inputE; outputE; shiftE; resetE].

Definition reify_input X `{Cofe X} : unitO * stateO * (natO -n> laterO X) →
                                     option (laterO X * stateO) :=
  λ '(_, σ, k), let '(n, σ') := (update_input σ : prodO natO stateO) in
                Some (k n, σ').
#[export] Instance reify_input_ne X `{Cofe X} :
  NonExpansive (reify_input X : prodO (prodO unitO stateO)
                                  (natO -n> laterO X) →
                                  optionO (prodO (laterO X) stateO)).
Proof.
  intros n [[? σ1] k1] [[? σ2] k2]. simpl.
  intros [[_ ->] Hk]. simpl in *.
  repeat f_equiv. assumption.
Qed.

Definition reify_output X `{Cofe X} : (natO * stateO * (unitO -n> laterO X)) →
                                      optionO (prodO (laterO X) stateO) :=
  λ '(n, σ, k), Some (k (), ((update_output n σ) : stateO)).
#[export] Instance reify_output_ne X `{Cofe X} :
  NonExpansive (reify_output X : prodO (prodO natO stateO)
                                   (unitO -n> laterO X) →
                                 optionO (prodO (laterO X) stateO)).
Proof.
  intros ? [[]] [[]] []; simpl in *.
  repeat f_equiv; first assumption; apply H0.
Qed.

Definition reify_shift X `{Cofe X} : ((laterO X -n> laterO X) -n> laterO X) *
                                        stateO * (laterO X -n> laterO X) →
                                      option (laterO X * stateO) :=
  λ '(f, σ, k), Some ((f k): laterO X, σ : stateO).
#[export] Instance reify_callcc_ne X `{Cofe X} :
  NonExpansive (reify_shift X :
    prodO (prodO ((laterO X -n> laterO X) -n> laterO X) stateO)
      (laterO X -n> laterO X) →
    optionO (prodO (laterO X) stateO)).
Proof. intros ?[[]][[]][[]]. simpl in *. repeat f_equiv; auto. Qed.


(* CHECK *)
Definition reify_reset X `{Cofe X} :
  (laterO X * stateO * (laterO X -n> laterO X)) →
  option (laterO X * stateO) :=
  λ '(e, σ, k), Some (k e, σ).
(* and add the [get_val] in interp. BUT: doesn't it defeat the whole purpose of
   having reset as an effect? *)
#[export] Instance reify_reset_ne X `{Cofe X} :
  NonExpansive (reify_reset X :
      prodO (prodO (laterO X) stateO) (laterO X -n> laterO X) →
      optionO (prodO (laterO X) stateO)).
Proof. intros ?[[]][[]][[]]. simpl in *. by repeat f_equiv. Qed.


(* Context {E : opsInterp} {A} `{!Cofe A}. *)
(* Context {subEff0 : subEff ioE E}. *)
(* Context {subOfe0 : SubOfe natO A}. *)
(* Notation IT := (IT E A). *)
(* Notation ITV := (ITV E A). *)

(* Definition reify_reset : (laterO IT * stateO * (laterO IT -n> laterO IT)) → *)
(*                          option (laterO IT * stateO) := *)
(*   λ '(e, σ, k), Some (k $ laterO_map (get_val idfun) e, σ). *)
(* #[export] Instance reify_reset_ne : *)
(*   NonExpansive (reify_reset : *)
(*       prodO (prodO (laterO IT) stateO) (laterO IT -n> laterO IT) → *)
(*       optionO (prodO (laterO IT) stateO)). *)
(* Proof. intros ?[[]][[]][[]]. simpl in *. repeat f_equiv; done. Qed. *)



Canonical Structure reify_io : sReifier.
Proof.
  simple refine {| sReifier_ops := ioE;
                   sReifier_state := stateO
                |}.
  intros X HX op.
  destruct op as [ | [ | [ | [| []]]]]; simpl.
  - simple refine (OfeMor (reify_input X)).
  - simple refine (OfeMor (reify_output X)).
  - simple refine (OfeMor (reify_shift X)).
  - simple refine (OfeMor (reify_reset X)).
Defined.


Notation op_input := (inl ()).
Notation op_output := (inr (inl ())).
Notation op_shift := (inr (inr (inl ()))).
Notation op_reset := (inr (inr (inr (inl ())))).

Section constructors.
  Context {E : opsInterp} {A} `{!Cofe A}.
  Context {subEff0 : subEff ioE E}.
  Context {subOfe0 : SubOfe natO A}.
  Notation IT := (IT E A).
  Notation ITV := (ITV E A).

  Program Definition INPUT : (nat -n> IT) -n> IT :=
    λne k, Vis (E:=E) (subEff_opid op_input)
             (subEff_ins (F:=ioE) (op:=op_input) ())
             (NextO ◎ k ◎ (subEff_outs (F:=ioE) (op:=op_input))^-1).
  Solve Obligations with solve_proper.

  Program Definition OUTPUT_ : nat -n> IT -n> IT :=
    λne m α, Vis (E:=E) (subEff_opid op_output)
                        (subEff_ins (F:=ioE) (op:=op_output) m)
                        (λne _, NextO α).
  Solve All Obligations with solve_proper_please.
  Program Definition OUTPUT : nat -n> IT := λne m, OUTPUT_ m (Ret 0).


  Program Definition SHIFT_ : ((laterO IT -n> laterO IT) -n> laterO IT) -n>
                                (laterO IT -n> laterO IT) -n>
                                IT :=
    λne f k, Vis (E:=E) (subEff_opid op_shift)
             (subEff_ins (F:=ioE) (op:=op_shift) f)
             (k ◎ (subEff_outs (F:=ioE) (op:=op_shift))^-1).
  Solve All Obligations with solve_proper.

  Program Definition SHIFT : ((laterO IT -n> laterO IT) -n> laterO IT) -n> IT :=
    λne f, SHIFT_ f (idfun).
  Solve Obligations with solve_proper.

  (* Program Definition RESET : laterO IT -n> IT := *)
  (*   λne e, Vis (E:=E) (subEff_opid op_reset) *)
  (*              (subEff_ins (F := ioE) (op := op_reset) e) *)
  (*              (subEff_outs (F := ioE) (op := op_reset)^-1). *)
  (* Solve All Obligations with solve_proper. *)

  Program Definition RESET_ : (laterO IT -n> laterO IT) -n>
                                laterO IT -n>
                                IT :=
      λne k e, Vis (E:=E) (subEff_opid op_reset)
                 (subEff_ins (F := ioE) (op := op_reset) e)
                 (k ◎ subEff_outs (F := ioE) (op := op_reset)^-1).
  Solve Obligations with solve_proper.

  Program Definition RESET : laterO IT -n> IT :=
    RESET_ idfun.


  Lemma hom_INPUT k f `{!IT_hom f} : f (INPUT k) ≡ INPUT (OfeMor f ◎ k).
  Proof.
    unfold INPUT.
    rewrite hom_vis/=. repeat f_equiv.
    intro x. cbn-[laterO_map]. rewrite laterO_map_Next.
    done.
  Qed.
  Lemma hom_OUTPUT_ m α f `{!IT_hom f} : f (OUTPUT_ m α) ≡ OUTPUT_ m (f α).
  Proof.
    unfold OUTPUT.
    rewrite hom_vis/=. repeat f_equiv.
    intro x. cbn-[laterO_map]. rewrite laterO_map_Next.
    done.
  Qed.

  Lemma hom_SHIFT_ k e f `{!IT_hom f} :
    f (SHIFT_ e k) ≡ SHIFT_ e (laterO_map (OfeMor f) ◎ k).
  Proof.
    unfold SHIFT_.
    rewrite hom_vis/=.
    f_equiv. by intro.
  Qed.


End constructors.

Section weakestpre.
  Context {sz : nat}.
  Variable (rs : gReifiers sz).
  Context {subR : subReifier reify_io rs}.
  Notation F := (gReifiers_ops rs).
  Context {R} `{!Cofe R}.
  Context `{!SubOfe natO R}.
  Notation IT := (IT F R).
  Notation ITV := (ITV F R).
  Context `{!invGS Σ, !stateG rs R Σ}.
  Notation iProp := (iProp Σ).

  Lemma wp_input' (σ σ' : stateO) (n : nat) (k : natO -n> IT) (κ : IT -n> IT)
    `{!IT_hom κ} Φ s :
    update_input σ = (n, σ') ->
    has_substate σ -∗
    ▷ (£ 1 -∗ has_substate σ' -∗ WP@{rs} (κ ◎ k $ n) @ s {{ Φ }}) -∗
    WP@{rs} κ (INPUT k) @ s {{ Φ }}.
  Proof.
    iIntros (Hσ) "Hs Ha".
    rewrite hom_INPUT. simpl.
    iApply (wp_subreify with "Hs").
    + simpl. by rewrite Hσ.
    + by rewrite ofe_iso_21.
    + done.
  Qed.

  Lemma wp_input (σ σ' : stateO) (n : nat) (k : natO -n> IT) Φ s :
    update_input σ = (n, σ') →
    has_substate σ -∗
    ▷ (£ 1 -∗ has_substate σ' -∗ WP@{rs} (k n) @ s {{ Φ }}) -∗
    WP@{rs} (INPUT k) @ s {{ Φ }}.
  Proof.
    eapply (wp_input' σ σ' n k idfun).
  Qed.

  (* Lemma wp_input (σ σ' : stateO) (n : nat) (k : natO -n> IT) Φ s : *)
  (*   update_input σ = (n, σ') → *)
  (*   has_substate σ -∗ *)
  (*   ▷ (£ 1 -∗ has_substate σ' -∗ WP@{rs} (k n) @ s {{ Φ }}) -∗ *)
  (*   WP@{rs} (INPUT k) @ s {{ Φ }}. *)
  (* Proof. *)
  (*   intros Hs. iIntros "Hs Ha". *)
  (*   unfold INPUT. simpl. *)
  (*   iApply (wp_subreify with "Hs"). *)
  (*   { simpl. by rewrite Hs. } *)
  (*   { simpl. by rewrite ofe_iso_21. } *)
  (*   iModIntro. done. *)
  (* Qed. *)

  Lemma wp_output' (σ σ' : stateO) (n : nat) (κ : IT -n> IT)
    `{!IT_hom κ} Φ s :
    update_output n σ = σ' →
    has_substate σ -∗
    ▷ (£ 1 -∗ has_substate σ' -∗ WP@{rs} (κ (Ret 0)) @ s {{ Φ }}) -∗
    WP@{rs} κ (OUTPUT n) @ s {{ Φ }}.
  Proof.
    iIntros (Hσ) "Hs Ha".
    rewrite /OUTPUT hom_OUTPUT_.
    iApply (wp_subreify with "Hs").
    + simpl. by rewrite Hσ.
    + done.
    + done.
  Qed.


  Lemma wp_output (σ σ' : stateO) (n : nat) Φ s :
    update_output n σ = σ' →
    has_substate σ -∗
    ▷ (£ 1 -∗ has_substate σ' -∗ Φ (RetV 0)) -∗
    WP@{rs} (OUTPUT n) @ s {{ Φ }}.
  Proof.
    iIntros (Hσ) "Hs Ha".
    iApply (wp_output' _ _ _ idfun with "Hs [Ha]"); first done.
    simpl. iNext. iIntros "Hcl Hs".
    iApply wp_val. iApply ("Ha" with "Hcl Hs").
  Qed.

  (* Lemma wp_throw' (σ : stateO) (f : laterO (IT -n> IT)) (x : IT) *)
  (*   (κ : IT -n> IT) `{!IT_hom κ} Φ s : *)
  (*   has_substate σ -∗ *)
  (*   ▷ (£ 1 -∗ has_substate σ -∗ WP@{rs} (later_car f) x @ s {{ Φ }}) -∗ *)
  (*   WP@{rs} κ (THROW x f) @ s {{ Φ }}. *)
  (* Proof. *)
  (*   iIntros "Hs Ha". rewrite /THROW. simpl. *)
  (*   rewrite hom_vis. *)
  (*   iApply (wp_subreify with "Hs"); simpl; done. *)
  (* Qed. *)

  (* Lemma wp_throw (σ : stateO) (f : laterO (IT -n> IT)) (x : IT) Φ s : *)
  (*   has_substate σ -∗ *)
  (*   ▷ (£ 1 -∗ has_substate σ -∗ WP@{rs} later_car f x @ s {{ Φ }}) -∗ *)
  (*   WP@{rs} (THROW x f) @ s {{ Φ }}. *)
  (* Proof. *)
  (*   iApply (wp_throw' _ _ _ idfun). *)
  (* Qed. *)

  Lemma wp_shift (σ : stateO) (f : (laterO IT -n> laterO IT) -n> laterO IT)
    (k : IT -n> IT) {Hk : IT_hom k} Φ s :
    has_substate σ -∗
    ▷ (£ 1 -∗ has_substate σ -∗ WP@{rs} idfun (later_car (f (laterO_map k))) @ s {{ Φ }}) -∗
    WP@{rs} (k (SHIFT f)) @ s {{ Φ }}.
  Proof.
    iIntros "Hs Ha".
    unfold SHIFT. simpl.
    rewrite hom_vis.
    iApply (wp_subreify _ _ _ _ _ _ _ ((later_map idfun ((f (laterO_map k))))) with "Hs").
    {
      simpl.
      repeat f_equiv.
      - rewrite ccompose_id_l later_map_id.
        f_equiv. intro x. simpl.
        by rewrite ofe_iso_21.
      - reflexivity.
    }
    { by rewrite later_map_Next. }
    iModIntro.
    iApply "Ha".
  Qed.

End weakestpre.

Section interp.
  Context {sz : nat}.
  Variable (rs : gReifiers sz).
  Context {subR : subReifier reify_io rs}.
  Context {R} `{CR : !Cofe R}.
  Context `{!SubOfe natO R}.
  Notation F := (gReifiers_ops rs).
  Notation IT := (IT F R).
  Notation ITV := (ITV F R).
  Context `{!invGS Σ, !stateG rs R Σ}.
  Notation iProp := (iProp Σ).

  Global Instance denot_cont_ne (κ : IT -n> IT) :
    NonExpansive (λ x : IT, Tau (laterO_map κ (Next x))).
  Proof.
    solve_proper.
  Qed.

  (** Interpreting individual operators *)
  Program Definition interp_input {A} : A -n> IT :=
    λne env, INPUT Ret.
  Program Definition interp_output {A} (t : A -n> IT) : A -n> IT :=
    get_ret OUTPUT ◎ t.
  Local Instance interp_ouput_ne {A} : NonExpansive2 (@interp_output A).
  Proof. solve_proper. Qed.

  Program Definition interp_shift {S}
    (e : @interp_scope F R _ (inc S) -n> IT) : interp_scope S -n> IT :=
    λne env, SHIFT (λne (f : laterO IT -n> laterO IT),
                       (Next (e (@extend_scope F R _ _ env
                                   (Fun (Next (λne x, Tau (f (Next x))))))))).
  Next Obligation.
    solve_proper.
  Qed.
  Next Obligation.
    solve_proper_prepare.
    repeat f_equiv.
    intros [| a]; simpl; last solve_proper.
    repeat f_equiv.
    intros ?; simpl.
    by repeat f_equiv.
  Qed.
  Next Obligation.
    solve_proper_prepare.
    repeat f_equiv.
    intros ?; simpl.
    repeat f_equiv.
    intros [| a]; simpl; last solve_proper.
    repeat f_equiv.
  Qed.

  (* Program Definition interp_reset {S} (e : S -n> IT) : S -n> IT := *)
  (*   λne env, get_val idfun (RESET (Next (e env))). *)
  (* Solve All Obligations with solve_proper_please. *)

  Program Definition interp_reset {S} (e : S -n> IT) : S -n> IT :=
    λne env, get_val idfun (RESET (Next (e env))).
  Solve All Obligations with solve_proper_please.

  (* Program Definition interp_throw {A} (e : A -n> IT) (k : A -n> IT) *)
  (*   : A -n> IT := *)
  (*   λne env, get_val (λne x, get_fun (λne (f : laterO (IT -n> IT)), *)
  (*                                THROW x f) (k env)) (e env). *)
  (* Next Obligation. *)
  (*   solve_proper. *)
  (* Qed. *)
  (* Next Obligation. *)
  (*   solve_proper_prepare. *)
  (*   repeat f_equiv. *)
  (*   intro; simpl. *)
  (*   by repeat f_equiv. *)
  (* Qed. *)
  (* Next Obligation. *)
  (*   solve_proper_prepare. *)
  (*   repeat f_equiv; last done. *)
  (*   intro; simpl. *)
  (*   by repeat f_equiv. *)
  (* Qed. *)


  Program Definition interp_natop {A} (op : nat_op) (t1 t2 : A -n> IT) : A -n> IT :=
    λne env, NATOP (do_natop op) (t1 env) (t2 env).
  Solve All Obligations with solve_proper_please.

  Global Instance interp_natop_ne A op : NonExpansive2 (@interp_natop A op).
  Proof. solve_proper. Qed.
  Typeclasses Opaque interp_natop.

  Opaque laterO_map.
  Program Definition interp_rec_pre {S : Set} (body : @interp_scope F R _ (inc (inc S)) -n> IT)
    : laterO (@interp_scope F R _ S -n> IT) -n> @interp_scope F R _ S -n> IT :=
    λne self env, Fun $ laterO_map (λne (self : @interp_scope F R  _ S -n> IT) (a : IT),
                      body (@extend_scope F R _ _ (@extend_scope F R _ _ env (self env)) a)) self.
  Next Obligation.
    intros.
    solve_proper_prepare.
    f_equiv; intros [| [| y']]; simpl; solve_proper.
  Qed.
  Next Obligation.
    intros.
    solve_proper_prepare.
    f_equiv; intros [| [| y']]; simpl; solve_proper.
  Qed.
  Next Obligation.
    intros.
    solve_proper_prepare.
    do 3 f_equiv; intros ??; simpl; f_equiv;
    intros [| [| y']]; simpl; solve_proper.
  Qed.
  Next Obligation.
    intros.
    solve_proper_prepare.
    by do 2 f_equiv.
  Qed.

  Program Definition interp_rec {S : Set}
    (body : @interp_scope F R _ (inc (inc S)) -n> IT) :
    @interp_scope F R _ S -n> IT :=
    mmuu (interp_rec_pre body).

  Program Definition ir_unf {S : Set}
    (body : @interp_scope F R _ (inc (inc S)) -n> IT) env : IT -n> IT :=
    λne a, body (@extend_scope F R _ _
                   (@extend_scope F R _ _ env (interp_rec body env))
                   a).
  Next Obligation.
    intros.
    solve_proper_prepare.
    f_equiv. intros [| [| y']]; simpl; solve_proper.
  Qed.

  Lemma interp_rec_unfold {S : Set} (body : @interp_scope F R _ (inc (inc S)) -n> IT) env :
    interp_rec body env ≡ Fun $ Next $ ir_unf body env.
  Proof.
    trans (interp_rec_pre body (Next (interp_rec body)) env).
    { f_equiv. rewrite /interp_rec. apply mmuu_unfold. }
    simpl. rewrite laterO_map_Next. repeat f_equiv.
    simpl. unfold ir_unf. intro. simpl. reflexivity.
  Qed.

  Program Definition interp_app {A} (t1 t2 : A -n> IT) : A -n> IT :=
    λne env, APP' (t1 env) (t2 env).
  Solve All Obligations with first [ solve_proper | solve_proper_please ].
  Global Instance interp_app_ne A : NonExpansive2 (@interp_app A).
  Proof. solve_proper. Qed.
  Typeclasses Opaque interp_app.

  Program Definition interp_if {A} (t0 t1 t2 : A -n> IT) : A -n> IT :=
    λne env, IF (t0 env) (t1 env) (t2 env).
  Solve All Obligations with first [ solve_proper | solve_proper_please ].
  Global Instance interp_if_ne A n :
    Proper ((dist n) ==> (dist n) ==> (dist n) ==> (dist n)) (@interp_if A).
  Proof. solve_proper. Qed.

  Program Definition interp_nat (n : nat) {A} : A -n> IT :=
    λne env, Ret n.

  (* Program Definition interp_cont {A} (K : A -n> (IT -n> IT)) : A -n> IT := *)
  (*   λne env, (Fun (Next (λne x, Tau (laterO_map (K env) (Next x))))). *)
  (* Solve All Obligations with solve_proper_please. *)




  (* Program Definition interp_natoprk {A} (op : nat_op) *)
  (*   (q : A -n> IT) *)
  (*   (K : A -n> (IT -n> IT)) : A -n> (IT -n> IT) := *)
  (*   λne env t, interp_natop op q (λne env, K env t) env. *)
  (* Solve All Obligations with solve_proper. *)

  (* Program Definition interp_natoplk {A} (op : nat_op) *)
  (*   (K : A -n> (IT -n> IT)) *)
  (*   (q : A -n> IT) : A -n> (IT -n> IT) := *)
  (*   λne env t, interp_natop op (λne env, K env t) q env. *)
  (* Solve All Obligations with solve_proper. *)

  (* Program Definition interp_ifk {A} (K : A -n> (IT -n> IT)) (q : A -n> IT) *)
  (*   (p : A -n> IT) : A -n> (IT -n> IT) := *)
  (*   λne env t, interp_if (λne env, K env t) q p env. *)
  (* Solve All Obligations with solve_proper. *)


  (* Program Definition interp_throwlk {A} (K : A -n> (IT -n> IT)) (k : A -n> IT) : *)
  (*   A -n> (IT -n> IT) := *)
  (*   λne env t, interp_throw (λne env, K env t) k env. *)
  (* Solve All Obligations with solve_proper_please. *)

  (* Program Definition interp_throwrk {A} (e : A -n> IT) (K : A -n> (IT -n> IT)) : *)
  (*   A -n> (IT -n> IT) := *)
  (*   λne env t, interp_throw e (λne env, K env t) env. *)
  (* Solve All Obligations with solve_proper_please. *)

  (** Interpretation for all the syntactic categories: values, expressions, contexts *)
  Fixpoint interp_val {S} (v : val S) : interp_scope S -n> IT :=
    match v with
    | LitV n => interp_nat n
    | RecV e => interp_rec (interp_expr e)
    (* | ContV K => interp_cont (interp_ectx K) *)
    end
  with
  interp_expr {S} (e : expr S) : interp_scope S -n> IT :=
    match e with
    | Val v => interp_val v
    | Var x => interp_var x
    | App e1 e2 => interp_app (interp_expr e1) (interp_expr e2)
    | NatOp op e1 e2 => interp_natop op (interp_expr e1) (interp_expr e2)
    | If e e1 e2 => interp_if (interp_expr e) (interp_expr e1) (interp_expr e2)
    | Input => interp_input
    | Output e => interp_output (interp_expr e)
    | Shift e => interp_shift (interp_expr e)
    | Reset e => interp_reset (interp_expr e)
    end.
  Solve All Obligations with first [ solve_proper | solve_proper_please ].


  Program Definition interp_outputk {A} : (A -n> IT) -n> A -n> IT :=
    λne t env, interp_output t env.
  Solve All Obligations with solve_proper.

  Program Definition interp_apprk {A} (q : A -n> IT) : (A -n> IT) -n> A -n> IT :=
    λne t env, interp_app q t env.
  Solve All Obligations with solve_proper.

  Program Definition interp_applk {A} (q : A -n> IT) : (A -n> IT) -n> A -n> IT :=
    λne t env, interp_app t q env.
  Solve All Obligations with solve_proper.

  Program Definition interp_natoprk {A} (op : nat_op) (q : A -n> IT) :
    (A -n> IT) -n> A -n> IT :=
    λne t env, interp_natop op q t env.
  Solve All Obligations with solve_proper.

  Program Definition interp_natoplk {A} (op : nat_op) (q : A -n> IT) :
    (A -n> IT) -n> A -n> IT :=
    λne t env, interp_natop op t q env.
  Solve All Obligations with solve_proper.

  Program Definition interp_ifk {A} (e1 e2 : A -n> IT) :
    (A -n> IT) -n> A -n> IT :=
  λne b env, interp_if b e1 e2 env.
  Solve All Obligations with solve_proper.

  (* Program Definition interp_iftruek {A} (b e2 : A -n> IT) : *)
  (*   (A -n> IT) -n> A -n> IT := *)
  (* λne e1 env, interp_if b e1 e2 env. *)
  (* Solve All Obligations with solve_proper. *)

  (* Program Definition interp_iffalsek {A} (b e1 : A -n> IT) : *)
  (*   (A -n> IT) -n> A -n> IT := *)
  (* λne e2 env, interp_if b e1 e2 env. *)
  (* Solve All Obligations with solve_proper. *)

  Program Definition interp_resetk {A} : (A -n> IT) -n> A -n> IT :=
    λne t env, interp_reset t env.
  Solve All Obligations with solve_proper.

  Definition interp_ectx_el {S} (C : ectx_el S) :
    (interp_scope S -n> IT) -n> (interp_scope S) -n> IT :=
    match C with
    | OutputK => interp_outputk
    | AppRK e1 => interp_apprk (interp_expr e1)
    | AppLK e2 => interp_applk (interp_expr e2)
    | NatOpRK op e1 => interp_natoprk op (interp_expr e1)
    | NatOpLK op e2 => interp_natoplk op (interp_expr e2)
    | IfK e1 e2 => interp_ifk (interp_expr e1) (interp_expr e2)
    (* | IfTrueK b e2 => interp_iftruek (interp_expr b) (interp_expr e2) *)
    (* | IfFalseK b e1 => interp_iffalsek (interp_expr b) (interp_expr e1) *)
    | ResetK => interp_resetk
    end.


  Fixpoint interp_ectx' {S} (K : ectx S) :
    interp_scope S → IT → IT :=
    match K with
    | [] => λ env, idfun
    | C :: K => λ (env : interp_scope S) (t : IT),
                  (interp_ectx' K env) (interp_ectx_el C (λne env, t) env)
    end.
  #[export] Instance interp_ectx_1_ne {S} (K : ectx S) (env : interp_scope S) :
    NonExpansive (interp_ectx' K env : IT → IT).
  Proof. induction K; solve_proper_please. Qed.

  Definition interp_ectx {S} (K : ectx S) : interp_scope S → (IT -n> IT) :=
    λ env, OfeMor (interp_ectx' K env).

  Example test_ectx : ectx ∅ := [OutputK ; AppRK (RecV (Var VZ))].
  (* Eval cbv[test_ectx interp_ectx interp_ectx' interp_ectx_el *)
  (*            interp_apprk interp_outputk interp_output interp_app] in (interp_ectx test_ectx). *)
  (* Definition interp_ectx {S} (K : ectx S) : interp_scope S -n> IT -n> IT := *)
  (*   λne env e, *)
  (*     (fold_left (λ k c, λne (e : interp_scope S -n> IT), *)
  (*                   (interp_ectx_el c env) (λne env, k e)) K (λne t : , t)) e. *)

  (* Open Scope syn_scope. *)

  (* Example callcc_ex : expr ∅ := *)
  (*   NatOp + (# 1) (Callcc (NatOp + (# 1) (Throw (# 2) ($ 0)))). *)
  (* Eval cbn in callcc_ex. *)
  (* Eval cbn in interp_expr callcc_ex *)
  (*               (λne (x : leibnizO ∅), match x with end). *)

  Global Instance interp_val_asval {S} {D : interp_scope S} (v : val S)
    : AsVal (interp_val v D).
  Proof.
    destruct v; simpl.
    - apply _.
    - rewrite interp_rec_unfold. apply _.
  Qed.

  Global Instance ArrEquiv {A B : Set} : Equiv (A [→] B) :=
    fun f g => ∀ x, f x = g x.

  Global Instance ArrDist {A B : Set} `{Dist B} : Dist (A [→] B) :=
    fun n => fun f g => ∀ x, f x ≡{n}≡ g x.

  Global Instance ren_scope_proper {S S'} :
    Proper ((≡) ==> (≡) ==> (≡)) (@ren_scope F _ CR S S').
  Proof.
    intros D D' HE s1 s2 Hs.
    intros x; simpl.
    f_equiv.
    - apply Hs.
    - apply HE.
 Qed.

  Lemma interp_expr_ren {S S'} env
    (δ : S [→] S') (e : expr S) :
    interp_expr (fmap δ e) env ≡ interp_expr e (ren_scope δ env)
  with interp_val_ren {S S'} env
         (δ : S [→] S') (e : val S) :
    interp_val (fmap δ e) env ≡ interp_val e (ren_scope δ env).
  (* with interp_ectx_ren {S S'} env *)
  (*        (δ : S [→] S') (e : ectx S) : *)
  (*   interp_ectx (fmap δ e) env ≡ interp_ectx e (ren_scope δ env). *)
  Proof.
    - destruct e; simpl; try by repeat f_equiv.
      repeat f_equiv.
      intros ?; simpl.
      repeat f_equiv.
      simpl; rewrite interp_expr_ren.
      f_equiv.
      intros [| y]; simpl.
      + reflexivity.
      + reflexivity.
    - destruct e; simpl.
      + reflexivity.
      + clear -interp_expr_ren.
        apply bi.siProp.internal_eq_soundness.
        iLöb as "IH".
        rewrite {2}interp_rec_unfold.
        rewrite {2}(interp_rec_unfold (interp_expr e)).
        do 1 iApply f_equivI. iNext.
        iApply internal_eq_pointwise.
        rewrite /ir_unf. iIntros (x). simpl.
        rewrite interp_expr_ren.
        iApply f_equivI.
        iApply internal_eq_pointwise.
        iIntros (y').
        destruct y' as [| [| y]]; simpl; first done; last done.
        by iRewrite - "IH".
  Qed.


  Lemma interp_ectx_ren {S S'} env (δ : S [→] S') (K : ectx S) :
    interp_ectx (fmap δ K) env ≡ interp_ectx K (ren_scope δ env).
  Proof.
    (* unfold interp_ectx. intro. simpl. *)
    (* generalize env x. *)
    induction K; intros ?; simpl; eauto.
    destruct a; simpl.
    - etrans; first by apply IHK. repeat f_equiv. 
    - etrans; first by apply IHK. repeat f_equiv; by apply interp_expr_ren.
    - etrans; first by apply IHK. repeat f_equiv; by apply interp_val_ren.
    - etrans; first by apply IHK. repeat f_equiv; by apply interp_expr_ren.
    - etrans; first by apply IHK. repeat f_equiv; by apply interp_val_ren.
    - etrans; first by apply IHK. repeat f_equiv; by apply interp_expr_ren.
    - etrans; first by apply IHK. repeat f_equiv; by apply interp_expr_ren.
  Qed.


  Lemma interp_comp {S} (e : expr S) (env : interp_scope S) (K : ectx S):
    interp_expr (fill K e) env ≡ (interp_ectx K) env ((interp_expr e) env).
  Proof.
    revert env e.
    induction K; eauto.
    destruct a; simpl; intros env e'; by eapply IHK.
  Qed.

  Program Definition sub_scope {S S'} (δ : S [⇒] S') (env : interp_scope S')
    : interp_scope S := λne x, interp_expr (δ x) env.

  Global Instance SubEquiv {A B : Set} : Equiv (A [⇒] B) := fun f g => ∀ x, f x = g x.

  Global Instance sub_scope_proper {S S'} :
    Proper ((≡) ==> (≡) ==> (≡)) (@sub_scope S S').
  Proof.
    intros D D' HE s1 s2 Hs.
    intros x; simpl.
    f_equiv.
    - f_equiv.
      apply HE.
    - apply Hs.
 Qed.

  Lemma interp_expr_subst {S S'} (env : interp_scope S')
    (δ : S [⇒] S') e :
    interp_expr (bind δ e) env ≡ interp_expr e (sub_scope δ env)
  with interp_val_subst {S S'} (env : interp_scope S')
         (δ : S [⇒] S') e :
    interp_val (bind δ e) env ≡ interp_val e (sub_scope δ env).
  (* with interp_ectx_subst {S S'} (env : interp_scope S') *)
  (*        (δ : S [⇒] S') e : *)
  (*   interp_ectx (bind δ e) env ≡ interp_ectx e (sub_scope δ env). *)
  Proof.
    - destruct e; simpl; try by repeat f_equiv.
      repeat f_equiv.
      intros ?; simpl.
      repeat f_equiv.
      rewrite interp_expr_subst.
      f_equiv.
      intros [| x']; simpl.
      + reflexivity.
      + rewrite interp_expr_ren.
        f_equiv.
        intros ?; reflexivity.
    - destruct e; simpl.
      + reflexivity.
      + clear -interp_expr_subst.
        apply bi.siProp.internal_eq_soundness.
        iLöb as "IH".
        rewrite {2}interp_rec_unfold.
        rewrite {2}(interp_rec_unfold (interp_expr e)).
        do 1 iApply f_equivI. iNext.
        iApply internal_eq_pointwise.
        rewrite /ir_unf. iIntros (x). simpl.
        rewrite interp_expr_subst.
        iApply f_equivI.
        iApply internal_eq_pointwise.
        iIntros (y').
        destruct y' as [| [| y]]; simpl; first done.
        * by iRewrite - "IH".
        * do 2 rewrite interp_expr_ren.
          iApply f_equivI.
          iApply internal_eq_pointwise.
          iIntros (z).
          done.
  Qed.


  Lemma interp_ectx_subst {S S'} (env : interp_scope S') (δ : S [⇒] S') K :
    interp_ectx (bind δ K) env ≡ interp_ectx K (sub_scope δ env).
  Proof.
    induction K; simpl; intros ?; simpl; eauto.
    destruct a; simpl; try by eapply IHK.
    - etrans; first by eapply IHK. repeat f_equiv; by eapply interp_expr_subst.
    - etrans; first by eapply IHK. repeat f_equiv; by eapply interp_val_subst.
    - etrans; first by eapply IHK. repeat f_equiv; by eapply interp_expr_subst.
    - etrans; first by eapply IHK. repeat f_equiv; by eapply interp_val_subst.
    - etrans; first by eapply IHK. repeat f_equiv; by eapply interp_expr_subst.
  Qed.
  (* FIXME this is aweful. *)



  (** ** Interpretation is a homomorphism (for some constructors) *)

  #[global] Instance interp_ectx_hom_emp {S} env :
    IT_hom (interp_ectx ([] : ectx S) env).
  Proof.
    simple refine (IT_HOM _ _ _ _ _); intros; auto.
    simpl. f_equiv. intro. simpl.
    by rewrite laterO_map_id.
  Qed.

  #[global] Instance interp_ectx_hom_output {S} (K : ectx S) env :
    IT_hom (interp_ectx K env) ->
    IT_hom (interp_ectx (OutputK :: K) env).
  Proof.
    intros. simple refine (IT_HOM _ _ _ _ _); intros; simpl.
    - by rewrite !hom_tick.
    - rewrite !hom_vis.
      f_equiv. intro. simpl. rewrite -laterO_map_compose.
      do 2 f_equiv. by intro.
    - by rewrite !hom_err.
  Qed.

  #[global] Instance interp_ectx_hom_if {S}
    (K : ectx S) (e1 e2 : expr S) env :
    IT_hom (interp_ectx K env) ->
    IT_hom (interp_ectx (IfK e1 e2 :: K) env).
  Proof.
    intros. simple refine (IT_HOM _ _ _ _ _); intros; simpl.
    - by rewrite -hom_tick -IF_Tick.
    - trans (Vis op i (laterO_map (λne y,
        (λne t : IT, interp_ectx' K env (IF t (interp_expr e1 env) (interp_expr e2 env)))
          y) ◎ ko));
        last (simpl; do 3 f_equiv; by intro).
      by rewrite -hom_vis.
    - trans (interp_ectx' K env (Err e)); first (f_equiv; apply IF_Err).
      apply hom_err.
  Qed.


  #[global] Instance interp_ectx_hom_appr {S} (K : ectx S)
    (e : expr S) env :
    IT_hom (interp_ectx K env) ->
    IT_hom (interp_ectx (AppRK e :: K) env).
  Proof.
    intros. simple refine (IT_HOM _ _ _ _ _); intros; simpl.
    - by rewrite !hom_tick.
    - rewrite !hom_vis. f_equiv. intro x. simpl.
      by rewrite -laterO_map_compose.
    - by rewrite !hom_err.
  Qed.

  #[global] Instance interp_ectx_hom_appl {S} (K : ectx S)
    (v : val S) (env : interp_scope S) :
    IT_hom (interp_ectx K env) ->
    IT_hom (interp_ectx (AppLK v :: K) env).
  Proof.
    intros H. simple refine (IT_HOM _ _ _ _ _); intros; simpl.
    - rewrite -hom_tick. f_equiv. apply APP'_Tick_l. apply interp_val_asval.
    - trans (Vis op i (laterO_map (λne y,
        (λne t : IT, interp_ectx' K env (t ⊙ (interp_val v env)))
          y) ◎ ko));
        last (simpl; do 3 f_equiv; by intro).
      by rewrite -hom_vis.
    - trans (interp_ectx' K env (Err e));
        first (f_equiv; apply APP'_Err_l; apply interp_val_asval).
      apply hom_err.
  Qed.

  #[global] Instance interp_ectx_hom_natopr {S} (K : ectx S)
    (e : expr S) op env :
    IT_hom (interp_ectx K env) ->
    IT_hom (interp_ectx (NatOpRK op e :: K) env).
  Proof.
    intros H. simple refine (IT_HOM _ _ _ _ _); intros; simpl.
    - by rewrite !hom_tick.
    - rewrite !hom_vis. f_equiv. intro x. simpl.
      by rewrite -laterO_map_compose.
    - by rewrite !hom_err.
  Qed.

  #[global] Instance interp_ectx_hom_natopl {S} (K : ectx S)
    (v : val S) op (env : interp_scope S) :
    IT_hom (interp_ectx K env) ->
    IT_hom (interp_ectx (NatOpLK op v :: K) env).
  Proof.
    intros H. simple refine (IT_HOM _ _ _ _ _); intros; simpl.
    - rewrite -hom_tick. f_equiv. by rewrite -NATOP_ITV_Tick_l.
    - trans (Vis op0 i (laterO_map (λne y,
        (λne t : IT, interp_ectx' K env (NATOP (do_natop op) t (interp_val v env))) y) ◎ ko));
        last (simpl; do 3 f_equiv; by intro).
      rewrite NATOP_ITV_Vis_l hom_vis. f_equiv. intro. simpl.
      by rewrite -laterO_map_compose.
    - trans (interp_ectx' K env (Err e)).
      + f_equiv. by apply NATOP_Err_l, interp_val_asval.
      + apply hom_err.
  Qed.

  (* ResetK is not a homomorphism *)
  Lemma interp_ectx_reset_not_hom {S} env :
    IT_hom (interp_ectx ([ResetK] : ectx S) env) -> False.
  Proof.
    intros [ _ Hi _ _ ]. simpl in Hi.
    specialize (Hi (Ret 0)).
    rewrite hom_vis in Hi.
    apply bi.siProp.pure_soundness.
    iApply IT_tick_vis_ne.
    iPureIntro.
    symmetry.
    eapply Hi.
    Unshelve. apply bi.siProp_internal_eq.
  Qed.


  Lemma get_fun_ret' E A `{Cofe A} n : (∀ f, @get_fun E A _ f (core.Ret n) ≡ Err RuntimeErr).
  Proof.
    intros.
    by rewrite IT_rec1_ret.
  Qed.


  #[global] Instance interp_ectx_hom {S}
    (K : ectx S) env :
    ResetK ∉ K ->
    IT_hom (interp_ectx K env).
  Proof.
    intro.
    induction K; simpl; first apply IT_hom_idfun.
    apply not_elem_of_cons in H. destruct H as [H1 ?]. specialize (IHK H).
    destruct a; try apply _. contradiction.
  Qed.

  (** ** Finally, preservation of reductions *)
  Lemma interp_expr_head_step {S : Set} (env : interp_scope S) (e : expr S) e' σ σ' K n :
    head_step e σ K e' σ' K (n, 0) →
    interp_expr e env ≡ Tick_n n $ interp_expr e' env.
  Proof.
    inversion 1; cbn-[IF APP' INPUT Tick get_ret2].
    - (* app lemma *)
      subst.
      erewrite APP_APP'_ITV; last apply _.
      trans (APP (Fun (Next (ir_unf (interp_expr e1) env))) (Next $ interp_val v2 env)).
      { repeat f_equiv. apply interp_rec_unfold. }
      rewrite APP_Fun. simpl. rewrite Tick_eq. do 2 f_equiv.
      simplify_eq.
      rewrite !interp_expr_subst.
      f_equiv.
      intros [| [| x]]; simpl; [| reflexivity | reflexivity].
      rewrite interp_val_ren.
      f_equiv.
      intros ?; simpl; reflexivity.
    - (* the natop stuff *)
      simplify_eq.
      destruct v1,v2; try naive_solver. simpl in *.
      rewrite NATOP_Ret.
      destruct op; simplify_eq/=; done.
    - rewrite IF_True; last lia.
      reflexivity.
    - rewrite IF_False; last lia.
      reflexivity.
  Qed.

  Lemma interp_expr_fill_no_reify {S} K K' (env : interp_scope S) (e e' : expr S) σ σ' n :
    head_step e σ K e' σ' K' (n, 0) →
    ResetK ∉ K->
    interp_expr (fill K e) env ≡ Tick_n n $ interp_expr (fill K' e') env.
  Proof.
    inversion 1; subst; intros H1; rewrite !interp_comp;
      apply (interp_ectx_hom K' env) in H1.
    - rewrite <-hom_tick_n; last eauto.
      simpl. apply (interp_expr_head_step env) in H.
      by rewrite equiv_dist => n; f_equiv; move : n; apply equiv_dist.
    - rewrite <-hom_tick_n; last eauto. apply (interp_expr_head_step env) in H.
      by rewrite H.
    - rewrite <-hom_tick_n; last eauto. apply (interp_expr_head_step env) in H.
      by rewrite H.
    - rewrite <-hom_tick_n; last eauto. apply (interp_expr_head_step env) in H.
      by rewrite H.
  Qed.

  Opaque INPUT OUTPUT_ SHIFT RESET.
  Opaque extend_scope.
  Opaque Ret.

  Lemma interp_expr_fill_yes_reify {S} K K' env (e e' : expr S)
    (σ σ' : stateO) (σr : gState_rest sR_idx rs ♯ IT) n :
    head_step e σ K e' σ' K' (n, 1) →
    ResetK ∉ K->
    reify (gReifiers_sReifier rs)
      (interp_expr (fill K e) env) (gState_recomp σr (sR_state σ))
      ≡ (gState_recomp σr (sR_state σ'), Tick_n n $ interp_expr (fill K' e') env).
  Proof.
    intros Hst H1. apply (interp_ectx_hom K env) in H1.
    trans (reify (gReifiers_sReifier rs) (interp_ectx K env (interp_expr e env))
             (gState_recomp σr (sR_state σ))).
    { f_equiv. by rewrite interp_comp. }
    inversion Hst; simplify_eq; cbn-[gState_recomp].
    - trans (reify (gReifiers_sReifier rs) (INPUT (interp_ectx K' env ◎ Ret)) (gState_recomp σr (sR_state σ))).
      {
        repeat f_equiv; eauto.
        rewrite hom_INPUT.
        do 2 f_equiv. by intro.
      }
      rewrite reify_vis_eq //; first last.
      {
        epose proof (@subReifier_reify sz reify_io rs _ IT _ (inl ()) () (Next (interp_ectx K' env (Ret n0))) (NextO ◎ (interp_ectx K' env ◎ Ret)) σ σ' σr) as H.
        simpl in H.
        simpl.
        erewrite <-H; last first.
        - rewrite H7. reflexivity.
        - f_equiv;
          solve_proper.
      }
      repeat f_equiv. rewrite Tick_eq/=. repeat f_equiv.
      rewrite interp_comp.
      reflexivity.
    - trans (reify (gReifiers_sReifier rs) (interp_ectx K' env (OUTPUT n0)) (gState_recomp σr (sR_state σ))).
      {
        do 3 f_equiv; eauto.
        rewrite get_ret_ret//.
      }
      trans (reify (gReifiers_sReifier rs) (OUTPUT_ n0 (interp_ectx K' env (Ret 0))) (gState_recomp σr (sR_state σ))).
      {
        do 2 f_equiv; eauto.
        by rewrite hom_OUTPUT_.
      }
      rewrite reify_vis_eq //; last first.
      {
        epose proof (@subReifier_reify sz reify_io rs _ IT _ op_output
                       n0 (Next (interp_ectx K' env ((Ret 0))))
                       (constO (Next (interp_ectx K' env ((Ret 0)))))
                       σ (update_output n0 σ) σr) as H.
        simpl in H.
        simpl.
        erewrite <-H; last reflexivity.
        f_equiv.
        + intros ???. by rewrite /prod_map H0.
        + do 2 f_equiv. by intro.
      }
      repeat f_equiv. rewrite Tick_eq/=. repeat f_equiv.
      rewrite interp_comp.
      reflexivity.
    - match goal with
      | |- context G [ofe_mor_car _ _ (SHIFT) ?g] => set (f := g)
      end.
      match goal with
      | |- context G [(?s, _)] => set (gσ := s) end.
      (* Transparent SHIFT. *)
      (* unfold SHIFT. *)
      simpl.
      set (subEff1 := @subReifier_subEff sz reify_io rs subR).
      trans (reify (gReifiers_sReifier rs)
               (SHIFT_ f (laterO_map (λne y, interp_ectx K env y) ◎ idfun)) gσ).
      {
        do 2 f_equiv.
        rewrite -(@hom_SHIFT_ F R CR subEff1 idfun f _).
        by f_equiv.
      }
      rewrite reify_vis_eq//; last first.
      {
        simpl.
        epose proof (@subReifier_reify sz reify_io rs subR IT _
                       op_shift f _
                       (laterO_map (interp_ectx K env)) σ' σ' σr) as H.
        simpl in H.
        erewrite <-H; last reflexivity.
        f_equiv.
        + intros ???. by rewrite /prod_map H2.
        + do 3f_equiv; try done. by intro.
      }
      (* simpl.  *)
      (* rewrite interp_comp. *)
      f_equiv.
      rewrite -Tick_eq.
      unfold cont_to_rec.
      rewrite interp_expr_subst.
      Disable Notation "λit".
      simpl. f_equiv.
      (* rewrite laterO_map_Next. *)
      Transparent extend_scope.
      f_equiv.

      intros [| x]; term_simpl; last reflexivity.
      rewrite interp_rec_unfold.
      do 2 f_equiv. intro.
      Opaque extend_scope.
      simpl.
      rewrite laterO_map_Next -Tick_eq.
      rewrite interp_comp.
      symmetry. etrans; first by apply interp_ectx_ren.
      etrans; first by apply interp_ectx_ren.
      rewrite -hom_tick.
      match goal with
      | |- context G [(interp_ectx K ?e)] => set (env' := e)
      end.
      trans (interp_ectx K env' (Tick x)).
      + f_equiv. Transparent extend_scope.
        simpl. admit.
      + admit.
    - Transparent RESET. unfold RESET.
      trans (reify (gReifiers_sReifier rs)
               (RESET_ (laterO_map (λne y, interp_ectx' K' env y) ◎
                          (laterO_map (λne y, get_val idfun y)) ◎
                          idfun)
                  (Next (interp_val v env)))
            (gState_recomp σr (sR_state σ'))).
      {
        do 2 f_equiv; last done.
        rewrite !hom_vis. simpl. f_equiv.
        by intro x.
      }
      rewrite reify_vis_eq//; last first.
      {
        simpl.
        epose proof (@subReifier_reify sz reify_io rs subR IT _
                       op_reset (Next (interp_val v env)) _
                       (laterO_map (interp_ectx K' env) ◎
                                   laterO_map (get_val idfun)) σ' σ' σr) as H.
        simpl in H. erewrite <-H; last reflexivity.
        f_equiv.
        + intros ???. by rewrite /prod_map H0.
        + do 2 f_equiv. by intro x.
      }
      f_equiv.
      rewrite laterO_map_Next -Tick_eq. f_equiv.
      rewrite interp_comp. f_equiv.
      simpl. by rewrite get_val_ITV. 
  Qed.

  Lemma soundness {S} (e1 e2 : expr S) σ1 σ2 (σr : gState_rest sR_idx rs ♯ IT) n m (env : interp_scope S) :
    prim_step e1 σ1 e2 σ2 (n,m) →
    ssteps (gReifiers_sReifier rs)
              (interp_expr e1 env) (gState_recomp σr (sR_state σ1))
              (interp_expr e2 env) (gState_recomp σr (sR_state σ2)) n.
  Proof.
    Opaque gState_decomp gState_recomp.
    inversion 1; simplify_eq/=.
    {
      destruct (head_step_io_01 _ _ _ _ _ _ _ H2); subst.
      - assert (σ1 = σ2) as ->.
        { eapply head_step_no_io; eauto. }
        unshelve eapply (interp_expr_fill_no_reify K) in H2; first apply env.
        rewrite H2.
        rewrite interp_comp.
        eapply ssteps_tick_n.
      - inversion H2;subst.
        + eapply (interp_expr_fill_yes_reify K env _ _ _ _ σr) in H2.
          rewrite interp_comp.
          rewrite hom_INPUT.
          change 1 with (Nat.add 1 0). econstructor; last first.
          { apply ssteps_zero; reflexivity. }
          eapply sstep_reify.
          { Transparent INPUT. unfold INPUT. simpl.
            f_equiv. reflexivity. }
          simpl in H2.
          rewrite -H2.
          repeat f_equiv; eauto.
          rewrite interp_comp hom_INPUT.
          eauto.
        + eapply (interp_expr_fill_yes_reify K env _ _ _ _ σr) in H2.
          rewrite interp_comp. simpl.
          rewrite get_ret_ret.
          rewrite hom_OUTPUT_.
          change 1 with (Nat.add 1 0). econstructor; last first.
          { apply ssteps_zero; reflexivity. }
          eapply sstep_reify.
          { Transparent OUTPUT_. unfold OUTPUT_. simpl.
            f_equiv. reflexivity. }
          simpl in H2.
          rewrite -H2.
          repeat f_equiv; eauto.
          Opaque OUTPUT_.
          rewrite interp_comp /= get_ret_ret hom_OUTPUT_.
          eauto.
        + eapply (interp_expr_fill_yes_reify K env _ _ _ _ σr) in H2.
          rewrite !interp_comp interp_expr_subst.
          change 1 with (Nat.add 1 0). econstructor; last first.
          { apply ssteps_zero; reflexivity. }
          rewrite -interp_comp.
          eapply sstep_reify.
          { Transparent CALLCC. unfold CALLCC. rewrite interp_comp hom_vis.
            f_equiv. reflexivity.
          }
          rewrite H2.
          simpl.
          repeat f_equiv.
          rewrite -interp_expr_subst.
          rewrite interp_comp.
          reflexivity.
    }
    {
      rewrite !interp_comp.
      simpl.
      pose proof (interp_val_asval v (D := env)).
      rewrite get_val_ITV.
      simpl.
      rewrite get_fun_fun.
      simpl.
      change 2 with (Nat.add (Nat.add 1 1) 0).
      econstructor; last first.
      { apply ssteps_tick_n. }
      eapply sstep_reify; first (rewrite hom_vis; reflexivity).
      match goal with
      | |- context G [ofe_mor_car _ _ _ (Next ?f)] => set (f' := f)
      end.
      trans (reify (gReifiers_sReifier rs) (THROW (interp_val v env) (Next f')) (gState_recomp σr (sR_state σ2))).
      {
        f_equiv; last done.
        f_equiv.
        rewrite hom_vis.
        Transparent THROW.
        unfold THROW.
        simpl.
        repeat f_equiv.
        intros x; simpl.
        destruct ((subEff_outs ^-1) x).
      }
      rewrite reify_vis_eq; first (rewrite Tick_eq; reflexivity).
      simpl.
      match goal with
      | |- context G [(_, _, ?a)] => set (κ := a)
      end.
      epose proof (@subReifier_reify sz reify_io rs subR IT _
                     (inr (inr (inr (inl ())))) (Next (interp_val v env), Next f')
                     (Next (Tau (Next ((interp_ectx K' env) (interp_val v env)))))
                     (Empty_setO_rec _) σ2 σ2 σr) as H'.
      subst κ.
      simpl in H'.
      erewrite <-H'; last reflexivity.
      rewrite /prod_map.
      f_equiv; first solve_proper.
      do 2 f_equiv; first reflexivity.
      intro; simpl.
      f_equiv.
    }
  Qed.

End interp.
#[global] Opaque INPUT OUTPUT_ CALLCC THROW.
