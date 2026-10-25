///|
enum Operation {
  Help
  Run(String?, Array[String])
  Replay(String)
} derive(Eq, @debug.Debug)

///|
fn parse(args : Array[String]) -> Operation raise {
  if args.is_empty() || args.contains("--help") || args.contains("-h") {
    return Help
  }
  match args[0] {
    "run" => {
      let mut filename = None
      let settings = []
      let mut index = 1
      while index < args.length() {
        let argument = args[index]
        let (flag, inline) = match argument.find("=") {
          Some(split) =>
            (argument[:split].to_owned(), Some(argument[split + 1:].to_owned()))
          None => (argument, None)
        }
        guard flag == "--config" || flag == "--set" else {
          if flag == "--seed" {
            fail("unsupported argument: --seed; use --set seed_start=VALUE")
          }
          fail("unknown run argument: \{argument}; use run --help")
        }
        let value = match inline {
          Some(value) => value
          None => {
            index += 1
            guard index < args.length() && !args[index].has_prefix("--") else {
              fail("\{flag} requires a value; use run --help")
            }
            args[index]
          }
        }
        guard !value.is_empty() else {
          fail("\{flag} requires a nonempty value")
        }
        if flag == "--config" {
          guard filename is None else {
            fail("--config may be specified only once")
          }
          filename = Some(value)
        } else {
          settings.push(value)
        }
        index += 1
      }
      Run(filename, settings)
    }
    "replay" => {
      guard args.length() == 2 else { fail("usage: moonsmith replay CASE_DIR") }
      Replay(args[1])
    }
    command => fail("unknown command: \{command}; use --help")
  }
}

///|
fn present(run : @app.DifferentialRun, output : (String) -> Unit) -> Int {
  output(@app.describe_differential(run))
  if run.save_error is Some(_) {
    return 1
  }
  if run.reduction is Some(reduction) && reduction.error is Some(_) {
    return 1
  }
  if run.build_reduction is Some(reduction) &&
    reduction.progress.error is Some(_) {
    return 1
  }
  match run.attempt.comparison {
    Consistent => 0
    Difference(_, _) => 2
    Incomplete => 3
  }
}

///|
async fn cli(
  args : Array[String],
  output? : (String) -> Unit = line => println(line),
) -> Int {
  try {
    match parse(args) {
      Help => {
        output(
          [
            "MoonSmith — differential compiler testing",
            "",
            "moonsmith run [--config FILE] [--set KEY=VALUE]...",
            "moonsmith replay CASE_DIR_OR_ATTEMPT_DIR",
            "",
            "Run starts a finite testing task; the default task has one sample.",
            "Configuration: defaults < explicit TOML file < --set assignments (last value wins).",
            "--set uses the same keys and TOML values as the file; arrays replace the whole list.",
            "Keys: name (string), seed_start (Int32), sample_count (positive Int32).",
            "  generation.generator (string; supported: \{@app.generator_identifiers().join(", ")}).",
            "  generation.max_nodes (1..2048), generation.max_depth (0..16), generation.max_attempts (1..8192).",
            "  execution.configurations (array of at least two distinct supported names).",
            "  execution.build_timeout_ms, execution.run_timeout_ms (1..600000 milliseconds).",
            "  reduction.candidate_limit (0..64), output.directory (string).",
            "Omitted seed_start is selected automatically to fit the full sample range and recorded.",
            "Output paths in TOML use the file's directory; CLI overrides use the current directory.",
            "Examples: moonsmith run --set seed_start=42 --set sample_count=10",
            "          moonsmith run --config acceptance.toml --set generation.max_nodes=64",
            "          moonsmith run --set 'output.directory=\"runs/local\"'",
            "          moonsmith run --set 'execution.configurations=[\"native-debug\",\"native-release\"]'",
            "Configurations: \{@app.differential_configurations().join(", ")}",
            "Runs continue through all configurations and save their evidence.",
            "A difference triggers bounded reduction and one fresh confirmation.",
            "Recognized constructor build failures also reduce with agreeing controls; their comparison stays incomplete.",
            "Replay uses saved material with the current toolchain and appends a new record.",
            "Pass a saved attempt directory to replay a reduced program without restarting reduction.",
            "Exit codes: 0 consistent, 2 difference, 3 incomplete comparison, 1 operation error.",
          ].join("\n"),
        )
        0
      }
      Run(filename, settings) => {
        let run = @app.run_task(
          filename?,
          settings~,
          on_plan=plan => output("Planned configurations: \{plan.join(", ")}"),
          on_progress=(done, total) => output("Samples: \{done}/\{total}"),
          on_sample=(sample, result) => {
            if result is Some(result) {
              output(@app.describe_differential(result))
            } else if sample.outcome is Failed(error) {
              output("Seed: \{sample.seed}\nOperation error: \{error}")
            }
          },
        )
        output(@app.describe_task(run))
        @app.task_exit_code(run)
      }
      Replay(directory) =>
        present(
          @app.replay_differential(directory, on_plan=plan => {
            output("Planned configurations: \{plan.join(", ")}")
          }),
          output,
        )
    }
  } catch {
    error => {
      output("MoonSmith: \{error}")
      1
    }
  }
}
