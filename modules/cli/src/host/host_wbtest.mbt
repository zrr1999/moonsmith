///|
fn shell(
  script : String,
  timeout_ms? : Int = 2000,
  output_limit? : Int = 1024,
) -> @contracts.Command {
  {
    program: "sh",
    args: ["-c", script],
    cwd: current_directory(),
    timeout_ms,
    output_limit,
  }
}

///|
async test "host captures streams and nonzero exits without evaluating arguments" {
  let output = execute(shell("printf 'out'; printf 'err' >&2; exit 7"))
  @debug.assert_eq(output.status, @contracts.Exited(7))
  @debug.assert_eq(output.stdout, "out")
  @debug.assert_eq(output.stderr, "err")
  let literal = execute({
    ..shell(""),
    program: "printf",
    args: ["%s", "$(exit 19); quoted argument"],
  })
  @debug.assert_eq(literal.stdout, "$(exit 19); quoted argument")
  @debug.assert_eq(literal.status, @contracts.Exited(0))
  assert_true(
    execute({ ..shell(""), program: "moonsmith-nonexistent-command", }).status
    is HostError(_),
  )
}

///|
async test "timeout reaps the direct child and preserves its partial output" {
  let output = execute(
    shell("printf '%s' \"$$\"; while :; do :; done", timeout_ms=200),
  )
  @debug.assert_eq(output.status, @contracts.TimedOut)
  assert_false(output.stdout.is_empty())
  let probe = execute({
    ..shell(""),
    args: ["-c", "kill -0 \"$1\" 2>/dev/null", "probe", output.stdout],
  })
  assert_true(probe.status is Exited(code) && code != 0)
}

///|
async test "output cap drains both streams concurrently and terminates a noisy child" {
  let output = execute(
    shell(
      "while :; do printf '12345678'; printf 'abcdefgh' >&2; done",
      output_limit=128,
    ),
  )
  @debug.assert_eq(output.status, @contracts.OutputLimit)
  assert_true(output.stdout.length() <= 128)
  assert_true(output.stderr.length() <= 128)
  assert_true(output.stdout.length() == 128 || output.stderr.length() == 128)
}

///|
async test "exclusive artifact writes preserve the original on a second write" {
  let directory = @fs.tmpdir(prefix="moonsmith-write-test")
  defer remove_tree(directory)
  let path = "\{directory}/original.mbt"
  write_new(path, "original")
  let rejected = try {
    write_new(path, "replacement")
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  @debug.assert_eq(read_text(path), "original")
}
