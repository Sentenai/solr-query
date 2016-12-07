module Solr.Expr.Class
  ( -- * Solr expression language
    ExprSYM(..)
    -- * Derived combinators
  , fuzzy
  , gt
  , gte
  , lt
  , lte
    -- * Range expression helpers
  , Boundary(..)
  , incl
  , excl
  , star
    -- * Named operators
  , fuzz
  , boost
  ) where

import Solr.DateTime.Internal
import Solr.Type

import Data.Int  (Int64)
import Data.Text (Text)


-- $setup
-- >>> import Solr.Query
-- >>> import Data.Time


-- | Solr expression.
class ExprSYM expr where
  -- | An @int@ expression.
  --
  -- ==== __Examples__
  --
  -- >>> compile [] [] ("foo" =: int 5 :: Query Expr)
  -- "q=foo:5"
  int :: Int64 -> expr 'TNum

  -- | A @float@ expression.
  --
  -- ==== __Examples__
  --
  -- >>> compile [] [] ("foo" =: float 5 :: Query Expr)
  -- "q=foo:5.0"
  float :: Double -> expr 'TNum

  -- | A @true@ expression.
  --
  -- ==== __Examples__
  --
  -- >>> compile [] [] ("foo" =: true :: Query Expr)
  -- "q=foo:true"
  true :: expr 'TBool

  -- | A @false@ expression.
  --
  -- ==== __Examples__
  --
  -- >>> compile [] [] ("foo" =: false :: Query Expr)
  -- "q=foo:false"
  false :: expr 'TBool

  -- | A single word. Must /not/ contain any spaces, wildcard characters
  -- (@\'?\'@ and @\'*\'@), or tildes (@\'~\'@), though this is not enforced by
  -- the type system.
  --
  -- Note that sometimes you may use the 'Data.String.IsString' instance for
  -- 'Solr.Query.Expr' 'TWord', but usually an explicit type signature
  -- will be required (at the interpretation site or earlier).
  --
  -- ==== __Examples__
  --
  -- >>> compile [] [] ("foo" =: word "bar" :: Query Expr)
  -- "q=foo:bar"
  word :: Text -> expr 'TWord

  -- | A single word that may contain wildcard characters (@\'?\'@ and @\'*\'@),
  -- although the meaning of consecutive @\'*\'@s is probably ill-defined. Must
  -- also /not/ contain any spaces or tildes (@\'~\'@), though this is not
  -- enforced by the type system.
  --
  -- ==== __Examples__
  --
  -- >>> compile [] [] ("foo" =: wild "b?r" :: Query Expr)
  -- "q=foo:b?r"
  wild :: Text -> expr 'TWild

  -- | A regular expression, whose syntax is described by
  -- <http://lucene.apache.org/core/5_5_0/core/org/apache/lucene/util/automaton/RegExp.html?is-external=true>.
  --
  -- Note that the leading and trailing @\'/\'@ must be omitted. The regex
  -- innards are not type checked in any way.
  --
  -- ==== __Examples__
  --
  -- >>> compile [] [] ("foo" =: regex "[mb]oat" :: Query Expr)
  -- "q=foo:/[mb]oat/"
  regex :: Text -> expr 'TRegex

  -- | A phrase, composed of multiple (non-fuzzy) words, none of which may
  -- contain wildcard characters. Both of these properties are enforced by the
  -- type system, as long as the words themselves adhere to the 'word' contract.
  -- The list should not be empty.
  --
  -- ==== __Examples__
  --
  -- >>> compile [] [] ("foo" =: phrase ["bar", "baz"] :: Query Expr)
  -- "q=foo:\"bar baz\""
  phrase :: [expr 'TWord] -> expr 'TPhrase

  -- | A 'DateTime' expression. This may either be a timestamp ('UTCTime'), or a
  -- "truncated" 'DateTime' such as @(2015, 5, 12)@.
  --
  -- ==== __Examples__
  --
  -- >>> let date = fromGregorian 2016 1 1
  -- >>> let time = fromIntegral 0
  -- >>> compile [] [] ("foo" =: datetime (UTCTime date time) :: Query Expr)
  -- "q=foo:\"2016-01-01T00:00:00Z\""
  --
  -- >>> compile [] [] ("foo" =: datetime (2015 :: Year) :: Query Expr)
  -- "q=foo:\"2015\""
  --
  -- >>> compile [] [] ("foo" =: datetime (2015, 1, 15, 11) :: Query Expr)
  -- "q=foo:\"2015-01-15T11\""
  datetime :: IsDateTime a => a -> expr 'TDateTime

  -- | The @\'~\'@ operator, which fuzzes its argument (either a word or phrase)
  -- by a numeric amount.
  --
  -- ==== __Examples__
  --
  -- >>> compile [] [] ("foo" =: word "bar" ~: 1 :: Query Expr)
  -- "q=foo:bar~1"
  --
  -- >>> compile [] [] ("foo" =: phrase ["bar", "baz", "qux"] ~: 10 :: Query Expr)
  -- "q=foo:\"bar baz qux\"~10"
  (~:) :: Fuzzable a => expr a -> Int -> expr 'TFuzzy
  infix 6 ~:

  -- | A range expression.
  --
  -- ==== __Examples__
  --
  -- >>> compile [] [] ("foo" =: incl (int 5) `to` excl (int 10) :: Query Expr)
  -- "q=foo:[5 TO 10}"
  --
  -- >>> compile [] [] ("foo" =: excl (word "bar") `to` star :: Query Expr)
  -- "q=foo:{bar TO *]"
  --
  -- >>> compile [] [] ("foo" =: star `to` star :: Query Expr)
  -- "q=foo:[* TO *]"
  to :: Rangeable a b => Boundary expr a -> Boundary expr b -> expr 'TRange
  infix 6 `to`

  -- | The @\'^\'@ operator, which boosts its argument.
  --
  -- ==== __Examples__
  --
  -- >>> compile [] [] ("foo" =: word "bar" ^: 3.5 :: Query Expr)
  -- "q=foo:bar^3.5"
  --
  -- >>> compile [] [] ("foo" =: phrase ["bar", "baz"] ^: 3.5 :: Query Expr)
  -- "q=foo:\"bar baz\"^3.5"
  (^:) :: Boostable a => expr a -> Float -> expr 'TBoosted
  infix 6 ^:

-- | Short-hand for fuzzing a word by 2. This is the default behavior of a
-- Solr @\'~\'@ operator without an integer added.
--
-- @
-- 'fuzzy' e = e '~:' 2
-- @
--
-- ==== __Examples__
--
-- >>> compile [] [] ("foo" =: fuzzy "bar" :: Query Expr)
-- "q=foo:bar~2"
fuzzy :: ExprSYM expr => expr 'TWord -> expr 'TFuzzy
fuzzy e = e ~: 2

-- | Short-hand for a greater-than range query.
--
-- @
-- 'gt' e = 'excl' e \`to\` 'star'
-- @
--
-- ==== __Examples__
--
-- >>> compile [] [] ("foo" =: gt (int 5) :: Query Expr)
-- "q=foo:{5 TO *]"
gt :: (ExprSYM expr, Rangeable a 'TAny) => expr a -> expr 'TRange
gt e = excl e `to` star

-- | Short-hand for a greater-than-or-equal-to range query.
--
-- @
-- 'gte' e = 'incl' e \`to\` 'star'
-- @
--
-- ==== __Examples__
--
-- >>> compile [] [] ("foo" =: gte (int 5) :: Query Expr)
-- "q=foo:[5 TO *]"
gte :: (ExprSYM expr, Rangeable a 'TAny) => expr a -> expr 'TRange
gte e = incl e `to` star

-- | Short-hand for a less-than range query.
--
-- @
--  'lt' e = 'star' \`to\` 'excl' e
-- @
--
-- ==== __Examples__
--
-- >>> compile [] [] ("foo" =: lt (int 5) :: Query Expr)
-- "q=foo:[* TO 5}"
lt :: (ExprSYM expr, Rangeable 'TAny a) => expr a -> expr 'TRange
lt e = star `to` excl e

-- | Short-hand for a less-than-or-equal-to range query.
--
-- @
-- 'lte' e = 'star' \`to\` 'incl' e
-- @
--
-- ==== __Examples__
--
-- >>> compile [] [] ("foo" =: lte (int 5) :: Query Expr)
-- "q=foo:[* TO 5]"
lte :: (ExprSYM expr, Rangeable 'TAny a) => expr a -> expr 'TRange
lte e = star `to` incl e


-- | An inclusive or exclusive expression for use in a range query, built with
-- either 'incl', 'excl', or 'star'.
--
-- The constructors are exported for use in interpreters.
data Boundary expr ty where
  Inclusive :: expr ty -> Boundary expr ty
  Exclusive :: expr ty -> Boundary expr ty
  Star :: Boundary expr 'TAny

deriving instance Eq   (expr ty) => Eq   (Boundary expr ty)
deriving instance Show (expr ty) => Show (Boundary expr ty)

-- | Mark an expression as inclusive, for use in a range query.
incl :: ExprSYM expr => expr a -> Boundary expr a
incl = Inclusive

-- | Mark an expression as exclusive, for use in a range query.
excl :: ExprSYM expr => expr a -> Boundary expr a
excl = Exclusive

-- | @\'*\'@ operator, signifying the minimum or maximun bound of a range.
star :: ExprSYM expr => Boundary expr 'TAny
star = Star

-- | Named version of ('~:').
fuzz :: (ExprSYM expr, Fuzzable a) => expr a -> Int -> expr 'TFuzzy
fuzz = (~:)

-- | Named version of ('^:').
boost :: (ExprSYM expr, Boostable a) => expr a -> Float -> expr 'TBoosted
boost = (^:)
