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
    ("leanVersion", toJson Lean.versionString)] ++
    (← latexFields "statementLatex" (expressionLatex proposition))

/-- Generic definition data. -/
meta def definitionReport (name : Name) : MetaM Json := do
  let _ ← getConstInfoDefn name
  let moduleName := (← findModuleOf? name).getD .anonymous
  return Json.mkObj <| [
    ("name", toJson name.toString), ("kind", toJson "definition"),
    ("sourceModule", toJson moduleName.toString),
    ("source", toJson (← declarationSource name)),
    ("leanVersion", toJson Lean.versionString)] ++
    (← latexFields "latex" (definitionLatex name))

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
  -- A structure, class, or inductive type: a definition with no formula to typeset.
  | .inductInfo _ => return (← plain "definition").mergeObj (Json.mkObj [("leanOnly", toJson true)])
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
