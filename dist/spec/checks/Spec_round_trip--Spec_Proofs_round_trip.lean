import Plaer.Check
import Spec.Statements

theorem Spec.Proofs.round_trip : Spec.round_trip :=
  fun r h => Plaer.Formula.parse_render r h


#plaer_check_proof Spec.round_trip Spec.Proofs.round_trip
