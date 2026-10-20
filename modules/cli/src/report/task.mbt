///|
pub fn render_task(
  summary : @contracts.TaskSummary,
  directory~ : String,
) -> String {
  [
    "# Task: \{summary.name}",
    "",
    "Samples attempted: \{summary.attempted}/\{summary.sample_count}",
    "Consistent: \{summary.consistent}",
    "Differences: \{summary.differences}",
    "Incomplete comparisons: \{summary.incomplete}",
    "Samples with operation errors: \{summary.operation_errors}",
    "Operation errors may overlap with observed comparisons; consult each sample record.",
    "",
    "Task material: \{directory}",
    "Effective configuration: \{directory}/effective.toml",
    "Sample records: \{directory}/samples/",
    "Each observed sample links its original case and attempt; replay those saved materials.",
  ].join("\n") +
  "\n"
}
