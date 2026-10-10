///|
/// The prototype's enumeration strategy, using the shared acceptance engine.
pub struct Reducer[P] {
  priv session : ReductionSession[P]
  priv mut queue : Array[P]
  priv mut index : Int
  priv candidates : (P) -> Array[P]
}

///|
pub fn[P] Reducer::new(
  initial : P,
  evidence : @contracts.Assessment,
  predicate : @contracts.FailurePredicate,
  id~ : String,
  limit~ : Int,
  size~ : (P) -> Int,
  valid~ : (P) -> Bool,
  candidates~ : (P) -> Array[P],
) -> Result[Reducer[P], ReductionStartError] {
  let session = match
    ReductionSession::new(
      initial,
      evidence,
      id~,
      limit~,
      valid~,
      accepts=(current, candidate) => size(candidate) < size(current),
      better=(best, candidate) => size(candidate) < size(best),
      predicate=assessment => match_failure(predicate, assessment),
    ) {
    Ok(session) => session
    Err(error) => return Err(error)
  }
  Ok({ session, queue: [], index: 0, candidates, })
}

///|
pub fn[P] Reducer::next(self : Reducer[P]) -> ReductionRequest[P]? {
  if self.session.pending() is Some(request) {
    return Some(request)
  }
  if self.session.stop_reason() is Some(_) {
    return None
  }
  if self.session.attempts() == 0 && self.index == 0 {
    self.queue = (self.candidates)(self.session.current()).copy()
  }
  while self.index < self.queue.length() {
    let candidate = self.queue[self.index]
    self.index += 1
    match self.session.offer(candidate) {
      Evaluate(request) => return Some(request)
      Declined(_) => ()
      Pending => return self.session.pending()
      Stopped(_) => return None
    }
  }
  ignore(self.session.finish())
  None
}

///|
pub fn[P] Reducer::observe(
  self : Reducer[P],
  id : CandidateId,
  evidence : @contracts.Assessment,
) -> Bool {
  if self.session.observe(id, evidence) is Some(Accepted) {
    self.queue = if self.session.stop_reason() is None {
      (self.candidates)(self.session.current()).copy()
    } else {
      []
    }
    self.index = 0
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
