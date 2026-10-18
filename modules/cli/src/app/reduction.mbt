///|
fn reduction_assessment(run : DifferentialRun) -> @contracts.Assessment {
  @engine.differential_assessment(
    run.attempt.configurations,
    run.attempt.observations,
    normalize=value => {
      match @moonbit.parse_result_protocol(run.attempt.result_protocol) {
        Some(ty) => ty.normalize_output(value)
        None => None
      }
    },
  )
}

///|
async fn reduce_differential(
  original : DifferentialRun,
  program : @moonbit.CompleteProgram,
  limit : Int,
) -> DifferentialRun {
  guard original.save_error is None &&
    original.attempt.comparison is Difference(first, second) else {
    return original
  }
  let predicate = @engine.difference_predicate(first, second)
  let mut result = original
  let mut record : @contracts.DifferentialReduction = {
    format_version: 2,
    first_configuration: first,
    second_configuration: second,
    original_attempt: original.attempt_directory,
    cost_model: @moonbit.reduction_cost_model(),
    original_cost: program.cost(),
    candidate_limit: limit,
    candidates: 0,
    accepted: 0,
    best_cost: program.cost(),
    best_attempt: original.attempt_directory,
    stop_reason: "not started",
    confirmation_attempt: None,
    confirmation: None,
    error: None,
  }
  try {
    guard @engine.Reducer::new(
        program,
        reduction_assessment(original),
        predicate,
        id=original.attempt_directory,
        limit~,
        better=(candidate, incumbent) => candidate.is_smaller_than(incumbent),
        valid=p => p.result_type() == program.result_type(),
        operations=[p => p.structural_candidates(), p => p.integer_candidates()],
      )
      is Ok(search) else {
      fail("initial differential reduction evidence is invalid")
    }
    while search.next() is Some(request) {
      record = { ..record, candidates: search.attempts(), }
      let candidate = execute_differential(
        original.directory,
        original.case,
        "reduction-\{request.id.attempt}",
        source=request.program.emit(),
      )
      if candidate.save_error is Some(error) {
        result = { ..result, save_error: Some(error), }
        fail("candidate evidence at \{candidate.attempt_directory}: \{error}")
      }
      if search.observe(request.id, reduction_assessment(candidate)) {
        record = {
          ..record,
          accepted: record.accepted + 1,
          best_cost: search.result().cost(),
          best_attempt: candidate.attempt_directory,
        }
      }
    }
    record = {
      ..record,
      candidates: search.attempts(),
      stop_reason: match search.stop_reason() {
        Some(BudgetExhausted) => "candidate budget exhausted"
        Some(SearchComplete) => "candidate search finished"
        Some(Cancelled) => "cancelled"
        None => "not stopped"
      },
    }
    let confirmation = execute_differential(
      original.directory,
      original.case,
      "confirmation",
      source=search.result().emit(),
    )
    record = {
      ..record,
      confirmation_attempt: Some(confirmation.attempt_directory),
    }
    if confirmation.save_error is Some(error) {
      result = { ..result, save_error: Some(error), }
      fail(
        "confirmation evidence at \{confirmation.attempt_directory}: \{error}",
      )
    }
    record = {
      ..record,
      confirmation: Some(
        @engine.match_failure(predicate, reduction_assessment(confirmation)),
      ),
    }
  } catch {
    error =>
      record = {
        ..record,
        stop_reason: "operation error",
        error: Some(error.to_string()),
      }
  }
  finish_reduction(result, record)
}

///|
async fn finish_reduction(
  original : DifferentialRun,
  reduction : @contracts.DifferentialReduction,
) -> DifferentialRun {
  let save_error = try {
    @artifacts.save_reduction(original.attempt_directory, reduction)
    original.save_error
  } catch {
    error => Some(error.to_string())
  }
  { ..original, reduction: Some(reduction), save_error, }
}
