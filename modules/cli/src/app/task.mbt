///|
pub struct TaskRun {
  directory : String
  summary : @contracts.TaskSummary
}

///|
fn record_task_result(
  summary : @contracts.TaskSummary,
  sample : @contracts.TaskSample,
) -> @contracts.TaskSummary {
  let mut summary = {
    ..summary,
    attempted: summary.attempted + 1,
    generated_valid: summary.generated_valid +
    (if sample.generation is Some(_) { 1 } else { 0 }),
    baseline_attempted: summary.baseline_attempted +
    (if sample.baseline_build is Some(_) { 1 } else { 0 }),
    baseline_accepted: summary.baseline_accepted +
    (if sample.baseline_build == Some(true) { 1 } else { 0 }),
    comparisons_complete: summary.comparisons_complete +
    (if sample.planned_results > 0 &&
      sample.comparable_results == sample.planned_results {
      1
    } else {
      0
    }),
  }
  match sample.outcome {
    Failed(_) =>
      summary = { ..summary, operation_errors: summary.operation_errors + 1, }
    Observed(observation) => {
      summary = match observation.comparison {
        Consistent => { ..summary, consistent: summary.consistent + 1, }
        Difference(_, _) => { ..summary, differences: summary.differences + 1, }
        Incomplete => { ..summary, incomplete: summary.incomplete + 1, }
      }
      if observation.error is Some(_) {
        summary = { ..summary, operation_errors: summary.operation_errors + 1, }
      }
    }
  }
  summary
}

///|
pub async fn run_task(
  filename? : String,
  settings? : Array[String] = [],
  on_progress? : (Int, Int) -> Unit = (_, _) => (),
  on_plan? : (Array[String]) -> Unit = _ => (),
  on_sample? : (@contracts.TaskSample, DifferentialRun?) -> Unit = (_, _) => (),
) -> TaskRun {
  let directory = @host.current_directory()
  let (source, config_directory) = match filename {
    Some(filename) => {
      let input = @host.canonical(filename)
      guard input.rev_find("/") is Some(index) else {
        fail("task file must have an absolute path")
      }
      (
        Some(@host.read_text(input)),
        if index == 0 {
          "/"
        } else {
          input[:index].to_owned()
        },
      )
    }
    None => (None, directory)
  }
  let task = parse_task(
    source.unwrap_or(""),
    settings~,
    directory~,
    config_directory~,
  )
  on_plan(task.configurations.copy())
  let directory = @artifacts.create_task(
    task.output_directory,
    task.document().to_string(),
    source?,
  ) catch {
    error =>
      fail(
        "task storage failed for seed range \{task.seed_start}..\{task.seed_start + task.sample_count - 1}: \{error}",
      )
  }
  let mut summary : @contracts.TaskSummary = {
    format_version: 2,
    name: task.name,
    sample_count: task.sample_count,
    attempted: 0,
    consistent: 0,
    differences: 0,
    incomplete: 0,
    operation_errors: 0,
    generated_valid: 0,
    baseline_configuration: if task.configurations.contains("native-debug") {
      Some("native-debug")
    } else {
      None
    },
    baseline_attempted: 0,
    baseline_accepted: 0,
    comparisons_complete: 0,
    elapsed_ms: 0L,
  }
  let started = @host.monotonic_ms()
  on_progress(0, task.sample_count)
  try {
    for index in 0..<task.sample_count {
      let seed = task.seed_start + index
      let sample_started = @host.monotonic_ms()
      let mut generation = None
      let mut baseline_build = None
      let mut comparable_results = 0
      let mut result = None
      let outcome : @contracts.TaskOutcome = try {
        let run = run_differential(
          seed~,
          base="\{directory}/cases",
          limits=task.limits,
          generator=task.generator,
          planned=task.configurations,
          build_timeout_ms=task.build_timeout_ms,
          run_timeout_ms=task.run_timeout_ms,
          reduction_limit=task.candidate_limit,
          on_generated=record => generation = Some(record),
        )
        let errors : Array[String] = []
        result = Some(run)
        if summary.baseline_configuration is Some(baseline) {
          for observation in run.attempt.observations {
            if observation.configuration == baseline &&
              observation.phase == Build {
              baseline_build = Some(observation.output.status == Exited(0))
              break
            }
          }
        }
        comparable_results = @engine.comparable_results(
          run.attempt.configurations,
          run.attempt.observations,
          normalize=value => {
            match @moonbit.parse_result_protocol(run.attempt.result_protocol) {
              Some(ty) => ty.normalize_output(value)
              None => None
            }
          },
        ).length()
        if run.save_error is Some(error) {
          errors.push(error)
        }
        if run.reduction is Some(reduction) && reduction.error is Some(error) {
          errors.push(error)
        }
        if run.build_reduction is Some(reduction) &&
          reduction.progress.error is Some(error) {
          errors.push(error)
        }
        Observed({
          case_directory: run.directory,
          attempt_directory: run.attempt_directory,
          comparison: run.attempt.comparison,
          error: if errors.is_empty() {
            None
          } else {
            Some(errors.join("\n"))
          },
        })
      } catch {
        error => Failed(error.to_string())
      }
      let sample : @contracts.TaskSample = {
        format_version: 2,
        seed,
        generation,
        baseline_build,
        comparable_results,
        planned_results: task.configurations.length(),
        elapsed_ms: @host.monotonic_ms() - sample_started,
        outcome,
      }
      @artifacts.save_task_sample(directory, index, sample)
      summary = record_task_result(summary, sample)
      on_sample(sample, result)
      on_progress(summary.attempted, task.sample_count)
    }
    summary = { ..summary, elapsed_ms: @host.monotonic_ms() - started, }
    @artifacts.finish_task(
      directory,
      summary,
      @report.render_task(summary, directory~),
    )
  } catch {
    error => fail("task incomplete at \{directory}: \{error}")
  }
  { directory, summary, }
}

///|
pub fn describe_task(run : TaskRun) -> String {
  @report.render_task(run.summary, directory=run.directory)
}

///|
pub fn task_exit_code(run : TaskRun) -> Int {
  let summary = run.summary
  if summary.operation_errors > 0 || summary.attempted != summary.sample_count {
    1
  } else if summary.differences > 0 {
    2
  } else if summary.incomplete > 0 {
    3
  } else {
    0
  }
}
