{-# LANGUAGE RankNTypes   #-}
{-# LANGUAGE TypeFamilies #-}
module Evaluation.Constant.AllTypedBuiltinSized where

import           Language.PlutusCore.Constant

import qualified Data.ByteString      as BS
import qualified Data.ByteString.Lazy as BSL
import           Hedgehog hiding (Size, Var, annotate)
import qualified Hedgehog.Gen   as Gen
import qualified Hedgehog.Range as Range

type AllTypedBuiltinSized = forall m a. Monad m => Size -> TypedBuiltinSized a -> PropertyT m a
-- Note that while this is just a generator, it can't return a @Gen a@, because
-- then we would need to apply 'forAll' to a generated value of abstract type @a@
-- which would force us to constrain @a@ to have a 'Show' instance which is really
-- inconvenient, because we would need to hardcode that constrain into the
-- 'TypeSchemeBuiltin' constructor or do something even sillier.
-- It is likely to be a deferred problem, but maybe we will never need to solve it.

newtype TheAllTypedBuiltinSized = TheAllTypedBuiltinSized
    { unTheAlltypedBuilinSized :: AllTypedBuiltinSized
    }

allTypedBuiltinSizedSize :: AllTypedBuiltinSized
allTypedBuiltinSizedSize size TypedBuiltinSizedSize = return size
allTypedBuiltinSizedSize _    tbs                   = fail $ concat
    [ "The generator for the following builtin is not implemented: "
    , show $ eraseTypedBuiltinSized tbs
    ]

class UpdateAllTypedBuiltinSized a where
    type RangeUpdater a

    updateAllTypedBuiltinSized
        :: TypedBuiltinSized a -- ^ Used as a @proxy@.
        -> RangeUpdater a
        -> AllTypedBuiltinSized
        -> AllTypedBuiltinSized

instance UpdateAllTypedBuiltinSized Integer where
    type RangeUpdater Integer = Integer -> Integer -> Gen Integer

    updateAllTypedBuiltinSized _ genInteger _      size TypedBuiltinSizedInt =
        let (low, high) = toBoundsInt size in
            forAll $ genInteger low (high - 1)
    updateAllTypedBuiltinSized _ _          allTbs size tbs                  =
        allTbs size tbs

instance UpdateAllTypedBuiltinSized BSL.ByteString where
    type RangeUpdater BSL.ByteString = Int -> Gen BS.ByteString

    updateAllTypedBuiltinSized _ genBytes _      size TypedBuiltinSizedBS =
        forAll . fmap BSL.fromStrict . genBytes $ fromIntegral size
    updateAllTypedBuiltinSized _ _        allTbs size tbs                 =
        allTbs size tbs

allTypedBuiltinSizedDef :: AllTypedBuiltinSized
allTypedBuiltinSizedDef
    = updateAllTypedBuiltinSized TypedBuiltinSizedInt
          (\low high -> Gen.integral $ Range.linear low high)
    $ updateAllTypedBuiltinSized TypedBuiltinSizedBS
          (Gen.bytes . Range.linear 0)
    $ allTypedBuiltinSizedSize

allTypedBuiltinSizedIntSum :: AllTypedBuiltinSized
allTypedBuiltinSizedIntSum
    = updateAllTypedBuiltinSized TypedBuiltinSizedInt
          (\low high -> Gen.integral $ Range.linear (low `div` 2) (high `div` 2))
    $ allTypedBuiltinSizedDef

allTypedBuiltinSizedIntDiv :: AllTypedBuiltinSized
allTypedBuiltinSizedIntDiv
    = updateAllTypedBuiltinSized TypedBuiltinSizedInt
          (\low high -> Gen.filter (/= 0) . Gen.integral $ Range.linear low high)
    $ allTypedBuiltinSizedDef
