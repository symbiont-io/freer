{-# LANGUAGE DataKinds        #-}
{-# LANGUAGE DeriveFunctor    #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase       #-}
{-# LANGUAGE TypeOperators    #-}

-- |
-- Module:       Control.Monad.Freer.Coroutine
-- Description:  Composable coroutine effects layer.
-- Copyright:    (c) 2016 Allele Dev
-- License:      BSD3
-- Maintainer:   ixcom-core@ixperta.com
-- Stability:    experimental
-- Portability:  GHC specific language extensions.
--
-- An effect to compose functions with the ability to yield.
--
-- Using <http://okmij.org/ftp/Haskell/extensible/Eff1.hs> as a starting point.
module Control.Monad.Freer.Coroutine
    ( Yield(..)
    , yield
    , Status(..)
    , runC
    , runC'
    )
  where

import Control.Monad.Freer.Internal (Arr, Eff, Member, handleRelay, send, interpose)
import Control.Monad.Freer.Functor (ContraEff (contraeffmap), transformEff)


-- | A type representing a yielding of control.
--
-- Type variables have following meaning:
--
-- [@a@]
--   The current type.
--
-- [@b@]
--   The input to the continuation function.
--
-- [@c@]
--   The output of the continuation.
data Yield a b c = Yield a (b -> c)
  deriving (Functor)

instance ContraEff (Yield a) where
  contraeffmap f = transformEff $ \arr -> \case
    Yield a b -> send (Yield a $ b . f) >>= arr

-- | Lifts a value and a function into the Coroutine effect.
yield :: Member (Yield a b) effs => a -> (b -> c) -> Eff effs c
yield x f = send (Yield x f)

-- | Represents status of a coroutine.
data Status effs a b x
    = Done x
    -- ^ Coroutine is done with a result value.
    | Continue a (b -> Eff effs (Status effs a b x))
    -- ^ Reporting a value of the type @a@, and resuming with the value of type
    -- @b@, possibly ending with a value of type @x@.

-- | Reply to a coroutine effect by returning the Continue constructor.
replyC
  :: Yield a b c
  -> Arr r c (Status r a b w)
  -> Eff r (Status r a b w)
replyC (Yield a k) arr = return $ Continue a (arr . k)

-- | Launch a coroutine and report its status.
runC :: Eff (Yield a b ': effs) w -> Eff effs (Status effs a b w)
runC = handleRelay (return . Done) replyC

-- | Launch a coroutine and report its status, without handling (removing)
-- `Yield` from the typelist. This is useful for reducing nested coroutines.
runC' :: Member (Yield a b) r => Eff r w -> Eff r (Status r a b w)
runC' = interpose (return . Done) replyC
