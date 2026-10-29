///|
pub struct Enumeration[P] {
  priv candidates : Array[P]
  priv mut index : Int32
}

///|
pub fn[P] Enumeration::new(candidates : Array[P]) -> Enumeration[P] {
  { candidates: candidates.copy(), index: 0, }
}

///|
pub fn[P] Enumeration::next(self : Enumeration[P]) -> P? {
  if self.index >= self.candidates.length() {
    return None
  }
  let candidate = self.candidates[self.index]
  self.index += 1
  Some(candidate)
}
