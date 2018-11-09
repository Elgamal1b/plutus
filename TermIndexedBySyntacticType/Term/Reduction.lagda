\begin{code}
module TermIndexedBySyntacticType.Term.Reduction where
\end{code}

## Imports

\begin{code}
open import Type
import Type.RenamingSubstitution as ⋆
open import TermIndexedBySyntacticType.Term
open import TermIndexedBySyntacticType.Term.RenamingSubstitution
open import Type.Equality

open import Relation.Binary.PropositionalEquality hiding ([_]) renaming (subst to substEq)
open import Data.Empty
open import Data.Product renaming (_,_ to _,,_)
open import Data.List hiding ([_]; take; drop)
\end{code}

## Values

\begin{code}
data Value :  ∀ {J Γ} {A : ∥ Γ ∥ ⊢⋆ J} → Γ ⊢ A → Set where

  V-ƛ : ∀ {Γ A B} {N : Γ , A ⊢ B}
      ---------------------------
    → Value (ƛ N)

  V-Λ_ : ∀ {Γ K} {B : ∥ Γ ∥ ,⋆ K ⊢⋆ *}
    → {N : Γ ,⋆ K ⊢ B}
      ----------------
    → Value (Λ N)

  V-wrap1 : ∀{Γ K}
   → {pat : ∥ Γ ∥ ⊢⋆ (K ⇒ *) ⇒ K ⇒ *}
   → {arg : ∥ Γ ∥ ⊢⋆ K}
   → {term : Γ ⊢ pat · (μ1 · pat) · arg}
   → Value (wrap1 pat arg term)

  V-con : ∀{Γ}{n}{tcn : TyCon}
    → (cn : TermCon (con tcn (size⋆ n)))
    → Value (con {Γ} cn)
\end{code}

## BUILTIN

\begin{code}
open import Agda.Builtin.Int

postulate
  append : ByteString → ByteString → ByteString
  take   : Int → ByteString → ByteString
  drop   : Int → ByteString → ByteString
  
{-# COMPILE GHC append = BS.append #-}
{-# COMPILE GHC take = BS.take #-}
{-# COMPILE GHC drop = BS.drop #-}

\end{code}

\begin{code}
open import Data.Unit
VTel : ∀ Γ Δ → ⋆.Sub ∥ Δ ∥ ∥ Γ ∥ → List (∥ Δ ∥ ⊢⋆ *) → Set
VTel Γ Δ σ [] = ⊤
VTel Γ Δ σ (A ∷ As) = Σ (Γ ⊢ ⋆.subst σ A) λ t → Value t × VTel Γ Δ σ As

open import Data.Integer
BUILTIN : ∀{Γ Γ'}
    → (bn : Builtin)
    → let Δ ,, As ,, C = El bn Γ in
      (σ : ⋆.Sub ∥ Δ ∥ ∥ Γ ∥)
    → (vtel : VTel Γ Δ σ As)
    → (σ' : ⋆.Sub ∥ Γ ∥ ∥ Γ' ∥)
      -----------------------------
    → Γ' ⊢ ⋆.subst σ' (⋆.subst σ C)
BUILTIN addInteger σ X σ' with σ Z
BUILTIN addInteger σ (_ ,, V-con (integer s i) ,, _ ,, V-con (integer .s j) ,, tt) σ' | .(size⋆ s) =
  con (integer s (i + j))
BUILTIN subtractInteger σ X σ' with σ Z
BUILTIN subtractInteger σ (_ ,, V-con (integer s i) ,, _ ,, V-con (integer .s j) ,, tt) σ' | .(size⋆ s) =
  con (integer s (i - j))
BUILTIN multiplyInteger σ X σ' with σ Z
BUILTIN multiplyInteger σ (_ ,, V-con (integer s i) ,, _ ,, V-con (integer .s j) ,, tt) σ' | .(size⋆ s) =
  con (integer s (_*_ i j))
BUILTIN concatenate σ X σ' with σ Z
BUILTIN concatenate σ (_ ,, V-con (bytestring s b) ,, _ ,, V-con (bytestring .s b') ,, tt) σ' | .(size⋆ s) =
  con (bytestring s (append b b'))
BUILTIN takeByteString σ X σ' with σ Z | σ (S Z)
BUILTIN takeByteString σ (_ ,, V-con (integer s i) ,, _ ,, V-con (bytestring s' b) ,, tt) σ'
  | .(size⋆ s')
  | .(size⋆ s) = con (bytestring s' (take i b))
BUILTIN dropByteString σ X σ' with σ Z | σ (S Z) 
BUILTIN dropByteString σ (_ ,, V-con (integer s i) ,, _ ,, V-con (bytestring s' b) ,, tt) σ'
  | .(size⋆ s')
  | .(size⋆ s) = con (bytestring s' (drop i b))
\end{code}

# recontructing the telescope after a reduction step

\begin{code}
reconstTel : ∀{Δ As} Bs Ds
    →  (σ : ⋆.Sub ∥ Δ ∥ ∥ ∅ ∥)
    → (vtel : VTel ∅ Δ σ Bs)
    → ∀{C}(t' : ∅ ⊢ ⋆.subst σ C)
    → (p : Bs ++ (C ∷ Ds) ≡ As)
    → (tel' : Tel ∅ Δ σ Ds)
    → Tel ∅ Δ σ As
reconstTel [] Ds σ vtel t' refl tel' = t' ,, tel'
reconstTel (B ∷ Bs) Ds σ (X ,, VX ,, vtel) t' refl tel' =
  X ,, reconstTel Bs Ds σ vtel t' refl tel'
\end{code}

## Intrinsically Type Preserving Reduction

\begin{code}
infix 2 _—→_

data _—→_ : ∀ {J Γ} {A : ∥ Γ ∥ ⊢⋆ J} → (Γ ⊢ A) → (Γ ⊢ A) → Set where

  ξ-·₁ : ∀ {Γ A B} {L L′ : Γ ⊢ A ⇒ B} {M : Γ ⊢ A}
    → L —→ L′
      -----------------
    → L · M —→ L′ · M

  ξ-·₂ : ∀ {Γ A B} {V : Γ ⊢ A ⇒ B} {M M′ : Γ ⊢ A}
    → Value V
    → M —→ M′
      ---------------
    → V · M —→ V · M′

  ξ-·⋆ : ∀ {Γ B}{L L′ : Γ ⊢ Π B}{A}
    → L —→ L′
      -----------------
    → L ·⋆ A —→ L′ ·⋆ A
    
  β-ƛ : ∀ {Γ A B} {N : Γ , A ⊢ B} {W : Γ ⊢ A}
    → Value W
      --------------------
    → (ƛ N) · W —→ N [ W ]

  β-Λ : ∀ {Γ}{B : ∥ Γ ∥ ,⋆ * ⊢⋆ *}{N : Γ ,⋆ * ⊢ B}{W}
      ----------------------
    → (Λ N) ·⋆ W —→ N [ W ]⋆

  β-wrap1 : ∀{Γ K}
    → {pat : ∥ Γ ∥ ⊢⋆ (K ⇒ *) ⇒ K ⇒ *}
    → {arg : ∥ Γ ∥ ⊢⋆ K}
    → {term : Γ ⊢ pat · (μ1 · pat) · arg}
    → unwrap1 (wrap1 pat arg term) —→ term

  ξ-unwrap1 : ∀{Γ K}
    → {pat : ∥ Γ ∥ ⊢⋆ (K ⇒ *) ⇒ K ⇒ *}
    → {arg : ∥ Γ ∥ ⊢⋆ K}
    → {M M' : Γ ⊢ μ1 · pat · arg}
    → M —→ M'
    → unwrap1 M —→ unwrap1 M'


  β-builtin : ∀{Γ'}
    → (bn : Builtin)
    → let Δ ,, As ,, C = El bn ∅ in
      (σ : ⋆.Sub ∥ Δ ∥ ∥ ∅ ∥)
    → (tel : Tel ∅ Δ σ As)
    → (vtel : VTel ∅ Δ σ As)
    → (σ' : ⋆.Sub ∥ ∅ ∥ ∥ Γ' ∥)
      -----------------------------
    → builtin {Γ'} bn σ tel σ' —→ BUILTIN bn σ vtel σ'

  ξ-builtin : ∀{Γ'}  → (bn : Builtin)
    → let Δ ,, As ,, C = El bn ∅ in
      (σ : ⋆.Sub ∥ Δ ∥ ∥ ∅ ∥)
    → (tel : Tel ∅ Δ σ As)
    → (σ' : ⋆.Sub ∥ ∅ ∥ ∥ Γ' ∥)
    → ∀ Bs Ds
    → (vtel : VTel ∅ Δ σ Bs)
    → ∀{C}{t t' : ∅ ⊢ ⋆.subst σ C}
    → t —→ t'
    → (p : Bs ++ (C ∷ Ds) ≡ As)
    → (tel' : Tel ∅ Δ σ Ds)
    → builtin {Γ'} bn σ tel σ'
      —→
      builtin {Γ'} bn σ (reconstTel Bs Ds σ vtel t' p tel') σ'
\end{code}


\begin{code}
data Progress {A : ∅ ⊢⋆ *} (M : ∅ ⊢ A) : Set where
  step : ∀ {N}
    → M —→ N
      -------------
    → Progress M
  done :
      Value M
      ----------
    → Progress M
  unhandled : Progress M 
\end{code}

\begin{code}

data TelProgress {Γ}{Δ}{σ : ⋆.Sub ∥ Δ ∥ ∥ Γ ∥}{As : List (∥ Δ ∥ ⊢⋆ *)}(tel : Tel Γ Δ σ As) : Set where
   done : VTel Γ Δ σ As → TelProgress tel
   step : ∀ Bs Ds
     → VTel Γ Δ σ Bs
     → ∀{C}{t t' : Γ ⊢ ⋆.subst σ C}
     → t —→ t'
     → Bs ++ (C ∷ Ds) ≡ As
     → Tel Γ Δ σ Ds
     → TelProgress tel
   unhandled : TelProgress tel

progress : ∀ {A} → (M : ∅ ⊢ A) → Progress M
progressTel : ∀ {Δ}{σ : ⋆.Sub ∥ Δ ∥ ∥ ∅ ∥}{As : List (∥ Δ ∥ ⊢⋆ *)}
  → (tel : Tel ∅ Δ σ As) → TelProgress tel

progressTel {As = []}    tel = done tt
progressTel {As = A ∷ As} (t ,, tel) with progress t
progressTel {σ = _} {A ∷ As} (t ,, tel) | step p = step [] As tt p refl tel
progressTel {σ = _} {A ∷ As} (t ,, tel) | done vt with progressTel tel
progressTel {σ = _} {A ∷ As} (t ,, tel) | done vt | done vtel =
  done (t ,, vt ,, vtel)
progressTel {σ = _} {A ∷ As} (t ,, tel) | done vt | step Bs Ds vtel p refl tel' =
  step (A ∷ Bs) Ds (t ,, vt ,, vtel) p refl tel'
progressTel {σ = _} {A ∷ As} (t ,, tel) | done vt | unhandled = unhandled
progressTel {σ = _} {A ∷ As} (t ,, tel) | unhandled = unhandled

progress (` ())
progress (ƛ M)    = done V-ƛ
progress (L · M)  with progress L
...                   | unhandled = unhandled
...                   | step p  = step (ξ-·₁ p)
progress (.(ƛ _) · M) | done V-ƛ with progress M
progress (.(ƛ _) · M) | done V-ƛ | step p = step (ξ-·₂ V-ƛ p)
progress (.(ƛ _) · M) | done V-ƛ | done VM = step (β-ƛ VM)
progress (.(ƛ _) · M) | done V-ƛ | unhandled = unhandled
progress (Λ M)    = done V-Λ_
progress (M ·⋆ A) with progress M
progress (M ·⋆ A) | step p = step (ξ-·⋆ p)
progress (.(Λ _) ·⋆ A) | done V-Λ_ = step β-Λ
progress (M ·⋆ A) | unhandled = unhandled
progress (wrap1 _ _ t) = done V-wrap1
progress (unwrap1 t) with progress t
progress (unwrap1 t) | step p = step (ξ-unwrap1 p)
progress (unwrap1 .(wrap1 _ _ _)) | done V-wrap1 = step β-wrap1
progress (unwrap1 t) | unhandled = unhandled
progress (conv p t) = unhandled
progress (con (integer s i)) = done (V-con _)
progress (con (bytestring s x)) = done (V-con _)
progress (con (size s)) = done (V-con _)
progress (builtin bn σ X σ') with progressTel X
progress (builtin bn σ X σ') | done VX = step (β-builtin bn σ X VX σ')
progress (builtin bn σ X σ') | step Bs Ds vtel p q tel' = step (ξ-builtin bn σ X σ' Bs Ds vtel p q tel')
progress (builtin bn σ X σ') | unhandled          = unhandled

open import Data.Maybe

-- does this lose the trace of the progress?
-- perhaps we should instead, return either a completed VTel,
-- or a step and the pieces, or fail, maybe inductively defined

progressTelSilent : ∀ Δ (σ : ⋆.Sub ∥ Δ ∥ ∥ ∅ ∥)(G : List (∥ Δ ∥ ⊢⋆ *))
  → Tel ∅ Δ σ G
  → Maybe (Σ (List (∥ Δ ∥ ⊢⋆ *)) λ G1 →
    Σ (List (∥ Δ ∥ ⊢⋆ *)) λ G2 → 
    G1 ++ G2 ≡ G
    ×
    VTel ∅ Δ σ G1
    ×
    Tel ∅ Δ σ G2)
    
progressTelSilent Δ σ [] tt = just ([] ,, [] ,, refl ,, tt ,, tt)
progressTelSilent Δ σ (A ∷ G) (t ,, tel) with progress t
progressTelSilent Δ σ (A ∷ G) (t ,, tel) | step {N = N} p =
  just ([] ,, A ∷ G ,, refl ,, tt ,, N ,, tel)
progressTelSilent Δ σ (A ∷ G) (t ,, tel) | done v with progressTelSilent Δ σ G tel
... | just (G1 ,, G2 ,, refl ,, vtel ,, tel') = just (A ∷ G1 ,, G2 ,, refl ,, (t ,, v ,, vtel) ,, tel')
... | nothing = nothing
progressTelSilent Δ σ (x ∷ G) (t ,, tel) | unhandled = nothing
\end{code}
