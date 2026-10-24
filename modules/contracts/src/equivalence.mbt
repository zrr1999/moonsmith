///|
/// Runtime view linking separately saved executions; not a versioned archive.
pub(all) struct EquivalentComparison {
  configurations : Array[String]
  observations : Array[Observation]
  attempts : Array[(String, String)]
  comparison : Comparison
  injected : Bool
  error : String?
}
