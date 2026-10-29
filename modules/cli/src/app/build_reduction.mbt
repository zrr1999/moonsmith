///|
fn build_failure_assessment(run : DifferentialRun) -> @contracts.Assessment {
  let controls = @engine.comparable_results(
    ["native-debug", "wasm-gc-debug"],
    run.attempt.observations,
    normalize=value => {
      match @moonbit.parse_result_protocol(run.attempt.result_protocol) {
        Some(ty) => ty.normalize_output(value)
        None => None
      }
    },
  )
  let mut expected = None
  for (configuration, value) in controls {
    if configuration == "native-debug" {
      expected = Some(value)
    }
  }
  @moon.native_constructor_assessment(run.attempt.observations, expected)
}

///|
async fn reduce_build_failure(
  original : DifferentialRun,
  program : @moonbit.CompleteProgram,
  limit : Int32,
) -> DifferentialRun {
  let predicate = @moon.native_constructor_predicate()
  guard original.save_error is None &&
    original.attempt.comparison == Incomplete &&
    @engine.match_failure(predicate, build_failure_assessment(original)) ==
    Preserved else {
    return original
  }
  let (result, progress) = reduce_program(
    original,
    program,
    limit,
    predicate,
    build_failure_assessment,
    prefix="build-",
  )
  finish_build_reduction(result, { predicate, progress, })
}

///|
async fn finish_build_reduction(
  original : DifferentialRun,
  reduction : @contracts.BuildFailureReduction,
) -> DifferentialRun {
  let save_error = try {
    @artifacts.save_build_reduction(
      original.attempt_directory,
      @report.render_build_reduction(reduction),
    )
    original.save_error
  } catch {
    error => Some(error.to_string())
  }
  { ..original, build_reduction: Some(reduction), save_error, }
}
