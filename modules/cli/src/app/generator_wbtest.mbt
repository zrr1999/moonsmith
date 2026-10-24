///|
async test "task version selection reaches generation and is preserved in effective configuration and case records" {
  @host.mkdir("runs")
  let base = @host.new_directory("runs/generator-selection-")
  defer @host.remove_tree(base)
  let run = run_task(settings=[
    "seed_start=7",
    "generation.generator='template-rules-v1'",
    "execution.configurations=['native-debug','native-release']",
    "output.directory='\{base}'",
  ])
  @debug.assert_eq(task_exit_code(run), 0)
  let effective = parse_task(@host.read_text("\{run.directory}/effective.toml"))
  @debug.assert_eq(effective.generator, @moonbit.ScalarV1)
  let sample : @contracts.TaskSample = @json.from_json(
    @json.parse(@host.read_text("\{run.directory}/samples/0.json")),
  )
  guard sample.outcome is Observed(observation) else {
    fail("missing selected-version execution")
  }
  let case = @artifacts.load_differential(observation.case_directory)
  @debug.assert_eq(case.generation.generator, "template-rules-v1")
  @debug.assert_eq(
    case.source,
    @moonbit.synthesize(7, generator=ScalarV1).program.emit(),
  )
  @debug.assert_eq(sample.generation, Some(case.generation))
  let before = @host.list_directory(base)
  let rejected = try {
    ignore(
      run_task(settings=[
        "generation.generator='unsupported'",
        "output.directory='\{base}'",
      ]),
    )
    false
  } catch {
    error => error.to_string().contains("unsupported generator")
  }
  assert_true(rejected)
  @debug.assert_eq(@host.list_directory(base), before)
}
