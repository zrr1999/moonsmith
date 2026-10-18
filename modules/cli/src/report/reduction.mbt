///|
pub fn summarize_reduction(record : @contracts.DifferentialReduction) -> String {
  let lines = [
    "Reduction pair: \{record.first_configuration}, \{record.second_configuration}",
    "Reduction nodes: \{record.original_cost.nodes} -> \{record.best_cost.nodes}",
    "Reduction cost (\{record.cost_model}): \{record.original_cost.integer_magnitude} -> \{record.best_cost.integer_magnitude} integer magnitude; \{record.original_cost.source_bytes} -> \{record.best_cost.source_bytes} UTF-8 bytes",
    "Reduction candidates: \{record.candidates}/\{record.candidate_limit}; accepted: \{record.accepted}",
    "Reduction stop: \{record.stop_reason}",
  ]
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
        "Reduction: unconfirmed; the selected difference did not reproduce",
      )
    Some(Undetermined) | Some(Inapplicable) | None =>
      lines.push("Reduction: unconfirmed; confirmation evidence is incomplete")
  }
  if record.error is Some(error) {
    lines.push("Reduction error: \{error}")
  }
  lines.join("\n")
}
