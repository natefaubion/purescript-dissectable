module Data.Dissectable where

import Prelude

import Control.Monad.Rec.Class (class MonadRec, Step(..), tailRec, tailRecM)
import Data.Bifunctor (class Bifunctor)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Monoid (class Monoid, mempty)
import Data.Traversable (class Traversable)
import Data.Tuple (Tuple(..))
import Data.Unfoldable (class Unfoldable, unfoldr)

-- Largely cribbed from Phil Freeman's "Stack-Safe Traversals via Dissection"
-- http://blog.functorial.com/posts/2017-06-18-Stack-Safe-Traversals-via-Dissection.html

class (Traversable f, Bifunctor d) <= Dissectable f d | f -> d where
  moveRight :: forall c j. Either (f j) (Tuple (d c j) c) -> Either (f c) (Tuple (d c j) j)
  moveLeft  :: forall c j. Either (f c) (Tuple (d c j) j) -> Either (f j) (Tuple (d c j) c)

-- instance for Maybe
-- instance for Either
-- instance for Tuple?

mapD :: forall f d a b. Dissectable f d => (a -> b) -> f a -> f b
mapD f = tailRec step <<< Left
  where
  step = moveRight >>> case _ of
           Left xs -> Done xs
           Right (Tuple dba a) -> Loop (Right (Tuple dba (f a)))

foldD :: forall f d a b. Dissectable f d => (b -> a -> b) -> b -> f a -> b
foldD f b = tailRec step <<< Tuple b <<< Left
  where
  step (Tuple acc dis) = case moveRight dis of
           Left  _                 -> Done acc
           r@(Right (Tuple dba a)) -> Loop $ Tuple (f acc a) r

foldMapD :: forall f d a b. Dissectable f d => Monoid b => (a -> b) -> f a -> b
foldMapD f = foldD (\b a -> b `append` f a) mempty

-- | Convert a `Dissectable` to any `Unfoldable` structure.
toUnfoldable :: forall f g d. Dissectable f d => Unfoldable g => f ~> g
toUnfoldable = unfoldr step <<< Left
  where
  step = moveRight >>> case _ of
           Left xs                 -> Nothing
           r@(Right (Tuple dba a)) -> Just $ Tuple a r

traverseRec
  :: forall m f d a b
   . Dissectable f d
  => MonadRec m
  => (a -> m b) -> f a -> m (f b)
traverseRec f = tailRecM step <<< Left
  where
  step = moveRight >>> case _ of
           Left xs -> pure $ Done xs
           Right (Tuple dba a) -> Loop <<< Right <<< Tuple dba <$> f a
