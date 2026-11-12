import Plaer.Extract
import Plaer.Proofs

open Lean Meta Elab Term

namespace Plaer

/-- The same checker is called by the Verso block and the local preview server. -/
meta def checkStatementProof (goal : Expr) (source : String) : TermElabM Json := do
  let statementLatex ← expressionLatex goal
  let statementLean := "example : " ++ (← ppExpr goal).pretty
  let saved ← Term.saveState
  let started ← IO.monoMsNow
  let result ← try
    let proofSyntax ← match Parser.runParserCategory (← getEnv) `term source with
      | .ok parsed => pure parsed
      | .error message => throwError "{message}"
    let proof ← withoutErrToSorry <| elabTerm proofSyntax (some goal)
    synthesizeSyntheticMVarsNoPostponing
    let proof ← instantiateMVars proof
    unless !proof.hasSorry && !proof.hasMVar do
      let mut errors : Array String := #[]
      for message in (← Core.getMessageLog).toList do
        if message.severity == .error then
          errors := errors.push (← message.data.toString)
      if !errors.isEmpty then throwError "{String.intercalate "\n" errors.toList}"
      throwError "Incomplete proof: sorry or an unsolved goal remains"
    unless ← isDefEq (← inferType proof) goal do
      throwError "The proof does not prove the displayed claim"
    checkWithKernel proof
    let mut axioms : Array Name := #[]
    for name in proof.getUsedConstants ++ goal.getUsedConstants do
      for axiomName in ← collectAxioms name do
        unless axioms.contains axiomName do axioms := axioms.push axiomName
    let allowed := #[``propext, ``Classical.choice, ``Quot.sound]
    for axiomName in axioms do
      unless allowed.contains axiomName do
        throwError "Unapproved axiom in proof: {axiomName}"
    pure <| Json.mkObj [
      ("ok", toJson true),
      ("diagnostics", toJson "Lean's kernel accepted the proof of the displayed claim. No sorry or unsolved goals. Axiom dependencies audited."),
      ("axioms", toJson (axioms.map Name.toString))]
  catch error =>
    let message ← error.toMessageData.toString
    pure <| Json.mkObj [
      ("ok", toJson false), ("diagnostics", toJson message), ("axioms", toJson (#[] : Array String))]
  let elapsed := (← IO.monoMsNow) - started
  saved.restore
  return Json.mkObj [
    ("source", toJson source), ("result", result),
    ("statementHash", toJson (toString (hash goal))),
    ("statementLatex", toJson statementLatex), ("statementLean", toJson statementLean),
    ("elapsedMs", toJson elapsed), ("leanVersion", toJson Lean.versionString)]

meta def checkPointProof (point : Nat) (source : String) : TermElabM Json := do
  let goalSyntax ← `(($(quote point) : ℝ) ∈ Plaer.I)
  let goal ← elabType goalSyntax
  let report ← checkStatementProof goal source
  return report.setObjVal! "point" (toJson point)

syntax "#check_point_proof " num str : command

elab_rules : command
  | `(#check_point_proof $point:num $source:str) => do
    let report ← Command.liftTermElabM <| checkPointProof point.getNat source.getString
    logInfo m!"LEAN_PROOF_RESULT={report.compress}"

/-- Check a theorem whose proof is stored in an imported Lean file. No proof text is exported. -/
meta def checkNamedTheorem (name : Name) : MetaM Json := do
  let .thmInfo info ← getConstInfo name
    | throwError "Expected a theorem declaration: {name}"
  let started ← IO.monoMsNow
  checkWithKernel info.value
  unless ← isDefEq (← inferType info.value) info.type do
    throwError "The proof does not prove the displayed theorem statement"
  let axioms ← collectAxioms name
  let allowed := #[``propext, ``Classical.choice, ``Quot.sound]
  for axiomName in axioms do
    unless allowed.contains axiomName do throwError "Unapproved axiom: {axiomName}"
  let statementLatex ← expressionLatex info.type
  let statementLean := "theorem " ++ name.toString ++ " : " ++ (← ppExpr info.type).pretty
  let sourceModule := (← findModuleOf? name).getD .anonymous
  return Json.mkObj [
    ("name", toJson name.toString),
    ("statementLatex", toJson statementLatex), ("statementLean", toJson statementLean),
    ("statementHash", toJson (toString (hash info.type))),
    ("proofFile", toJson (sourceModule.toString.replace "." "/" ++ ".lean")),
    ("result", Json.mkObj [("ok", toJson true)]),
    ("elapsedMs", toJson ((← IO.monoMsNow) - started)),
    ("leanVersion", toJson Lean.versionString)]

/-- Dispatch only documented statements. A candidate remains a proposition, never an axiom. -/
meta def checkDisplayedStatement (name : Name) : TermElabM Json := do
  if name != ``outside_point_statement && name != ``fermat_last_statement then return ← checkNamedTheorem name
  let .defnInfo info ← getConstInfo name
    | throwError "Expected a candidate proposition"
  let attempt := if name == ``fermat_last_statement then fermat_last_attempt else outside_point_attempt
  let report ← checkStatementProof info.value attempt
  let mut fields := [("name", toJson name.toString),
    ("kind", toJson "candidate"), ("proofFile", toJson "Plaer/Proofs.lean")]
  for key in ["statementLatex", "statementLean", "statementHash", "elapsedMs", "leanVersion"] do
    fields := fields ++ [(key, (report.getObjVal? key).toOption.getD Json.null)]
  -- The detailed compiler result and the attempted proof stay outside the paper.
  let accepted := ((report.getObjVal? "result" >>= fun r => r.getObjValAs? Bool "ok").toOption).getD false
  return Json.mkObj (fields ++ [("result", Json.mkObj [("ok", toJson accepted)])])

syntax "#check_theorem " ident : command

elab_rules : command
  | `(#check_theorem $name:ident) => do
    let report ← Command.liftTermElabM <| checkNamedTheorem name.getId
    logInfo m!"LEAN_THEOREM_RESULT={report.compress}"

end Plaer
