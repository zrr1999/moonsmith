///|
test "integer observations require a canonical signed 32-bit value and one LF" {
  for text in ["0\n", "1\n", "-1\n", "2147483647\n", "-2147483648\n"] {
    @debug.assert_eq(Ty::Int.normalize_output(text), Some(text))
  }
  for
    text in [
      "", "1", "1\r\n", "1\n\n", " 1\n", "1 \n", "+1\n", "01\n", "-0\n", "1.0\n",
      "0x1\n", "2147483648\n", "-2147483649\n", "true\n", "value=1\n", "1\ndiagnostic\n",
    ] {
    @debug.assert_eq(Ty::Int.normalize_output(text), None, msg=text)
  }
}

///|
test "boolean observations reject values of other types and extra output" {
  for text in ["true\n", "false\n"] {
    @debug.assert_eq(Ty::Bool.normalize_output(text), Some(text))
  }
  for
    text in [
      "", "true", "True\n", " true\n", "true \n", "false\r\n", "false\n\n", "true\nfalse\n",
      "0\n", "1\n", "diagnostic\nfalse\n",
    ] {
    @debug.assert_eq(Ty::Bool.normalize_output(text), None, msg=text)
  }
}
