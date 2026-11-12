import Plaer.Check
import Plaer.Proofs

open Lean Meta

unsafe def main : IO Unit := do
  initSearchPath (← findSysroot)
  enableInitializersExecution
  let env ← importModules #[{module := `Plaer.Check}, {module := `Plaer.Proofs}] {}
    (loadExts := true)
  let input ← IO.getStdin
  let output ← IO.getStdout
  output.putStrLn "LEAN_WORKER_READY"
  output.flush
  repeat
    let line ← input.getLine
    if line.isEmpty then break
    let result ← try
      let name := line.trimAscii.toString.toName
      let report ← (Plaer.checkDisplayedStatement name).run' |>.run' |>.toIO'
        {fileName := "<live proof check>", fileMap := default}
        {env := env}
      pure report
    catch error => pure <| Json.mkObj [("error", toJson error.toString)]
    output.putStrLn result.compress
    output.flush
