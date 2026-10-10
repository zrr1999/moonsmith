///|
pub(all) struct CandidateId {
  session : String
  attempt : Int
} derive(Eq, @debug.Debug)

///|
pub(all) struct ReductionRequest[P] {
  id : CandidateId
  program : P
}

///|
pub(all) enum CandidateOutcome {
  Accepted
  Invalid
  Disallowed
  Rejected(@contracts.PredicateStatus)
} derive(Eq, @debug.Debug)

///|
pub(all) enum ReductionStop {
  BudgetExhausted
  Cancelled
  SearchComplete
} derive(Eq, @debug.Debug)

///|
pub(all) enum Offer[P] {
  Evaluate(ReductionRequest[P])
  Declined(CandidateOutcome)
  Pending
  Stopped(ReductionStop)
}

///|
pub(all) enum ReductionEvent[P] {
  Started(P, @contracts.Assessment)
  Proposed(ReductionRequest[P])
  Decided(CandidateId, CandidateOutcome, @contracts.Assessment?)
  Finished(ReductionStop)
}

///|
pub(all) enum ReductionStartError {
  InvalidBudget
  InvalidInitial
  UnestablishedFailure(@contracts.PredicateStatus)
} derive(Eq, @debug.Debug)

///|
/// Strategies own candidate selection; the session owns validation and acceptance.
pub struct ReductionSession[P] {
  priv id : String
  priv original : P
  priv mut current : P
  priv mut best : P
  priv mut evidence : @contracts.Assessment
  priv limit : Int
  priv mut tried : Int
  priv mut pending : ReductionRequest[P]?
  priv mut stopped : ReductionStop?
  priv events : Array[ReductionEvent[P]]
  priv valid : (P) -> Bool
  priv accepts : (P, P) -> Bool
  priv better : (P, P) -> Bool
  priv predicate : (@contracts.Assessment) -> @contracts.PredicateStatus
}

///|
/// Program values stay immutable; callbacks are pure and deterministic.
/// The caller supplies a unique session id and associates evidence with each request.
pub fn[P] ReductionSession::new(
  initial : P,
  evidence : @contracts.Assessment,
  id~ : String,
  limit~ : Int,
  valid~ : (P) -> Bool,
  accepts~ : (P, P) -> Bool,
  better~ : (P, P) -> Bool,
  predicate~ : (@contracts.Assessment) -> @contracts.PredicateStatus,
) -> Result[ReductionSession[P], ReductionStartError] {
  if limit < 0 {
    return Err(InvalidBudget)
  }
  if !valid(initial) {
    return Err(InvalidInitial)
  }
  let status = predicate(evidence)
  if status != Preserved {
    return Err(UnestablishedFailure(status))
  }
  let session : ReductionSession[P] = {
    id,
    original: initial,
    current: initial,
    best: initial,
    evidence,
    limit,
    tried: 0,
    pending: None,
    stopped: None,
    events: [Started(initial, evidence)],
    valid,
    accepts,
    better,
    predicate,
  }
  session.check_budget()
  Ok(session)
}

///|
pub fn[P] ReductionSession::offer(
  self : ReductionSession[P],
  program : P,
) -> Offer[P] {
  if self.stop_reason() is Some(reason) {
    return Stopped(reason)
  }
  if self.pending is Some(_) {
    return Pending
  }
  self.tried += 1
  let request = { id: { session: self.id, attempt: self.tried, }, program, }
  self.events.push(Proposed(request))
  let rejection = if !(self.valid)(program) {
    Some(Invalid)
  } else if !(self.accepts)(self.current, program) {
    Some(Disallowed)
  } else {
    None
  }
  if rejection is Some(reason) {
    self.events.push(Decided(request.id, reason, None))
    self.check_budget()
    return Declined(reason)
  }
  self.pending = Some(request)
  Evaluate(request)
}

///|
/// Unrelated, duplicate, and cancelled responses cannot consume the pending request.
pub fn[P] ReductionSession::observe(
  self : ReductionSession[P],
  id : CandidateId,
  evidence : @contracts.Assessment,
) -> CandidateOutcome? {
  guard self.pending is Some(request) && request.id == id else { return None }
  self.pending = None
  let status = (self.predicate)(evidence)
  let outcome = if status == Preserved {
    self.current = request.program
    if (self.better)(self.best, request.program) {
      self.best = request.program
      self.evidence = evidence
    }
    Accepted
  } else {
    Rejected(status)
  }
  self.events.push(Decided(id, outcome, Some(evidence)))
  self.check_budget()
  Some(outcome)
}

///|
pub fn[P] ReductionSession::pending(
  self : ReductionSession[P],
) -> ReductionRequest[P]? {
  self.pending
}

///|
pub fn[P] ReductionSession::stop_reason(
  self : ReductionSession[P],
) -> ReductionStop? {
  self.stopped
}

///|
fn[P] ReductionSession::check_budget(self : ReductionSession[P]) -> Unit {
  if self.stopped is None && self.pending is None && self.tried >= self.limit {
    self.stopped = Some(BudgetExhausted)
    self.events.push(Finished(BudgetExhausted))
  }
}

///|
pub fn[P] ReductionSession::finish(self : ReductionSession[P]) -> Bool {
  if self.pending is Some(_) || self.stop_reason() is Some(_) {
    return false
  }
  self.stopped = Some(SearchComplete)
  self.events.push(Finished(SearchComplete))
  true
}

///|
pub fn[P] ReductionSession::cancel(self : ReductionSession[P]) -> Unit {
  if self.stop_reason() is Some(_) {
    return
  }
  self.pending = None
  self.stopped = Some(Cancelled)
  self.events.push(Finished(Cancelled))
}

///|
pub fn[P] ReductionSession::original(self : ReductionSession[P]) -> P {
  self.original
}

///|
pub fn[P] ReductionSession::current(self : ReductionSession[P]) -> P {
  self.current
}

///|
pub fn[P] ReductionSession::result(self : ReductionSession[P]) -> P {
  self.best
}

///|
pub fn[P] ReductionSession::evidence(
  self : ReductionSession[P],
) -> @contracts.Assessment {
  self.evidence
}

///|
pub fn[P] ReductionSession::attempts(self : ReductionSession[P]) -> Int {
  self.tried
}

///|
pub fn[P] ReductionSession::events(
  self : ReductionSession[P],
) -> Array[ReductionEvent[P]] {
  self.events.copy()
}

///|
pub extend CandidateId with Eq::{equal, not_equal}

///|
pub extend CandidateId with @debug.Debug::{to_repr}

///|
pub extend CandidateOutcome with Eq::{equal, not_equal}

///|
pub extend CandidateOutcome with @debug.Debug::{to_repr}

///|
pub extend ReductionStop with Eq::{equal, not_equal}

///|
pub extend ReductionStop with @debug.Debug::{to_repr}

///|
pub extend ReductionStartError with Eq::{equal, not_equal}

///|
pub extend ReductionStartError with @debug.Debug::{to_repr}
