///|
pub fn render_task(
  summary : @contracts.TaskSummary,
  directory~ : String,
) -> String {
  [
    "# Task: \{summary.name}",
    "",
    "Samples attempted: \{summary.attempted}/\{summary.sample_count}",
    "Generated and internally checked: \{summary.generated_valid}/\{summary.sample_count}",
    match summary.baseline_configuration {
      Some(configuration) =>
        "Baseline builds accepted (\{configuration}): \{summary.baseline_accepted}/\{summary.sample_count}; attempted: \{summary.baseline_attempted}"
      None => "Baseline builds: unavailable (native-debug was not selected)"
    },
    "Complete comparisons: \{summary.comparisons_complete}/\{summary.sample_count}",
    "Consistent: \{summary.consistent}",
    "Differences: \{summary.differences}",
    "Incomplete comparisons: \{summary.incomplete}",
    "Samples with operation errors: \{summary.operation_errors}",
    "Operation errors may overlap with observed comparisons; consult each sample record.",
    "Task elapsed: \{summary.elapsed_ms} ms (sample processing and persistence; excludes final task report)",
    "",
    "Task material: \{directory}",
    "Effective configuration: \{directory}/effective.toml",
    "Sample records: \{directory}/samples/",
    "Each observed sample links its original case and attempt; replay those saved materials.",
  ].join("\n") +
  "\n"
}
