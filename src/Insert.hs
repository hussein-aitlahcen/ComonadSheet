{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE UndecidableInstances  #-}

module Insert where

import Stream
import Tape
import Indexed
import Nested

import Control.Applicative

data Signed f a = Positive (f a)
                | Negative (f a)
                deriving ( Eq , Ord , Show )

class InsertBase l where
   insertBase :: l a -> Tape a -> Tape a

instance InsertBase Tape where
   insertBase t _ = t

instance InsertBase Stream where
   insertBase (Cons x xs) (Tape ls _ _) = Tape ls x xs

instance InsertBase (Signed Stream) where
   insertBase (Positive (Cons x xs)) (Tape ls _ _) = Tape ls x xs
   insertBase (Negative (Cons x xs)) (Tape _ _ rs) = Tape xs x rs

instance InsertBase [] where
   insertBase [] t = t
   insertBase (x : xs) (Tape ls c rs) =
      Tape ls x (prefix xs (Cons c rs))

instance InsertBase (Signed []) where
   insertBase (Positive []) t = t
   insertBase (Negative []) t = t
   insertBase (Positive (x : xs)) (Tape ls c rs) =
      Tape ls x (prefix xs (Cons c rs))
   insertBase (Negative (x : xs)) (Tape ls c rs) =
      Tape (prefix xs (Cons c ls)) x rs

class InsertNested l t where
   insertNested :: l a -> t a -> t a

instance (InsertBase l) => InsertNested (Nested (Flat l)) (Nested (Flat Tape)) where
   insertNested (Flat l) (Flat t) = Flat $ insertBase l t

instance ( InsertBase l , InsertNested (Nested ls) (Nested ts)
         , Functor (Nested ls) , Applicative (Nested ts) )
         => InsertNested (Nested (Nest ls l)) (Nested (Nest ts Tape)) where
   insertNested (Nest l) (Nest t) =
      Nest $ insertNested (insertBase <$> l) (pure id) <*> t

instance (InsertNested l (Nested ts)) => InsertNested l (Indexed ts) where
   insertNested l (Indexed i t) = Indexed i (insertNested l t)

class DimensionalAs x y where
   type AsDimensionalAs x y
   asDimensionalAs :: x -> y -> x `AsDimensionalAs` y

instance (NestedAs x (Nested ts y), AsDimensionalAs x (Nested ts y) ~ AsNestedAs x (Nested ts y)) => DimensionalAs x (Nested ts y) where
   type x `AsDimensionalAs` (Nested ts a) = x `AsNestedAs` (Nested ts a)
   asDimensionalAs = asNestedAs

instance (NestedAs x (Nested ts y)) => DimensionalAs x (Indexed ts y) where
   type x `AsDimensionalAs` (Indexed ts a) = x `AsNestedAs` (Nested ts a)
   x `asDimensionalAs` (Indexed i t)       = x `asNestedAs` t

insert :: (DimensionalAs x (t a), InsertNested l t, AsDimensionalAs x (t a) ~ l a) => x -> t a -> t a
insert l t = insertNested (l `asDimensionalAs` t) t
