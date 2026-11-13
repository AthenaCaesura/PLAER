module
public import Plaer.Check
public import Plaer.Formula.Reflect
public import Plaer.Formula.RoundTrip


public section

open Lean Meta
open Plaer.Formula (statementFormula signatureLatex definitionLatex rowLatex bindParams
  notesOf latexOf constName Scope)

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

/-- LaTeX fields for a box. Every formula is kernel-checked to mean the declaration
(`Plaer.Formula.Reflect`); one outside the formula language, or failing the check, does
not fail the document: the box keeps its Lean view and reports the reason. -/
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
    (← try
        let (r, latex) ← statementFormula proposition
        pure [("statementLatex", toJson latex), ("notes", toJson (notesOf r))]
      catch error =>
        pure [("statementLatex", Json.null), ("latexError", toJson (← error.toMessageData.toString))])

/-- Generic definition data. -/
meta def definitionReport (name : Name) : MetaM Json := do
  let info ← getConstInfoDefn name
  let moduleName := (← findModuleOf? name).getD .anonymous
  -- Its type, as Lean elaborated it: `triangle : ℕ → ℕ`, domain and range first.
  let signature ← try pure (some (← signatureLatex name)) catch _ => pure none
  return Json.mkObj <| [
    ("name", toJson name.toString), ("kind", toJson "definition"),
    ("signatureLatex", toJson signature),
    ("sourceModule", toJson moduleName.toString),
    ("source", toJson (← declarationSource name)),
    ("leanVersion", toJson Lean.versionString)] ++
    (← latexFields "latex" (definitionLatex name))

/-- A structure or class lists its fields, an inductive type its constructors, each
with its type. Each row is checked like any formula: a field whose type is a proposition
is a formula over the parameters and the fields before it.

    Monoid(α) : Type   for α : Type        even : ℕ → Prop
      op : (α, α) → α                        zero : even(0)
      op_assoc : ∀ a, b, c ∈ α, …            step : ∀ n ∈ ℕ, even(n) ⟹ even(n + 2)
-/
meta def inductiveReport (name : Name) (info : InductiveVal) : MetaM Json := do
  let env ← getEnv
  let label (n : String) : MetaM String := return latexOf [.name (← Plaer.Formula.displayNameM n)]
  let signature ← try
      forallBoundedTelescope info.type (some info.numParams) fun params result => do
        -- a family of propositions, `even : ℕ → Prop`, has a checked type line
        unless (← whnf result).isSort do
          unless params.isEmpty do throwError "a family with parameters"
          return some (← signatureLatex name)
        let head ← label name.getString!
        let names ← params.toList.mapM fun p => do label (← p.fvarId!.getDecl).userName.toString
        -- `Monoid(α) : Type for α : Type`: a type and its parameters, in a fixed template
        let given ← params.toList.mapM fun p => do
          let decl ← p.fvarId!.getDecl
          unless (← whnf decl.type).isType do throwError "a parameter that is not a type"
          return (← label decl.userName.toString) ++ " : \\mathbf{Type}"
        return some (head ++ (if names.isEmpty then "" else " ( " ++ " , ".intercalate names ++ " )") ++
          " : \\mathbf{Type}" ++ (if given.isEmpty then "" else " \\quad \\text{for } " ++ " , ".intercalate given))
    catch _ => pure none
  let rows : MetaM (List String) := do
    if isStructure env name then
      forallTelescope (← getConstInfo info.ctors.head!).type fun binders _ => do
        let params := binders[:info.numParams].toArray
        let fields := binders[info.numParams:].toArray
        let (vars, scope) ← (bindParams params (implicitOk := true)).run {}
        let mut vars := vars
        let mut scope := scope
        let mut rows := #[]
        for i in [0:fields.size] do
          let field := fields[i]!
          let decl ← field.fvarId!.getDecl
          let row ← rowLatex scope (params ++ fields[:i].toArray) vars decl.type
          rows := rows.push ((← label decl.userName.toString) ++ " &: " ++ row)
          -- later fields may mention this one by name
          unless ← isProp decl.type do
            let ((t, n), s) ← (show Plaer.Formula.ReflectM (Plaer.Formula.Ty × Plaer.Formula.Name) from do
                let t ← Plaer.Formula.reflectTy decl.type
                let n ← Plaer.Formula.displayName decl.userName.toString
                modify fun (s : Scope) => { s with vars := s.vars.push (field.fvarId!, n) }
                return (t, n)).run scope
            scope := s
            vars := (n, t, field) :: vars
        return rows.toList
    else
      info.ctors.mapM fun ctor => do
        forallBoundedTelescope (← getConstInfo ctor).type (some info.numParams) fun params type => do
          let (vars, scope) ← (bindParams params (implicitOk := true)).run {}
          return (← label ctor.getString!) ++ " &: " ++ (← rowLatex scope params vars type)
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
    (← latexFields "statementLatex" (return (← statementFormula info.type).2))
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
