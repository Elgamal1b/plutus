{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TemplateHaskell   #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}
module Language.PlutusTx.Coordination.Contracts.Swap(
    Swap(..),
    -- * Script
    swapValidator
    ) where

import qualified Language.PlutusTx            as PlutusTx
import qualified Language.PlutusTx.Prelude    as P
import           Ledger                       (Slot, PubKey, ValidatorScript (..))
import qualified Ledger                       as Ledger
import           Ledger.Validation            (OracleValue (..), PendingTx (..), PendingTxIn (..), PendingTxOut (..))
import qualified Ledger.Validation            as Validation
import qualified Ledger.Ada.TH                as Ada
import           Ledger.Ada.TH                (Ada)
import           Ledger.Value                 (Value)

import           Prelude                      (Bool (..), Eq (..), Integer)

data Ratio a = a :% a  deriving Eq

-- | A swap is an agreement to exchange cashflows at future dates. To keep
--  things simple, this is an interest rate swap (meaning that the cashflows are
--  interest payments on the same principal amount but with two different
--  interest rates, of which one is fixed and one is floating (varying with
--  time)) with only a single payment date.
--
--  At the beginning of the contract, the fixed rate is set to the expected
--  future value of the floating rate (so if the floating rate behaves as
--  expected, the two payments will be exactly equal).
--
data Swap = Swap
    { swapNotionalAmt     :: !Ada
    , swapObservationTime :: !Slot
    , swapFixedRate       :: !(Ratio Integer) -- ^ Interest rate fixed at the beginning of the contract
    , swapFloatingRate    :: !(Ratio Integer) -- ^ Interest rate whose value will be observed (by an oracle) on the day of the payment
    , swapMargin          :: !Ada -- ^ Margin deposited at the beginning of the contract to protect against default (one party failing to pay)
    , swapOracle          :: !PubKey -- ^ Public key of the oracle (see note [Oracles] in [[Language.PlutusTx.Coordination.Contracts]])
    }

-- | Identities of the parties involved in the swap. This will be the data
--   script which allows us to change the identities during the lifetime of
--   the contract (ie. if one of the parties sells their part of the contract)
--
--   In the future we could also put the `swapMargin` value in here to implement
--   a variable margin.
data SwapOwners = SwapOwners {
    swapOwnersFixedLeg :: !PubKey,
    swapOwnersFloating :: !PubKey
    }

type SwapOracle = OracleValue (Ratio Integer)

-- | Validator script for the two transactions that initialise the swap.
--   See note [Swap Transactions]
--   See note [Contracts and Validator Scripts] in
--       Language.Plutus.Coordination.Contracts
swapValidator :: Swap -> ValidatorScript
swapValidator _ = ValidatorScript result where
    result = $$(Ledger.compileScript [|| (\SwapOwners{..} (redeemer :: SwapOracle) (p :: PendingTx) Swap{..} ->
        let
            infixr 3 &&
            (&&) :: Bool -> Bool -> Bool
            (&&) = PlutusTx.and

            mn :: Integer -> Integer -> Integer
            mn = PlutusTx.min

            mx :: Integer -> Integer -> Integer
            mx = PlutusTx.max

            timesR :: Ratio Integer -> Ratio Integer -> Ratio Integer
            timesR (x :% y) (x' :% y') = (P.multiply x x') :% (P.multiply y y')

            plusR :: Ratio Integer -> Ratio Integer -> Ratio Integer
            plusR (x :% y) (x' :% y') = (P.plus (P.multiply x y') (P.multiply x' y)) :% (P.multiply y y')

            minusR :: Ratio Integer -> Ratio Integer -> Ratio Integer
            minusR (x :% y) (x' :% y') = (P.minus (P.multiply x y') (P.multiply x' y)) :% (P.multiply y y')

            extractVerifyAt :: OracleValue (Ratio Integer) -> PubKey -> Ratio Integer -> Slot -> Ratio Integer
            extractVerifyAt = PlutusTx.error ()

            round :: Ratio Integer -> Integer
            round = PlutusTx.error ()

            -- | Convert an [[Integer]] to a [[Ratio Integer]]
            fromInt :: Integer -> Ratio Integer
            fromInt = PlutusTx.error ()

            signedBy :: PendingTx -> PubKey -> Bool
            signedBy = $$(Validation.txSignedBy)

            adaValueIn :: Value -> Integer
            adaValueIn v = Ada.toInt (Ada.fromValue v)

            (||) :: Bool -> Bool -> Bool
            (||) = PlutusTx.or

            isPubKeyOutput :: PendingTxOut -> PubKey -> Bool
            isPubKeyOutput o k = PlutusTx.maybe False ($$(Validation.eqPubKey) k) ($$(Validation.pubKeyOutput) o)

            -- Verify the authenticity of the oracle value and compute
            -- the payments.
            rt = extractVerifyAt redeemer swapOracle swapFloatingRate swapObservationTime

            rtDiff :: Ratio Integer
            rtDiff = rt `minusR` swapFixedRate

            amt    = Ada.toInt swapNotionalAmt
            margin = Ada.toInt swapMargin

            amt' :: Ratio Integer
            amt' = fromInt amt

            delta :: Ratio Integer
            delta = amt' `timesR` rtDiff

            fixedPayment :: Integer
            fixedPayment = round (amt' `plusR` delta)

            floatPayment :: Integer
            floatPayment = round (amt' `plusR` delta)

            -- Compute the payouts (initial margin +/- the sum of the two
            -- payments), ensuring that it is at least 0 and does not exceed
            -- the total amount of money at stake (2 * margin)
            clamp :: Integer -> Integer
            clamp x = mn 0 (mx (P.multiply 2 margin) x)
            fixedRemainder = clamp (P.plus (P.minus margin fixedPayment) floatPayment)
            floatRemainder = clamp (P.plus (P.minus margin floatPayment) fixedPayment)

            -- The transaction must have one input from each of the
            -- participants.
            -- NOTE: Partial match is OK because if it fails then the PLC script
            --       terminates with `error` and the validation fails (which is
            --       what we want when the number of inputs and outputs is /= 2)
            PendingTx [t1, t2] [o1, o2] _ _ _ _ _ _ = p

            -- Each participant must deposit the margin. But we don't know
            -- which of the two participant's deposit we are currently
            -- evaluating (this script runs on both). So we use the two
            -- predicates iP1 and iP2 to cover both cases

            -- True if the transaction input is the margin payment of the
            -- fixed leg
            iP1 :: PendingTxIn -> Bool
            iP1 (PendingTxIn _ _ v) = signedBy p swapOwnersFixedLeg && PlutusTx.eq (adaValueIn v) margin

            -- True if the transaction input is the margin payment of the
            -- floating leg
            iP2 :: PendingTxIn -> Bool
            iP2 (PendingTxIn _ _ v) = signedBy p swapOwnersFloating && PlutusTx.eq (adaValueIn v) margin

            inConditions = (iP1 t1  && iP2 t2) || (iP1 t2 && iP2 t1)

            -- The transaction must have two outputs, one for each of the
            -- participants, which equal the margin adjusted by the difference
            -- between fixed and floating payment

            -- True if the output is the payment of the fixed leg.
            ol1 :: PendingTxOut -> Bool
            ol1 o@(PendingTxOut v _ _) = isPubKeyOutput o swapOwnersFixedLeg && PlutusTx.leq (adaValueIn v) fixedRemainder

            -- True if the output is the payment of the floating leg.
            ol2 :: PendingTxOut -> Bool
            ol2 o@(PendingTxOut v _ _) = isPubKeyOutput o swapOwnersFloating && PlutusTx.leq (adaValueIn v) floatRemainder

            -- NOTE: I didn't include a check that the slot is greater
            -- than the observation time. This is because the slot is
            -- already part of the oracle value and we trust the oracle.

            outConditions = (ol1 o1 && ol2 o2) || (ol1 o2 && ol2 o1)


        in
        if inConditions && outConditions then () else PlutusTx.error ()
        ) ||])

{- Note [Swap Transactions]

The swap involves three transactions at two different times.

1. At t=0. Each participant deposits the margin. The outputs are locked with
   the same validator script, `swapValidator`
2. At t=n. The value of the floating rate, and consequently the values of the
   two payments are determined. Each participant gets their margin plus or
   minus the actual payment.

There is a risk of losing out if the interest rate moves outside the range of
fixedRate +/- (margin / notional amount). In a real financial contract this
would be dealt with by agreeing a "Variation Margin". This means that the
margin is adjusted at predefined dates before the actual payment is due. If one
of the parties fails to make the variation margin payment, the contract ends
prematurely and the other party gets to keep both margins.

Plutus should be able to handle variation margins in a series of validation
scripts. But it seems to me that they could get quite messy so I don't want to
write them by hand :) We can probably use TH to generate them at compile time.

-}
