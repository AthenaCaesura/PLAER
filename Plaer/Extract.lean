module
public import Plaer.Check
public import Plaer.Latex

public section

open Lean Meta

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

/-- LaTeX fields for a box. Notation the strict printer cannot typeset does not
fail the document: the box keeps its Lean view and reports the reason. -/
private meta def latexFields (field : String) (render : MetaM String) : MetaM (List (String × Json)) := do
  try
    return [(field, toJson (← render))]
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
    ("notes", toJson (← boxNotes proposition)),
    ("leanVersion", toJson Lean.versionString)] ++
    (← latexFields "statementLatex" (expressionLatex proposition))

/-- Generic definition data. -/
meta def definitionReport (name : Name) : MetaM Json := do
  let info ← getConstInfoDefn name
  let moduleName := (← findModuleOf? name).getD .anonymous
  -- Its type, as Lean elaborated it: `triangle : ℕ → ℕ`, domain and range first.
  let signature ← try
      pure (some ((← nameLatex name) ++ " : " ++ (← expressionLatex info.type)))
    catch _ => pure none
  return Json.mkObj <| [
    ("name", toJson name.toString), ("kind", toJson "definition"),
    ("signatureLatex", toJson signature),
    ("sourceModule", toJson moduleName.toString),
    ("notes", toJson ((← boxNotes info.type) ++ (← boxNotes info.value)).toList.eraseDups),
    ("source", toJson (← declarationSource name)),
    ("leanVersion", toJson Lean.versionString)] ++
    (← latexFields "latex" (definitionLatex name))

/-- A structure or class lists its fields, an inductive type its constructors,
each with its type as Lean elaborated it. Parameters are named once, in the type
line, and the rows use them:

    Monoid'(α) : Type   for α : Type        even : ℕ → Prop
      op : α → α → α                          zero : even(0)
      op_assoc : ∀ a, b, c : α, …             step : ∀ n : ℕ, even(n) ⟹ even(n + 2)

A field's type is read from the constructor, where each field is a variable, so the
fields before it are written by name, `op(a, b)` or `value < 10`, as in the list. -/
meta def inductiveReport (name : Name) (info : InductiveVal) : MetaM Json := do
  let env ← getEnv
  let signature ← try
      forallBoundedTelescope info.type (some info.numParams) fun params result => do
        let names ← params.toList.mapM fun p => return (← p.fvarId!.getDecl).userName.toLatex
        let head := (← nameLatex name) ++ (if names.isEmpty then "" else "(" ++ ", ".intercalate names ++ ")")
        let binders ← params.toList.mapM fun p => do
          let decl ← p.fvarId!.getDecl
          return decl.userName.toLatex ++ " : " ++ (← expressionLatex decl.type)
        let given := if binders.isEmpty then "" else " \\quad \\text{for } " ++ ", ".intercalate binders
        return some (head ++ " : " ++ (← expressionLatex result) ++ given)
    catch _ => pure none
  let rows : MetaM (List String) := do
    if isStructure env name then
      forallTelescope (← getConstInfo info.ctors.head!).type fun binders _ => do
        binders[info.numParams:].toList.mapM fun field => do
          let decl ← field.fvarId!.getDecl
          return decl.userName.toLatex ++ " &: " ++ (← expressionLatex decl.type)
    else
      info.ctors.mapM fun ctor => do
        forallBoundedTelescope (← getConstInfo ctor).type (some info.numParams) fun _ type => do
          return (Name.mkSimple ctor.getString!).toLatex ++ " &: " ++ (← expressionLatex type)
  let body : MetaM String := do
    return "\\begin{aligned}" ++ " \\\\ ".intercalate (← rows) ++ "\\end{aligned}"
  return Json.mkObj <| [
    ("name", toJson name.toString), ("kind", toJson "definition"),
    ("signatureLatex", toJson signature),
    ("source", toJson (← declarationSource name)),
    ("leanVersion", toJson Lean.versionString)] ++
    (← latexFields "latex" body)

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
    (← latexFields "statementLatex" (expressionLatex info.type))
  | .defnInfo definition =>
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
