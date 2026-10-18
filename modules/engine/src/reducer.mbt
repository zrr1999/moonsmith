///|
/// Connects language operations, enumeration, and scheduling to one session.
pub struct Reducer[P] {
  priv session : ReductionSession[P]
  priv schedule : OperationSchedule[P]
  priv mut search : Enumeration[P]?
}

///|
/// `better(candidate, incumbent)` orders programs without interpreting their cost.
pub fn[P] Reducer::new(
  initial : P,
  evidence : @contracts.Assessment,
  predicate : @contracts.FailurePredicate,
  id~ : String,
  limit~ : Int,
  better~ : (P, P) -> Bool,
  valid~ : (P) -> Bool,
  operations~ : Array[(P) -> Array[P]],
) -> Result[Reducer[P], ReductionStartError] {
  let session = match
    ReductionSession::new(
      initial,
      evidence,
      id~,
      limit~,
      valid~,
      accepts=(current, candidate) => better(candidate, current),
      better=(best, candidate) => better(candidate, best),
      predicate=assessment => match_failure(predicate, assessment),
    ) {
    Ok(session) => session
    Err(error) => return Err(error)
  }
  Ok({ session, schedule: OperationSchedule::new(operations), search: None, })
}

///|
pub fn[P] Reducer::next(self : Reducer[P]) -> ReductionRequest[P]? {
  if self.session.pending() is Some(request) {
    return Some(request)
  }
  while self.session.stop_reason() is None {
    if self.search is Some(search) && search.next() is Some(candidate) {
      match self.session.offer(candidate) {
        Evaluate(request) => return Some(request)
        Declined(_) => continue
        Pending => return self.session.pending()
        Stopped(_) => return None
      }
    }
    match self.schedule.next() {
      Some(operation) =>
        self.search = Some(Enumeration::new(operation(self.session.current())))
      None => {
        ignore(self.session.finish())
        return None
      }
    }
  } nobreak {
    None
  }
}

///|
pub fn[P] Reducer::observe(
  self : Reducer[P],
  id : CandidateId,
  evidence : @contracts.Assessment,
) -> Bool {
  if self.session.observe(id, evidence) is Some(Accepted) {
    self.schedule.restart()
    self.search = None
    true
  } else {
    false
  }
}

///|
pub fn[P] Reducer::result(self : Reducer[P]) -> P {
  self.session.result()
}

///|
pub fn[P] Reducer::attempts(self : Reducer[P]) -> Int {
  self.session.attempts()
}

///|
pub fn[P] Reducer::stop_reason(self : Reducer[P]) -> ReductionStop? {
  self.session.stop_reason()
}
