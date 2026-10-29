///|
test "equivalent groups have stable identities and aggregate lexicographic costs" {
  let group = literal_program(42).equivalent_group()
  @debug.assert_eq(group.relations(), [
    ("original", "identity/v1"),
    ("equivalent-1", "int-add-zero/v1"),
    ("equivalent-2", "true-branch/v1"),
  ])
  @debug.assert_eq(group.cost().nodes, 8)
  @debug.assert_eq(group.cost().integer_magnitude, 126L)
  let expected_sources = [
    "fn main {\n  println(42)\n}\n", "fn main {\n  println((42 + 0))\n}\n", "fn main {\n  println((if true { 42 } else { 0 }))\n}\n",
  ]
  @debug.assert_eq(
    group.members().map(entry => entry.2.emit()),
    expected_sources,
  )
  @debug.assert_eq(
    group.cost().source_bytes,
    expected_sources.join("").length(),
  )
  assert_true(literal_program(1).equivalent_group().is_smaller_than(group))
  assert_true(
    literal_program(1)
    .equivalent_group()
    .is_smaller_than(literal_program(-1).equivalent_group()),
  )
  assert_false(group.is_smaller_than(group))
  let boolean = Template::{
      enums: [],
      functions: [],
      result: BoolLiteral(true),
    }
    .finish()
    .equivalent_group()
  @debug.assert_eq(
    boolean.relations()[1],
    ("equivalent-1", "bool-double-not/v1"),
  )
}

///|
test "group candidates shrink only the original and reapply the same transformations" {
  let original = synthesize(7, generator=ScalarV1).program
  let source = original.emit()
  let group = original.equivalent_group()
  let candidates = group.structural_candidates()
  candidates.append(group.integer_candidates())
  assert_true(!candidates.is_empty())
  for candidate in candidates {
    @debug.assert_eq(candidate.relations(), group.relations())
    let members = candidate.members()
    let regenerated = members[0].2.equivalent_group()
    @debug.assert_eq(
      members.map(entry => entry.2.emit()),
      regenerated.members().map(entry => entry.2.emit()),
    )
    @debug.assert_eq(candidate.result_type(), original.result_type())
  }
  @debug.assert_eq(original.emit(), source)
  @debug.assert_eq(group.members()[0].2.emit(), source)
}
