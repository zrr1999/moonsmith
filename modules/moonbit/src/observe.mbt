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
  }
}
