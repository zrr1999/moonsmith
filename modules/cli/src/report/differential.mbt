///|
pub fn render_differential(
  attempt : @contracts.DifferentialAttempt,
  runtimes~ : Array[@contracts.ProcessEvidence] = [],
  original_runtimes~ : Array[@contracts.ProcessEvidence]? = None,
) -> String {
  let lines = [
    "# MoonSmith differential report",
    "",
    if attempt.injected {
      "Evidence: fault injection (not a compiler defect)."
    } else {
      "Evidence: real compiler execution."
    },
    "",
    "Purpose: \{attempt.purpose}",
    "Protocol: `\{attempt.result_protocol}`",
    "Planned configurations: \{attempt.configurations.join(", ")}",
    "Comparison: `\{@debug.to_string(attempt.comparison)}`",
    "",
    match attempt.comparison {
      Consistent =>
        "No difference was observed in this execution. Agreement does not prove correctness."
      Difference(a, b) =>
        "\{a} and \{b} disagree. The evidence does not identify which compiler configuration is wrong."
      Incomplete =>
        "Some planned configurations have no valid comparable result. Inspect the raw observations."
    },
    "",
    "| Configuration | Phase | Status | Injected |",
    "| --- | --- | --- | --- |",
  ]
  for o in attempt.observations {
    lines.push(
      "| \{o.configuration} | \{@debug.to_string(o.phase)} | \{@debug.to_string(o.output.status)} | \{o.injected_stdout is Some(_)} |",
    )
  }
  lines.push("")
  lines.push(
    "The saved program contains its inputs and runs with empty stdin and no program arguments.",
  )
  lines.push(
    "Toolchain and platform probes, commands, raw stdout/stderr, and any injected output are preserved in attempt.json.",
  )
  if !runtimes.is_empty() {
    lines.push("")
    lines.push("## Runtime versions")
    lines.push("")
    lines.append(
      runtime_lines(
        runtimes,
        original_runtimes,
        replay=attempt.purpose == "replay",
      ),
    )
    lines.push("")
    lines.push("Raw runtime version probes are preserved in runtimes.json.")
  }
  lines.join("\n") + "\n"
}
