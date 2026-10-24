///|
pub fn summarize_reduction(record : @contracts.DifferentialReduction) -> String {
  let progress : @contracts.ReductionProgress = {
    original_attempt: record.original_attempt,
    cost_model: record.cost_model,
    original_cost: record.original_cost,
    candidate_limit: record.candidate_limit,
    candidates: record.candidates,
    accepted: record.accepted,
    elapsed_ms: record.elapsed_ms,
    best_cost: record.best_cost,
    best_attempt: record.best_attempt,
    stop_reason: record.stop_reason,
    confirmation_attempt: record.confirmation_attempt,
    confirmation: record.confirmation,
    error: record.error,
    trials: [],
  }
  "Reduction pair: \{record.first_configuration}, \{record.second_configuration}\n" +
  summarize_progress(progress, "difference")
}

///|
fn summarize_progress(
  record : @contracts.ReductionProgress,
  target : String,
) -> String {
  let lines = [
    "Reduction nodes: \{record.original_cost.nodes} -> \{record.best_cost.nodes}",
    "Reduction cost (\{record.cost_model}): \{record.original_cost.integer_magnitude} -> \{record.best_cost.integer_magnitude} integer magnitude; \{record.original_cost.source_bytes} -> \{record.best_cost.source_bytes} UTF-8 bytes",
    "Reduction candidates: \{record.candidates}/\{record.candidate_limit}; accepted: \{record.accepted}",
    "Reduction elapsed: \{record.elapsed_ms} ms (search and independent confirmation)",
    "Reduction stop: \{record.stop_reason}",
  ]
  if record.original_cost.nodes > 0 {
    let removed = record.original_cost.nodes - record.best_cost.nodes
    let tenths = removed.to_int64() *
      1000L /
      record.original_cost.nodes.to_int64()
    lines.push(
      "Reduction nodes removed: \{removed}/\{record.original_cost.nodes} (\{tenths / 10L}.\{tenths % 10L}%)",
    )
  }
  match record.confirmation {
    Some(Preserved) => {
      lines.push(
        "Reduction: confirmed by one fresh execution; no minimality guarantee",
      )
      if record.best_cost == record.original_cost {
        lines.push("Reduction made no cost improvement.")
      }
      if record.confirmation_attempt is Some(directory) {
        lines.push("Reduced source: \{directory}/main.mbt")
        lines.push("Replay material: \{directory}")
      }
    }
    Some(NotPreserved) =>
      lines.push(
        "Reduction: unconfirmed; the selected \{target} did not reproduce",
      )
    Some(Undetermined) | Some(Inapplicable) | None =>
      lines.push("Reduction: unconfirmed; confirmation evidence is incomplete")
  }
  if record.error is Some(error) {
    lines.push("Reduction error: \{error}")
  }
  lines.join("\n")
}

///|
pub fn summarize_build_reduction(
  record : @contracts.BuildFailureReduction,
) -> String {
  "Build failure target: \{record.predicate.oracle}\n" +
  "Build failure comparison remains incomplete; matching controls do not prove correctness.\n" +
  summarize_progress(record.progress, "build failure") +
  "\nBuild reduction record: \{record.progress.original_attempt}/build-reduction.md"
}

///|
pub fn render_build_reduction(
  record : @contracts.BuildFailureReduction,
) -> String {
  let lines = [
    "# Build failure reduction",
    "",
    summarize_build_reduction(record),
    "",
    "Target configuration: \{record.predicate.fingerprint.configuration}",
    "Target phase: \{@debug.to_string(record.predicate.fingerprint.phase)}",
    "Target failure: \{@debug.to_string(record.predicate.fingerprint.kind)}",
    "Original attempt: \{record.progress.original_attempt}",
    "Best attempt: \{record.progress.best_attempt}",
    "",
    "Controls: native-debug and wasm-gc-debug must build and execute successfully with valid, equal candidate outputs. No reference evaluator is used.",
    "Each attempt preserves source, commands, toolchain identity, process statuses and raw output. The diagnostic oracle rejects mixed errors and incomplete or injected evidence.",
    "",
    "| Attempt | Nodes | Integer magnitude | UTF-8 bytes | Predicate | Accepted |",
    "| --- | --- | --- | --- | --- | --- |",
  ]
  for trial in record.progress.trials {
    lines.push(
      "| \{trial.attempt} | \{trial.cost.nodes} | \{trial.cost.integer_magnitude} | \{trial.cost.source_bytes} | \{@debug.to_string(trial.status)} | \{trial.accepted} |",
    )
  }
  lines.push("")
  lines.push(
    "This local report is not a versioned archive protocol. Replay the listed saved attempt to append fresh execution evidence; replay does not restart reduction.",
  )
  lines.join("\n") + "\n"
}
