import Spec.Statements

theorem Spec.Proofs.round_trip : Spec.round_trip :=
  fun r h => Plaer.Formula.parse_render r h
