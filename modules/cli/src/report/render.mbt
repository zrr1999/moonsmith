///|
pub fn render(attempt : @contracts.Attempt, injected~ : Bool) -> String {
  let lines = [
    "# MoonSmith prototype report",
    "",
    if injected {
      "Evidence: fault injection (not a compiler defect)."
    } else {
      "Evidence: real compiler execution."
    },
    "",
    "Purpose: \{attempt.purpose}",
    "Nodes: \{attempt.nodes}",
    "Verdict: `\{@debug.to_string(attempt.verdict)}`",
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
  lines.push("## Toolchain")
  lines.push("")
  lines.push("```text\n\{attempt.compiler}```")
  lines.push("")
  lines.push("Commands and raw stdout/stderr are preserved in attempt.json.")
  lines.join("\n") + "\n"
}
