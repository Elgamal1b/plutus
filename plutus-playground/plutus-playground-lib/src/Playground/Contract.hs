-- | Re-export functions that are needed when creating a Contract for use in the playground
module Playground.Contract
    ( mkFunction
    , ToSchema
    , Schema
    , ToJSON
    , FromJSON
    , FunctionSchema
    , Generic
    , payToPublicKey
    , MockWallet
    ) where

import           Control.Monad         (void)
import           Data.Aeson            (FromJSON, ToJSON)
import           Data.Swagger          (Schema, ToSchema)
import           GHC.Generics          (Generic)
import           Ledger.Types          (PubKey, Value)
import           Playground.API        (FunctionSchema)
import           Playground.TH         (mkFunction)
import           Wallet.API            (WalletAPI)
import qualified Wallet.API            as WAPI
import           Wallet.Emulator.Types (MockWallet)

payToPublicKey :: (Monad m, WalletAPI m) => Value -> PubKey -> m ()
payToPublicKey v = void . WAPI.payToPubKey v
