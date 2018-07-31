{-# LANGUAGE GADTs #-}
module Language.PlutusCore.Constant.Make
    ( toBoundsInt
    , makeBuiltinInt
    , makeBuiltinBS
    , makeBuiltinSize
    , makeDupBuiltinBool
    , makeConstant
    ) where

import           PlutusPrelude
import           Language.PlutusCore.Type
import           Language.PlutusCore.Name
import           Language.PlutusCore.Constant.Prelude
import           Language.PlutusCore.Constant.Typed

import qualified Data.ByteString.Lazy as BSL

-- | Return the @[-2^(8s - 1), 2^(8s - 1))@ bounds for integers of given size.
toBoundsInt :: Size -> (Integer, Integer)
toBoundsInt s = (-2 ^ p, 2 ^ p) where
    p = 8 * fromIntegral s - 1 :: Int

-- | Check whether an 'Integer' is in the @[-2^(8s - 1), 2^(8s - 1))@ interval.
checkBoundsInt :: Size -> Integer -> Bool
checkBoundsInt s i = low <= i && i < high where
    (low, high) = toBoundsInt s

checkBoundsBS :: Size -> BSL.ByteString -> Bool
checkBoundsBS = undefined

-- | Check whether an 'Integer' is in bounds (see 'checkBoundsInt') and return it as a term.
makeBuiltinInt :: Size -> Integer -> Maybe (Constant ())
makeBuiltinInt size int = checkBoundsInt size int ? BuiltinInt () size int

-- | Check whether a 'ByteString' is in bounds (see 'checkBoundsBS') and return it as a term.
makeBuiltinBS :: Size -> BSL.ByteString -> Maybe (Constant ())
makeBuiltinBS size bs = checkBoundsBS size bs ? BuiltinBS () size bs

-- | Check whether a 'Size' is a singleton and return it as a term.
makeBuiltinSize :: Size -> Size -> Maybe (Constant ())
makeBuiltinSize size size' = size == size' ? BuiltinSize () size

-- | Coerce a 'Bool' to PLC's @boolean@.
makeDupBuiltinBool :: Bool -> Value TyName Name ()
makeDupBuiltinBool b = dropFresh $ if b then getBuiltinTrue else getBuiltinFalse

-- | Coerce a Haskell value to a PLC constant indexed by size checking all constraints
-- (e.g. an `Integer` is in appropriate bounds) along the way.
makeSizedConstant :: Size -> TypedBuiltinSized a -> a -> Maybe (Constant ())
makeSizedConstant size TypedBuiltinSizedInt  int   = makeBuiltinInt  size int
makeSizedConstant size TypedBuiltinSizedBS   bs    = makeBuiltinBS   size bs
makeSizedConstant size TypedBuiltinSizedSize size' = makeBuiltinSize size size'

-- | Coerce a Haskell value to a PLC term checking all constraints
-- (e.g. an `Integer` is in appropriate bounds) along the way.
makeConstant :: TypedBuiltin Size a -> a -> Maybe (Value TyName Name ())
makeConstant (TypedBuiltinSized size tbs) x = Constant () <$> makeSizedConstant size tbs x
makeConstant TypedBuiltinBool             b = Just $ makeDupBuiltinBool b
