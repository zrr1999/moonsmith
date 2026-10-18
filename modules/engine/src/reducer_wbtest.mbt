///|
test "operation changes restart enumeration without reusing stale candidates or evidence" {
  let reducer = Reducer::new(
    10,
    toy_evidence(10),
    toy_predicate(),
    id="operations",
    limit=10,
    better=(candidate, incumbent) => candidate < incumbent,
    valid=n => n >= 0,
    operations=[
      n => {
        match n {
          9 => [8, 7]
          5 => [4]
          _ => []
        }
      },
      n => {
        match n {
          10 => [9]
          8 => [5]
          _ => []
        }
      },
    ],
  ).unwrap()
  let proposed : Array[Int] = []
  let mut previous : CandidateId? = None
  while reducer.next() is Some(request) {
    proposed.push(request.program)
    if previous is Some(id) {
      assert_false(reducer.observe(id, toy_evidence(request.program)))
      @debug.assert_eq(reducer.next().map(r => r.id), Some(request.id))
    }
    assert_true(reducer.observe(request.id, toy_evidence(request.program)))
    previous = Some(request.id)
  }
  @debug.assert_eq(proposed, [9, 8, 5, 4])
  @debug.assert_eq(reducer.attempts(), 4)
  @debug.assert_eq(reducer.result(), 4)
  @debug.assert_eq(reducer.stop_reason(), Some(SearchComplete))
}

///|
test "operations share one budget including declined candidates" {
  let reducer = Reducer::new(
    10,
    toy_evidence(10),
    toy_predicate(),
    id="operation-budget",
    limit=3,
    better=(candidate, incumbent) => candidate < incumbent,
    valid=n => n >= 0,
    operations=[_ => [-1, 11], n => [n - 1]],
  ).unwrap()
  guard reducer.next() is Some(request) else { fail("missing request") }
  @debug.assert_eq(request.id.attempt, 3)
  @debug.assert_eq(request.program, 9)
  assert_true(reducer.observe(request.id, toy_evidence(9)))
  assert_true(reducer.next() is None)
  @debug.assert_eq(reducer.attempts(), 3)
  @debug.assert_eq(reducer.result(), 9)
  @debug.assert_eq(reducer.stop_reason(), Some(BudgetExhausted))
}

///|
test "the reducer follows the supplied objective instead of numeric size" {
  let reducer = Reducer::new(
    3,
    toy_evidence(3),
    toy_predicate(),
    id="objective",
    limit=8,
    better=(candidate, incumbent) => candidate > incumbent,
    valid=n => n >= 0,
    operations=[n => if n < 5 { [n + 1] } else { [] }],
  ).unwrap()
  while reducer.next() is Some(request) {
    assert_true(reducer.observe(request.id, toy_evidence(request.program)))
  }
  @debug.assert_eq(reducer.result(), 5)
  @debug.assert_eq(reducer.attempts(), 2)
  @debug.assert_eq(reducer.stop_reason(), Some(SearchComplete))
}

///|
test "exhaustion during a declined operation does not construct the following operation" {
  for limit in [0, 2] {
    let mut following_constructed = false
    let reducer = Reducer::new(
      10,
      toy_evidence(10),
      toy_predicate(),
      id="declined-budget",
      limit~,
      better=(candidate, incumbent) => candidate < incumbent,
      valid=n => n >= 0,
      operations=[
        _ => [-1, 11],
        _ => {
          following_constructed = true
          [9]
        },
      ],
    ).unwrap()
    assert_true(reducer.next() is None)
    assert_false(following_constructed)
    @debug.assert_eq(reducer.attempts(), limit)
    @debug.assert_eq(reducer.result(), 10)
    @debug.assert_eq(reducer.stop_reason(), Some(BudgetExhausted))
  }
}
