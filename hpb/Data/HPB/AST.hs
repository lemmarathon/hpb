{-# LANGUAGE DeriveFunctor #-}
module Data.HPB.AST
  ( Package(..)
  , Decl(..)
  , CompoundName(..)
  , ImportVis(..)
  , ppDecls
    -- * Messages
  , MessageDecl(..)
  , ExtendDecl(..)
  , MessageField(..)
  , FieldDecl(..)
  , FieldRule(..)
  , Field(..)
  , FieldType(..)
  , extensionMax
    -- * Enum
  , EnumDecl(..)
  , enumPos
  , EnumValue(..)
    -- * Services
  , ServiceDecl(..)
  , ServiceField(..)
  , RpcMethod(..)
    -- * Options
  , OptionDecl(..)
  , OptionName(..)
  , Val(..)
    -- * Base types
  , Ident(..)
  , ScalarType(..)
  , NumLit(..)
  , Base(..)
  , baseVal
  , StringLit(..)
  , CustomOption(..)
    -- * Source position information.
  , SourcePos(..)
  , nextCol
  , nextLine
  , Posd(..)
  ) where

import Control.Applicative
import Data.Text (Text)
import qualified Data.Text as Text
import Text.PrettyPrint.Leijen as PP hiding ((<$>), line)

------------------------------------------------------------------------
-- SourcePos

data SourcePos = Pos { filename :: !Text
                     , line :: !Int
                     , col :: !Int
                     } deriving Show

nextCol :: SourcePos -> SourcePos
nextCol p = p { col = col p + 1 }

nextLine :: SourcePos -> SourcePos
nextLine p = p { line = line p + 1
               , col = 0
               }

------------------------------------------------------------------------
-- Posd

data Posd v = Posd { val :: !v
                   , pos :: !SourcePos
                   } deriving (Functor, Show)

------------------------------------------------------------------------
-- Ident

newtype Ident = Ident Text
  deriving (Eq, Ord)

instance Pretty Ident where
  pretty (Ident t) = text (Text.unpack t)

instance Show Ident where
  show (Ident t) = Text.unpack t

------------------------------------------------------------------------
-- CompoundName

newtype CompoundName = CompoundName [Posd Ident]

instance Pretty CompoundName where
  pretty (CompoundName nms) = hcat (punctuate dot (pretty . val <$> nms))

------------------------------------------------------------------------
-- ScalarType

data ScalarType
   = DoubleType
   | FloatType
   | Int32Type
   | Int64Type
   | Uint32Type
   | Uint64Type
   | Sint32Type
   | Sint64Type
   | Fixed32Type
   | Fixed64Type
   | Sfixed32Type
   | Sfixed64Type
   | BoolType
   | StringType
   | BytesType


instance Show ScalarType where
  show tp =
    case tp of
      DoubleType   -> "double"
      FloatType    -> "float"
      Int32Type    -> "int32"
      Int64Type    -> "int64"
      Uint32Type   -> "uint32"
      Uint64Type   -> "uint64"
      Sint32Type   -> "sint32"
      Sint64Type   -> "sint64"
      Fixed32Type  -> "fixed32"
      Fixed64Type  -> "fixed64"
      Sfixed32Type -> "sfixed32"
      Sfixed64Type -> "sfixed64"
      BoolType     -> "bool"
      StringType   -> "string"
      BytesType    -> "bytes"

instance Pretty ScalarType where
  pretty tp = text (show tp)

------------------------------------------------------------------------
-- Base

data Base = Oct | Dec | Hex

baseVal :: Base -> Integer
baseVal Oct =  8
baseVal Dec = 10
baseVal Hex = 16

------------------------------------------------------------------------
-- NumLit

data NumLit = NumLit Base Integer

instance Show NumLit where
  show n = show (pretty n)

instance Pretty NumLit where
  pretty (NumLit b v) = do
    let ppNum 0 = text "0"
        ppNum n = ppDigits n PP.empty
        ppDigits 0 prev = prev
        ppDigits n prev = do
          let (q,r) = n `quotRem` baseVal b
          ppDigits q (integer r <> prev)
    case b of
      Oct -> text "0" <> ppNum v
      Dec -> ppNum v
      Hex -> text "0x" <> ppNum v

------------------------------------------------------------------------
-- StringLit

newtype StringLit = StringLit Text

instance Show StringLit where
  show l = show (pretty l)

instance Pretty StringLit where
  pretty (StringLit t) = text "\"" <> Text.foldr go (text "\"") t
    where go '\\' s = text "\\\\" <> s
          go '\"' s = text "\\\"" <> s
          go c s = char c <> s

------------------------------------------------------------------------
-- CustomOption

newtype CustomOption = CustomOption Text

instance Pretty CustomOption where
  pretty (CustomOption t) = parens (text (Text.unpack t))

------------------------------------------------------------------------
-- Val

data Val
   = NumVal    NumLit
   | IdentVal  Ident
   | StringVal StringLit
   | BoolVal   Bool

instance Pretty Val where
  pretty (NumVal v) = pretty v
  pretty (IdentVal v) = pretty v
  pretty (StringVal v) = pretty v
  pretty (BoolVal b) = pretty b

------------------------------------------------------------------------
-- OptionDecl

data OptionDecl = OptionDecl !(Posd OptionName) !(Posd Val)

instance Pretty OptionDecl where
  pretty (OptionDecl nm v) =
    text "option" <+> pretty (val nm) <+> text "=" <+> pretty (val v) <> text ";"

data OptionName = KnownName !Ident
                | CustomName !CustomOption ![Posd Ident]

instance Pretty OptionName where
  pretty (KnownName o) = pretty o
  pretty (CustomName o l) = pretty o <> hsep ((\f -> text "." <> pretty (val f)) <$> l)

------------------------------------------------------------------------
-- EnumValue

data EnumValue = EnumValue (Posd Ident) (Posd NumLit)

instance Pretty EnumValue where
  pretty (EnumValue nm l) = pretty (val nm) <+> text "=" <+> pretty (val l) <> text ";"

------------------------------------------------------------------------
-- EnumDecl

data EnumDecl = EnumDecl { enumIdent :: !(Posd Ident)
                         , enumValues :: !([EnumValue])
                         }

enumPos :: EnumDecl -> SourcePos
enumPos = pos . enumIdent

instance Pretty EnumDecl where
  pretty (EnumDecl nm opts) =
    text "enum" <+> pretty (val nm) <+> text "{" <$$>
    indent 2 (vcat (pretty <$> opts)) <$$>
    text "}"

------------------------------------------------------------------------
-- FieldType

data FieldType = ScalarFieldType ScalarType
               | MessageFieldType CompoundName

instance Pretty FieldType where
  pretty (ScalarFieldType tp) = pretty tp
  pretty (MessageFieldType nm) = pretty nm

------------------------------------------------------------------------
-- Field

data Field = Field { fieldType :: !FieldType
                   , fieldName :: !(Posd Ident)
                   , fieldTag  :: !(Posd NumLit)
                   , fieldOptions :: [OptionDecl]
                   }
instance Pretty Field where
  pretty (Field tp nm v opts) =
    pretty tp <+> pretty (val nm) <+> text "=" <+> pretty (val v)
              <> ppInlineOptions opts <> text ";"

ppInlineOptions :: [OptionDecl] -> Doc
ppInlineOptions [] = PP.empty
ppInlineOptions l = text " [" <> hsep (punctuate comma (pretty <$> l)) <> text "]"

------------------------------------------------------------------------
-- FieldRule

data FieldRule = Required | Optional | Repeated

instance Pretty FieldRule where
  pretty Required = text "required"
  pretty Optional = text "optional"
  pretty Repeated = text "repeated"

------------------------------------------------------------------------
-- FieldDecl

-- | A pair contining a field and the associated rule.
data FieldDecl = FieldDecl FieldRule Field

instance Pretty FieldDecl where
  pretty (FieldDecl rl f) = pretty rl <+> pretty f

------------------------------------------------------------------------
-- ExtendDecl

data ExtendDecl = ExtendDecl (Posd Ident) [FieldDecl]

instance Pretty ExtendDecl where
  pretty (ExtendDecl nm fields) =
    text "extend" <+> pretty (val nm) <+> text "{" <$$>
    indent 2 (vcat (pretty <$> fields)) <$$>
    text "}"

------------------------------------------------------------------------
-- MessageDecl

extensionMax :: NumLit
extensionMax = NumLit Dec (2^(29::Int) - 1)

data MessageDecl = MessageDecl (Posd Ident) [MessageField]

data MessageField
   = MessageField FieldDecl
   | MessageOption OptionDecl
   | OneOf (Posd Ident) [Field]
   | Extensions (Posd NumLit) (Posd NumLit)
   | LocalEnum    EnumDecl
   | LocalMessage MessageDecl
   | LocalExtend  ExtendDecl

instance Pretty MessageDecl where
  pretty (MessageDecl nm fields) =
    text "message" <+> pretty (val nm) <+> text "{" <$$>
    indent 2 (vcat (pretty <$> fields)) <$$>
    text "}"

instance Pretty MessageField where
  pretty (MessageField f) = pretty f
  pretty (MessageOption o) = pretty o
  pretty (OneOf nm fields) =
    text "oneof" <+> pretty (val nm) <+> text "{" <$$>
    indent 2 (vcat (pretty <$> fields)) <$$>
    text "}"
  pretty (Extensions l h) =
    text "extensions" <+> pretty (val l) <+> text "to" <+> pretty (val h)
  pretty (LocalEnum d)   = pretty d
  pretty (LocalMessage d) = pretty d
  pretty (LocalExtend d) = pretty d


------------------------------------------------------------------------
-- ServiceDecl

data ServiceDecl = ServiceDecl !(Posd Ident) !([ServiceField])

instance Pretty ServiceDecl where
  pretty (ServiceDecl nm fields) =
    text "service" <+> pretty (val nm) <+> text "{" <$$>
    indent 2 (vcat (pretty <$> fields)) <$$>
    text "}"

data ServiceField
   = ServiceOption !OptionDecl
   | ServiceRpcMethod !RpcMethod

instance Pretty ServiceField where
  pretty (ServiceOption d) = pretty d
  pretty (ServiceRpcMethod m) = pretty m

data RpcMethod = RpcMethod { rpcName :: (Posd Ident)
                           , rpcInputs :: [FieldType]
                           , rpcReturns :: [FieldType]
                           , rpcOptions :: [OptionDecl]
                           }

ppTypeList :: [FieldType] -> Doc
ppTypeList tps = parens (hsep (punctuate comma (pretty <$> tps)))

ppRpcOptions :: [OptionDecl] -> Doc
ppRpcOptions [] = text ";"
ppRpcOptions l = text " {" <$$>
  indent 2 (vcat (pretty <$> l)) <$$>
  text "}"

instance Pretty RpcMethod where
  pretty m =
    text "rpc" <+> pretty (val (rpcName m)) <> ppTypeList (rpcInputs m)
               <+> text "returns" <+> ppTypeList (rpcReturns m)
               <> ppRpcOptions (rpcOptions m)

------------------------------------------------------------------------
-- Decl

data ImportVis = Public | Private

data Decl
   = Import ImportVis (Posd StringLit)
   | Option OptionDecl
   | Enum EnumDecl
   | Message MessageDecl
   | Extend ExtendDecl
   | Service ServiceDecl

instance Pretty Decl where
  pretty decl =
    case decl of
      Import v nm -> text "import" <> visd <+> pretty (val nm) <> text ";"
        where visd = case v of
                       Public -> text " public"
                       Private -> PP.empty
      Option d -> pretty d
      Enum d -> pretty d
      Message m -> pretty m
      Extend d -> pretty d
      Service d -> pretty d

ppDecls :: [Decl] -> Doc
ppDecls decls = vcat (pretty <$> decls)

------------------------------------------------------------------------
-- Package

data Package = Package (Maybe CompoundName) [Decl]

instance Pretty Package where
  pretty (Package (Just nm) decls) =
    text "package" <+> pretty nm <> text ";" <$$>
    vcat (pretty <$> decls)
  pretty (Package Nothing decls) =
    vcat (pretty <$> decls)