module
public import Plaer.Check
public import Plaer.Latex.Print

public section

open Lean Meta
open Plaer.Latex (statementLatex signatureLatex definitionLatex rowLatex typeLatex nameLatex
  entries entryFormLatex entryMeaning)

namespace Plaer

/-- Read a declaration's source span through Lean's source search path. -/
meta def declarationSource (name : Name) : MetaM String := do
  -- Declarations made in the REPL have no module; the page reads their text from the paper.
  let some moduleName ← findModuleOf? name | return ""
  let sourcePath ← findLean (← getSrcSearchPath) moduleName
  let source ← IO.FS.readFile sourcePath
  let some ranges ← findDeclarationRanges? name | throwError "No source span recorded for {name}"
  let fileMap := FileMap.ofString source
  let start := fileMap.ofPosition ranges.range.pos
  let stop := fileMap.ofPosition ranges.range.endPos
  return (String.Pos.Raw.extract source start stop).trimAscii.copy

/-- LaTeX fields for a box. Every formula is read back by Lean, through the dictionary,
and must be exactly the declaration (`Plaer.Latex.checkLatex`); one that is not does not
fail the document: the box keeps its Lean view and reports the reason. -/
private meta def latexFields (field : String) (render : Elab.TermElabM String) : MetaM (List (String × Json)) := do
  try
    return [(field, toJson (← render.run'))]
  catch error =>
    return [(field, Json.null), ("latexError", toJson (← error.toMessageData.toString))]

/-- Extract statement data without loading a separately configured proof. -/
meta def statementReport (name : Name) : MetaM Json := do
  let info ← getConstInfo name
  let proposition ← statementProposition name
  let moduleName := (← findModuleOf? name).getD .anonymous
  let kind := if info.isTheorem then "theorem" else "candidate"
  let pretty := (← ppExpr proposition).pretty
  let statementLean :=
    if info.isTheorem then "theorem " ++ name.toString ++ " : " ++ pretty
    else "def " ++ name.toString ++ " : Prop := " ++ pretty
  return Json.mkObj <| [
    ("name", toJson name.toString), ("kind", toJson kind),
    ("statementLean", toJson statementLean),
    ("statementHash", toJson (toString (hash proposition))),
    ("sourceModule", toJson moduleName.toString),
    ("leanVersion", toJson Lean.versionString)] ++
    (← latexFields "statementLatex" (statementLatex proposition))

/-- Generic definition data. -/
meta def definitionReport (name : Name) : MetaM Json := do
  let info ← getConstInfoDefn name
  let moduleName := (← findModuleOf? name).getD .anonymous
  -- Its type, as Lean elaborated it: `triangle : ℕ → ℕ`, domain and range first.
  let signature ← try pure (some (← (signatureLatex name).run')) catch _ => pure none
  return Json.mkObj <| [
    ("name", toJson name.toString), ("kind", toJson "definition"),
    ("signatureLatex", toJson signature),
    ("sourceModule", toJson moduleName.toString),
    ("source", toJson (← declarationSource name)),
    ("leanVersion", toJson Lean.versionString)] ++
    (← latexFields "latex" (definitionLatex name))

/-- A structure or class lists its fields, an inductive type its constructors, each
with its type. Each row is checked like any formula, with the parameters and the fields
before it in scope, so a law reads `\operatorname{op}(a, b)`.

    Monoid(α) : Type   for α : Type        even : ℕ → Prop
      op : (α, α) → α                        zero : even(0)
      op_assoc : ∀ a, b, c ∈ α, …            step : ∀ n ∈ ℕ, even(n) ⟹ even(n + 2)
-/
meta def inductiveReport (name : Name) (info : InductiveVal) : MetaM Json := do
  let env ← getEnv
  let signature ← try
      forallBoundedTelescope info.type (some info.numParams) fun params result => do
        -- a family of propositions, `even : ℕ → Prop`, has a checked type line
        unless (← whnf result).isSort do
          unless params.isEmpty do throwError "a family with parameters"
          return some (← (signatureLatex name).run')
        let head ← nameLatex name
        let names ← params.toList.mapM fun p => do nameLatex (← p.fvarId!.getDecl).userName
        -- `Monoid(α) : Type for α : Type`: a type and its parameters, in a fixed template
        let given ← params.toList.mapM fun p => do
          let decl ← p.fvarId!.getDecl
          unless (← whnf decl.type).isType do throwError "a parameter that is not a type"
          return (← nameLatex decl.userName) ++ " : \\mathbf{Type}"
        return some (head ++ (if names.isEmpty then "" else "(" ++ ", ".intercalate names ++ ")") ++
          " : \\mathbf{Type}" ++ (if given.isEmpty then "" else " \\quad \\text{for } " ++ ", ".intercalate given))
    catch _ => pure none
  let rows : Elab.TermElabM (List String) := do
    if isStructure env name then
      forallTelescope (← getConstInfo info.ctors.head!).type fun binders _ => do
        binders[info.numParams:].toList.mapM fun field => do
          let decl ← field.fvarId!.getDecl
          return (← nameLatex decl.userName) ++ " &: " ++ (← rowLatex decl.type)
    else
      info.ctors.mapM fun ctor => do
        forallBoundedTelescope (← getConstInfo ctor).type (some info.numParams) fun _ type => do
          return (← nameLatex (Name.mkSimple ctor.getString!)) ++ " &: " ++ (← rowLatex type)
  let body : Elab.TermElabM String := do
    return "\\begin{aligned}" ++ " \\\\ ".intercalate (← rows) ++ "\\end{aligned}"
  return Json.mkObj <| [
    ("name", toJson name.toString), ("kind", toJson "definition"),
    ("signatureLatex", toJson signature),
    ("source", toJson (← declarationSource name)),
    ("leanVersion", toJson Lean.versionString)] ++
    (← latexFields "latex" body)

/-- A dictionary entry: its LaTeX form, and the Lean definition it stands for. -/
meta def notationReport (name : Name) (entry : Plaer.Latex.Entry) : MetaM Json := do
  let (meaning, function, type) ← entryMeaning entry
  return Json.mkObj [
    ("name", toJson name.toString), ("kind", toJson "notation"),
    ("formLatex", toJson (← entryFormLatex entry)),
    ("meaningLean", toJson meaning), ("leanFunction", toJson function), ("typeLean", toJson type),
    ("source", toJson (← declarationSource name))]

/-- The box for one declaration: a statement (a theorem, or a closed `Prop`
definition awaiting proofs), a definition, or anything else shown as Lean only. -/
meta def declarationReport (name : Name) : MetaM Json := do
  let plain (kind : String) : MetaM Json := return Json.mkObj [
    ("name", toJson name.toString), ("kind", toJson kind),
    ("source", toJson (← declarationSource name))]
  if ← isInstance name then return ← plain "instance"
  match ← getConstInfo name with
  | .thmInfo _ => statementReport name
  | .axiomInfo info => return Json.mkObj <| [
    ("name", toJson name.toString), ("kind", toJson "axiom"),
    ("statementLean", toJson ("axiom " ++ name.toString ++ " : " ++ (← ppExpr info.type).pretty)),
    ("leanVersion", toJson Lean.versionString)] ++
    (← latexFields "statementLatex" (statementLatex info.type))
  | .defnInfo definition =>
    if let some entry := (entries (← getEnv)).find? (·.decl == name) then return ← notationReport name entry
    if definition.type.isProp then statementReport name else definitionReport name
  | .inductInfo info => inductiveReport name info
  | _ => plain "other"

/-- Reports for the given declarations, in source order, with line spans and doc
comments. Constants Lean generates inside another declaration are skipped. -/
meta def reportOf (names : Array Name) : MetaM Json := do
  let env ← getEnv
  let mut spans : Array (Nat × Nat × Name) := #[]
  for name in names do
    if name.isInternal then continue
    -- a syntax declaration, such as a dictionary entry's LaTeX form, is not a box
    if let some info := env.find? name then
      if info.type.isConstOf ``Lean.ParserDescr || info.type.isConstOf ``Lean.TrailingParserDescr then continue
    let some ranges ← findDeclarationRanges? name | continue
    spans := spans.push (ranges.range.pos.line, ranges.range.endPos.line, name)
  -- Outermost first: earlier start, then later end, then the shorter name.
  spans := spans.qsort fun (a, b, m) (c, d, n) =>
    a < c || (a == c && (b > d || (b == d && m.toString.length < n.toString.length)))
  let mut reports : Array Json := #[]
  let mut covered := 0
  for (first, last, name) in spans do
    if first ≤ covered then continue
    covered := last
    let report ← declarationReport name
    let doc := (← findDocString? env name).getD ""
    reports := reports.push <| report.mergeObj <| Json.mkObj [
      ("line", toJson first), ("endLine", toJson last), ("doc", toJson doc.trimAscii.copy)]
  return toJson reports

/-- Every declaration written in an imported module. -/
meta def moduleReport (moduleName : Name) : MetaM Json := do
  let env ← getEnv
  let some index := env.getModuleIdx? moduleName
    | throwError "Module is not imported: {moduleName}"
  reportOf env.header.moduleData[index.toNat]!.constNames

/-- Every declaration made after the imports, as when the REPL runs a paper. -/
meta def localReport : MetaM Json := do
  reportOf <| (← getEnv).constants.map₂.toList.map (·.1) |>.toArray

end Plaer
