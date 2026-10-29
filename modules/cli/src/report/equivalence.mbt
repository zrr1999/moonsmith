///|
pub fn render_equivalents(
  record : @contracts.EquivalentComparison,
  values : Array[(String, String)],
  group_directory~ : String? = None,
) -> String {
  let result = match record.comparison {
    Consistent => "consistent (no difference observed)"
    Difference(first, second) => "difference observed: \{first} / \{second}"
    Incomplete => "comparison incomplete"
  }
  let lines = [
    "Equivalent program result: \{result}",
    "Valid equivalent results: \{values.length()}/\{record.configurations.length()}",
    "Relation: equivalent-1 wraps the result with Int + 0 or Bool double negation; equivalent-2 wraps it in a true branch.",
    "Each program uses the original configuration plan and output protocol; comparison requires no reference value.",
    "Replay the group directory to execute all saved sources and compare their outputs again.",
    "Group reduction regenerates the same transformations from each smaller original; its target member/configuration pair stays fixed.",
  ]
  if group_directory is Some(directory) {
    lines.push("Group replay material: \{directory}")
  }
  if record.injected {
    lines.push("Evidence: fault injection (not a compiler defect)")
  }
  for (label, directory) in record.attempts {
    lines.push("\{label} replay material: \{directory}")
  }
  if record.comparison != Consistent {
    for configuration in record.configurations {
      let mut detail = configuration_details(configuration, record.observations)
      for (name, value) in values {
        if name == configuration {
          detail = value.trim().to_owned()
          break
        }
      }
      lines.push("\{configuration}: \{detail}")
    }
  }
  if record.error is Some(error) {
    lines.push("Equivalent check operation error: \{error}")
  }
  lines.join("\n")
}
