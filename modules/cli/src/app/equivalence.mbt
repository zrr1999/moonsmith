///|
fn compare_equivalents(
  original : DifferentialRun,
  labels : Array[String],
  runs : Array[(String, DifferentialRun)],
) -> @contracts.EquivalentComparison {
  let configurations = []
  for label in labels {
    for configuration in original.case.configurations {
      configurations.push("\{label}/\{configuration}")
    }
  }
  let observations = []
  let attempts = []
  let errors = []
  for (label, run) in runs {
    attempts.push((label, run.attempt_directory))
    for observation in run.attempt.observations {
      observations.push({
        ..observation,
        configuration: "\{label}/\{observation.configuration}",
      })
    }
    if run.save_error is Some(error) {
      errors.push("\{label}: \{error}")
    }
  }
  let comparison = @engine.compare(configurations, observations, normalize=value => {
    match @moonbit.parse_result_protocol(original.case.result_protocol) {
      Some(ty) => ty.normalize_output(value)
      None => None
    }
  })
  {
    configurations,
    observations,
    attempts,
    comparison,
    injected: original.case.injected,
    error: if errors.is_empty() {
      None
    } else {
      Some(errors.join("\n"))
    },
  }
}

///|
fn equivalent_values(
  run : DifferentialRun,
  comparison : @contracts.EquivalentComparison,
) -> Array[(String, String)] {
  @engine.comparable_results(
    comparison.configurations,
    comparison.observations,
    normalize=value => {
      match @moonbit.parse_result_protocol(run.case.result_protocol) {
        Some(ty) => ty.normalize_output(value)
        None => None
      }
    },
  )
}

///|
async fn finish_equivalents(
  original : DifferentialRun,
  comparison : @contracts.EquivalentComparison,
) -> DifferentialRun {
  let comparison = try {
    @artifacts.save_equivalents(
      original.attempt_directory,
      @report.render_equivalents(
        comparison,
        equivalent_values(original, comparison),
        group_directory=original.group.map(group => group.directory),
      ),
    )
    comparison
  } catch {
    error =>
      {
        ..comparison,
        error: Some(
          comparison.error.map(message => message + "\n").unwrap_or("") +
          "equivalent comparison storage failed: \{error}",
        ),
      }
  }
  { ..original, equivalents: Some(comparison), }
}

///|
pub fn DifferentialRun::comparison(
  self : DifferentialRun,
) -> @contracts.Comparison {
  match self.equivalents {
    Some(comparison) => comparison.comparison
    None => self.attempt.comparison
  }
}
