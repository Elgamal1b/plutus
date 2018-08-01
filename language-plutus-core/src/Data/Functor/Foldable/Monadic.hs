{-# LANGUAGE FlexibleContexts #-}

module Data.Functor.Foldable.Monadic ( cataM
                                   ) where

import           Data.Functor.Foldable
import           PlutusPrelude

-- | A monadic catamorphism
cataM :: (Recursive t, Traversable (Base t), Monad m) => (Base t a -> m a) -> (t -> m a)
cataM phi = c where c = phi <=< (traverse c . project)
