///|
/// Language-owned candidates and validation; the search never sees an AST or host.
pub struct Reducer[P] {
  priv mut best : P
  priv fingerprint : @contracts.Fingerprint
  priv limit : Int
  priv mut tried : Int
  priv mut pending : P?
  priv mut queue : Array[P]
  priv mut index : Int
  priv size : (P) -> Int
  priv valid : (P) -> Bool
  priv candidates : (P) -> Array[P]
}

///|
pub fn[P] Reducer::new(
  initial : P,
  fingerprint : @contracts.Fingerprint,
  limit~ : Int,
  size~ : (P) -> Int,
  valid~ : (P) -> Bool,
  candidates~ : (P) -> Array[P],
) -> Reducer[P] {
  {
    best: initial,
    fingerprint,
    limit,
    tried: 0,
    pending: None,
    queue: candidates(initial),
    index: 0,
    size,
    valid,
    candidates,
  }
}

///|
pub fn[P] Reducer::next(self : Reducer[P]) -> P? {
  if self.pending is Some(_) {
    return self.pending
  }
  while self.tried < self.limit && self.index < self.queue.length() {
    let candidate = self.queue[self.index]
    self.index += 1
    self.tried += 1
    if (self.size)(candidate) < (self.size)(self.best) &&
      (self.valid)(candidate) {
      self.pending = Some(candidate)
      return self.pending
    }
  }
  None
}

///|
/// A timeout, a different failure, or a passing candidate cannot replace the best.
pub fn[P] Reducer::observe(
  self : Reducer[P],
  verdict : @contracts.Verdict,
) -> Bool {
  guard self.pending is Some(candidate) else { return false }
  self.pending = None
  if verdict == Finding(self.fingerprint) {
    self.best = candidate
    self.queue = (self.candidates)(candidate)
    self.index = 0
    true
  } else {
    false
  }
}

///|
pub fn[P] Reducer::result(self : Reducer[P]) -> P {
  self.best
}

///|
pub fn[P] Reducer::attempts(self : Reducer[P]) -> Int {
  self.tried
}
