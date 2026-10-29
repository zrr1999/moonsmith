///|
/// Member order and transformation identifiers are stable within this relation version.
pub fn equivalent_relations(ty : Ty) -> Array[(String, String)] {
  let relations = [("original", "identity/v1")]
  match ty {
    Int => relations.push(("equivalent-1", "int-add-zero/v1"))
    Bool => relations.push(("equivalent-1", "bool-double-not/v1"))
    _ => ()
  }
  relations.push(("equivalent-\{relations.length()}", "true-branch/v1"))
  relations
}

///|
pub struct EquivalentGroup {
  priv original : CompleteProgram
  priv members : Array[CompleteProgram]
}

///|
pub fn CompleteProgram::equivalent_group(
  self : CompleteProgram,
) -> EquivalentGroup raise StructureError {
  let members = [self]
  members.append(self.equivalent_variants())
  { original: self, members, }
}

///|
pub fn EquivalentGroup::members(
  self : EquivalentGroup,
) -> Array[(String, String, CompleteProgram)] {
  let relations = equivalent_relations(self.original.result_type())
  self.members.mapi((index, program) => {
    let (id, transformation) = relations[index]
    (id, transformation, program)
  })
}

///|
pub fn EquivalentGroup::relations(
  self : EquivalentGroup,
) -> Array[(String, String)] {
  equivalent_relations(self.original.result_type())
}

///|
pub fn EquivalentGroup::result_type(self : EquivalentGroup) -> Ty {
  self.original.result_type()
}

///|
pub fn group_cost_model() -> String {
  "moonbit-group-sum-nodes-int-magnitude-utf8-v1"
}

///|
pub fn EquivalentGroup::cost(
  self : EquivalentGroup,
) -> @contracts.ReductionCost {
  self.members.fold(
    init={ nodes: 0, integer_magnitude: 0L, source_bytes: 0, },
    (sum, program) => {
      let cost = program.cost()
      {
        nodes: sum.nodes + cost.nodes,
        integer_magnitude: sum.integer_magnitude + cost.integer_magnitude,
        source_bytes: sum.source_bytes + cost.source_bytes,
      }
    },
  )
}

///|
pub fn EquivalentGroup::is_smaller_than(
  self : EquivalentGroup,
  other : EquivalentGroup,
) -> Bool {
  cost_is_smaller(self.cost(), other.cost())
}

///|
fn regroup(candidates : Array[CompleteProgram]) -> Array[EquivalentGroup] {
  candidates.filter_map(program => {
    Some(program.equivalent_group()) catch {
      _ => None
    }
  })
}

///|
pub fn EquivalentGroup::structural_candidates(
  self : EquivalentGroup,
) -> Array[EquivalentGroup] {
  regroup(self.original.structural_candidates())
}

///|
pub fn EquivalentGroup::integer_candidates(
  self : EquivalentGroup,
) -> Array[EquivalentGroup] {
  regroup(self.original.integer_candidates())
}
