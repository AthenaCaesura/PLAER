import Verso
import Plaer.Extract
import Plaer.Check
import Plaer.Proofs

open Lean Verso Doc Elab
open Verso.ArgParse
open Verso.Output Html

namespace Plaer

structure DefinitionDisplay where
  title : String
  source : String
  latex : String
  payload : String

structure ProofDisplay where
  payload : String

inductive PaperBlock where
  | definition (display : DefinitionDisplay)
  | proof (display : ProofDisplay)
  | explanations

/-- A small Verso genre for a paper containing executable definition blocks. -/
def PaperGenre : Genre where
  PartMetadata := Empty
  Block := PaperBlock
  Inline := Empty
  TraverseContext := Unit
  TraverseState := Unit

instance : TraversePart PaperGenre := {}
instance : TraverseBlock PaperGenre := {}

private def tag (name : String) (attrs : Array (String × String)) (children : Array Html) : Html :=
  .tag name attrs (.seq children)

private def text (s : String) : Html := .text true s

private def definitionHtml (display : DefinitionDisplay) : Html :=
  tag "section" #[("class", "definition"), ("data-definition", display.payload),
      ("aria-label", display.title)] #[
    tag "div" #[("class", "definition-heading")] #[
      tag "div" #[] #[
        tag "p" #[("class", "eyebrow")] #[text "Definition 1"],
        tag "h2" #[] #[text display.title]],
      tag "div" #[("class", "view-toggle"), ("role", "tablist"),
          ("aria-label", "Definition representation")] #[
        tag "button" #[("type", "button"), ("role", "tab"), ("id", "latex-tab"),
            ("aria-controls", "latex-panel"), ("aria-selected", "true"),
            ("data-view", "latex"), ("tabindex", "0")] #[text "LaTeX"],
        tag "button" #[("type", "button"), ("role", "tab"), ("id", "lean-tab"),
            ("aria-controls", "lean-panel"), ("aria-selected", "false"),
            ("data-view", "lean"), ("tabindex", "-1")] #[text "Lean"]]],
    tag "div" #[("class", "definition-body")] #[
      tag "div" #[("id", "latex-panel"), ("role", "tabpanel"),
          ("aria-labelledby", "latex-tab"), ("class", "definition-panel math-panel")] #[
        tag "div" #[("class", "display-math"), ("data-latex", display.latex)] #[text display.latex]],
      tag "div" #[("id", "lean-panel"), ("role", "tabpanel"),
          ("aria-labelledby", "lean-tab"), ("hidden", "hidden"),
          ("class", "definition-panel lean-panel")] #[
        tag "pre" #[] #[tag "code" #[("class", "lean-source")] #[text display.source]]]]]

private def proofHtml (display : ProofDisplay) : Html :=
  tag "section" #[("class", "proof-check"), ("data-proof", display.payload),
      ("aria-label", "Theorem statement and proof verification")] #[
    tag "div" #[("class", "proof-heading")] #[
      tag "div" #[] #[
        tag "p" #[("class", "eyebrow theorem-label")] #[text "Theorem"],
        tag "h2" #[("class", "theorem-title")] #[]],
      tag "div" #[("class", "view-toggle"), ("role", "tablist"),
          ("aria-label", "Theorem statement representation")] #[
        tag "button" #[("type", "button"), ("role", "tab"), ("aria-selected", "true"),
            ("data-theorem-view", "latex")] #[text "LaTeX"],
        tag "button" #[("type", "button"), ("role", "tab"), ("aria-selected", "false"),
            ("data-theorem-view", "lean")] #[text "Lean"]]],
    tag "div" #[("class", "theorem-statement")] #[
      tag "div" #[("data-statement-panel", "latex"), ("role", "tabpanel")] #[
        tag "div" #[("class", "theorem-math")] #[]],
      tag "div" #[("data-statement-panel", "lean"), ("role", "tabpanel"), ("hidden", "hidden")] #[
        tag "pre" #[("class", "theorem-lean")] #[]]],
    tag "div" #[("class", "proof-actions")] #[
      tag "button" #[("type", "button"), ("class", "verify-proof"), ("disabled", "disabled")] #[text "Run proof"],
      tag "span" #[("class", "proof-result"), ("role", "status"), ("aria-live", "polite")] #[
        tag "span" #[("class", "proof-status")] #[text "From save · not run in this session"]]]]

instance : GenreHtml PaperGenre (BuildLogT IO) where
  part _ metadata := nomatch metadata
  block _ _ display _ := pure <| match display with
    | .definition definition => definitionHtml definition
    | .proof proof => proofHtml proof
    | .explanations => tag "div" #[("class", "explanation-notebook"),
        ("data-notebook", "paper-explanations"), ("aria-label", "Explanations")] #[]
  inline _ extension := nomatch extension

structure DefinitionArgs where
  name : Name
  title : String

instance : FromArgs DefinitionArgs DocElabM where
  fromArgs := DefinitionArgs.mk <$> .positional `name .resolvedName <*>
    .namedD `title .string "The closed unit interval"

@[directive]
meta def definition : DirectiveExpanderOf DefinitionArgs
  | args, contents => do
    unless contents.isEmpty do
      throwError "The definition block takes a Lean name and generates its own contents"
    let shape ← extractInterval args.name
    let (source, sourcePath) ← declarationSource args.name
    let latex ← definitionLatex args.name
    let samples ← certifiedSamples args.name shape
    let payload := Json.mkObj [
      ("name", toJson args.name.toString), ("shape", toJson shape),
      ("samples", samples), ("sourcePath", toJson sourcePath),
      ("leanVersion", toJson Lean.versionString), ("latex", toJson latex)]
    ``(Verso.Doc.Block.other
      (PaperBlock.definition (DefinitionDisplay.mk $(quote args.title) $(quote source) $(quote latex)
        $(quote payload.compress))) #[])

structure TheoremArgs where
  name : Name
  title : String

instance : FromArgs TheoremArgs DocElabM where
  fromArgs := TheoremArgs.mk <$> .positional `name .resolvedName <*>
    .namedD `title .string "Theorem statement"

@[directive]
meta def theoremStatement : DirectiveExpanderOf TheoremArgs
  | args, contents => do
    unless contents.isEmpty do throwError "The statement box only takes a theorem name"
    let report ← checkDisplayedStatement args.name
    let payload := Json.mkObj [
      ("title", toJson args.title), ("report", report)]
    ``(Verso.Doc.Block.other (PaperBlock.proof (ProofDisplay.mk $(quote payload.compress))) #[])

@[directive]
meta def explanations : DirectiveExpanderOf Unit
  | (), contents => do
    unless contents.isEmpty do throwError "Explanation cells are edited in the notebook"
    ``(Verso.Doc.Block.other PaperBlock.explanations #[])

def renderPaper (doc : Part PaperGenre) : IO UInt32 := do
  Verso.withLogger fun logger => do
    let (content, _) ← PaperGenre.toHtml (m := BuildLogT IO) {} () () {} {} {} doc .empty |>.run logger
    IO.FS.createDirAll "build"
    IO.FS.writeFile "build/document.html" content.asString
    IO.println "Rendered the checked Verso document to build/document.html"

end Plaer
