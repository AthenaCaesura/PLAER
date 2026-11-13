module
public import Plaer.Check
public import Plaer.Latex

public section

open Lean Meta

namespace Plaer

/-- Read a declaration's source span through Lean's source search path. -/
meta def declarationSource (name : Name) : MetaM String := do
  let some moduleName ← findModuleOf? name | throwError "No source module recorded for {name}"
  let sourcePath ← findLean (← getSrcSearchPath) moduleName
  let source ← IO.FS.readFile sourcePath
  let some ranges ← findDeclarationRanges? name | throwError "No source span recorded for {name}"
  let fileMap := FileMap.ofString source
  let start := fileMap.ofPosition ranges.range.pos
  let stop := fileMap.ofPosition ranges.range.endPos
  return (String.Pos.Raw.extract source start stop).trimAscii.copy

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
  return Json.mkObj [
    ("name", toJson name.toString), ("kind", toJson kind),
    ("statementLean", toJson statementLean),
    ("statementLatex", toJson (← expressionLatex proposition)),
    ("statementHash", toJson (toString (hash proposition))),
    ("sourceModule", toJson moduleName.toString),
    ("leanVersion", toJson Lean.versionString)]

/-- Generic definition data. Plotting metadata belongs to an optional illustration. -/
meta def definitionReport (name : Name) : MetaM Json := do
  let _ ← getConstInfoDefn name
  let moduleName := (← findModuleOf? name).getD .anonymous
  return Json.mkObj [
    ("name", toJson name.toString), ("sourceModule", toJson moduleName.toString),
    ("source", toJson (← declarationSource name)),
    ("latex", toJson (← definitionLatex name)),
    ("leanVersion", toJson Lean.versionString)]

end Plaer
