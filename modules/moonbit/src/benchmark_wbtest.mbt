///|
test "bounded composite generation" (b : @bench.T) {
  let seeds = [0, 7, 42, 1999]
  let limits = GenerationLimits::default()
  for seed in seeds {
    let generated = synthesize(seed, limits~, generator=CompositeV2)
    assert_true(generated.program.size() <= limits.max_nodes)
    assert_true(generated.program.depth() <= limits.max_depth)
  }
  b.bench(() => {
    for seed in seeds {
      b.keep(try! synthesize(seed, limits~, generator=CompositeV2))
    }
  })
}

///|
test "structural reduction candidates" (b : @bench.T) {
  let programs = [0, 7, 42, 1999].map(seed => {
    try! synthesize(seed, generator=CompositeV2).program
  })
  for program in programs {
    for candidate in program.candidates() {
      assert_true(candidate.is_smaller_than(program))
      @debug.assert_eq(candidate.result_type(), program.result_type())
    }
  }
  b.bench(() => {
    for program in programs {
      b.keep(program.candidates())
    }
  })
}
