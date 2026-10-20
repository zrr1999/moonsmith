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
  let mut summary = { ..summary, attempted: summary.attempted + 1, }
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
    format_version: 1,
    name: task.name,
    sample_count: task.sample_count,
    attempted: 0,
    consistent: 0,
    differences: 0,
    incomplete: 0,
    operation_errors: 0,
  }
  on_progress(0, task.sample_count)
  try {
    for index in 0..<task.sample_count {
      let seed = task.seed_start + index
      let mut result = None
      let outcome : @contracts.TaskOutcome = try {
        let run = run_differential(
          seed~,
          base="\{directory}/cases",
          limits=task.limits,
          planned=task.configurations,
          build_timeout_ms=task.build_timeout_ms,
          run_timeout_ms=task.run_timeout_ms,
          reduction_limit=task.candidate_limit,
        )
        let errors : Array[String] = []
        result = Some(run)
        if run.save_error is Some(error) {
          errors.push(error)
        }
        if run.reduction is Some(reduction) && reduction.error is Some(error) {
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
      let sample : @contracts.TaskSample = { seed, outcome, }
      @artifacts.save_task_sample(directory, index, sample)
      summary = record_task_result(summary, sample)
      on_sample(sample, result)
      on_progress(summary.attempted, task.sample_count)
    }
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
