///|
/// Accept exactly one canonical scalar followed by LF, matching CompleteProgram.emit.
/// Raw output remains unchanged; malformed output is not a comparable value.
pub fn Ty::normalize_output(self : Ty, stdout : String) -> String? {
  match self {
    Bool =>
      if stdout == "true\n" || stdout == "false\n" {
        Some(stdout)
      } else {
        None
      }
    Int => {
      guard stdout.strip_suffix("\n") is Some(text) else { return None }
      let value = @string.parse_int(text) catch { _ => return None }
      if stdout == "\{value}\n" {
        Some(stdout)
      } else {
        None
      }
    }
    Tuple(_) | Enum(_) => None
  }
}

///|
pub fn Ty::result_protocol(self : Ty) -> String? {
  match self {
    Int => Some("moonbit-int32-line-v1")
    Bool => Some("moonbit-bool-line-v1")
    Tuple(_) | Enum(_) => None
  }
}

///|
pub fn parse_result_protocol(protocol : String) -> Ty? {
  match protocol {
    "moonbit-int32-line-v1" => Some(Int)
    "moonbit-bool-line-v1" => Some(Bool)
    _ => None
  }
}
