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
async fn reduce_program(
  original : DifferentialRun,
  program : @moonbit.CompleteProgram,
  limit : Int,
  predicate : @contracts.FailurePredicate,
  assess : (DifferentialRun) -> @contracts.Assessment,
  prefix? : String = "",
) -> (DifferentialRun, @contracts.ReductionProgress) {
  let started = @host.monotonic_ms()
  let mut result = original
  let mut record : @contracts.ReductionProgress = {
    original_attempt: original.attempt_directory,
    cost_model: @moonbit.reduction_cost_model(),
    original_cost: program.cost(),
    candidate_limit: limit,
    candidates: 0,
    accepted: 0,
    elapsed_ms: 0L,
    best_cost: program.cost(),
    best_attempt: original.attempt_directory,
    stop_reason: "not started",
    confirmation_attempt: None,
    confirmation: None,
    error: None,
    trials: [],
  }
  try {
    guard @engine.Reducer::new(
        program,
        assess(original),
        predicate,
        id=original.attempt_directory,
        limit~,
        better=(candidate, incumbent) => candidate.is_smaller_than(incumbent),
        valid=p => p.result_type() == program.result_type(),
        operations=[p => p.structural_candidates(), p => p.integer_candidates()],
      )
      is Ok(search) else {
      fail("initial reduction evidence is invalid")
    }
    while search.next() is Some(request) {
      record = { ..record, candidates: search.attempts(), }
      let candidate = execute_differential(
        original.directory,
        original.case,
        "\{prefix}reduction-\{request.id.attempt}",
        source=request.program.emit(),
      )
      if candidate.save_error is Some(error) {
        result = { ..result, save_error: Some(error), }
        fail("candidate evidence at \{candidate.attempt_directory}: \{error}")
      }
      let evidence = assess(candidate)
      let accepted = search.observe(request.id, evidence)
      record.trials.push({
        attempt: candidate.attempt_directory,
        cost: request.program.cost(),
        status: @engine.match_failure(predicate, evidence),
        accepted,
      })
      if accepted {
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
      "\{prefix}confirmation",
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
      confirmation: Some(@engine.match_failure(predicate, assess(confirmation))),
    }
  } catch {
    error =>
      record = {
        ..record,
        stop_reason: "operation error",
        error: Some(error.to_string()),
      }
  }
  (result, { ..record, elapsed_ms: @host.monotonic_ms() - started, })
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
  let (result, progress) = reduce_program(
    original,
    program,
    limit,
    @engine.difference_predicate(first, second),
    reduction_assessment,
  )
  finish_reduction(result, {
    format_version: 3,
    first_configuration: first,
    second_configuration: second,
    original_attempt: progress.original_attempt,
    cost_model: progress.cost_model,
    original_cost: progress.original_cost,
    candidate_limit: progress.candidate_limit,
    candidates: progress.candidates,
    accepted: progress.accepted,
    elapsed_ms: progress.elapsed_ms,
    best_cost: progress.best_cost,
    best_attempt: progress.best_attempt,
    stop_reason: progress.stop_reason,
    confirmation_attempt: progress.confirmation_attempt,
    confirmation: progress.confirmation,
    error: progress.error,
  })
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
