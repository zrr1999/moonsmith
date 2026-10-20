///|
pub async fn create_task(
  base : String,
  effective : String,
  source? : String,
) -> String {
  @host.mkdir(base)
  let directory = @host.new_directory("\{base}/task-")
  try {
    @host.mkdir("\{directory}/cases")
    @host.mkdir("\{directory}/samples")
    @host.write_new("\{directory}/effective.toml", effective)
    if source is Some(source) {
      @host.write_new("\{directory}/task.toml", source)
    }
  } catch {
    error => fail("task storage failed at \{directory}: \{error}")
  }
  directory
}

///|
pub async fn save_task_sample(
  directory : String,
  index : Int,
  sample : @contracts.TaskSample,
) -> Unit {
  @host.write_new(
    "\{directory}/samples/\{index}.json",
    sample.to_json().stringify(),
  )
}

///|
pub async fn finish_task(
  directory : String,
  summary : @contracts.TaskSummary,
  report : String,
) -> Unit {
  @host.write_new("\{directory}/report.md", report)
  // The final summary is written only after every sample record and the report.
  @host.write_new("\{directory}/summary.json", summary.to_json().stringify())
}
