module
public import Lean

public section

open Lean Meta Elab Term

namespace Plaer

/-- The displayed proposition. Predicate-valued functions need explicit arguments. -/
meta def statementProposition (name : Name) : MetaM Expr := do
  let info ← getConstInfo name
  match info with
  | .thmInfo theoremInfo =>
    unless ← isProp theoremInfo.type do throwError "Expected a proposition: {name}"
    return theoremInfo.type
  | .defnInfo definition =>
    unless ← isDefEq definition.type (mkSort .zero) do
      throwError "Expected a closed proposition definition or a theorem: {name}"
    unless ← isProp definition.value do throwError "Expected a proposition: {name}"
    return definition.value
  | _ => throwError "Expected a closed proposition definition or a theorem: {name}"

/-- Compare a separately compiled proof export with the complete displayed proposition. -/
meta def checkExternalProof (statementName proofName : Name) : MetaM Json := do
  let expected ← statementProposition statementName
  let result ← try
    let info ← getConstInfo proofName
    if info.isAxiom || info.isUnsafe || info.isPartial then
      throwError "The proof export must be a safe declaration with a proof body"
    let some value := info.value? (allowOpaque := true)
      | throwError "The proof export has no proof body: {proofName}"
    unless ← isProp info.type do throwError "The export is not a proof: {proofName}"
    -- Source universes remain rigid; only proof universes may be specialized to them.
    let levels ← mkFreshLevelMVarsFor info
    let value := value.instantiateLevelParams info.levelParams levels
    unless ← isDefEq (← inferType value) expected do
      throwError "The exported proof does not prove the displayed proposition"
    let value ← instantiateMVars value
    unless !value.hasSorry && !value.hasMVar do
      throwError "The exported proof contains sorry or unresolved metavariables"
    checkWithKernel value
    let mut axioms ← collectAxioms proofName
    for constant in expected.getUsedConstants do
      for axiomName in ← collectAxioms constant do
        unless axioms.contains axiomName do axioms := axioms.push axiomName
    let allowed := #[``propext, ``Classical.choice, ``Quot.sound]
    -- Axioms the paper itself states are allowed, and reported: the page says the
    -- theorem assumes them. Any other axiom fails the check.
    let paper ← findModuleOf? statementName
    let mut assumed : Array Name := #[]
    for axiomName in axioms do
      if allowed.contains axiomName then continue
      if (← findModuleOf? axiomName) == paper then
        assumed := assumed.push axiomName
        continue
      throwError "Unapproved axiom: {axiomName}"
    pure <| Json.mkObj [
      ("ok", toJson true),
      ("diagnostics", toJson "Lean's kernel accepted the displayed proposition; axiom dependencies audited."),
      ("axioms", toJson (axioms.map Name.toString)),
      ("assumes", toJson (assumed.map Name.toString))]
  catch error =>
    pure <| Json.mkObj [
      ("ok", toJson false),
      ("diagnostics", toJson (← error.toMessageData.toString)),
      ("axioms", toJson (#[] : Array String))]
  return Json.mkObj [
    ("name", toJson statementName.toString),
    ("proofDeclaration", toJson proofName.toString),
    ("statementHash", toJson (toString (hash expected))),
    ("leanVersion", toJson Lean.versionString),
    ("result", result)]

syntax "#plaer_check_proof " ident ident : command

elab_rules : command
  | `(#plaer_check_proof $statement:ident $proof:ident) => do
    let report ← Command.liftTermElabM do
      let statementName ← resolveGlobalConstNoOverload statement
      let proofName ← resolveGlobalConstNoOverload proof
      checkExternalProof statementName proofName
    logInfo m!"PLAER_PROOF_RESULT={report.compress}"

end Plaer
