///|
fn toy_evidence(n : Int) -> @contracts.Assessment {
  @contracts.Assessment::new([
    {
      oracle: "reference",
      configuration: "toy",
      phase: Execute,
      outcome: if n >= 3 {
        @contracts.Violated(Mismatch)
      } else {
        @contracts.Satisfied
      },
    },
  ])
}

///|
fn toy_predicate() -> @contracts.FailurePredicate {
  {
    oracle: "reference",
    fingerprint: { configuration: "toy", phase: Execute, kind: Mismatch, },
  }
}

///|
fn toy_session(limit? : Int = 20) -> ReductionSession[Int] {
  ReductionSession::new(
    10,
    toy_evidence(10),
    id="toy",
    limit~,
    valid=n => n >= 0,
    accepts=(current, candidate) => candidate < current,
    better=(best, candidate) => candidate < best,
    predicate=e => match_failure(toy_predicate(), e),
  ).unwrap()
}

///|
test "requests isolate pending evidence, duplicates, and cancellation" {
  let session = toy_session()
  guard session.offer(9) is Evaluate(first) else { fail("missing request") }
  assert_true(session.offer(8) is Pending)
  @debug.assert_eq(session.attempts(), 1)
  assert_true(
    session.observe(
      { session: "other", attempt: first.id.attempt, },
      toy_evidence(9),
    )
    is None,
  )
  assert_false(session.finish())
  @debug.assert_eq(session.observe(first.id, toy_evidence(9)), Some(Accepted))
  assert_true(session.observe(first.id, toy_evidence(9)) is None)
  guard session.offer(8) is Evaluate(second) else { fail("missing request") }
  assert_true(session.observe(first.id, toy_evidence(9)) is None)
  @debug.assert_eq(session.pending().map(r => r.id), Some(second.id))
  session.cancel()
  assert_true(session.observe(second.id, toy_evidence(8)) is None)
  assert_true(session.offer(7) is Stopped(Cancelled))
  @debug.assert_eq(session.result(), 9)
  @debug.assert_eq(session.original(), 10)
  @debug.assert_eq(session.stop_reason(), Some(Cancelled))
  assert_true(session.events().last() is Some(Finished(Cancelled)))
}

///|
test "invalid and disallowed proposals consume the shared budget" {
  let session = toy_session(limit=3)
  assert_true(session.offer(-1) is Declined(Invalid))
  assert_true(session.offer(11) is Declined(Disallowed))
  guard session.offer(9) is Evaluate(request) else { fail("missing request") }
  assert_true(session.stop_reason() is None)
  @debug.assert_eq(session.observe(request.id, toy_evidence(9)), Some(Accepted))
  @debug.assert_eq(session.attempts(), 3)
  assert_true(session.offer(4) is Stopped(BudgetExhausted))
  assert_false(session.finish())
  @debug.assert_eq(session.result(), 9)
  assert_true(session.events().last() is Some(Finished(BudgetExhausted)))
  let history = session.events()
  history.clear()
  @debug.assert_eq(session.events().length(), 8)
}

///|
test "search acceptance and best-result ordering can differ" {
  let session = ReductionSession::new(
    10,
    toy_evidence(10),
    id="growth",
    limit=10,
    valid=n => n >= 0,
    accepts=(current, candidate) => candidate != current,
    better=(best, candidate) => candidate < best,
    predicate=e => match_failure(toy_predicate(), e),
  ).unwrap()
  guard session.offer(12) is Evaluate(first) else {
    fail("growth should be eligible")
  }
  @debug.assert_eq(session.observe(first.id, toy_evidence(12)), Some(Accepted))
  @debug.assert_eq(session.current(), 12)
  @debug.assert_eq(session.result(), 10)
  guard session.offer(4) is Evaluate(second) else { fail("missing request") }
  @debug.assert_eq(session.observe(second.id, toy_evidence(4)), Some(Accepted))
  guard session.offer(2) is Evaluate(third) else { fail("missing request") }
  @debug.assert_eq(
    session.observe(third.id, toy_evidence(2)),
    Some(Rejected(NotPreserved)),
  )
  @debug.assert_eq(session.current(), 4)
  @debug.assert_eq(session.result(), 4)
  @debug.assert_eq(session.original(), 10)
  guard session.events()[0] is Started(original, evidence) else {
    fail("missing initial evidence")
  }
  @debug.assert_eq(original, 10)
  @debug.assert_eq(evidence, toy_evidence(10))
  @debug.assert_eq(
    match_failure(toy_predicate(), session.evidence()),
    @contracts.Preserved,
  )
  assert_true(session.finish())
  assert_false(session.finish())
  assert_true(session.offer(3) is Stopped(SearchComplete))
}

///|
test "another primary finding cannot replace the selected reduction condition" {
  let session = toy_session()
  guard session.offer(4) is Evaluate(request) else { fail("missing request") }
  let rows = toy_evidence(4).results()
  rows.insert(0, {
    oracle: "reference",
    configuration: "earlier",
    phase: Build,
    outcome: Violated(Exit(9)),
  })
  let evidence = @contracts.Assessment::new(rows)
  assert_true(summarize(evidence) != summarize(toy_evidence(10)))
  @debug.assert_eq(session.observe(request.id, evidence), Some(Accepted))
  @debug.assert_eq(session.result(), 4)
  @debug.assert_eq(session.evidence(), evidence)
}

///|
test "missing, inapplicable, and changed failure evidence cannot be accepted" {
  let session = toy_session()
  let outcomes : Array[@contracts.CheckOutcome] = [
    Insufficient(Timeout),
    NotApplicable,
    Violated(Exit(9)),
    Satisfied,
  ]
  let expected : Array[@contracts.PredicateStatus] = [
    Undetermined,
    Inapplicable,
    NotPreserved,
    NotPreserved,
  ]
  for i = 0; i < outcomes.length(); i = i + 1 {
    guard session.offer(9 - i) is Evaluate(request) else {
      fail("missing request")
    }
    let evidence = @contracts.Assessment::new([
      {
        oracle: "reference",
        configuration: "toy",
        phase: Execute,
        outcome: outcomes[i],
      },
    ])
    @debug.assert_eq(
      session.observe(request.id, evidence),
      Some(Rejected(expected[i])),
    )
    @debug.assert_eq(session.result(), 10)
  }
}

///|
test "a session needs valid initial evidence and cannot revive a zero budget" {
  let create = (initial, evidence, limit) => {
    ReductionSession::new(
      initial,
      evidence,
      id="start",
      limit~,
      valid=n => n >= 0,
      accepts=(current, candidate) => candidate < current,
      better=(best, candidate) => candidate < best,
      predicate=e => match_failure(toy_predicate(), e),
    )
  }
  assert_true(create(10, toy_evidence(10), -1) is Err(InvalidBudget))
  assert_true(create(-1, toy_evidence(10), 5) is Err(InvalidInitial))
  assert_true(
    create(10, toy_evidence(1), 5) is Err(UnestablishedFailure(NotPreserved)),
  )
  assert_true(
    create(10, @contracts.Assessment::new([]), 5)
    is Err(UnestablishedFailure(Undetermined)),
  )
  let session = create(10, toy_evidence(10), 0).unwrap()
  assert_true(session.offer(9) is Stopped(BudgetExhausted))
  @debug.assert_eq(session.attempts(), 0)
  @debug.assert_eq(session.result(), 10)
}

///|
test "linear and binary searches share the same acceptance engine" {
  let linear = toy_session()
  while linear.current() > 0 {
    guard linear.offer(linear.current() - 1) is Evaluate(request) else {
      fail("missing request")
    }
    if linear.observe(request.id, toy_evidence(request.program)) !=
      Some(Accepted) {
      break
    }
  }
  assert_true(linear.finish())
  let binary = toy_session()
  let mut lower = 0
  while binary.current() - lower > 1 {
    let candidate = (lower + binary.current()) / 2
    guard binary.offer(candidate) is Evaluate(request) else {
      fail("missing request")
    }
    if binary.observe(request.id, toy_evidence(candidate)) != Some(Accepted) {
      lower = candidate
    }
  }
  assert_true(binary.finish())
  @debug.assert_eq(linear.result(), 3)
  @debug.assert_eq(binary.result(), 3)
  @debug.assert_eq(linear.attempts(), 8)
  @debug.assert_eq(binary.attempts(), 3)
}

///|
test "changing candidate selection retains the remaining budget" {
  let session = toy_session(limit=3)
  guard session.offer(5) is Evaluate(first) else { fail("missing request") }
  ignore(session.observe(first.id, toy_evidence(5)))
  for n in [4, 3] {
    guard session.offer(n) is Evaluate(request) else { fail("missing request") }
    ignore(session.observe(request.id, toy_evidence(n)))
  }
  @debug.assert_eq(session.result(), 3)
  @debug.assert_eq(session.attempts(), 3)
  assert_true(session.offer(2) is Stopped(BudgetExhausted))
}

///|
test "enumeration does not construct more candidates after exhausting its budget" {
  let mut generated = 0
  let reducer = Reducer::new(
    10,
    toy_evidence(10),
    toy_predicate(),
    id="enumerator",
    limit=1,
    size=n => n,
    valid=n => n >= 0,
    candidates=n => {
      generated += 1
      [n - 1]
    },
  ).unwrap()
  guard reducer.next() is Some(request) else { fail("missing request") }
  assert_true(reducer.observe(request.id, toy_evidence(request.program)))
  assert_true(reducer.next() is None)
  @debug.assert_eq(generated, 1)
}
