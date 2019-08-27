\begin{code}
module Type.Equality where
\end{code}

## Fixity

\begin{code}
infix  1 _≡β_
\end{code}

## Imports

\begin{code}
open import Type
open import Type.RenamingSubstitution
open import Builtin.Constant.Type

open import Relation.Binary.PropositionalEquality
  renaming (subst to substEq) using (_≡_; refl; cong; cong₂; trans; sym)
\end{code}

## Beta equality relation for types

This serves as a declaritive specification of the semantics of types.

We need to give constructors for reflexivity, symmetry and
transitivity as the presence of the beta-rule prevents these
properties from being derivable. We have congruence rules for all
constructors of type (except variables as this is subsumed by
reflexivity). Finally, we have one computation rule: the beta-rule for
application.

\begin{code}
data _≡β_ {Γ} : ∀{J} → Γ ⊢⋆ J → Γ ⊢⋆ J → Set where

  -- structural rules

  refl≡β  : ∀{J}
    → (A : Γ ⊢⋆ J)
      ------------
    → A ≡β A
    
  sym≡β   : ∀{J}{A B : Γ ⊢⋆ J}
    → A ≡β B
      ------
    → B ≡β A
  trans≡β : ∀{J}{A B C : Γ ⊢⋆ J}
    → A ≡β B
    → B ≡β C
      ------
    → A ≡β C

  -- congruence rules

  -- (no variable rule is needed)
 
  ⇒≡β : {A A' B B' : Γ ⊢⋆ *}
    → A ≡β A'
    → B ≡β B'
      ---------------------
    → (A ⇒ B) ≡β (A' ⇒ B')
    
  Π≡β : ∀{J}{B B' : Γ ,⋆ J ⊢⋆ *} .x .x'
    → B ≡β B'
      -------
    → Π x B ≡β Π x' B'
    
  ƛ≡β : ∀{K J}{B B' : Γ ,⋆ J ⊢⋆ K} .x .x'
    → B ≡β B'
      ---------------
    → ƛ x B ≡β ƛ x' B'
    
  ·≡β : ∀{K J}{A A' : Γ ⊢⋆ K ⇒ J}{B B' : Γ ⊢⋆ K}
    → A ≡β A'
    → B ≡β B'
      --------------------
    → A · B ≡β A' · B'
    
  -- no μ1 rule is needed

  -- computation rule

  β≡β : ∀{K J} .x
    → (B : Γ ,⋆ J ⊢⋆ K)
    → (A : Γ ⊢⋆ J)
      ------------------------
    → ƛ x B · A ≡β B [ A ]
    
\end{code}

Let `p` and `q` range over proofs of type equality.

## Renaming for proofs of type equality

\begin{code}
ren≡β : ∀{Φ Ψ J}{A B : Φ ⊢⋆ J}
  → (ρ : ∀ {J} → Φ ∋⋆ J → Ψ ∋⋆ J)
  → A ≡β B
    ----------------------------
  → ren ρ A ≡β ren ρ B
ren≡β ρ (refl≡β A)    = refl≡β (ren ρ A)
ren≡β ρ (sym≡β p)     = sym≡β (ren≡β ρ p)
ren≡β ρ (trans≡β p q) = trans≡β (ren≡β ρ p) (ren≡β ρ q)
ren≡β ρ (⇒≡β p q)     = ⇒≡β (ren≡β ρ p) (ren≡β ρ q)
ren≡β ρ (Π≡β x x' p)  = Π≡β x x' (ren≡β (ext ρ) p)
ren≡β ρ (ƛ≡β x x' p)  = ƛ≡β x x' (ren≡β (ext ρ) p)
ren≡β ρ (·≡β p q)     = ·≡β (ren≡β ρ p) (ren≡β ρ q)
ren≡β ρ (β≡β x B A)     =
  substEq (ren ρ ((ƛ x B) · A) ≡β_)
          (trans (sym (subst-ren B))
                 (trans (subst-cong (ren-subst-cons ρ A) B)
                        (ren-subst B)))
          (β≡β x _ _)
\end{code}

## Substitution for proofs of type equality

\begin{code}
subst≡β : ∀{Φ Ψ J}{A B : Φ ⊢⋆ J}
 → (σ : ∀ {J} → Φ ∋⋆ J → Ψ ⊢⋆ J)
  → A ≡β B
    ----------------------------
  → subst σ A ≡β subst σ B
subst≡β σ (refl≡β A)    = refl≡β (subst σ A)
subst≡β σ (sym≡β p)     = sym≡β (subst≡β σ p)
subst≡β σ (trans≡β p q) = trans≡β (subst≡β σ p) (subst≡β σ q) 
subst≡β σ (⇒≡β p q)     = ⇒≡β (subst≡β σ p) (subst≡β σ q)
subst≡β σ (Π≡β x x' p)  = Π≡β x x' (subst≡β (exts σ) p)
subst≡β σ (ƛ≡β x x' p)  = ƛ≡β x x' (subst≡β (exts σ) p)
subst≡β σ (·≡β p q)     = ·≡β (subst≡β σ p) (subst≡β σ q)
subst≡β σ (β≡β x B A)   =
  substEq (subst σ ((ƛ x B) · A) ≡β_)
          (trans (trans (sym (subst-comp B))
                        (subst-cong (subst-subst-cons σ A) B))
          (subst-comp B))
          (β≡β x _ _)
\end{code}
