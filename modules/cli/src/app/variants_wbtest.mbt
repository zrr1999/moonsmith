///|
async test "equivalent variants agree with their original across five real compiler configurations" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/equivalent-variants-")
  defer @host.remove_tree(base)
  let programs = [
    @moonbit.Template::{
      functions: [],
      result: Add(IntLiteral(2147483647), IntLiteral(1)),
    }.finish(),
    @moonbit.Template::{
      functions: [],
      result: Less(
        Subtract(IntLiteral(-2147483648), IntLiteral(1)),
        IntLiteral(0),
      ),
    }.finish(),
    composed_structure(3).finish(),
    @moonbit.synthesize(7).program,
  ]
  let planned = @moon.available_configurations()
  for program in programs {
    let source = program.emit()
    let mut original : String? = None
    for variant in [program] + program.equivalent_variants() {
      let case = {
        ..saved_fixture(
          variant.emit(),
          protocol=variant.result_type().result_protocol(),
        ),
        configurations: planned,
      }
      let directory = @artifacts.create_differential(base, case)
      let run = replay_differential(directory)
      assert_true(run.save_error is None)
      @debug.assert_eq(
        run.attempt.comparison,
        @contracts.Consistent,
        msg=@debug.to_string(run.attempt),
      )
      let values = @engine.comparable_results(
        planned,
        run.attempt.observations,
        normalize=value => program.result_type().normalize_output(value),
      )
      @debug.assert_eq(values.length(), planned.length())
      for (_, value) in values {
        if original is Some(expected) {
          @debug.assert_eq(value, expected, msg=variant.emit())
        } else {
          original = Some(value)
        }
      }
    }
    @debug.assert_eq(program.emit(), source)
  }
}
