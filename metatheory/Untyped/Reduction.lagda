\begin{code}
module Untyped.Reduction where
\end{code}

\begin{code}
open import Untyped
open import Untyped.RenamingSubstitution
open import Builtin
open import Builtin.Constant.Type hiding (length)

open import Data.Bool using (Bool;true;false)
open import Data.Nat using (ℕ;suc;zero;_<_)
open import Data.Integer using (_+_;_-_;_*_;∣_∣;_<?_;_≤?_;_≟_)
open import Data.Product renaming (proj₁ to fst; proj₂ to snd)
open import Data.Sum renaming (inj₁ to inl; inj₂ to inr)
open import Data.List hiding ([_]; take; drop)
open import Data.Unit hiding (_≤_; _≤?_; _≟_)
open import Function
open import Relation.Binary.PropositionalEquality hiding ([_];trans)
open import Utils
open import Data.Fin using ()
\end{code}

\begin{code}
infix 2 _—→_
\end{code}


\begin{code}
-- for untyped reduction, error also includes thing like impossible
-- applications
data Error {n} : n ⊢ → Set where
  E-error : Error error

\end{code}

\begin{code}
data Value {n} : n ⊢ → Set where
  V-ƛ : ∀(t : suc n ⊢) → Value (ƛ t)
  V-con : (tcn : TermCon) → Value (con {n} tcn)
  V-builtin : (b : Builtin)
              (ts : List (n ⊢))
              → length ts < arity b
              → Value (builtin b ts)

VTel : ∀ n → Tel n → Set
VTel n []       = ⊤
VTel n (t ∷ ts) = Value {n} t × VTel n ts

BUILTIN : ∀{n}
    → (bn : Builtin)
    → (tel : Tel n)
    → VTel n tel
      --------------
    → n ⊢

data _—→_ {n} : n ⊢ → n ⊢ → Set where
  ξ-·₁ : {L L' M : n ⊢} → L —→ L' → L · M —→ L' · M
  ξ-·₂ : {L M M' : n ⊢} → Value L → M —→ M' → L · M —→ L · M'

  β-ƛ : ∀{L : suc n ⊢}{V : n ⊢} → Value V → ƛ L · V —→ L [ V ]

  ξ-builtin : (b : Builtin)
              (ts : Tel n)
              {ts' : Tel n}
              (vs : VTel n ts')
              {t t' : n ⊢}
            → t —→ t'
            → (ts'' : Tel n)
            → ts ≡ ts' ++ Data.List.[ t ] ++ ts''
            → builtin b ts —→
                builtin b (ts' ++ Data.List.[ t' ] ++ ts'')
  β-builtin : {b : Builtin}
              (ts : Tel n)
            → length ts ≡ arity b
            → (vs : VTel n ts)
            → builtin b ts —→ BUILTIN b ts vs

  sat-builtin : {b : Builtin}
                {ts : List (n ⊢)}
                {t : n ⊢}
              → length ts < arity b
              → builtin b ts · t —→ builtin b (ts ++ Data.List.[ t ])

  E-·₁ : {M : n ⊢} → error · M —→ error
  E-·₂ : {L : n ⊢} → Value L → L · error —→ error
  E-builtin : (b : Builtin)
              (ts : Tel n)
              {ts' : Tel n}
              (vs : VTel n ts')
              {t : n ⊢}
            → Error t
            → (ts'' : Tel n)
            -- → ts ≡ ts' ++ Data.List.[ t ] ++ ts'' -- TODO
            → builtin b ts —→ error

  -- these correspond to type errors encountered at runtime
  E-con : {tcn : TermCon}{L : n ⊢} → con tcn · L —→ error

  -- this is a runtime type error that ceases to be a type error after erasure
  -- E-runtime : {L : n ⊢} → L —→ error

\end{code}


\begin{code}
data _—→⋆_ {n} : n ⊢ → n ⊢ → Set where
  refl  : {t : n ⊢} → t —→⋆ t
  trans : {t t' t'' : n ⊢} → t —→ t' → t' —→⋆ t'' → t —→⋆ t''
\end{code}

\begin{code}
VERIFYSIG : ∀{n} → Maybe Bool → n ⊢
VERIFYSIG (just Bool.false) = plc_false 
VERIFYSIG (just Bool.true)  = plc_true 
VERIFYSIG nothing           = error

BUILTIN addInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , _)
  = con (integer (i + j))
BUILTIN subtractInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , _)
  = con (integer (i - j))
BUILTIN multiplyInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , _)
  = con (integer (i * j))
BUILTIN divideInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , _)
  = decIf (∣ j ∣ Data.Nat.≟ zero) error (con (integer (div i j)))
BUILTIN quotientInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , _)
  = decIf (∣ j ∣ Data.Nat.≟ zero) error (con (integer (quot i j)))
BUILTIN remainderInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , _)
  = decIf (∣ j ∣ Data.Nat.≟ zero) error (con (integer (rem i j)))
BUILTIN modInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , _)
  = decIf (∣ j ∣ Data.Nat.≟ zero) error (con (integer (mod i j)))
BUILTIN lessThanInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , tt) =
  decIf (i <? j) plc_true plc_false 
BUILTIN lessThanEqualsInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , tt) =
  decIf (i ≤? j) plc_true plc_false 
BUILTIN greaterThanInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , tt) =
  decIf (i Builtin.Constant.Type.>? j) plc_true plc_false 
BUILTIN greaterThanEqualsInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , tt) =
  decIf (i Builtin.Constant.Type.≥? j) plc_true plc_false 
BUILTIN equalsInteger (_ ∷ _ ∷ []) (V-con (integer i) , V-con (integer j) , tt) =
  decIf (i ≟ j) plc_true plc_false 
BUILTIN concatenate (_ ∷ _ ∷ []) (V-con (bytestring b) , V-con (bytestring b') , tt) =
  con (bytestring (append b b'))
BUILTIN takeByteString (_ ∷ _ ∷ []) (V-con (integer i) , V-con (bytestring b) , tt) =
  con (bytestring (take i b))
BUILTIN dropByteString (_ ∷ _ ∷ []) (V-con (integer i) , V-con (bytestring b) , tt) =
  con (bytestring (drop i b))
BUILTIN sha2-256 (_ ∷ []) (V-con (bytestring b) , tt) = con (bytestring (SHA2-256 b))
BUILTIN sha3-256 (_ ∷ []) (V-con (bytestring b) , tt) = con (bytestring (SHA3-256 b))
BUILTIN verifySignature (_ ∷ _ ∷ _ ∷ []) (V-con (bytestring k) , V-con (bytestring d) , V-con (bytestring c) , tt) = VERIFYSIG (verifySig k d c)
BUILTIN equalsByteString (_ ∷ _ ∷ []) (V-con (bytestring b) , V-con (bytestring b') , tt) =
  con (bool (equals b b'))
BUILTIN ifThenElse (_ ∷ t ∷ _ ∷ []) (V-con (bool true)  , vt , _ , tt) = t
BUILTIN ifThenElse (_ ∷ _ ∷ u ∷ []) (V-con (bool false) , _ , vu , tt) = u
BUILTIN _ _ _ = error

data ProgList {n} (tel : Tel n) : Set where
  done : VTel n tel → ProgList tel
  step : (tel' : Tel n) → VTel n tel' → {t t' : n ⊢} → t —→ t' → (tel'' : Tel n)
    → tel ≡ tel' ++ Data.List.[ t ] ++ tel'' → ProgList tel 
  error : (tel' : Tel n) → VTel n tel' → {t : n ⊢} → Error t → (tel'' : Tel n)
    → tel ≡ tel' ++ Data.List.[ t ] ++ tel''
    → ProgList tel

data Progress {n}(M : n ⊢) : Set where
  step : ∀{N}
    → M —→ N
      -------------
    → Progress M
  done :
      Value M
      ----------
    → Progress M
  error :
      Error M
      -------
    → Progress M

progress-·V : ∀{n}
  → {t : n ⊢} → Value t
  → {u : n ⊢} → Progress u
  → Progress (t · u)
progress-·V v                  (step q)        = step (ξ-·₂ v q)
progress-·V v                  (error E-error) = step (E-·₂ v)
progress-·V (V-ƛ t)            (done v)        = step (β-ƛ v)
progress-·V (V-con tcn)        (done v)        = step E-con
progress-·V (V-builtin b ts p) (done v)        = step (sat-builtin p)

progress-· : ∀{n}
  → {t : n ⊢} → Progress t
  → {u : n ⊢} → Progress u
  → Progress (t · u)
progress-· (done v)        q = progress-·V v q
progress-· (step p)        q = step (ξ-·₁ p)
progress-· (error E-error) q = step E-·₁

progress : (t : 0 ⊢) → Progress t
progressList : (tel : Tel 0) → ProgList {0} tel

progressList []       = done _
progressList (t ∷ ts) with progress t
progressList (t ∷ ts) | done vt with progressList ts
progressList (t ∷ ts) | done vt | done vs   = done (vt , vs)
progressList (t ∷ ts) | done vt | step  ts' vs p ts'' p' =
  step (t ∷ ts') (vt , vs) p ts'' (cong (t ∷_) p')
progressList (t ∷ ts) | done vt | error ts' vs e ts'' p =
  error (t ∷ ts') (vt , vs) e ts'' (cong (t ∷_) p)
progressList (t ∷ ts) | error e = error [] _ e ts refl
progressList (t ∷ ts) | step p = step [] _ p ts refl

progress (` ())
progress (ƛ t)        = done (V-ƛ t)
progress (t · u)      = progress-· (progress t) (progress u)
progress (con tcn)    = done (V-con tcn)
progress (builtin b ts) with progressList ts
progress (builtin b ts) | done vs with length ts Data.Nat.≤? arity b
progress (builtin b ts) | done vs | does Relation.Nullary.Dec.because proof = ? --step (β-builtin ts {!!} vs)
progress (builtin b ts) | step  ts' vs p ts'' p' =
  step (ξ-builtin b ts vs p ts'' p')
progress (builtin b ts) | error ts' vs e ts'' p =
  step (E-builtin b ts vs e ts'')
progress error       = error E-error
\end{code}

\begin{code}
run : ∀(t : 0 ⊢) → ℕ
  → Σ (0 ⊢) λ t' → t —→⋆ t' × (Maybe (Value t') ⊎ Error t')
run t 0       = t , refl , inl nothing
run t (suc n) with progress t
run t (suc n) | done vt = t , refl , inl (just vt)
run t (suc n) | error et = t , refl , inr et
run t (suc n) | step {N = t'} p with run t' n
run t (suc n) | step p | t'' , q , mvt'' = t'' , trans p q , mvt''
\end{code}

\begin{code}
open import Data.Empty
open import Relation.Nullary

-- a value cannot make progress

val-red : ∀{n}{t : n ⊢} → Value t → ¬ (Σ (n ⊢)  (t —→_))
val-red (V-builtin b ts p) (fst₁ , snd₁) = {!!}
\end{code}
