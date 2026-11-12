"""Confirm that changing the separate proof file is reflected by Run proof."""

import os
import subprocess
from _support import ROOT
from verify_proof import WARM_LEAN, verify_theorem

proof_path = ROOT / "Plaer/Proofs.lean"
original = proof_path.read_bytes()
changed = original.replace(b"exact Int.ModEq.pow_prime_eq_self hp a", b"exact True.intro", 1)
assert changed != original
assert verify_theorem("Plaer.fermat_little")["result"]["ok"] is True
previous_pid = WARM_LEAN.process.pid
try:
    proof_path.write_bytes(changed)
    result = verify_theorem("Plaer.fermat_little")
    assert result["result"]["ok"] is False
    assert "source" not in result and "norm_num" not in str(result)
    assert WARM_LEAN.process is None, "The stale worker survived a changed proof"
    print("PASS: Lean rejects the changed external proof; the response contains no proof text", flush=True)
finally:
    if proof_path.read_bytes() != changed:
        raise RuntimeError("The proof file changed concurrently; it has not been overwritten")
    proof_path.write_bytes(original)
    from toolchain import lean_environment
    lake, environment = lean_environment()
    subprocess.run([lake, "build", "Plaer.Proofs"], cwd=ROOT, env=environment, check=True)
    print("Restored and rebuilt the original proof file", flush=True)
    assert verify_theorem("Plaer.fermat_little")["result"]["ok"] is True
    assert WARM_LEAN.process.pid != previous_pid
    WARM_LEAN.close()
    print("PASS: restored proof accepted by a freshly loaded worker", flush=True)
