///|
pub struct DifferentialRun {
  directory : String
  case : @contracts.DifferentialCase
  attempt : @contracts.DifferentialAttempt
  attempt_directory : String
  original_toolchain : @contracts.ProcessEvidence?
  runtimes : Array[@contracts.ProcessEvidence]
  original_runtimes : Array[@contracts.ProcessEvidence]?
  save_error : String?
  reduction : @contracts.DifferentialReduction?
}

///|
pub fn differential_configurations() -> Array[String] {
  @moon.available_configurations()
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
  source? : String,
  original_toolchain? : @contracts.ProcessEvidence,
  original_runtimes? : Array[@contracts.ProcessEvidence],
  on_plan? : (Array[String]) -> Unit = _ => (),
) -> DifferentialRun {
  let source = source.unwrap_or(case.source)
  guard @moonbit.parse_result_protocol(case.result_protocol) is Some(ty) else {
    fail("unsupported result protocol: \{case.result_protocol}")
  }
  @moon.validate_plan(case.configurations)
  @moon.validate_timeouts(case.build_timeout_ms, case.run_timeout_ms)
  on_plan(case.configurations.copy())
  let attempt_directory = @artifacts.begin_attempt(directory)
  @moon.prepare_saved(
    attempt_directory,
    source,
    case.module_source,
    case.package_source,
  )
  let toolchain = @moon.identify()
  let platform = @host.platform()
  let runtimes = @moon.identify_runtimes(case.configurations)
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
        _ => fail("fault injection requires a scalar output protocol")
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
    source,
    configurations: case.configurations.copy(),
    result_protocol: case.result_protocol,
    toolchain,
    platform,
    injected: case.injected,
    observations,
    comparison,
  }
  finish_differential(
    directory,
    case,
    attempt_directory,
    attempt,
    original_toolchain,
    runtimes~,
    original_runtimes~,
  )
}

///|
async fn finish_differential(
  directory : String,
  case : @contracts.DifferentialCase,
  attempt_directory : String,
  attempt : @contracts.DifferentialAttempt,
  original_toolchain : @contracts.ProcessEvidence?,
  runtimes? : Array[@contracts.ProcessEvidence] = [],
  original_runtimes? : Array[@contracts.ProcessEvidence]? = None,
) -> DifferentialRun {
  let save_error = try {
    @artifacts.finish_attempt(
      attempt_directory,
      attempt,
      @report.render_differential(attempt, runtimes~, original_runtimes~),
      runtimes~,
    )
    None
  } catch {
    error => Some(error.to_string())
  }
  {
    directory,
    case,
    attempt,
    attempt_directory,
    original_toolchain,
    runtimes,
    original_runtimes,
    save_error,
    reduction: None,
  }
}

///|
pub async fn run_differential(
  seed? : Int,
  base? : String = "runs",
  limits? : @moonbit.GenerationLimits = @moonbit.GenerationLimits::default(),
  build_timeout_ms? : Int = 30000,
  run_timeout_ms? : Int = 2000,
  injected? : Bool = false,
  reduction_limit? : Int = 16,
  planned? : Array[String] = @moon.configurations(),
  on_plan? : (Array[String]) -> Unit = _ => (),
  on_generated? : (@contracts.GenerationRecord) -> Unit = _ => (),
) -> DifferentialRun {
  @moon.validate_plan(planned)
  @moon.validate_timeouts(build_timeout_ms, run_timeout_ms)
  limits.validate()
  guard reduction_limit >= 0 && reduction_limit <= 64 else {
    fail("reduction limit must be between 0 and 64")
  }
  let seed = choose_seed(seed, @host.random_seed)
  let generated = @moonbit.synthesize(seed, limits~) catch {
    error =>
      fail("generation failed for seed \{seed} (template-rules-v1): \{error}")
  }
  let program = generated.program
  guard program.result_type().result_protocol() is Some(result_protocol) else {
    fail("generated program has no supported output protocol")
  }
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
    result_protocol,
    configurations: planned.copy(),
    build_timeout_ms,
    run_timeout_ms,
    injected,
  }
  on_generated(case.generation)
  let directory = @artifacts.create_differential(base, case) catch {
    error => fail("case storage failed for seed \{seed}: \{error}")
  }
  let run = execute_differential(directory, case, "original", on_plan~) catch {
    error => fail("execution failed for seed \{seed} at \{directory}: \{error}")
  }
  reduce_differential(run, program, reduction_limit)
}

///|
pub async fn replay_differential(
  directory : String,
  on_plan? : (Array[String]) -> Unit = _ => (),
) -> DifferentialRun {
  let input = @host.canonical(directory)
  let (directory, case, source, original_toolchain, original_runtimes) = try {
    if @host.exists("\{input}/case.json") {
      let case = @artifacts.load_differential(input)
      let (toolchain, runtimes) = @artifacts.original_environment(input)
      (input, case, case.source, toolchain, runtimes)
    } else {
      let directory = @host.canonical("\{input}/../..")
      let case = @artifacts.load_differential(directory)
      let saved = @artifacts.load_differential_attempt(input, case)
      (
        directory,
        case,
        saved.source,
        Some(saved.toolchain),
        @artifacts.load_runtimes(input),
      )
    }
  } catch {
    error => fail("loading saved material at \{input} failed: \{error}")
  }
  execute_differential(
    directory,
    case,
    "replay",
    source~,
    original_toolchain?,
    original_runtimes?,
    on_plan~,
  ) catch {
    error =>
      fail(
        "replay failed for seed \{case.generation.seed} at \{directory}: \{error}",
      )
  }
}

///|
pub fn describe_differential(run : DifferentialRun) -> String {
  let ty = @moonbit.parse_result_protocol(run.case.result_protocol)
  let values = @engine.comparable_results(
    run.attempt.configurations,
    run.attempt.observations,
    normalize=value => {
      match ty {
        Some(ty) => ty.normalize_output(value)
        None => None
      }
    },
  )
  let summary = @report.summarize_differential(
    run.case,
    run.attempt,
    values,
    directory=run.directory,
    attempt_directory=run.attempt_directory,
    original_toolchain=run.original_toolchain,
    save_error=run.save_error,
    runtimes=run.runtimes,
    original_runtimes=run.original_runtimes,
  )
  match run.reduction {
    None => summary
    Some(reduction) => summary + "\n" + @report.summarize_reduction(reduction)
  }
}
