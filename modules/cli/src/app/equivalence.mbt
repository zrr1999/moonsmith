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
async fn check_equivalents(
  original : DifferentialRun,
  variants : Array[@moonbit.CompleteProgram],
) -> DifferentialRun {
  let labels = ["original"]
  let runs = [("original", original)]
  let errors = []
  for index, variant in variants {
    let label = "equivalent-\{index + 1}"
    labels.push(label)
    try {
      let run = execute_differential(
        original.directory,
        original.case,
        label,
        source=variant.emit(),
      )
      runs.push((label, run))
    } catch {
      error => errors.push("\{label}: \{error}")
    }
  }
  let mut comparison = compare_equivalents(original, labels, runs)
  if comparison.error is Some(error) {
    errors.push(error)
  }
  comparison = {
    ..comparison,
    error: if errors.is_empty() {
      None
    } else {
      Some(errors.join("\n"))
    },
  }
  finish_equivalents(original, comparison)
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
