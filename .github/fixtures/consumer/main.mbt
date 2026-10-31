///|
fn main raise {
  let group = @moonbit.synthesize(42).program.equivalent_group()
  @debug.assert_eq(group.members().length(), 3)
  let cost : @contracts.ReductionCost = group.cost()
  assert_true(cost.nodes > 0)
  @debug.assert_eq(
    @engine.compare(["a", "b"], [], normalize=value => Some(value)),
    @contracts.Incomplete,
  )
  println("MoonSmith library consumer passed")
}
