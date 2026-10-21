///|
fn first_line(text : String) -> String {
  for line in text.split("\n") {
    let line = line.trim()
    if !line.is_empty() {
      return line.to_owned()
    }
  }
  ""
}

///|
fn toolchain_identity(evidence : @contracts.ProcessEvidence) -> String? {
  if evidence.output.status == Exited(0) &&
    !evidence.output.stdout.trim().is_empty() {
    Some(evidence.output.stdout.trim().to_owned())
  } else {
    None
  }
}

///|
fn runtime_lines(
  current : Array[@contracts.ProcessEvidence],
  original : Array[@contracts.ProcessEvidence]?,
  replay~ : Bool,
) -> Array[String] {
  let lines = []
  for probe in current {
    let program = probe.command.program
    let identity = toolchain_identity(probe)
    lines.push(
      "Runtime `\{program}`: \{identity.unwrap_or("unknown")} (\{@debug.to_string(probe.output.status)})",
    )
    if !replay {
      continue
    }
    let mut before : String? = None
    for previous in original.unwrap_or([]) {
      if previous.command.program == program {
        before = toolchain_identity(previous)
        break
      }
    }
    match (before, identity) {
      (Some(before), Some(after)) =>
        if before != after {
          lines.push("Runtime changed: \{program}: \{before} -> \{after}")
        }
      _ => lines.push("Runtime version comparison unavailable: \{program}")
    }
  }
  lines
}

///|
fn configuration_details(
  configuration : String,
  observations : Array[@contracts.Observation],
) -> String {
  let related = observations.filter(o => o.configuration == configuration)
  if related.is_empty() {
    return "not executed"
  }
  let problems = []
  for observation in related {
    if observation.output.status == Exited(0) {
      continue
    }
    let phase = match observation.phase {
      Build => "build"
      Execute => "execution"
    }
    let status = match observation.output.status {
      Exited(code) => "exited with code \{code}"
      TimedOut => "timed out"
      OutputLimit => "output limit exceeded"
      HostError(message) => "host error: \{first_line(message)}"
    }
    let diagnostic = first_line(observation.output.stderr)
    let suffix = if diagnostic.is_empty() { "" } else { " (\{diagnostic})" }
    problems.push("\{phase}: \{status}\{suffix}")
  }
  if problems.is_empty() {
    "no valid comparable result; execution evidence is missing, ambiguous, or outside the result protocol"
  } else {
    problems.join("; ")
  }
}

///|
pub fn summarize_differential(
  case : @contracts.DifferentialCase,
  attempt : @contracts.DifferentialAttempt,
  values : Array[(String, String)],
  directory~ : String,
  attempt_directory~ : String,
  original_toolchain~ : @contracts.ProcessEvidence?,
  save_error~ : String?,
  runtimes? : Array[@contracts.ProcessEvidence] = [],
  original_runtimes? : Array[@contracts.ProcessEvidence]? = None,
) -> String {
  let result = match attempt.comparison {
    Consistent => "consistent (no difference observed)"
    Difference(_, _) => "difference observed"
    Incomplete => "comparison incomplete"
  }
  let lines = [
    "Result: \{result}",
    "Configurations: \{attempt.configurations.join(", ")}",
    "Valid results: \{values.length()}/\{attempt.configurations.length()}",
    "Seed: \{case.generation.seed}",
    "Case: \{directory}",
    "Attempt: \{attempt_directory}",
  ]
  if attempt.injected {
    lines.push("Evidence: fault injection (not a compiler defect)")
  }
  if attempt.comparison != Consistent {
    for configuration in attempt.configurations {
      let mut detail = configuration_details(
        configuration,
        attempt.observations,
      )
      for (name, value) in values {
        if name == configuration {
          detail = value.trim().to_owned()
          break
        }
      }
      lines.push("\{configuration}: \{detail}")
    }
  }
  let current = toolchain_identity(attempt.toolchain)
  match current {
    Some(identity) => lines.push("Toolchain: \{@debug.to_string(identity)}")
    None => {
      lines.push(
        "Toolchain: unknown (probe status: \{@debug.to_string(attempt.toolchain.output.status)})",
      )
      let diagnostic = first_line(attempt.toolchain.output.stderr)
      if !diagnostic.is_empty() {
        lines.push("Toolchain probe: \{diagnostic}")
      }
    }
  }
  if attempt.purpose == "replay" {
    let original = match original_toolchain {
      Some(probe) => toolchain_identity(probe)
      None => None
    }
    match (original, current) {
      (Some(before), Some(after)) =>
        if before != after {
          lines.push("Toolchain changed since the original execution.")
          lines.push("Original toolchain: \{@debug.to_string(before)}")
        }
      (None, _) =>
        lines.push(
          "Original toolchain: unknown; version comparison is unavailable.",
        )
      (Some(_), None) =>
        lines.push("Toolchain version comparison is unavailable.")
    }
  }
  lines.append(
    runtime_lines(
      runtimes,
      original_runtimes,
      replay=attempt.purpose == "replay",
    ),
  )
  match save_error {
    None => lines.push("Evidence: saved")
    Some(error) => {
      lines.push("Evidence: incomplete; saving failed")
      lines.push("Save error: \{error}")
    }
  }
  lines.join("\n")
}
