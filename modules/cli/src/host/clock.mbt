///|
/// Milliseconds on the host monotonic clock; absolute values have no calendar meaning.
pub fn monotonic_ms() -> Int64 raise {
  let value = monotonic_ms_raw()
  guard value >= 0L else { fail("monotonic clock is unavailable") }
  value
}

///|
extern "c" fn monotonic_ms_raw() -> Int64 = "moonsmith_monotonic_ms"
