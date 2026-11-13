module

public import Plaer.Formula.Syntax

@[expose] public section

/-! # The formula language: LaTeX

A formula is shown in two steps. `render` turns it into tokens, deciding its structure
(brackets go where the precedence of the symbols needs them). `print` spells the tokens
out, separated by single spaces. Both are inverted in `Plaer.Formula.Parse`, and the
round-trip theorems there show that the LaTeX string determines the formula. -/

namespace Plaer.Formula

/-- The fixed symbols of the language. -/
inductive Sym where
  | forall_ | exists_ | in_ | colon | comma | sep
  | lp | rp
  | implies | iff | or | and | not
  | eq | ne | lt | le | gt | ge
  | add | sub | monus | mul
  | pow | rbrace | lfloor | frac | mid | rfloor
  | nat | int | prop | to
  deriving DecidableEq, Repr

/-- Every symbol, once. -/
def Sym.all : List Sym :=
  [.forall_, .exists_, .in_, .colon, .comma, .sep, .lp, .rp, .implies, .iff, .or, .and, .not,
   .eq, .ne, .lt, .le, .gt, .ge, .add, .sub, .monus, .mul, .pow, .rbrace, .lfloor, .frac,
   .mid, .rfloor, .nat, .int, .prop, .to]

/-- Each symbol's LaTeX. None contains a space. -/
def Sym.text : Sym → List Char
  | .forall_ => "\\forall".toList
  | .exists_ => "\\exists".toList
  | .in_ => "\\in".toList
  | .colon => ":".toList
  | .comma => ",".toList
  | .sep => ",\\;".toList
  | .lp => "(".toList
  | .rp => ")".toList
  | .implies => "\\implies".toList
  | .iff => "\\iff".toList
  | .or => "\\lor".toList
  | .and => "\\land".toList
  | .not => "\\neg".toList
  | .eq => "=".toList
  | .ne => "\\neq".toList
  | .lt => "<".toList
  | .le => "\\le".toList
  | .gt => ">".toList
  | .ge => "\\ge".toList
  | .add => "+".toList
  | .sub => "-".toList
  | .monus => "\\mathbin{\\dot{-}}".toList
  | .mul => "\\cdot".toList
  | .pow => "^{".toList
  | .rbrace => "}".toList
  | .lfloor => "\\left\\lfloor".toList
  | .frac => "\\frac{".toList
  | .mid => "}{".toList
  | .rfloor => "\\right\\rfloor".toList
  | .nat => "\\mathbb{N}".toList
  | .int => "\\mathbb{Z}".toList
  | .prop => "\\mathbf{Prop}".toList
  | .to => "\\to".toList

/-- Tokens: a symbol, a name, or a numeral. -/
inductive Tok where
  | sym (s : Sym)
  | name (n : Name)
  | num (k : Nat)
  deriving DecidableEq, Repr

/-! ## Names

A one-letter name is the letter itself: `x`, or `\alpha` for `α`. A longer name is a
word, set upright: `\operatorname{op\_assoc}`. -/

/-- The Greek letters a name may be, with their LaTeX. -/
def greek : List (Char × List Char) :=
  [('α', "\\alpha".toList), ('β', "\\beta".toList), ('γ', "\\gamma".toList),
   ('δ', "\\delta".toList), ('ε', "\\varepsilon".toList), ('ζ', "\\zeta".toList),
   ('η', "\\eta".toList), ('θ', "\\theta".toList), ('ι', "\\iota".toList),
   ('κ', "\\kappa".toList), ('λ', "\\lambda".toList), ('μ', "\\mu".toList),
   ('ν', "\\nu".toList), ('ξ', "\\xi".toList), ('π', "\\pi".toList), ('ρ', "\\rho".toList),
   ('σ', "\\sigma".toList), ('τ', "\\tau".toList), ('φ', "\\varphi".toList),
   ('χ', "\\chi".toList), ('ψ', "\\psi".toList), ('ω', "\\omega".toList),
   ('Γ', "\\Gamma".toList), ('Δ', "\\Delta".toList), ('Θ', "\\Theta".toList),
   ('Λ', "\\Lambda".toList), ('Ξ', "\\Xi".toList), ('Π', "\\Pi".toList),
   ('Σ', "\\Sigma".toList), ('Φ', "\\Phi".toList), ('Ψ', "\\Psi".toList),
   ('Ω', "\\Omega".toList)]

def isAsciiLetter (c : Char) : Bool := ('a' ≤ c && c ≤ 'z') || ('A' ≤ c && c ≤ 'Z')
def isDigitChar (c : Char) : Bool := '0' ≤ c && c ≤ '9'

/-- The characters a word may contain. -/
def isWordChar (c : Char) : Bool := isAsciiLetter c || isDigitChar c || c == '_'

/-- The names the language can show: one ASCII or Greek letter, or a word of ASCII
letters, digits and `_` that starts with a letter. -/
def Name.valid : Name → Bool
  | [c] => isAsciiLetter c || (greek.lookup c).isSome
  | c :: d :: rest => isAsciiLetter c && (d :: rest).all isWordChar
  | [] => false

/-- `_` written as `\_`. -/
def escape : List Char → List Char
  | [] => []
  | '_' :: cs => '\\' :: '_' :: escape cs
  | c :: cs => c :: escape cs

def operatorname : List Char := "\\operatorname{".toList

/-- A name's LaTeX. -/
def Name.text : Name → List Char
  | [c] => (greek.lookup c).getD [c]
  | n => operatorname ++ escape n ++ ['}']

/-! ## Numerals -/

/-- The decimal digits of `k`, least significant first. -/
def digitsRev (k : Nat) : List Char :=
  let d := Char.ofNat (48 + k % 10)
  if k < 10 then [d] else d :: digitsRev (k / 10)
termination_by k
decreasing_by omega

def digits (k : Nat) : List Char := (digitsRev k).reverse

def Tok.text : Tok → List Char
  | .sym s => s.text
  | .name n => n.text
  | .num k => digits k

/-- Tokens spelled out, separated by single spaces. -/
def print (ts : List Tok) : List Char := [' '].intercalate (ts.map Tok.text)

/-! ## Structure

Each formula has a level; a lower level binds less tightly. A formula is put in brackets
exactly when it appears where a higher level is needed.

| level | formulas | grouping |
| --- | --- | --- |
| 0 | `∀`, `∃` | the body extends as far as possible |
| 1 | `⟹`, `⇔` | neither side may be another `⟹` or `⇔` |
| 2 | `∨` | `a ∨ b ∨ c` is `a ∨ (b ∨ c)` |
| 3 | `∧` | `a ∧ b ∧ c` is `a ∧ (b ∧ c)` |
| 4 | `¬` | |
| 5 | `= ≠ < ≤ > ≥` | neither side may be another comparison |
| 6 | `+ - ∸` | `a - b + c` is `(a - b) + c` |
| 7 | `·` | `a · b · c` is `(a · b) · c` |
| 8 | `aᵇ` | the base is an application or simpler |
| 9 | `f(a, b)` | |
| 10 | names, numerals, `⌊a/b⌋`, `(e : T)` | |
-/

def BinOp.level : BinOp → Nat
  | .implies | .iff => 1
  | .or => 2
  | .and => 3
  | .eq | .ne | .lt | .le | .gt | .ge => 5
  | .add | .sub | .monus => 6
  | .mul => 7

/-- How a chain of operations of one level groups. -/
inductive Assoc where
  | none | right | left
  deriving DecidableEq

def BinOp.assoc : BinOp → Assoc
  | .implies | .iff | .eq | .ne | .lt | .le | .gt | .ge => .none
  | .or | .and => .right
  | .add | .sub | .monus | .mul => .left

def BinOp.sym : BinOp → Sym
  | .implies => .implies | .iff => .iff | .or => .or | .and => .and
  | .eq => .eq | .ne => .ne | .lt => .lt | .le => .le | .gt => .gt | .ge => .ge
  | .add => .add | .sub => .sub | .monus => .monus | .mul => .mul

def Raw.level : Raw → Nat
  | .quant .. => 0
  | .bin o _ _ => o.level
  | .not _ => 4
  | .pow _ _ => 8
  | .app _ _ => 9
  | _ => 10

/-- Tokens in brackets when `b`. -/
def bracket (b : Bool) (ts : List Tok) : List Tok :=
  if b then .sym .lp :: ts ++ [.sym .rp] else ts

/-- A variable over a type of elements reads `x ∈ T`; over a function type or `Prop`,
`f : T`. -/
def Ty.binder : Ty → Sym
  | .fn _ _ | .prop => .colon
  | _ => .in_

mutual
/-- A type's tokens. `fn a (fn b c)` is `(a, b) → c`, its inputs together. -/
def Ty.toks : Ty → List Tok
  | .prop => [.sym .prop]
  | .nat => [.sym .nat]
  | .int => [.sym .int]
  | .named n => [.name n]
  | .fn a b =>
    match b with
    | .fn .. => .sym .lp :: a.toks ++ Ty.moreInputs b
    | _ => bracket (a matches .fn ..) a.toks ++ .sym .to :: b.toks

/-- The remaining inputs of a function type, then its output. -/
def Ty.moreInputs : Ty → List Tok
  | .fn a b =>
    match b with
    | .fn .. => .sym .comma :: a.toks ++ Ty.moreInputs b
    | _ => .sym .comma :: a.toks ++ .sym .rp :: .sym .to :: b.toks
  | _ => []
end

/-- Names separated by commas. -/
def namesToks : List Name → List Tok
  | [] => []
  | [x] => [.name x]
  | x :: xs => .name x :: .sym .comma :: namesToks xs

mutual
/-- A formula's tokens, at its own level. Its parts are bracketed where they need it. -/
def Raw.toks : Raw → List Tok
  | .ident n => [.name n]
  | .num k => [.num k]
  | .app f args => bracket (f.level < 9) f.toks ++ .sym .lp :: Args.toks args ++ [.sym .rp]
  | .bin o a b =>
    let j := o.level
    match o.assoc with
    | .none => bracket (a.level < j + 1) a.toks ++ .sym o.sym :: bracket (b.level < j + 1) b.toks
    | .right => bracket (a.level < j + 1) a.toks ++ .sym o.sym :: bracket (b.level < j) b.toks
    | .left => bracket (a.level < j) a.toks ++ .sym o.sym :: bracket (b.level < j + 1) b.toks
  | .not a => .sym .not :: bracket (a.level < 4) a.toks
  | .pow a b => bracket (a.level < 9) a.toks ++ .sym .pow :: b.toks ++ [.sym .rbrace]
  | .floorDiv a b => [.sym .lfloor, .sym .frac] ++ a.toks ++ .sym .mid :: b.toks ++ [.sym .rbrace, .sym .rfloor]
  | .ann e t => .sym .lp :: e.toks ++ .sym .colon :: t.toks ++ [.sym .rp]
  | .quant q xs t body =>
    .sym (match q with | .all => .forall_ | .ex => .exists_) :: namesToks xs ++
      .sym t.binder :: t.toks ++ .sym .sep :: body.toks

/-- Arguments, separated by commas. A quantifier is bracketed, so that a comma after
it cannot be read as part of its body. -/
def Args.toks : Args → List Tok
  | .one a => bracket (a.level < 1) a.toks
  | .cons a rest => bracket (a.level < 1) a.toks ++ .sym .comma :: Args.toks rest
end

/-- A formula's LaTeX. -/
def render (r : Raw) : List Char := print r.toks

/-- A type's LaTeX. -/
def renderTy (t : Ty) : List Char := print t.toks

end Plaer.Formula
