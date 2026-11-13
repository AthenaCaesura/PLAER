module

public import Lean
public import Plaer.Latex.Grammar
public meta import Lean
public meta import Plaer.Latex.Grammar

public section

/-! # Dictionary entries

    /-- Subtraction in ℕ, which stops at 0 -/
    latex_notation monus (a b : ℕ) := a - b as:65 a:65 " \\mathbin{\\dot{-}} " b:66

declares three things, from one line:

1. the Lean definition `monus (a b : ℕ) : ℕ := a - b`, reducible, so that a claim
   written `a - b` and one written `monus a b` are the same claim;
2. the LaTeX form `a \mathbin{\dot{-}} b`, a new production of the `latex` grammar;
3. how Lean reads it: `⟪a \mathbin{\dot{-}} b⟫` is `monus ⟪a⟫ ⟪b⟫`.

The holes of the LaTeX form are the definition's explicit arguments, by name. The entry
is also recorded, so that PLAER can print formulas with it and show it in a paper. -/

open Lean Elab Command

namespace Plaer.Latex

/-- A piece of a LaTeX form: fixed text, or a hole for an argument. -/
inductive Piece where
  | text (s : String)
  | hole (name : Name) (prec : Nat)
  deriving Inhabited, Repr

/-- A dictionary entry: the Lean definition, its LaTeX form, and the form's precedence. -/
structure Entry where
  decl : Name
  pieces : Array Piece
  prec : Nat
  deriving Inhabited, Repr

meta initialize entryExt : SimplePersistentEnvExtension Entry (Array Entry) ←
  registerSimplePersistentEnvExtension {
    addEntryFn := Array.push
    addImportedFn := fun ess => ess.foldl (· ++ ·) #[]
  }

/-- Every dictionary entry in scope, latest first. -/
meta def entries (env : Environment) : Array Entry := (entryExt.getState env).reverse

syntax (name := latexCmd) (docComment)? "latex_notation " ident (ppSpace bracketedBinder)* " := " term
  " as" (":" prec)? (ppSpace Lean.Parser.Command.notationItem)+ : command

meta def explicitNames (bs : Array Syntax) : Array Name := Id.run do
  let mut names := #[]
  for b in bs do
    if b.getKind == ``Lean.Parser.Term.explicitBinder then
      for id in b[1].getArgs do
        names := names.push id.getId
  return names

@[command_elab latexCmd] meta def elabLatex : CommandElab := fun stx => do
  let doc? := stx[0].getOptional?
  let name := stx[2]
  let binders := stx[3].getArgs
  let body := stx[5]
  -- `as:65`: the optional `:` and precedence
  let prec? := if stx[7].getNumArgs == 2 then some stx[7][1] else none
  let items := stx[8].getArgs
  -- 1. the definition
  let docStx : Option (TSyntax ``Lean.Parser.Command.docComment) := doc?.map (⟨·⟩)
  -- the arguments are named for the LaTeX form, so the linter would call them unused
  let defCmd ← `($[$docStx]? @[reducible] noncomputable def $(⟨name⟩):ident $(binders.map (⟨·⟩))* := $(⟨body⟩))
  withScope (fun sc => { sc with opts := sc.opts.setBool `linter.unusedVariables false }) (elabCommand defCmd)
  let decl := (← getCurrNamespace) ++ name.getId
  unless (← getEnv).contains decl do throwErrorAt stx "The definition of this entry has errors"
  -- 2. the LaTeX form, as a production of the grammar
  let mut parts : Array (TSyntax `stx) := #[]
  let mut pieces : Array Piece := #[]
  for item in items do
    if item.getKind == ``Lean.Parser.Command.identPrec then
      let p? : Option (TSyntax `prec) := (item[1].getOptional?).map fun p => ⟨p[1]⟩
      parts := parts.push (← `(stx| tex $[:$p?]?))
      let p ← match p? with
        | some p => liftMacroM <| evalPrec p
        | none => pure 0
      pieces := pieces.push (.hole item[0].getId p)
    else if item.isOfKind strLitKind then
      let lit : StrLit := ⟨item⟩
      parts := parts.push (← `(stx| $lit:str))
      pieces := pieces.push (.text (item.isStrLit?.getD ""))
    else
      throwErrorAt item "A LaTeX form is made of text and holes"
  let precStx : Option (TSyntax `prec) := prec?.map (⟨·⟩)
  let syntaxCmd ← match precStx with
    | some p => `(syntax:$p $[$parts]* : tex)
    | none => `(syntax $[$parts]* : tex)
  let kind ← elabSyntax syntaxCmd
  -- 3. how Lean reads it: the definition applied to each hole, read as LaTeX
  let holes := pieces.filterMap fun | .hole n _ => some n | _ => none
  let args := explicitNames binders
  unless holes.qsort (·.toString < ·.toString) == args.qsort (·.toString < ·.toString) do
    throwErrorAt stx "The holes of the LaTeX form must be exactly the explicit arguments: {args}"
  let pat ← items.mapM fun item => do
    if item.getKind == ``Lean.Parser.Command.identPrec then
      return Syntax.mkAntiquotNode item[0] (kind := `tex)
    else liftMacroM <| strLitToPattern item
  let pat : TSyntax `tex := ⟨mkNode kind pat⟩
  let readArgs ← args.mapM fun a => do
    let hole : TSyntax `tex := ⟨Syntax.mkAntiquotNode (mkIdent a) (kind := `tex)⟩
    `(⟪$hole⟫)
  let rhs ← `($(mkIdent decl) $readArgs*)
  let lhs : Term ← `(⟪$pat⟫)
  elabCommand (← `(macro_rules | `($lhs) => ``($rhs)))
  -- 4. the record
  let prec ← match precStx with
    | some p => liftMacroM <| evalPrec p
    | none => pure 1024
  modifyEnv fun env => entryExt.addEntry env { decl, pieces, prec }

end Plaer.Latex
