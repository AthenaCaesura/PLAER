module

public import Plaer.Formula.Parse

@[expose] public section

/-! # The LaTeX determines the formula

The theorems of this file are what make a box's LaTeX trustworthy: reading a formula's
LaTeX back, by the precedence rules of `Plaer.Formula.Latex`, gives exactly that
formula. So two different formulas never have the same LaTeX, and since `denote` is a
function of the formula, the LaTeX determines the meaning. -/

namespace Plaer.Formula

/-- A type the language can show: every name in it is valid. -/
def Ty.wf : Ty → Bool
  | .named n => n.valid
  | .fn a b => a.wf && b.wf
  | _ => true

mutual
/-- A formula the language can show: every name in it is valid, and every quantifier
binds at least one name. -/
def Raw.wf : Raw → Bool
  | .ident n => n.valid
  | .num _ => true
  | .app f args => f.wf && args.wf
  | .bin _ a b => a.wf && b.wf
  | .not a => a.wf
  | .pow a b => a.wf && b.wf
  | .floorDiv a b => a.wf && b.wf
  | .ann e t => e.wf && t.wf
  | .quant _ xs t body => !xs.isEmpty && xs.all Name.valid && t.wf && body.wf

def Args.wf : Args → Bool
  | .one a => a.wf
  | .cons a rest => a.wf && rest.wf
end

/-- A token the lexer can read back: a name in it is valid. -/
def Tok.wf : Tok → Bool
  | .name n => n.valid
  | _ => true

/-! ## Proofs

The lexer: every token's text reads back as that token, and contains no space. -/

theorem Sym.mem_all (s : Sym) : s ∈ Sym.all := by cases s <;> decide

theorem Sym.ofText_text (s : Sym) : Sym.ofText s.text = some s := by cases s <;> rfl

theorem Sym.ofText_eq_none {w : List Char} (h : ∀ s : Sym, s.text ≠ w) : Sym.ofText w = none := by
  unfold Sym.ofText
  rw [List.find?_eq_none]
  intro s _ hs
  exact h s (by simpa using hs)

theorem ascii_facts {c : Char} (h : isAsciiLetter c = true) :
    isDigitChar c = false ∧ c ≠ ' ' := by
  simp [isAsciiLetter, isDigitChar, Char.le_def, Char.ext_iff, UInt32.le_iff_toNat_le,
    ← UInt32.toNat_inj] at *
  omega

theorem word_facts {c : Char} (h : isWordChar c = true) : c ≠ ' ' ∧ c ≠ '\\' := by
  simp [isWordChar, isAsciiLetter, isDigitChar, Char.le_def, Char.ext_iff,
    UInt32.le_iff_toNat_le, ← UInt32.toNat_inj] at *
  omega

/-! ### Numerals -/

theorem digit_facts (m : Nat) (h : m < 10) :
    isDigitChar (Char.ofNat (48 + m)) = true ∧ (Char.ofNat (48 + m)).toNat = 48 + m := by
  have : ∀ i : Fin 10, isDigitChar (Char.ofNat (48 + i.val)) = true ∧
      (Char.ofNat (48 + i.val)).toNat = 48 + i.val := by decide
  exact this ⟨m, h⟩

theorem digitsRev_ne_nil (k : Nat) : digitsRev k ≠ [] := by
  rw [digitsRev.eq_1]; split <;> simp

theorem digitsRev_all (k : Nat) : (digitsRev k).all isDigitChar = true := by
  induction k using Nat.strongRecOn with
  | _ k ih =>
    rw [digitsRev.eq_1]
    have := (digit_facts (k % 10) (Nat.mod_lt _ (by omega))).1
    split
    · simp [this]
    · simp [this, ih (k / 10) (by omega)]

theorem digitsRev_foldr (k : Nat) :
    (digitsRev k).foldr (fun x y => 10 * y + (x.toNat - 48)) 0 = k := by
  induction k using Nat.strongRecOn with
  | _ k ih =>
    rw [digitsRev.eq_1]
    have := (digit_facts (k % 10) (Nat.mod_lt _ (by omega))).2
    split
    · simp [this]; omega
    · simp [this, ih (k / 10) (by omega)]; omega

theorem ofDigits_digits (k : Nat) : ofDigits (digits k) = some k := by
  unfold ofDigits digits
  have h1 := digitsRev_ne_nil k
  split
  · rename_i h; simp at h; exact absurd h h1
  · simp [List.all_reverse, digitsRev_all, digitsRev_foldr]

theorem space_not_digits (k : Nat) : ' ' ∉ digits k := by
  intro h
  have := List.all_eq_true.mp (digitsRev_all k) ' ' (by simpa [digits] using h)
  simp [isDigitChar] at this

theorem sym_not_digits : ∀ s ∈ Sym.all, s.text.all isDigitChar = false := by decide

/-! ### Names -/

theorem operatorname_eq :
    operatorname = ['\\','o','p','e','r','a','t','o','r','n','a','m','e','{'] := rfl

theorem sym_not_operatorname : ∀ s ∈ Sym.all, operatorname.isPrefixOf s.text = false := by decide
theorem greek_not_operatorname : ∀ p ∈ greek, operatorname.isPrefixOf p.2 = false := by decide
theorem greek_ofText : ∀ p ∈ greek, Tok.ofText p.2 = some (.name [p.1]) := by decide
theorem greek_space : ∀ p ∈ greek, ' ' ∉ p.2 ∧ p.2 ≠ [] := by decide
theorem greek_not_ascii : ∀ p ∈ greek, isAsciiLetter p.1 = false := by decide
theorem sym_single : ∀ s ∈ Sym.all, s.text.length = 1 → isAsciiLetter (s.text.headD 'a') = false := by
  decide
theorem sym_space : ∀ s ∈ Sym.all, ' ' ∉ s.text ∧ s.text ≠ [] := by decide

theorem lookup_mem {c : Char} {s : List Char} :
    ∀ {l : List (Char × List Char)}, l.lookup c = some s → (c, s) ∈ l
  | [], h => by simp [List.lookup] at h
  | (a, b) :: l, h => by
    simp only [List.lookup] at h
    split at h
    · rename_i hc; simp at hc h; subst hc; subst h; simp
    · exact List.mem_cons_of_mem _ (lookup_mem h)

theorem unescape_cons {c : Char} (hc : c ≠ '\\') (l : List Char) :
    unescape (c :: l) = c :: unescape l := by
  cases l with
  | nil => simp [unescape]
  | cons d ds => simp [unescape, hc]

theorem unescape_escape : ∀ n : List Char, n.all isWordChar = true → unescape (escape n) = n
  | [], _ => rfl
  | c :: cs, h => by
    simp only [List.all_cons, Bool.and_eq_true] at h
    have ih := unescape_escape cs h.2
    have hc := word_facts h.1
    by_cases hu : c = '_'
    · subst hu; simp [escape, unescape, ih]
    · rw [escape, unescape_cons hc.2, ih]
      exact hu

theorem escape_space : ∀ n : List Char, n.all isWordChar = true → ' ' ∉ escape n
  | [], _ => by simp [escape]
  | c :: cs, h => by
    simp only [List.all_cons, Bool.and_eq_true] at h
    have ih := escape_space cs h.2
    have hc := word_facts h.1
    by_cases hu : c = '_'
    · subst hu; simp [escape, ih]
    · rw [escape]
      · simp [ih]; exact fun e => hc.1 e.symm
      · exact hu

theorem name_ofText (n : Name) (h : n.valid = true) :
    Tok.ofText n.text = some (.name n) ∧ ' ' ∉ n.text ∧ n.text ≠ [] := by
  match n, h with
  | [c], h =>
    simp only [Name.valid, Bool.or_eq_true] at h
    rcases h with h | h
    · have hl : greek.lookup c = none := by
        cases hl : greek.lookup c with
        | none => rfl
        | some s =>
          have := greek_not_ascii _ (lookup_mem hl)
          simp at this; rw [this] at h; cases h
      have ha := ascii_facts h
      simp only [Name.text, hl, Option.getD_none]
      refine ⟨?_, ?_, by simp⟩
      · have hs : Sym.ofText [c] = none := Sym.ofText_eq_none (by
          intro s hs
          have := sym_single s (Sym.mem_all s) (by simp [hs])
          rw [hs] at this; simp at this; rw [this] at h; cases h)
        simp [Tok.ofText, hs, ofDigits, ha.1, Name.ofText, h]
      · simp; exact fun e => ha.2 e.symm
    · obtain ⟨s, hs⟩ := Option.isSome_iff_exists.mp h
      have hm := lookup_mem hs
      simp only [Name.text, hs, Option.getD_some]
      exact ⟨greek_ofText _ hm, (greek_space _ hm).1, (greek_space _ hm).2⟩
  | c :: d :: rest, h =>
    simp only [Name.valid, Bool.and_eq_true] at h
    have hall : (c :: d :: rest).all isWordChar = true := by
      simp only [List.all_cons, Bool.and_eq_true] at h ⊢
      refine ⟨?_, h.2⟩
      simp [isWordChar, h.1]
    have htext : Name.text (c :: d :: rest) = operatorname ++ (escape (c :: d :: rest) ++ ['}']) := by
      simp [Name.text]
    rw [htext]
    generalize hW : escape (c :: d :: rest) = W at *
    have hpre : operatorname.isPrefixOf (operatorname ++ (W ++ ['}'])) = true := by
      rw [List.isPrefixOf_iff_prefix]; exact List.prefix_append _ _
    refine ⟨?_, ?_, by simp⟩
    · have hs : Sym.ofText (operatorname ++ (W ++ ['}'])) = none :=
        Sym.ofText_eq_none (by
          intro s hs
          have := sym_not_operatorname s (Sym.mem_all s)
          rw [hs, hpre] at this; cases this)
      have hd : ofDigits (operatorname ++ (W ++ ['}'])) = none := by
        simp [ofDigits, operatorname_eq, isDigitChar]
      have hg : greek.find? (·.2 == operatorname ++ (W ++ ['}'])) = none := by
        rw [List.find?_eq_none]
        intro p hp he
        have := greek_not_operatorname p hp
        simp at he; rw [he, hpre] at this; cases this
      simp only [Tok.ofText, hs, hd]
      have hlen : 2 ≤ (operatorname ++ (W ++ ['}'])).length := by
        simp [operatorname_eq]
      generalize hw : operatorname ++ (W ++ ['}']) = w at *
      unfold Name.ofText
      split
      · simp at hlen
      · rw [hg]
        have hl : w.getLast? = some '}' := by rw [← hw]; simp
        have hd : (w.drop operatorname.length).dropLast = W := by
          rw [← hw, List.drop_left]; simp
        simp only [hpre, hl, hd, ← hW, unescape_escape _ hall]
        simp [Name.valid, h]
    · rw [operatorname_eq, ← hW]
      simp [escape_space _ hall]

theorem Tok.ofText_text (t : Tok) (h : t.wf = true) :
    Tok.ofText t.text = some t ∧ ' ' ∉ t.text ∧ t.text ≠ [] := by
  cases t with
  | sym s =>
    have := sym_space s (Sym.mem_all s)
    exact ⟨by simp [Tok.ofText, Tok.text, Sym.ofText_text], this⟩
  | name n => exact name_ofText n h
  | num k =>
    have hs : Sym.ofText (digits k) = none := Sym.ofText_eq_none (by
      intro s hs
      have := sym_not_digits s (Sym.mem_all s)
      rw [hs] at this
      simp [digits, List.all_reverse, digitsRev_all] at this)
    refine ⟨by simp [Tok.ofText, Tok.text, hs, ofDigits_digits], space_not_digits k, ?_⟩
    simp [Tok.text, digits, digitsRev_ne_nil]

theorem mapM_ofText (ts : List Tok) (h : ∀ t ∈ ts, t.wf) :
    (ts.map Tok.text).mapM Tok.ofText = some ts := by
  induction ts with
  | nil => rfl
  | cons t ts ih =>
    simp only [List.map_cons, List.mapM_cons]
    rw [(Tok.ofText_text t (h t (by simp))).1, ih (fun x hx => h x (by simp [hx]))]
    rfl


/-! ### The parser

The follow-set invariant: a formula parsed at level `k` stops before any token that
would continue a formula of level `k` or higher (`Stops k`). -/

def Tok.cont : Tok → Option Nat
  | .sym .implies | .sym .iff => some 1
  | .sym .or => some 2
  | .sym .and => some 3
  | .sym .eq | .sym .ne | .sym .lt | .sym .le | .sym .gt | .sym .ge => some 5
  | .sym .add | .sym .sub | .sym .monus => some 6
  | .sym .mul => some 7
  | .sym .pow => some 8
  | .sym .lp => some 9
  | _ => none

def Stops (k : Nat) : List Tok → Prop
  | [] => True
  | t :: _ => ∀ l, t.cont = some l → l < k

theorem Stops.mono {k k' : Nat} (h : k ≤ k') : ∀ {ts : List Tok}, Stops k ts → Stops k' ts
  | [], _ => trivial
  | _ :: _, hs => fun l hl => Nat.lt_of_lt_of_le (hs l hl) h

theorem Stops.of_none {k : Nat} {t : Tok} {ts : List Tok} (h : t.cont = none) :
    Stops k (t :: ts) := by
  intro l hl; rw [h] at hl; cases hl

theorem Tok.cont_le (t : Tok) : ∀ l, t.cont = some l → l ≤ 9 := by
  intro l hl
  rcases t with s | n | k
  · cases s <;> simp [Tok.cont] at hl <;> omega
  · simp [Tok.cont] at hl
  · simp [Tok.cont] at hl

theorem Stops.ten : ∀ ts : List Tok, Stops 10 ts
  | [] => trivial
  | t :: _ => fun l hl => Nat.lt_of_le_of_lt (Tok.cont_le t l hl) (by decide)

theorem BinOp.cont_sym (o : BinOp) : (Tok.sym o.sym).cont = some o.level := by cases o <;> rfl
theorem opAt_sym (o : BinOp) : opAt o.level (.sym o.sym) = some o := by cases o <;> rfl

theorem opAt_cont {k : Nat} {t : Tok} {o : BinOp} (h : opAt k t = some o) : t.cont = some k := by
  cases t with
  | sym s =>
    simp only [opAt] at h
    have h1 := List.find?_some h
    simp only [Bool.and_eq_true, beq_iff_eq] at h1
    obtain ⟨rfl, rfl⟩ := h1
    exact BinOp.cont_sym o
  | name _ => simp [opAt] at h
  | num _ => simp [opAt] at h

theorem opAt_none {k : Nat} {t : Tok} {ts : List Tok} (h : Stops k (t :: ts)) : opAt k t = none := by
  cases hk : opAt k t with
  | none => rfl
  | some o => exact absurd (h k (opAt_cont hk)) (Nat.lt_irrefl k)

/-! ### Unfolding the parser -/

def binTail (f k : Nat) (a : Raw) (ts : List Tok) : Option (Raw × List Tok) :=
  match ts with
  | t :: rest =>
    match opAt k t with
    | some o => (parseAt f (if o.assoc == .right then k else k + 1) rest).bind
        (fun p => some (.bin o a p.1, p.2))
    | none => some (a, ts)
  | [] => some (a, ts)

def powTail (f : Nat) (a : Raw) (ts : List Tok) : Option (Raw × List Tok) :=
  match ts with
  | .sym .pow :: ts => do
    let (b, ts) ← parseAt f 0 ts
    let ts ← expect .rbrace ts
    some (.pow a b, ts)
  | _ => some (a, ts)

theorem parseAt_bin (f k : Nat) (ts : List Tok) (hk : k = 1 ∨ k = 2 ∨ k = 3 ∨ k = 5) :
    parseAt (f + 1) k ts = (parseAt f (k + 1) ts).bind (fun p => binTail f k p.1 p.2) := by
  rcases hk with rfl | rfl | rfl | rfl <;> rfl

theorem parseAt_left (f k : Nat) (ts : List Tok) (hk : k = 6 ∨ k = 7) :
    parseAt (f + 1) k ts = (parseAt f (k + 1) ts).bind (fun p => parseLeft f k p.1 p.2) := by
  rcases hk with rfl | rfl <;> rfl

theorem parseAt_eight (f : Nat) (ts : List Tok) :
    parseAt (f + 1) 8 ts = (parseAt f 9 ts).bind (fun p => powTail f p.1 p.2) := rfl

theorem parseAt_nine (f : Nat) (ts : List Tok) :
    parseAt (f + 1) 9 ts = (parseAtom f ts).bind (fun p => parseCalls f p.1 p.2) := rfl

theorem parseAt_ten (f : Nat) (ts : List Tok) : parseAt (f + 1) 10 ts = parseAtom f ts := rfl

theorem parseAt_zero (f : Nat) (t : Tok) (ts : List Tok) (h1 : t ≠ .sym .forall_)
    (h2 : t ≠ .sym .exists_) : parseAt (f + 1) 0 (t :: ts) = parseAt f 1 (t :: ts) := by
  rcases t with s | n | k
  · cases s <;> first | rfl | (exfalso; simp_all)
  · rfl
  · rfl

theorem parseAt_four (f : Nat) (t : Tok) (ts : List Tok) (h1 : t ≠ .sym .not) :
    parseAt (f + 1) 4 (t :: ts) = parseAt f 5 (t :: ts) := by
  rcases t with s | n | k
  · cases s <;> first | rfl | (exfalso; simp_all)
  · rfl
  · rfl

theorem binTail_stop {f k : Nat} {v : Raw} {rest : List Tok} (h : Stops k rest) :
    binTail f k v rest = some (v, rest) := by
  cases rest with
  | nil => rfl
  | cons t ts => simp [binTail, opAt_none h]

theorem parseLeft_stop {f k : Nat} {v : Raw} {rest : List Tok} (h : Stops k rest) :
    parseLeft (f + 1) k v rest = some (v, rest) := by
  cases rest with
  | nil => rfl
  | cons t ts => simp [parseLeft, opAt_none h]

theorem powTail_stop {f : Nat} {v : Raw} {rest : List Tok} (h : Stops 8 rest) :
    powTail f v rest = some (v, rest) := by
  match rest, h with
  | [], _ => rfl
  | .sym .pow :: _, h => exact absurd (h 8 rfl) (by decide)
  | .sym s :: _, h => cases s <;> first | rfl | exact absurd (h 8 rfl) (by decide)
  | .name _ :: _, _ => rfl
  | .num _ :: _, _ => rfl

theorem parseCalls_stop {f : Nat} {v : Raw} {rest : List Tok} (h : Stops 9 rest) :
    parseCalls (f + 1) v rest = some (v, rest) := by
  match rest, h with
  | [], _ => rfl
  | .sym s :: _, h => cases s <;> first | rfl | exact absurd (h 9 rfl) (by decide)
  | .name _ :: _, _ => rfl
  | .num _ :: _, _ => rfl

/-! ### Parsing a token list at a level -/

def ParsesAt (j : Nat) (L : List Tok) (v : Raw) : Prop :=
  ∀ fuel rest, 16 * L.length + 11 - j ≤ fuel → Stops j rest →
    parseAt fuel j (L ++ rest) = some (v, rest)

def HeadOK (L : List Tok) (j : Nat) : Prop :=
  ∃ t tl, L = t :: tl ∧ (0 < j → t ≠ .sym .forall_ ∧ t ≠ .sym .exists_) ∧
    (4 < j → t ≠ .sym .not)

theorem down {L : List Tok} {v : Raw} {j : Nat} (hj : j ≤ 10) (hh : HeadOK L j)
    (hp : ParsesAt j L v) : ∀ k ≤ j, ParsesAt k L v := by
  obtain ⟨t, tl, rfl, h0, h4⟩ := hh
  have key : ∀ d, d ≤ j → ParsesAt (j - d) (t :: tl) v := by
    intro d
    induction d with
    | zero => intro _; simpa using hp
    | succ d ih =>
      intro hd
      have ih := ih (by omega)
      generalize hk : j - (d + 1) = k
      have hk1 : j - d = k + 1 := by omega
      rw [hk1] at ih
      intro fuel rest hf hs
      obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by simp at hf; omega⟩
      have hs1 : Stops (k + 1) rest := Stops.mono (by omega) hs
      have hlen : (t :: tl).length ≥ 1 := by simp
      rcases (show k = 0 ∨ k = 1 ∨ k = 2 ∨ k = 3 ∨ k = 4 ∨ k = 5 ∨ k = 6 ∨ k = 7 ∨ k = 8 ∨
          k = 9 by omega) with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
      · have := h0 (by omega)
        rw [List.cons_append, parseAt_zero _ _ _ this.1 this.2, ← List.cons_append]
        exact ih f rest (by omega) hs1
      · rw [parseAt_bin _ _ _ (by omega), ih f rest (by omega) hs1]
        exact binTail_stop hs
      · rw [parseAt_bin _ _ _ (by omega), ih f rest (by omega) hs1]
        exact binTail_stop hs
      · rw [parseAt_bin _ _ _ (by omega), ih f rest (by omega) hs1]
        exact binTail_stop hs
      · have := h4 (by omega)
        rw [List.cons_append, parseAt_four _ _ _ this, ← List.cons_append]
        exact ih f rest (by omega) hs1
      · rw [parseAt_bin _ _ _ (by omega), ih f rest (by omega) hs1]
        exact binTail_stop hs
      · obtain ⟨g, rfl⟩ : ∃ g, f = g + 1 := ⟨f - 1, by omega⟩
        rw [parseAt_left _ _ _ (by omega), ih (g + 1) rest (by omega) hs1]
        exact parseLeft_stop hs
      · obtain ⟨g, rfl⟩ : ∃ g, f = g + 1 := ⟨f - 1, by omega⟩
        rw [parseAt_left _ _ _ (by omega), ih (g + 1) rest (by omega) hs1]
        exact parseLeft_stop hs
      · rw [parseAt_eight, ih f rest (by omega) hs1]
        exact powTail_stop hs
      · obtain ⟨g, rfl⟩ : ∃ g, f = g + 1 := ⟨f - 1, by omega⟩
        rw [parseAt_nine, ← parseAt_ten, ih (g + 1 + 1) rest (by omega) hs1]
        exact parseCalls_stop hs
  intro k hk
  have := key (j - k) (by omega)
  rwa [show j - (j - k) = k by omega] at this

/-! ### Types -/

def TyStops (rest : List Tok) : Prop := ∀ tl, rest ≠ .sym .to :: tl

def TyParses (L : List Tok) (t : Ty) : Prop :=
  ∀ fuel rest, 16 * L.length ≤ fuel → TyStops rest → parseTy fuel (L ++ rest) = some (t, rest)

def IsAtom : Ty → Prop
  | .fn .. => False
  | _ => True

/-- What `parseTyList` reads from `moreInputs b` (after its leading comma). -/
def MoreParses (b : Ty) : Prop :=
  ∃ Y, b.moreInputs = .sym .comma :: Y ∧
    ∀ fuel rest, 16 * Y.length ≤ fuel → ∃ c ins out, (c :: ins).foldr Ty.fn out = b ∧ IsAtom out ∧
      parseTyList fuel (Y ++ rest) = some (c :: ins, .sym .rp :: .sym .to :: out.toks ++ rest) ∧
      out.toks.length = 1

theorem atom_toks (t : Ty) (h : IsAtom t) :
    ∃ x, t.toks = [x] ∧ x ≠ .sym .lp ∧ ∀ fuel ts, parseTy (fuel + 1) (x :: ts) =
      match ts with
      | .sym .to :: ts => (parseTy fuel ts).bind (fun p => some (.fn t p.1, p.2))
      | _ => some (t, ts) := by
  cases t with
  | fn => exact h.elim
  | prop => exact ⟨_, rfl, by decide, fun _ _ => rfl⟩
  | nat => exact ⟨_, rfl, by decide, fun _ _ => rfl⟩
  | int => exact ⟨_, rfl, by decide, fun _ _ => rfl⟩
  | named n => exact ⟨_, rfl, by simp, fun _ _ => rfl⟩

theorem atom_parses (t : Ty) (h : IsAtom t) : TyParses t.toks t := by
  obtain ⟨x, hx, -, hp⟩ := atom_toks t h
  intro fuel rest hf hs
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by simp [hx] at hf; omega⟩
  rw [hx, List.singleton_append, hp]
  match rest, hs with
  | [], _ => rfl
  | .sym .to :: tl, hs => exact absurd rfl (hs tl)
  | .sym s :: tl, hs => cases s <;> first | rfl | exact absurd rfl (hs tl)
  | .name _ :: _, _ => rfl
  | .num _ :: _, _ => rfl

theorem parseTy_lp_one {f : Nat} {ts ts' rest : List Tok} {a b : Ty}
    (h1 : parseTyList f ts = some ([a], .sym .rp :: .sym .to :: ts'))
    (h2 : parseTy f ts' = some (b, rest)) :
    parseTy (f + 1) (.sym .lp :: ts) = some (.fn a b, rest) := by
  simp [parseTy, h1, h2, expect]

theorem parseTy_lp_many {f : Nat} {ts ts' rest : List Tok} {a c : Ty} {more : List Ty} {b : Ty}
    (h1 : parseTyList f ts = some (a :: c :: more, .sym .rp :: .sym .to :: ts'))
    (h2 : parseTy f ts' = some (b, rest)) :
    parseTy (f + 1) (.sym .lp :: ts) = some (.fn a ((c :: more).foldr Ty.fn b), rest) := by
  simp [parseTy, h1, h2, expect]

theorem parseTyList_one {f : Nat} {ts rest : List Tok} {a : Ty}
    (h1 : parseTy f ts = some (a, rest)) (h2 : ∀ tl, rest ≠ .sym .comma :: tl) :
    parseTyList (f + 1) ts = some ([a], rest) := by
  simp only [parseTyList, h1]
  match rest, h2 with
  | .sym .comma :: tl, h2 => exact absurd rfl (h2 tl)
  | [], _ => rfl
  | .sym s :: tl, h2 => cases s <;> first | rfl | exact absurd rfl (h2 tl)
  | .name _ :: _, _ => rfl
  | .num _ :: _, _ => rfl

theorem parseTyList_cons {f : Nat} {ts rest rest' : List Tok} {a : Ty} {more : List Ty}
    (h1 : parseTy f ts = some (a, .sym .comma :: rest))
    (h2 : parseTyList f rest = some (more, rest')) :
    parseTyList (f + 1) ts = some (a :: more, rest') := by
  simp [parseTyList, h1, h2]

theorem TyStops.of_ne {x : Tok} {tl : List Tok} (h : x ≠ .sym .to) : TyStops (x :: tl) := by
  intro tl' e; cases e; exact h rfl

theorem fn_atom_toks (a b : Ty) (hb : IsAtom b) :
    (Ty.fn a b).toks = bracket (a matches .fn ..) a.toks ++ .sym .to :: b.toks := by
  cases b with
  | fn => exact hb.elim
  | _ => rfl

theorem matches_fn_false : ∀ a : Ty, IsAtom a → (a matches .fn ..) = false := by
  intro a ha
  cases a with
  | fn => exact ha.elim
  | _ => rfl

theorem fnAtomAtom (a b : Ty) (ha : IsAtom a) (hb : IsAtom b) :
    TyParses (Ty.fn a b).toks (.fn a b) := by
  rw [fn_atom_toks a b hb, matches_fn_false a ha]
  obtain ⟨xb, hxb, -, -⟩ := atom_toks b hb
  obtain ⟨xa, hxa, -, hpa⟩ := atom_toks a ha
  intro fuel rest hf hs
  have hB := atom_parses b hb
  simp only [bracket, Bool.false_eq_true, ite_false, hxa, hxb, List.length_append,
    List.length_cons] at hf ⊢
  obtain ⟨g, rfl⟩ : ∃ g, fuel = g + 1 := ⟨fuel - 1, by simp at hf; omega⟩
  have h2 := hB g rest (by simp [hxb]; omega) hs
  rw [hxb, List.singleton_append] at h2
  simp [hpa, h2]

theorem fnFnAtom (a1 a2 b : Ty) (hb : IsAtom b) (hA : TyParses (Ty.fn a1 a2).toks (.fn a1 a2)) :
    TyParses (Ty.fn (.fn a1 a2) b).toks (.fn (.fn a1 a2) b) := by
  rw [fn_atom_toks _ b hb]
  obtain ⟨xb, hxb, -, -⟩ := atom_toks b hb
  intro fuel rest hf hs
  have hB := atom_parses b hb
  simp only [bracket, ite_true, List.length_append, List.length_cons, hxb] at hf ⊢
  obtain ⟨g, rfl⟩ : ∃ g, fuel = g + 1 + 1 := ⟨fuel - 2, by simp at hf; omega⟩
  have h1 : parseTyList (g + 1) ((Ty.fn a1 a2).toks ++ (.sym .rp :: .sym .to :: xb :: rest)) =
      some ([.fn a1 a2], .sym .rp :: .sym .to :: xb :: rest) :=
    parseTyList_one (hA g _ (by simp at hf; omega) (TyStops.of_ne (by decide)))
      (by intro tl e; cases e)
  have h2 := hB (g + 1) rest (by simp [hxb]; omega) hs
  rw [hxb] at h2
  simpa using parseTy_lp_one h1 h2

theorem fnAtom (a b : Ty) (hb : IsAtom b) (hA : TyParses a.toks a) :
    TyParses (Ty.fn a b).toks (.fn a b) := by
  cases a with
  | fn a1 a2 => exact fnFnAtom a1 a2 b hb hA
  | prop => exact fnAtomAtom _ _ trivial hb
  | nat => exact fnAtomAtom _ _ trivial hb
  | int => exact fnAtomAtom _ _ trivial hb
  | named => exact fnAtomAtom _ _ trivial hb

theorem moreAtom (c d : Ty) (hd : IsAtom d) (hC : TyParses c.toks c) :
    MoreParses (.fn c d) := by
  refine ⟨c.toks ++ .sym .rp :: .sym .to :: d.toks, ?_, ?_⟩
  · cases d with
    | fn => exact hd.elim
    | _ => simp [Ty.moreInputs]
  intro fuel rest hf
  obtain ⟨xd, hxd, -, -⟩ := atom_toks d hd
  simp only [List.length_append, List.length_cons, hxd] at hf
  obtain ⟨g, rfl⟩ : ∃ g, fuel = g + 1 := ⟨fuel - 1, by simp at hf; omega⟩
  refine ⟨c, [], d, rfl, hd, ?_, by simp [hxd]⟩
  have := parseTyList_one (hC g (.sym .rp :: .sym .to :: d.toks ++ rest) (by simp at hf; omega)
    (TyStops.of_ne (by decide))) (by intro tl e; cases e)
  simpa using this

mutual
theorem tyMain : ∀ t : Ty, TyParses t.toks t
  | .prop => atom_parses _ trivial
  | .nat => atom_parses _ trivial
  | .int => atom_parses _ trivial
  | .named _ => atom_parses _ trivial
  | .fn a (.fn c d) => by
    obtain ⟨Y, hY, hm⟩ := moreMain (.fn c d) ⟨c, d, rfl⟩
    have hA := tyMain a
    have htoks : (Ty.fn a (.fn c d)).toks = .sym .lp :: a.toks ++ .sym .comma :: Y := by
      rw [← hY]; simp [Ty.toks]
    rw [htoks]
    intro fuel rest hf hs
    simp only [List.length_cons, List.length_append] at hf
    obtain ⟨g, rfl⟩ : ∃ g, fuel = g + 1 + 1 := ⟨fuel - 2, by omega⟩
    obtain ⟨c', ins, out, hfold, hout, hl, hlen⟩ := hm g rest (by omega)
    have h1 : parseTyList (g + 1) (a.toks ++ (.sym .comma :: (Y ++ rest))) =
        some (a :: c' :: ins, .sym .rp :: .sym .to :: out.toks ++ rest) := by
      have := parseTyList_cons (hA g _ (by omega) (TyStops.of_ne (by decide))) hl
      simpa using this
    have h2 := atom_parses out hout (g + 1) rest (by omega) hs
    have := parseTy_lp_many h1 h2
    rw [hfold] at this
    simpa using this
  | .fn a .prop => by exact fnAtom a .prop trivial (tyMain a)
  | .fn a .nat => by exact fnAtom a .nat trivial (tyMain a)
  | .fn a .int => by exact fnAtom a .int trivial (tyMain a)
  | .fn a (.named n) => by exact fnAtom a (.named n) trivial (tyMain a)

theorem moreMain : ∀ b : Ty, (∃ c d, b = .fn c d) → MoreParses b
  | .fn c (.fn e d), _ => by
    obtain ⟨Y, hY, hm⟩ := moreMain (.fn e d) ⟨e, d, rfl⟩
    have hC := tyMain c
    refine ⟨c.toks ++ .sym .comma :: Y, ?_, ?_⟩
    · rw [← hY]; simp [Ty.moreInputs]
    intro fuel rest hf
    simp only [List.length_cons, List.length_append] at hf
    obtain ⟨g, rfl⟩ : ∃ g, fuel = g + 1 := ⟨fuel - 1, by omega⟩
    obtain ⟨c', ins, out, hfold, hout, hl, hlen⟩ := hm g rest (by omega)
    refine ⟨c, c' :: ins, out, ?_, hout, ?_, hlen⟩
    · simp only [List.foldr_cons] at hfold ⊢; rw [hfold]
    · have := parseTyList_cons (hC g _ (by omega) (TyStops.of_ne (by decide))) hl
      simpa using this
  | .fn c .prop, _ => moreAtom c .prop trivial (tyMain c)
  | .fn c .nat, _ => moreAtom c .nat trivial (tyMain c)
  | .fn c .int, _ => moreAtom c .int trivial (tyMain c)
  | .fn c (.named n), _ => moreAtom c (.named n) trivial (tyMain c)
  | .prop, h => by simp at h
  | .nat, h => by simp at h
  | .int, h => by simp at h
  | .named _, h => by simp at h
end

/-! ### Sizes -/

mutual
def Raw.sz : Raw → Nat
  | .ident _ | .num _ => 1
  | .app f args => f.sz + args.sz + 1
  | .bin _ a b | .pow a b | .floorDiv a b => a.sz + b.sz + 1
  | .not a => a.sz + 1
  | .ann e _ => e.sz + 1
  | .quant _ _ _ body => body.sz + 1

def Args.sz : Args → Nat
  | .one a => a.sz + 1
  | .cons a rest => a.sz + rest.sz + 1
end

/-! ### Shapes of token lists -/

theorem Raw.level_le (r : Raw) : r.level ≤ 10 := by
  cases r with
  | bin o => cases o <;> simp [Raw.level, BinOp.level]
  | _ => simp [Raw.level]

theorem BinOp.classes (o : BinOp) :
    (o.assoc = .none ∧ (o.level = 1 ∨ o.level = 5)) ∨
    (o.assoc = .right ∧ (o.level = 2 ∨ o.level = 3)) ∨
    (o.assoc = .left ∧ (o.level = 6 ∨ o.level = 7)) := by
  cases o <;> simp [BinOp.assoc, BinOp.level]

theorem toks_bin_none {o : BinOp} {a b : Raw} (h : o.assoc = .none) :
    (Raw.bin o a b).toks = bracket (decide (a.level < o.level + 1)) a.toks ++
      .sym o.sym :: bracket (decide (b.level < o.level + 1)) b.toks := by
  simp [Raw.toks, h]

theorem toks_bin_right {o : BinOp} {a b : Raw} (h : o.assoc = .right) :
    (Raw.bin o a b).toks = bracket (decide (a.level < o.level + 1)) a.toks ++
      .sym o.sym :: bracket (decide (b.level < o.level)) b.toks := by
  simp [Raw.toks, h]

theorem toks_bin_left {o : BinOp} {a b : Raw} (h : o.assoc = .left) :
    (Raw.bin o a b).toks = bracket (decide (a.level < o.level)) a.toks ++
      .sym o.sym :: bracket (decide (b.level < o.level + 1)) b.toks := by
  simp [Raw.toks, h]

theorem HeadOK.lp {X : List Tok} {j : Nat} : HeadOK (.sym .lp :: X) j :=
  ⟨_, _, rfl, fun _ => ⟨by decide, by decide⟩, fun _ => by decide⟩

theorem HeadOK.bracket {e : Raw} {X : List Tok} {j : Nat} (c : Bool)
    (hh : HeadOK e.toks e.level) (hc : c = false → j ≤ e.level) :
    HeadOK (bracket c e.toks ++ X) j := by
  cases c with
  | true => simpa [Formula.bracket] using (HeadOK.lp (X := e.toks ++ .sym .rp :: X) (j := j))
  | false =>
    obtain ⟨t, tl, ht, h0, h4⟩ := hh
    have hj := hc rfl
    refine ⟨t, tl ++ X, by simp [Formula.bracket, ht], fun h => h0 (by omega),
      fun h => h4 (by omega)⟩

theorem headOK (r : Raw) : HeadOK r.toks r.level := by
  match r with
  | .ident n => exact ⟨_, _, rfl, fun _ => ⟨by simp, by simp⟩, fun _ => by simp⟩
  | .num k => exact ⟨_, _, rfl, fun _ => ⟨by simp, by simp⟩, fun _ => by simp⟩
  | .floorDiv a b => exact ⟨_, _, rfl, fun _ => ⟨by simp, by simp⟩, fun _ => by simp⟩
  | .ann e t => exact ⟨_, _, rfl, fun _ => ⟨by simp, by simp⟩, fun _ => by simp⟩
  | .not a => exact ⟨_, _, rfl, fun _ => ⟨by simp, by simp⟩, fun h => by simp [Raw.level] at h⟩
  | .quant q xs t body =>
    refine ⟨_, _, rfl, fun h => by simp [Raw.level] at h, fun h => by simp [Raw.level] at h⟩
  | .app f args =>
    have := HeadOK.bracket (X := .sym .lp :: args.toks ++ [.sym .rp]) (j := 9)
      (decide (f.level < 9)) (headOK f) (by simp)
    simpa [Raw.toks, Raw.level] using this
  | .pow a b =>
    have := HeadOK.bracket (X := .sym .pow :: b.toks ++ [.sym .rbrace]) (j := 8)
      (decide (a.level < 9)) (headOK a) (by simp; omega)
    simpa [Raw.toks, Raw.level] using this
  | .bin o a b =>
    have ha := headOK a
    have hl : (Raw.bin o a b).level = o.level := rfl
    rw [hl]
    rcases BinOp.classes o with ⟨h, -⟩ | ⟨h, -⟩ | ⟨h, -⟩
    · rw [toks_bin_none h]
      exact HeadOK.bracket _ ha (by intro h; simp at h; omega)
    · rw [toks_bin_right h]
      exact HeadOK.bracket _ ha (by intro h; simp at h; omega)
    · rw [toks_bin_left h]
      exact HeadOK.bracket _ ha (by intro h; simp at h; omega)
termination_by r.sz
decreasing_by all_goals simp [Raw.sz]; omega

/-! ### Atoms and brackets -/

def AtomParses (L : List Tok) (v : Raw) : Prop :=
  ∀ fuel rest, 16 * L.length ≤ fuel → parseAtom fuel (L ++ rest) = some (v, rest)

theorem AtomParses.parsesAt {L : List Tok} {v : Raw} (h : AtomParses L v) : ParsesAt 10 L v := by
  intro fuel rest hf _
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by omega⟩
  rw [parseAt_ten]; exact h f rest (by omega)

theorem ParsesAt.atom {L : List Tok} {v : Raw} (h : ParsesAt 10 L v) : AtomParses L v := by
  intro fuel rest hf
  rw [← parseAt_ten]; exact h (fuel + 1) rest (by omega) (Stops.ten rest)

def Main (r : Raw) : Prop := ∀ k ≤ r.level, ParsesAt k r.toks r

theorem bracketAtom {e : Raw} (he : Main e) :
    AtomParses (.sym .lp :: e.toks ++ [.sym .rp]) e := by
  intro fuel rest hf
  simp only [List.length_cons, List.length_append, List.length_nil] at hf
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by omega⟩
  have := he 0 (Nat.zero_le _) f (.sym .rp :: rest) (by omega) (Stops.of_none rfl)
  simp [parseAtom, this]

theorem child {e : Raw} (he : Main e) {j : Nat} (hj : j ≤ 10) :
    ParsesAt j (bracket (decide (e.level < j)) e.toks) e := by
  by_cases h : e.level < j
  · simp only [h, decide_true, bracket, ite_true]
    exact down (by decide) HeadOK.lp (bracketAtom he).parsesAt j hj
  · simp only [h, decide_false, bracket, Bool.false_eq_true, ite_false]
    exact he j (by omega)

theorem mainOfProper {r : Raw} (hp : ParsesAt r.level r.toks r) : Main r :=
  down (Raw.level_le r) (headOK r) hp

/-! ### Application chains -/

def AppRes (L : List Tok) (v : Raw) : Prop :=
  ∀ fuel rest, 16 * L.length + 1 ≤ fuel → ∃ m ≤ L.length,
    (parseAtom fuel (L ++ rest)).bind (fun p => parseCalls fuel p.1 p.2) =
      parseCalls (fuel - m) v rest

def ArgsParses (args : Args) : Prop :=
  ∀ fuel rest, 16 * args.toks.length + 11 ≤ fuel →
    parseArgs fuel (args.toks ++ .sym .rp :: rest) = some (args, .sym .rp :: rest)

theorem appLeaf {L : List Tok} {v : Raw} (h : AtomParses L v) : AppRes L v := by
  intro fuel rest hf
  exact ⟨0, Nat.zero_le _, by simp [h fuel rest (by omega)]⟩

theorem appStep {Lf : List Tok} {f : Raw} {args : Args} (hf : AppRes Lf f)
    (ha : ArgsParses args) :
    AppRes (Lf ++ .sym .lp :: args.toks ++ [.sym .rp]) (.app f args) := by
  intro fuel rest hfuel
  simp only [List.length_append, List.length_cons, List.length_nil] at hfuel
  obtain ⟨m, hm, he⟩ := hf fuel (.sym .lp :: args.toks ++ .sym .rp :: rest) (by omega)
  obtain ⟨f', hf'⟩ : ∃ f', fuel - m = f' + 1 := ⟨fuel - m - 1, by omega⟩
  have hargs := ha f' rest (by omega)
  refine ⟨m + 1, by simp; omega, ?_⟩
  have h2 : fuel - (m + 1) = f' := by omega
  simp only [List.append_assoc, List.cons_append, List.nil_append] at he ⊢
  rw [he, hf', h2]
  simp [parseCalls, hargs, expect]

theorem mainApp {Lf : List Tok} {f : Raw} {args : Args} (hf : AppRes Lf f) (ha : ArgsParses args)
    (htoks : (Raw.app f args).toks = Lf ++ .sym .lp :: args.toks ++ [.sym .rp]) :
    Main (.app f args) := by
  apply mainOfProper
  show ParsesAt 9 _ _
  rw [htoks]
  have h := appStep hf ha
  intro fuel rest hfuel hs
  obtain ⟨g, rfl⟩ : ∃ g, fuel = g + 1 := ⟨fuel - 1, by omega⟩
  obtain ⟨m, hm, he⟩ := h g rest (by simp at hfuel ⊢; omega)
  rw [parseAt_nine, he]
  simp at hm
  obtain ⟨g', hg'⟩ : ∃ g', g - m = g' + 1 := ⟨g - m - 1, by simp at hfuel; omega⟩
  rw [hg']
  exact parseCalls_stop hs

/-! ### Left-grouping chains -/

def SpineRes (k : Nat) (L : List Tok) (v : Raw) : Prop :=
  ∀ fuel rest, 16 * L.length + 10 - k ≤ fuel → Stops (k + 1) rest → ∃ m ≤ L.length,
    (parseAt fuel (k + 1) (L ++ rest)).bind (fun p => parseLeft fuel k p.1 p.2) =
      parseLeft (fuel - m) k v rest

theorem leftLeaf {k : Nat} {L : List Tok} {v : Raw} (h : ParsesAt (k + 1) L v) : SpineRes k L v := by
  intro fuel rest hf hs
  exact ⟨0, Nat.zero_le _, by simp [h fuel rest (by omega) hs]⟩

theorem leftStep {k : Nat} (hk : k ≤ 7) {o : BinOp} (ho : o.level = k) {La Lb : List Tok} {a b : Raw}
    (ha : SpineRes k La a) (hb : ParsesAt (k + 1) Lb b) :
    SpineRes k (La ++ .sym o.sym :: Lb) (.bin o a b) := by
  intro fuel rest hf hs
  simp only [List.length_append, List.length_cons] at hf
  have hs' : Stops (k + 1) (.sym o.sym :: Lb ++ rest) := by
    intro l hl; rw [BinOp.cont_sym] at hl; cases hl; omega
  obtain ⟨m, hm, he⟩ := ha fuel (.sym o.sym :: Lb ++ rest) (by omega) hs'
  obtain ⟨f', hf'⟩ : ∃ f', fuel - m = f' + 1 := ⟨fuel - m - 1, by omega⟩
  have hb' := hb f' rest (by omega) hs
  refine ⟨m + 1, by simp; omega, ?_⟩
  have h2 : fuel - (m + 1) = f' := by omega
  simp only [List.append_assoc, List.cons_append] at he ⊢
  rw [he, hf', h2]
  subst ho
  simp [parseLeft, opAt_sym, hb']

theorem leftFinish {k : Nat} (hk : k = 6 ∨ k = 7) {L : List Tok} {v : Raw} (h : SpineRes k L v) :
    ParsesAt k L v := by
  intro fuel rest hf hs
  obtain ⟨g, rfl⟩ : ∃ g, fuel = g + 1 := ⟨fuel - 1, by omega⟩
  obtain ⟨m, hm, he⟩ := h g rest (by omega) (Stops.mono (by omega) hs)
  rw [parseAt_left _ _ _ hk, he]
  obtain ⟨g', hg'⟩ : ∃ g', g - m = g' + 1 := ⟨g - m - 1, by omega⟩
  rw [hg']
  exact parseLeft_stop hs

/-! ### Each kind of formula -/

theorem mainIdent (n : Name) : Main (.ident n) := by
  apply mainOfProper; show ParsesAt 10 _ _
  apply AtomParses.parsesAt
  intro fuel rest hf
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by simp [Raw.toks] at hf; omega⟩
  rfl

theorem mainNum (k : Nat) : Main (.num k) := by
  apply mainOfProper; show ParsesAt 10 _ _
  apply AtomParses.parsesAt
  intro fuel rest hf
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by simp [Raw.toks] at hf; omega⟩
  rfl

theorem mainFloor {a b : Raw} (ha : Main a) (hb : Main b) : Main (.floorDiv a b) := by
  apply mainOfProper; show ParsesAt 10 _ _
  apply AtomParses.parsesAt
  intro fuel rest hf
  simp [Raw.toks] at hf
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by omega⟩
  have h1 := ha 0 (Nat.zero_le _) f (.sym .mid :: b.toks ++ .sym .rbrace :: .sym .rfloor :: rest)
    (by omega) (Stops.of_none rfl)
  have h2 := hb 0 (Nat.zero_le _) f (.sym .rbrace :: .sym .rfloor :: rest) (by omega)
    (Stops.of_none rfl)
  simp only [List.cons_append] at h1 h2
  simp [Raw.toks, parseAtom, h1, h2, expect]

theorem mainAnn {e : Raw} {t : Ty} (he : Main e) : Main (.ann e t) := by
  apply mainOfProper; show ParsesAt 10 _ _
  apply AtomParses.parsesAt
  intro fuel rest hf
  simp [Raw.toks] at hf
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by omega⟩
  have h1 := he 0 (Nat.zero_le _) f (.sym .colon :: t.toks ++ .sym .rp :: rest)
    (by omega) (Stops.of_none rfl)
  have h2 := tyMain t f (.sym .rp :: rest) (by omega) (TyStops.of_ne (by decide))
  simp only [List.cons_append] at h1 h2
  simp [Raw.toks, parseAtom, h1, h2, expect]

theorem mainPow {a b : Raw} (ha : Main a) (hb : Main b) : Main (.pow a b) := by
  apply mainOfProper; show ParsesAt 8 _ _
  intro fuel rest hf hs
  simp [Raw.toks] at hf
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by omega⟩
  have h1 := child ha (j := 9) (by decide) f (.sym .pow :: b.toks ++ .sym .rbrace :: rest)
    (by simp; omega) (fun l hl => by cases hl; decide)
  have h2 := hb 0 (Nat.zero_le _) f (.sym .rbrace :: rest) (by omega) (Stops.of_none rfl)
  simp only [List.cons_append] at h1 h2
  simp [Raw.toks, parseAt_eight, h1, powTail, h2, expect]

theorem mainNot {a : Raw} (ha : Main a) : Main (.not a) := by
  apply mainOfProper; show ParsesAt 4 _ _
  intro fuel rest hf hs
  simp [Raw.toks] at hf
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by omega⟩
  have h1 := child ha (j := 4) (by decide) f rest (by simp; omega) hs
  have : parseAt (f + 1) 4 (.sym .not :: (bracket (decide (a.level < 4)) a.toks ++ rest)) =
      (parseAt f 4 (bracket (decide (a.level < 4)) a.toks ++ rest)).bind
        (fun p => some (.not p.1, p.2)) := rfl
  simp only [Raw.toks, List.cons_append]
  rw [this, h1]; rfl

theorem stops_sym {j : Nat} {o : BinOp} (h : o.level = j) (ts : List Tok) :
    Stops (j + 1) (.sym o.sym :: ts) := by
  intro l hl; rw [BinOp.cont_sym] at hl; cases hl; omega

theorem mainBinNone {o : BinOp} {a b : Raw} (hc : o.assoc = .none) (hl : o.level = 1 ∨ o.level = 5)
    (ha : Main a) (hb : Main b) : Main (.bin o a b) := by
  apply mainOfProper; show ParsesAt o.level _ _
  rw [toks_bin_none hc]
  intro fuel rest hf hs
  simp at hf
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by omega⟩
  have h1 := child ha (j := o.level + 1) (by omega) f
    (.sym o.sym :: bracket (decide (b.level < o.level + 1)) b.toks ++ rest)
    (by simp; omega) (stops_sym rfl _)
  have h2 := child hb (j := o.level + 1) (by omega) f rest (by simp; omega)
    (Stops.mono (by omega) hs)
  simp only [List.cons_append, List.append_assoc] at h1 h2 ⊢
  rw [parseAt_bin _ _ _ (by omega), h1]
  simp [binTail, opAt_sym, hc, h2]

theorem mainBinRight {o : BinOp} {a b : Raw} (hc : o.assoc = .right) (hl : o.level = 2 ∨ o.level = 3)
    (ha : Main a) (hb : Main b) : Main (.bin o a b) := by
  apply mainOfProper; show ParsesAt o.level _ _
  rw [toks_bin_right hc]
  intro fuel rest hf hs
  simp at hf
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by omega⟩
  have h1 := child ha (j := o.level + 1) (by omega) f
    (.sym o.sym :: bracket (decide (b.level < o.level)) b.toks ++ rest)
    (by simp; omega) (stops_sym rfl _)
  have h2 := child hb (j := o.level) (by omega) f rest (by simp; omega) hs
  simp only [List.cons_append, List.append_assoc] at h1 h2 ⊢
  rw [parseAt_bin _ _ _ (by omega), h1]
  simp [binTail, opAt_sym, hc, h2]

theorem parseNames_namesToks : ∀ (xs : List Name) (rest : List Tok), xs ≠ [] →
    (∀ tl, rest ≠ .sym .comma :: tl) → parseNames (namesToks xs ++ rest) = some (xs, rest)
  | [], _, h, _ => absurd rfl h
  | [x], rest, _, hr => by
    match rest, hr with
    | .sym .comma :: tl, hr => exact absurd rfl (hr tl)
    | [], _ => rfl
    | .sym s :: tl, hr => cases s <;> first | rfl | exact absurd rfl (hr tl)
    | .name _ :: _, _ => rfl
    | .num _ :: _, _ => rfl
  | x :: y :: ys, rest, _, hr => by
    have := parseNames_namesToks (y :: ys) rest (by simp) hr
    simp [namesToks, parseNames, this]

theorem mainQuant {q : Quant} {xs : List Name} {t : Ty} {body : Raw} (hxs : xs ≠ [])
    (hb : Main body) : Main (.quant q xs t body) := by
  apply mainOfProper; show ParsesAt 0 _ _
  intro fuel rest hf hs
  simp [Raw.toks] at hf
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 + 1 := ⟨fuel - 2, by omega⟩
  have hbind : t.binder = .in_ ∨ t.binder = .colon := by
    cases t <;> simp [Ty.binder]
  have hn := parseNames_namesToks xs (.sym t.binder :: t.toks ++ .sym .sep :: body.toks ++ rest)
    hxs (by intro tl e; simp at e; rcases hbind with h | h <;> rw [h] at e <;> cases e.1)
  have h1 := tyMain t f (.sym .sep :: body.toks ++ rest) (by omega) (TyStops.of_ne (by decide))
  have h2 := hb 0 (Nat.zero_le _) f rest (by omega) hs
  simp only [List.cons_append, List.append_assoc] at hn h1 h2
  have hq : ∀ q', parseQuant (f + 1) q' (namesToks xs ++ .sym t.binder :: (t.toks ++
      .sym .sep :: (body.toks ++ rest))) = some (.quant q' xs t body, rest) := by
    intro q'
    rcases hbind with h | h <;> rw [h] at hn ⊢ <;> simp [parseQuant, hn, h1, expect, h2]
  cases q
  · simp only [Raw.toks, List.cons_append, List.append_assoc]
    exact hq _
  · simp only [Raw.toks, List.cons_append, List.append_assoc]
    exact hq _

theorem bracket_true {c : Prop} [Decidable c] (h : c) (L : List Tok) :
    bracket (decide c) L = .sym .lp :: L ++ [.sym .rp] := by
  simp [bracket, h]

theorem bracket_false {c : Prop} [Decidable c] (h : ¬c) (L : List Tok) :
    bracket (decide c) L = L := by
  simp [bracket, h]

theorem mainBinLeft {o : BinOp} {a b : Raw} (hc : o.assoc = .left) (hl : o.level = 6 ∨ o.level = 7)
    (ha : SpineRes o.level (bracket (decide (a.level < o.level)) a.toks) a) (hb : Main b) :
    Main (.bin o a b) := by
  apply mainOfProper; show ParsesAt o.level _ _
  rw [toks_bin_left hc]
  exact leftFinish hl (leftStep (by omega) rfl ha (child hb (by omega)))

/-! ### The induction -/

theorem argsParses {N : Nat} (H : ∀ y : Raw, y.sz < N → y.wf → Main y) :
    ∀ args : Args, args.sz < N → args.wf → ArgsParses args
  | .one a, hs, hw => by
    intro fuel rest hf
    simp only [Args.toks] at hf
    obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by omega⟩
    have h1 := child (H a (by simp [Args.sz] at hs; omega) (by simpa [Args.wf] using hw))
      (j := 1) (by decide) f (.sym .rp :: rest) (by omega) (Stops.of_none rfl)
    simp only [Args.toks, parseArgs, h1]; rfl
  | .cons a more, hs, hw => by
    simp [Args.wf] at hw
    have hm := argsParses H more (by simp [Args.sz] at hs; omega) hw.2
    intro fuel rest hf
    simp only [Args.toks, List.length_append, List.length_cons] at hf
    obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by omega⟩
    have h1 := child (H a (by simp [Args.sz] at hs; omega) hw.1)
      (j := 1) (by decide) f (.sym .comma :: more.toks ++ .sym .rp :: rest) (by omega)
      (Stops.of_none rfl)
    have h2 := hm f rest (by omega)
    simp only [List.cons_append] at h1
    simp only [Args.toks, parseArgs, List.append_assoc, List.cons_append, h1]
    simp [h2]

theorem spineL {k : Nat} (hk : k = 6 ∨ k = 7) {N : Nat} (H : ∀ y : Raw, y.sz < N → y.wf → Main y)
    (x : Raw) (hx : x.sz < N) (hw : x.wf) :
    SpineRes k (bracket (decide (x.level < k)) x.toks) x := by
  by_cases h1 : x.level < k
  · have := child (H x hx hw) (j := k + 1) (by omega)
    rw [bracket_true (by omega)] at this
    rw [bracket_true h1]
    exact leftLeaf this
  rw [bracket_false h1]
  by_cases h2 : x.level = k
  · cases x with
    | bin o a b =>
      have hlev : o.level = k := h2
      have hc : o.assoc = .left := by
        rcases BinOp.classes o with ⟨_, h⟩ | ⟨_, h⟩ | ⟨h, _⟩ <;> first | exact h | omega
      simp [Raw.wf] at hw
      simp [Raw.sz] at hx
      rw [toks_bin_left hc]
      have hb := child (H b (by omega) hw.2) (j := o.level + 1) (by omega)
      have ha := spineL hk H a (by omega) hw.1
      rw [hlev] at hb ⊢
      exact leftStep (by omega) hlev ha hb
    | _ => simp [Raw.level] at h2 <;> omega
  · exact leftLeaf (H x hx hw (k + 1) (by omega))
termination_by x.sz
decreasing_by all_goals (subst_vars; simp [Raw.sz]; omega)

theorem appSpine {N : Nat} (H : ∀ y : Raw, y.sz < N → y.wf → Main y)
    (x : Raw) (hx : x.sz < N) (hw : x.wf) :
    AppRes (bracket (decide (x.level < 9)) x.toks) x := by
  by_cases h1 : x.level < 9
  · rw [bracket_true h1]
    exact appLeaf (bracketAtom (H x hx hw))
  rw [bracket_false h1]
  by_cases h2 : x.level = 9
  · cases x with
    | app f args =>
      simp [Raw.wf] at hw
      simp [Raw.sz] at hx
      have hf := appSpine H f (by omega) hw.1
      have ha := argsParses H args (by omega) hw.2
      have := appStep hf ha
      simpa [Raw.toks] using this
    | bin o => cases o <;> simp [Raw.level, BinOp.level] at h2
    | _ => simp [Raw.level] at h2
  · exact appLeaf (H x hx hw 10 (by have := Raw.level_le x; omega)).atom
termination_by x.sz
decreasing_by all_goals (subst_vars; simp [Raw.sz]; omega)

theorem mainAll : ∀ n, ∀ r : Raw, r.sz < n → r.wf → Main r := by
  intro n
  induction n with
  | zero => intro r h; omega
  | succ n ih =>
    intro r hr hw
    have H : ∀ y : Raw, y.sz < r.sz → y.wf → Main y := fun y hy hw => ih y (by omega) hw
    cases r with
    | ident n => exact mainIdent n
    | num k => exact mainNum k
    | app f args =>
      simp [Raw.wf] at hw
      have hf := appSpine H f (by simp [Raw.sz]; omega) hw.1
      have ha := argsParses H args (by simp [Raw.sz]; omega) hw.2
      exact mainApp hf ha (by simp [Raw.toks])
    | bin o a b =>
      simp [Raw.wf] at hw
      have hA := H a (by simp [Raw.sz]; omega) hw.1
      have hB := H b (by simp [Raw.sz]; omega) hw.2
      rcases BinOp.classes o with ⟨hc, hl⟩ | ⟨hc, hl⟩ | ⟨hc, hl⟩
      · exact mainBinNone hc hl hA hB
      · exact mainBinRight hc hl hA hB
      · exact mainBinLeft hc hl (spineL hl H a (by simp [Raw.sz]; omega) hw.1) hB
    | not a =>
      exact mainNot (H a (by simp [Raw.sz]) (by simpa [Raw.wf] using hw))
    | pow a b =>
      simp [Raw.wf] at hw
      exact mainPow (H a (by simp [Raw.sz]; omega) hw.1) (H b (by simp [Raw.sz]; omega) hw.2)
    | floorDiv a b =>
      simp [Raw.wf] at hw
      exact mainFloor (H a (by simp [Raw.sz]; omega) hw.1) (H b (by simp [Raw.sz]; omega) hw.2)
    | ann e t =>
      simp [Raw.wf] at hw
      exact mainAnn (H e (by simp [Raw.sz]) hw.1)
    | quant q xs t body =>
      simp only [Raw.wf, Bool.and_eq_true] at hw
      exact mainQuant (by simpa using hw.1.1.1) (H body (by simp [Raw.sz]) hw.2)


/-! ### Readable tokens -/

theorem bracket_wf (c : Bool) {L : List Tok} (h : ∀ x ∈ L, x.wf) : ∀ x ∈ bracket c L, x.wf := by
  cases c <;> simp only [bracket, Bool.false_eq_true, ite_false, ite_true, List.forall_mem_cons,
    List.forall_mem_append] <;> simp_all [Tok.wf]

/-- Splits a goal `∀ x ∈ tokens, x.wf` into its parts and closes them from hypotheses. -/
macro "wf_close" : tactic =>
  `(tactic| (simp only [List.forall_mem_cons, List.forall_mem_append]
             and_intros <;> first | rfl | assumption | (exact bracket_wf _ (by assumption)) | (simp [Tok.wf]; done) | (simp_all [Tok.wf, Ty.toks, Ty.wf]; done)))

mutual
theorem Ty.toks_wf' (t : Ty) (h : t.wf) : ∀ x ∈ t.toks, x.wf := by
  match t with
  | .prop | .nat | .int => simp [Ty.toks, Tok.wf]
  | .named n => simpa [Ty.toks, Tok.wf, Ty.wf] using h
  | .fn a (.fn c d) =>
    have h : (a.wf && Ty.wf (.fn c d)) = true := h
    rw [Bool.and_eq_true] at h
    have h1 := Ty.toks_wf' a h.1
    have h2 := Ty.moreInputs_wf (.fn c d) h.2
    show ∀ x ∈ Tok.sym .lp :: a.toks ++ Ty.moreInputs (.fn c d), x.wf
    wf_close
  | .fn a .prop | .fn a .nat | .fn a .int | .fn a (.named _) =>
    have h : (a.wf && Ty.wf _) = true := h
    rw [Bool.and_eq_true] at h
    have h1 := Ty.toks_wf' a h.1
    have h2 := Ty.toks_wf' _ h.2
    simp only [Ty.toks]
    wf_close

theorem Ty.moreInputs_wf (t : Ty) (h : t.wf) : ∀ x ∈ t.moreInputs, x.wf := by
  match t with
  | .prop | .nat | .int | .named _ => simp [Ty.moreInputs]
  | .fn a (.fn c d) =>
    have h : (a.wf && Ty.wf (.fn c d)) = true := h
    rw [Bool.and_eq_true] at h
    have h1 := Ty.toks_wf' a h.1
    have h2 := Ty.moreInputs_wf (.fn c d) h.2
    show ∀ x ∈ Tok.sym .comma :: a.toks ++ Ty.moreInputs (.fn c d), x.wf
    wf_close
  | .fn a .prop | .fn a .nat | .fn a .int | .fn a (.named _) =>
    have h : (a.wf && Ty.wf _) = true := h
    rw [Bool.and_eq_true] at h
    have h1 := Ty.toks_wf' a h.1
    have h2 := Ty.toks_wf' _ h.2
    simp only [Ty.moreInputs]
    wf_close
end

theorem namesToks_wf : ∀ xs : List Name, xs.all Name.valid → ∀ x ∈ namesToks xs, x.wf
  | [], _ => by simp [namesToks]
  | [x], h => by simpa [namesToks, Tok.wf] using h
  | x :: y :: ys, h => by
    simp only [List.all_cons, Bool.and_eq_true] at h
    have h2 := namesToks_wf (y :: ys) (by simpa using h.2)
    have h1 : (Tok.name x).wf = true := h.1
    simp only [namesToks]
    wf_close

mutual
theorem toks_wf' (r : Raw) (h : r.wf) : ∀ t ∈ r.toks, t.wf := by
  match r with
  | .ident n => simpa [Raw.toks, Tok.wf, Raw.wf] using h
  | .num _ => simp [Raw.toks, Tok.wf]
  | .app f args =>
    simp only [Raw.wf, Bool.and_eq_true] at h
    have h1 := toks_wf' f h.1
    have h2 := args_toks_wf args h.2
    simp only [Raw.toks]
    wf_close
  | .bin o a b =>
    simp only [Raw.wf, Bool.and_eq_true] at h
    have h1 := toks_wf' a h.1
    have h2 := toks_wf' b h.2
    rcases BinOp.classes o with ⟨hc, -⟩ | ⟨hc, -⟩ | ⟨hc, -⟩
    · rw [toks_bin_none hc]; wf_close
    · rw [toks_bin_right hc]; wf_close
    · rw [toks_bin_left hc]; wf_close
  | .not a =>
    simp only [Raw.wf] at h
    have h1 := toks_wf' a h
    simp only [Raw.toks]
    wf_close
  | .pow a b =>
    simp only [Raw.wf, Bool.and_eq_true] at h
    have h1 := toks_wf' a h.1
    have h2 := toks_wf' b h.2
    simp only [Raw.toks]
    wf_close
  | .floorDiv a b =>
    simp only [Raw.wf, Bool.and_eq_true] at h
    have h1 := toks_wf' a h.1
    have h2 := toks_wf' b h.2
    simp only [Raw.toks]
    wf_close
  | .ann e t =>
    simp only [Raw.wf, Bool.and_eq_true] at h
    have h1 := toks_wf' e h.1
    have h2 := Ty.toks_wf' t h.2
    simp only [Raw.toks]
    wf_close
  | .quant q xs t body =>
    simp only [Raw.wf, Bool.and_eq_true] at h
    have h1 := namesToks_wf xs h.1.1.2
    have h2 := Ty.toks_wf' t h.1.2
    have h3 := toks_wf' body h.2
    simp only [Raw.toks]
    wf_close

theorem args_toks_wf (args : Args) (h : args.wf) : ∀ t ∈ args.toks, t.wf := by
  match args with
  | .one a =>
    simp only [Args.wf] at h
    have h1 := toks_wf' a h
    simp only [Args.toks]
    exact bracket_wf _ h1
  | .cons a rest =>
    simp only [Args.wf, Bool.and_eq_true] at h
    have h1 := toks_wf' a h.1
    have h2 := args_toks_wf rest h.2
    simp only [Args.toks]
    wf_close
end

/-! ## The theorems -/

/-- Spelling tokens out and splitting the result gives the tokens back. -/
theorem lex_print (ts : List Tok) (h : ∀ t ∈ ts, t.wf) : lex (print ts) = some ts := by
  cases ts with
  | nil => rfl
  | cons t rest =>
    have hsplit : (print (t :: rest)).splitOn ' ' = (t :: rest).map Tok.text :=
      List.splitOn_intercalate ' ' (by
        intro l hl
        simp only [List.mem_map] at hl
        obtain ⟨x, hx, rfl⟩ := hl
        exact (Tok.ofText_text x (h x hx)).2.1) (by simp)
    have hne : print (t :: rest) ≠ [] := by
      have := (Tok.ofText_text t (h t (by simp))).2.2
      cases rest <;> simp [print, List.intercalate, this]
    unfold lex
    split
    · contradiction
    · rw [hsplit, mapM_ofText _ h]

/-- A type's tokens read back as that type. -/
theorem parseTyToks_toks (t : Ty) (h : t.wf) : parseTyToks t.toks = some t := by
  have _ := h
  have := tyMain t (fuelFor t.toks.length) [] (by simp [fuelFor]; omega) (by intro tl e; cases e)
  simp only [List.append_nil] at this
  simp [parseTyToks, this]

/-- A formula's tokens read back as that formula. -/
theorem parseToks_toks (r : Raw) (h : r.wf) : parseToks r.toks = some r := by
  have := mainAll (r.sz + 1) r (by omega) h 0 (Nat.zero_le _) (fuelFor r.toks.length) []
    (by simp [fuelFor]; omega) trivial
  simp only [List.append_nil] at this
  simp [parseToks, this]

/-- Every token of a formula that can be shown is readable. -/
theorem toks_wf (r : Raw) (h : r.wf) : ∀ t ∈ r.toks, t.wf := toks_wf' r h

theorem Ty.toks_wf (t : Ty) (h : t.wf) : ∀ x ∈ t.toks, x.wf := Ty.toks_wf' t h

/-- **The LaTeX of a formula determines it.** -/
theorem parse_render (r : Raw) (h : r.wf) : parse (render r) = some r := by
  simp only [parse, render, lex_print _ (toks_wf r h), Option.bind_some, parseToks_toks r h]

/-- The same for types. -/
theorem parseTy_renderTy (t : Ty) (h : t.wf) : ((lex (renderTy t)).bind parseTyToks) = some t := by
  simp only [renderTy, lex_print _ (Ty.toks_wf t h), Option.bind_some, parseTyToks_toks t h]

/-- Two formulas with the same LaTeX are the same formula. -/
theorem render_injective (r s : Raw) (hr : r.wf) (hs : s.wf) (h : render r = render s) : r = s := by
  have := parse_render r hr
  rw [h, parse_render s hs] at this
  exact (Option.some.inj this).symm

end Plaer.Formula
