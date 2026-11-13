module

public import Plaer.Formula.Latex

@[expose] public section

/-! # Reading the LaTeX back

`lex` splits a LaTeX string into tokens and `parse` reads a formula from tokens, by the
same precedence table that `render` uses. They exist to state, and prove, that the LaTeX
of a formula determines it (`Plaer.Formula.RoundTrip`). -/

namespace Plaer.Formula

/-- The symbol with this LaTeX, if any. -/
def Sym.ofText (w : List Char) : Option Sym := Sym.all.find? (·.text == w)

/-- A numeral's value, from its digits. -/
def ofDigits : List Char → Option Nat
  | [] => none
  | cs => if cs.all isDigitChar then some (cs.foldl (fun k c => 10 * k + (c.toNat - 48)) 0) else none

/-- `\_` read back as `_`. -/
def unescape : List Char → List Char
  | [] => []
  | '\\' :: '_' :: cs => '_' :: unescape cs
  | c :: cs => c :: unescape cs

/-- A name, from its LaTeX. -/
def Name.ofText (w : List Char) : Option Name :=
  match w with
  | [c] => if isAsciiLetter c then some [c] else none
  | _ =>
    match (greek.find? (·.2 == w)) with
    | some (c, _) => some [c]
    | none =>
      if operatorname.isPrefixOf w && w.getLast? == some '}' then
        let n := unescape ((w.drop operatorname.length).dropLast)
        if n.length > 1 && Name.valid n then some n else none
      else none

/-- A token, from its LaTeX. -/
def Tok.ofText (w : List Char) : Option Tok :=
  match Sym.ofText w with
  | some s => some (.sym s)
  | none =>
    match ofDigits w with
    | some k => some (.num k)
    | none => (Name.ofText w).map .name

/-- Tokens, from LaTeX whose tokens are separated by single spaces. -/
def lex : List Char → Option (List Tok)
  | [] => some []
  | cs => (cs.splitOn ' ').mapM Tok.ofText

/-! ## Parsing

One function per level, as in the table in `Plaer.Formula.Latex`. Every function takes
`fuel`, which bounds its recursion; `parse` gives it more than any formula needs. -/

/-- The binary operation of level `k` a token stands for. -/
def opAt (k : Nat) : Tok → Option BinOp
  | .sym s =>
    [BinOp.implies, .iff, .or, .and, .eq, .ne, .lt, .le, .gt, .ge, .add, .sub, .monus, .mul].find?
      (fun o => o.sym == s && o.level == k)
  | _ => none

def expect (s : Sym) : List Tok → Option (List Tok)
  | .sym t :: rest => if t == s then some rest else none
  | _ => none

/-- `ℕ`, `ℤ`, `Prop`, or a named type. -/
def parseTyAtom : List Tok → Option (Ty × List Tok)
  | .sym .nat :: ts => some (.nat, ts)
  | .sym .int :: ts => some (.int, ts)
  | .sym .prop :: ts => some (.prop, ts)
  | .name n :: ts => some (.named n, ts)
  | _ => none

mutual
/-- A type. -/
def parseTy : Nat → List Tok → Option (Ty × List Tok)
  | 0, _ => none
  | fuel + 1, .sym .lp :: ts => do
    let (inputs, ts) ← parseTyList fuel ts
    let ts ← expect .rp ts
    match inputs, ts with
    | [t], .sym .to :: ts => do
      let (out, ts) ← parseTy fuel ts
      some (.fn t out, ts)
    | [t], ts => some (t, ts)
    | t :: more, .sym .to :: ts => do
      let (out, ts) ← parseTy fuel ts
      some (.fn t (more.foldr Ty.fn out), ts)
    | _, _ => none
  | fuel + 1, ts => do
    let (t, ts) ← parseTyAtom ts
    match ts with
    | .sym .to :: ts => do
      let (out, ts) ← parseTy fuel ts
      some (.fn t out, ts)
    | _ => some (t, ts)

/-- Types separated by commas. -/
def parseTyList : Nat → List Tok → Option (List Ty × List Tok)
  | 0, _ => none
  | fuel + 1, ts => do
    let (t, ts) ← parseTy fuel ts
    match ts with
    | .sym .comma :: ts => do
      let (more, ts) ← parseTyList fuel ts
      some (t :: more, ts)
    | _ => some ([t], ts)
end

/-- Names separated by commas. -/
def parseNames : List Tok → Option (List Name × List Tok)
  | .name x :: .sym .comma :: ts => do
    let (xs, ts) ← parseNames ts
    some (x :: xs, ts)
  | .name x :: ts => some ([x], ts)
  | _ => none

mutual
/-- A formula of level `k` or higher. -/
def parseAt : Nat → Nat → List Tok → Option (Raw × List Tok)
  | 0, _, _ => none
  | fuel + 1, 0, ts =>
    match ts with
    | .sym .forall_ :: ts => parseQuant fuel .all ts
    | .sym .exists_ :: ts => parseQuant fuel .ex ts
    | _ => parseAt fuel 1 ts
  | fuel + 1, 4, ts =>
    match ts with
    | .sym .not :: ts => do
      let (a, ts) ← parseAt fuel 4 ts
      some (.not a, ts)
    | _ => parseAt fuel 5 ts
  | fuel + 1, 8, ts => do
    let (a, ts) ← parseAt fuel 9 ts
    match ts with
    | .sym .pow :: ts => do
      let (b, ts) ← parseAt fuel 0 ts
      let ts ← expect .rbrace ts
      some (.pow a b, ts)
    | _ => some (a, ts)
  | fuel + 1, 9, ts => do
    let (f, ts) ← parseAtom fuel ts
    parseCalls fuel f ts
  | fuel + 1, k, ts =>
    if k ≥ 10 then parseAtom fuel ts else do
    -- levels 1, 2, 3, 5, 6, 7: binary operations
    let (a, ts) ← parseAt fuel (k + 1) ts
    if k == 6 || k == 7 then parseLeft fuel k a ts else
    match ts with
    | t :: rest =>
      match opAt k t with
      | some o => do
        let (b, ts) ← parseAt fuel (if o.assoc == .right then k else k + 1) rest
        some (.bin o a b, ts)
      | none => some (a, ts)
    | [] => some (a, ts)

/-- The rest of a left-grouping chain `a ∘ b ∘ c` of level `k`, after `a`. -/
def parseLeft : Nat → Nat → Raw → List Tok → Option (Raw × List Tok)
  | 0, _, _, _ => none
  | fuel + 1, k, a, ts =>
    match ts with
    | t :: rest =>
      match opAt k t with
      | some o => do
        let (b, ts) ← parseAt fuel (k + 1) rest
        parseLeft fuel k (.bin o a b) ts
      | none => some (a, ts)
    | [] => some (a, ts)

/-- Applications `f(a, b)(c)` after `f`. -/
def parseCalls : Nat → Raw → List Tok → Option (Raw × List Tok)
  | 0, _, _ => none
  | fuel + 1, f, .sym .lp :: ts => do
    let (args, ts) ← parseArgs fuel ts
    let ts ← expect .rp ts
    parseCalls fuel (.app f args) ts
  | _ + 1, f, ts => some (f, ts)

/-- Arguments separated by commas. -/
def parseArgs : Nat → List Tok → Option (Args × List Tok)
  | 0, _ => none
  | fuel + 1, ts => do
    let (a, ts) ← parseAt fuel 1 ts
    match ts with
    | .sym .comma :: ts => do
      let (rest, ts) ← parseArgs fuel ts
      some (.cons a rest, ts)
    | _ => some (.one a, ts)

/-- A name, a numeral, `⌊a/b⌋`, `(e : T)`, or a formula in brackets. -/
def parseAtom : Nat → List Tok → Option (Raw × List Tok)
  | 0, _ => none
  | _ + 1, .name n :: ts => some (.ident n, ts)
  | _ + 1, .num k :: ts => some (.num k, ts)
  | fuel + 1, .sym .lfloor :: .sym .frac :: ts => do
    let (a, ts) ← parseAt fuel 0 ts
    let ts ← expect .mid ts
    let (b, ts) ← parseAt fuel 0 ts
    let ts ← expect .rbrace ts
    let ts ← expect .rfloor ts
    some (.floorDiv a b, ts)
  | fuel + 1, .sym .lp :: ts => do
    let (e, ts) ← parseAt fuel 0 ts
    match ts with
    | .sym .colon :: ts => do
      let (t, ts) ← parseTy fuel ts
      let ts ← expect .rp ts
      some (.ann e t, ts)
    | .sym .rp :: ts => some (e, ts)
    | _ => none
  | _, _ => none

/-- `∀ x, y ∈ T, body` after the `∀`. -/
def parseQuant : Nat → Quant → List Tok → Option (Raw × List Tok)
  | 0, _, _ => none
  | fuel + 1, q, ts => do
    let (xs, ts) ← parseNames ts
    let ts ← match ts with
      | .sym .in_ :: ts => some ts
      | .sym .colon :: ts => some ts
      | _ => none
    let (t, ts) ← parseTy fuel ts
    let ts ← expect .sep ts
    let (body, ts) ← parseAt fuel 0 ts
    some (.quant q xs t body, ts)
end

/-- Enough fuel for any formula with `n` tokens. -/
def fuelFor (n : Nat) : Nat := 16 * (n + 1)

/-- A formula from its tokens, when they are exactly one formula. -/
def parseToks (ts : List Tok) : Option Raw :=
  match parseAt (fuelFor ts.length) 0 ts with
  | some (r, []) => some r
  | _ => none

/-- A formula from its LaTeX. -/
def parse (cs : List Char) : Option Raw := (lex cs).bind parseToks

/-- A type from its tokens. -/
def parseTyToks (ts : List Tok) : Option Ty :=
  match parseTy (fuelFor ts.length) ts with
  | some (t, []) => some t
  | _ => none

end Plaer.Formula
