\begin{code}
module TermIndexedByNormalType.Main where
open import Agda.Builtin.IO
open import Agda.Builtin.Unit
open import Agda.Builtin.String

open import Type
open import Type.BetaNormal
open import TermIndexedByNormalType.Term
open import TermIndexedByNormalType.Term.Reduction

open import TermIndexedByNormalType.Evaluation
open import Builtin.Constant.Type
open import Builtin.Constant.Term
open import Builtin.Signature

open import Function
open import Agda.Builtin.Nat
open import Data.Nat
open import Agda.Builtin.Int
open import Data.Integer
open import Data.Product renaming (_,_ to _,,_)
open import Agda.Builtin.TrustMe
open import Relation.Binary.PropositionalEquality


postulate
  putStrLn : String → IO ⊤

{-# FOREIGN GHC import qualified Data.Text.IO as Text #-}
{-# FOREIGN GHC import qualified Data.Text as T #-}
{-# COMPILE GHC putStrLn = Text.putStrLn #-}

open import TermIndexedByNormalType.Examples

postulate
  str1 : ByteString
  str2 : ByteString

  printByteString : ByteString -> String

{-# FOREIGN GHC import qualified Data.ByteString.Char8 as BS #-}
{-# COMPILE GHC str1 = BS.pack "Hello, " #-}
{-# COMPILE GHC str2 = BS.pack "world"   #-}
{-# COMPILE GHC printByteString = T.pack . BS.unpack #-}

lemma1 : length str1 ≡ 7
lemma1 = primTrustMe 
lemma2 : length str2 ≡ 7
lemma2 = primTrustMe

constr1 : ∀{Γ} → Γ ⊢ con bytestring (size⋆ 16)
constr1 = con (bytestring 16 str1 (subst (λ x → x Data.Nat.≤ 16) (sym lemma1) (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s z≤n)))))))))

constr2 : ∀{Γ} → Γ ⊢ con bytestring (size⋆ 16)
constr2 = con (bytestring 16 str2 (subst (λ x → x Data.Nat.≤ 16) (sym lemma2) (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s (s≤s z≤n)))))))))

con1 : ∀{Γ} → Γ ⊢ con integer (size⋆ 8)
con1 = con (integer 8 (pos 1) (-≤+ ,, (+≤+ (s≤s (s≤s z≤n)))))

con2 : ∀{Γ} → Γ ⊢ con integer (size⋆ 8)
con2 = con (integer 8 (pos 2) (-≤+ ,, (+≤+ (s≤s (s≤s (s≤s z≤n))))))

builtin2plus2 : ∅ ⊢ con integer (size⋆ 8)
builtin2plus2 = builtin
  addInteger
  (λ { Z → size⋆ 8 ; (S x) → ne (` x)})
  (con2 ,, con2 ,, tt)

inc : ∅ ⊢ Π (con integer (ne (` Z)) ⇒ con integer (ne (` Z)))
inc = Λ (ƛ (builtin addInteger (ne ∘ `) ((builtin resizeInteger (λ { Z → (ne (` Z)) ; (S Z) → size⋆ 8 ; (S (S ()))}) (builtin sizeOfInteger (ne ∘ `) (` Z ,, tt) ,, (con1 ,, tt))) ,, (` Z) ,, tt)))

builtininc2' : ∅ ⊢ con integer (size⋆ 8)
builtininc2' = (inc ·⋆ size⋆ 8) · con2

printInt : (x : ∅ ⊢ con integer (size⋆ 8)) → Value x → ℤ
printInt .(con (integer 8 i x)) (V-con (integer .8 i x)) = i

printBS : (x : ∅ ⊢ con bytestring (size⋆ 16)) → Value x → String
printBS .(con (bytestring 16 b x)) (V-con (bytestring .16 b x)) =
  printByteString b

help :  (M : ∅ ⊢ con integer (size⋆ 8)) → Steps M → String
help M (steps x (done n v)) = show (printInt n v)
help M (steps x out-of-gas) = "out of gas..."
help M error                = "something went wrong..."

helpB :  (M : ∅ ⊢ con bytestring (size⋆ 16)) → Steps M → String
helpB M (steps x (done n v)) = printBS n v
helpB M (steps x out-of-gas) = "out of gas..."
helpB M error                = "something went wrong..."

main : IO ⊤
main = putStrLn (help _ (eval (gas 100) builtin2plus2))

\end{code}
