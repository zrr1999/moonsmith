///|
/// Fixed operation order; accepted programs restart the schedule.
pub struct OperationSchedule[P] {
  priv operations : Array[(P) -> Array[P]]
  priv mut index : Int
}

///|
pub fn[P] OperationSchedule::new(
  operations : Array[(P) -> Array[P]],
) -> OperationSchedule[P] {
  { operations: operations.copy(), index: 0, }
}

///|
pub fn[P] OperationSchedule::next(
  self : OperationSchedule[P],
) -> ((P) -> Array[P])? {
  if self.index >= self.operations.length() {
    return None
  }
  let operation = self.operations[self.index]
  self.index += 1
  Some(operation)
}

///|
pub fn[P] OperationSchedule::restart(self : OperationSchedule[P]) -> Unit {
  self.index = 0
}
