{-# LANGUAGE FlexibleContexts       #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE LambdaCase             #-}
{-# LANGUAGE OverloadedStrings      #-}
{-# LANGUAGE TemplateHaskell        #-}
module Language.PlutusTx.Compiler.Error (
    CompileError
    , Error (..)
    , WithContext (..)
    , withContext
    , withContextM
    , throwPlain
    , pruneContext) where

import qualified Language.PlutusIR.Compiler        as PIR

import qualified Language.PlutusCore               as PLC
import qualified Language.PlutusCore.Check.Uniques as PLC
import qualified Language.PlutusCore.Pretty        as PLC

import           Control.Lens
import           Control.Monad.Except

import qualified Data.Text                         as T
import qualified Data.Text.Prettyprint.Doc         as PP
import           Data.Typeable

-- | An error with some (nested) context. The integer argument to 'WithContextC' represents
-- the priority of the context when displaying it. Lower numbers are more prioritised.
data WithContext c e = NoContext e | WithContextC Int c (WithContext c e)
    deriving Functor
makeClassyPrisms ''WithContext

type CompileError = WithContext T.Text (Error ())

withContext :: (MonadError (WithContext c e) m) => Int -> c -> m a -> m a
withContext p c act = catchError act $ \err -> throwError (WithContextC p c err)

withContextM :: (MonadError (WithContext c e) m) => Int -> m c -> m a -> m a
withContextM p mc act = do
    c <- mc
    catchError act $ \err -> throwError (WithContextC p c err)

throwPlain :: MonadError (WithContext c e) m => e -> m a
throwPlain = throwError . NoContext

pruneContext :: Int -> WithContext c e -> WithContext c e
pruneContext prio = \case
    NoContext e -> NoContext e
    WithContextC p c e ->
        let inner = pruneContext prio e in if p > prio then inner else WithContextC p c inner

instance (PP.Pretty c, PP.Pretty e) => PP.Pretty (WithContext c e) where
    pretty = \case
        NoContext e     -> "Error:" PP.<+> (PP.align $ PP.pretty e)
        WithContextC _ c e -> PP.vsep [
            PP.pretty e,
            "Context:" PP.<+> (PP.align $ PP.pretty c)
            ]

data Error a = PLCError (PLC.Error a)
             | PIRError (PIR.Error (PIR.Provenance a))
             | CompilationError T.Text
             | UnsupportedError T.Text
             | FreeVariableError T.Text
             deriving Typeable
makeClassyPrisms ''Error

instance (PP.Pretty a) => PP.Pretty (Error a) where
    pretty = PLC.prettyPlcClassicDebug

instance PLC.AsTypeError CompileError () where
    _TypeError = _NoContext . _PLCError . PLC._TypeError

instance PLC.AsNormCheckError CompileError PLC.TyName PLC.Name () where
    _NormCheckError = _NoContext . _PLCError . PLC._NormCheckError

instance PLC.AsUniqueError CompileError () where
    _UniqueError = _NoContext . _PLCError . PLC._UniqueError

instance PIR.AsError CompileError (PIR.Provenance ()) where
    _Error = _NoContext . _PIRError

instance (PP.Pretty a) => PLC.PrettyBy PLC.PrettyConfigPlc (Error a) where
    prettyBy config = \case
        PLCError e -> PP.vsep [ "Error from the PLC compiler:", PLC.prettyBy config e ]
        PIRError e -> PP.vsep [ "Error from the PIR compiler:", PLC.prettyBy config e ]
        CompilationError e -> "Unexpected error during compilation, please report this to the Plutus team:" PP.<+> PP.pretty e
        UnsupportedError e -> "Unsupported feature:" PP.<+> PP.pretty e
        FreeVariableError e -> "Reference to a name which is not a local, a builtin, or an external INLINABLE function:" PP.<+> PP.pretty e
