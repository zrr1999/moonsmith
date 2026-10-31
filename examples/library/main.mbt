///|
fn main raise {
  let program = @moonbit.synthesize(42).program
  let group = program.equivalent_group()
  @debug.assert_eq(group.members().length(), 3)
  let cost : @contracts.ReductionCost = group.cost()
  assert_true(cost.nodes > 0)
  @debug.assert_eq(
    @engine.compare(["native-debug", "native-release"], [], normalize=value => {
      program.result_type().normalize_output(value)
    }),
    @contracts.Incomplete,
  )
  println("Seed: 42")
  for (id, transformation, variant) in group.members() {
    println("\{id}: \{transformation}, \{variant.size()} nodes")
  }
  println("Group cost: \{cost.nodes} nodes, \{cost.source_bytes} source bytes")
  println("Before execution: Incomplete")
  println("Generated MoonBit source:")
  println(program.emit())
}
