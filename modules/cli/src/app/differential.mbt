///|
pub struct DifferentialRun {
  directory : String
  case : @contracts.DifferentialCase
  attempt : @contracts.DifferentialAttempt
}

///|
fn choose_seed(seed : Int?, automatic : () -> Int raise) -> Int raise {
  match seed {
    Some(value) => value
    None => automatic()
  }
}

///|
async fn execute_differential(
  directory : String,
  case : @contracts.DifferentialCase,
  purpose : String,
) -> @contracts.DifferentialAttempt {
  guard @moonbit.parse_result_protocol(case.result_protocol) is Some(ty) else {
    fail("unsupported result protocol: \{case.result_protocol}")
  }
  @moon.validate_plan(case.configurations)
  @moon.validate_timeouts(case.build_timeout_ms, case.run_timeout_ms)
  let attempt_directory = @artifacts.begin_attempt(directory)
  @moon.prepare_saved(
    attempt_directory,
    case.source,
    case.module_source,
    case.package_source,
  )
  let toolchain = @moon.identify()
  let platform = @host.platform()
  let observations = @moon.observe(
    attempt_directory,
    build_timeout_ms=case.build_timeout_ms,
    run_timeout_ms=case.run_timeout_ms,
    planned=case.configurations,
  ).map(observation => {
    if case.injected &&
      observation.configuration == "native-release" &&
      observation.phase == Execute &&
      observation.output.status == Exited(0) &&
      ty.normalize_output(observation.output.stdout) is Some(value) {
      let other = match ty {
        @moonbit.Ty::Int => if value == "0\n" { "1\n" } else { "0\n" }
        @moonbit.Ty::Bool =>
          if value == "true\n" {
            "false\n"
          } else {
            "true\n"
          }
      }
      { ..observation, injected_stdout: Some(other), }
    } else {
      observation
    }
  })
  let comparison = @engine.compare(case.configurations, observations, normalize=value => {
    ty.normalize_output(value)
  })
  let attempt : @contracts.DifferentialAttempt = {
    format_version: 2,
    purpose,
    source: case.source,
    configurations: case.configurations.copy(),
    result_protocol: case.result_protocol,
    toolchain,
    platform,
    injected: case.injected,
    observations,
    comparison,
  }
  @artifacts.finish_differential(
    attempt_directory,
    attempt,
    @report.render_differential(attempt),
  )
  attempt
}

///|
pub async fn run_differential(
  seed? : Int,
  base? : String = "runs",
  limits? : @moonbit.GenerationLimits = @moonbit.GenerationLimits::default(),
  build_timeout_ms? : Int = 30000,
  run_timeout_ms? : Int = 2000,
  injected? : Bool = false,
) -> DifferentialRun {
  @moon.validate_timeouts(build_timeout_ms, run_timeout_ms)
  limits.validate()
  let seed = choose_seed(seed, @host.random_seed)
  let generated = @moonbit.synthesize(seed, limits~) catch {
    error =>
      fail("generation failed for seed \{seed} (template-rules-v1): \{error}")
  }
  let program = generated.program
  let case : @contracts.DifferentialCase = {
    format_version: 2,
    generation: {
      generator: "template-rules-v1",
      seed,
      max_nodes: limits.max_nodes,
      max_depth: limits.max_depth,
      max_attempts: limits.max_attempts,
      construction_attempts: generated.construction_attempts,
      nodes: program.size(),
      depth: program.depth(),
    },
    source: program.emit(),
    module_source: @moon.module_source(),
    package_source: @moon.package_source(),
    result_protocol: program.result_type().result_protocol(),
    configurations: @moon.configurations(),
    build_timeout_ms,
    run_timeout_ms,
    injected,
  }
  let directory = @artifacts.create_differential(base, case)
  let attempt = execute_differential(directory, case, "original")
  { directory, case, attempt, }
}

///|
pub async fn replay_differential(
  directory : String,
) -> @contracts.DifferentialAttempt {
  let directory = @host.canonical(directory)
  let case = @artifacts.load_differential(directory)
  execute_differential(directory, case, "replay")
}
