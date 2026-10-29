///|
priv enum Runner {
  Native
  Moonrun
  Node
}

///|
priv struct Configuration {
  name : String
  target : String
  mode : String
  runner : Runner
  default_enabled : Bool
}

///|
fn configuration_specs() -> Array[Configuration] {
  [
    {
      name: "native-debug",
      target: "native",
      mode: "debug",
      runner: Native,
      default_enabled: true,
    },
    {
      name: "native-release",
      target: "native",
      mode: "release",
      runner: Native,
      default_enabled: true,
    },
    {
      name: "wasm-gc-debug",
      target: "wasm-gc",
      mode: "debug",
      runner: Moonrun,
      default_enabled: true,
    },
    {
      name: "wasm-debug",
      target: "wasm",
      mode: "debug",
      runner: Moonrun,
      default_enabled: false,
    },
    {
      name: "js-debug",
      target: "js",
      mode: "debug",
      runner: Node,
      default_enabled: false,
    },
  ]
}

///|
fn select_configuration(name : String) -> Configuration raise {
  for configuration in configuration_specs() {
    if configuration.name == name {
      return configuration
    }
  }
  fail("unsupported configuration: \{name}")
}

///|
pub fn configurations() -> Array[String] {
  configuration_specs()
  .filter(configuration => configuration.default_enabled)
  .map(configuration => configuration.name)
}

///|
pub fn available_configurations() -> Array[String] {
  configuration_specs().map(configuration => configuration.name)
}

///|
fn command(
  program : String,
  args : Array[String],
  cwd : String,
  timeout_ms : Int32,
) -> @contracts.Command {
  { program, args, cwd, timeout_ms, output_limit: 65536, }
}

///|
pub async fn version() -> String {
  let output = identify().output
  guard output.status == Exited(0) else {
    fail("Moon toolchain unavailable: \{output.stderr}")
  }
  output.stdout
}

///|
pub async fn identify() -> @contracts.ProcessEvidence {
  let command = command(
    "moon",
    ["version", "--all"],
    @host.current_directory(),
    10000,
  )
  { command, output: @host.execute(command), }
}

///|
pub async fn identify_runtimes(
  planned : Array[String],
) -> Array[@contracts.ProcessEvidence] {
  validate_plan(planned)
  let programs : Array[String] = []
  for name in planned {
    let program = match select_configuration(name).runner {
      Native => continue
      Moonrun => "moonrun"
      Node => "node"
    }
    if !programs.contains(program) {
      programs.push(program)
    }
  }
  let evidence : Array[@contracts.ProcessEvidence] = []
  for program in programs {
    let command = command(
      program,
      ["--version"],
      @host.current_directory(),
      10000,
    )
    evidence.push({ command, output: @host.execute(command), })
  }
  evidence
}

///|
pub fn module_source() -> String {
  "name = \"moonsmith/generated\"\nversion = \"0.0.0\"\n"
}

///|
pub fn package_source() -> String {
  "pkgtype(kind: \"executable\")\n"
}

///|
pub async fn prepare(directory : String, source : String) -> Unit {
  prepare_saved(directory, source, module_source(), package_source())
}

///|
pub async fn prepare_saved(
  directory : String,
  source : String,
  module_source : String,
  package_source : String,
) -> Unit {
  @host.write_new("\{directory}/moon.mod", module_source)
  @host.write_new("\{directory}/moon.pkg", package_source)
  @host.write_new("\{directory}/main.mbt", source)
}

///|
pub fn validate_plan(planned : Array[String]) -> Unit raise {
  guard planned.length() >= 2 else {
    fail("comparison requires at least two configurations")
  }
  for i, configuration in planned {
    ignore(select_configuration(configuration))
    guard !planned[:i].contains(configuration) else {
      fail("duplicate configuration: \{configuration}")
    }
  }
}

///|
pub fn validate_timeouts(
  build_timeout_ms : Int32,
  run_timeout_ms : Int32,
) -> Unit raise {
  guard build_timeout_ms >= 1 && build_timeout_ms <= 600000 else {
    fail("build timeout must be between 1 and 600000 milliseconds")
  }
  guard run_timeout_ms >= 1 && run_timeout_ms <= 600000 else {
    fail("run timeout must be between 1 and 600000 milliseconds")
  }
}

///|
pub async fn observe(
  directory : String,
  inject~ : Bool = false,
  build_timeout_ms~ : Int32 = 30000,
  run_timeout_ms~ : Int32 = 2000,
  planned~ : Array[String] = configurations(),
) -> Array[@contracts.Observation] {
  validate_timeouts(build_timeout_ms, run_timeout_ms)
  validate_plan(planned)
  let observations : Array[@contracts.Observation] = []
  for configuration in planned {
    let spec = select_configuration(configuration)
    let build = command(
      "moon",
      ["build", "--target", spec.target, "--\{spec.mode}"],
      directory,
      build_timeout_ms,
    )
    let output = @host.execute(build)
    observations.push({
      configuration,
      phase: Build,
      command: build,
      output,
      injected_stdout: None,
    })
    if output.status != Exited(0) {
      continue
    }
    // The generated root package has a fixed name; each attempt has a fresh build directory.
    let artifact = "\{directory}/_build/\{spec.target}/\{spec.mode}/build/generated"
    let run = match spec.runner {
      Native => command("\{artifact}.exe", [], directory, run_timeout_ms)
      Moonrun =>
        command("moonrun", ["\{artifact}.wasm"], directory, run_timeout_ms)
      Node => command("node", ["\{artifact}.js"], directory, run_timeout_ms)
    }
    let output = @host.execute(run)
    let injected_stdout = if inject &&
      configuration == "native-release" &&
      output.status == Exited(0) {
      Some("injected-mismatch\n")
    } else {
      None
    }
    observations.push({
      configuration,
      phase: Execute,
      command: run,
      output,
      injected_stdout,
    })
  }
  observations
}
