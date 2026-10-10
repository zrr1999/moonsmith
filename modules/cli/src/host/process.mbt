///|
priv suberror OutputExceeded

///|
async fn collect(
  reader : @process.ReadFromProcess,
  buffer : @buffer.Buffer,
  limit : Int,
) -> Unit {
  while reader.read_some(max_len=4096) is Some(chunk) {
    let remaining = limit - buffer.length()
    if chunk.length() > remaining {
      buffer.write_bytes(chunk[:remaining])
      raise OutputExceeded
    }
    buffer.write_bytes(chunk)
  }
}

///|
/// Captures streams independently, with a byte cap on each, and reaps the child.
pub async fn execute(command : @contracts.Command) -> @contracts.Output {
  let stdout = @buffer.Buffer()
  let stderr = @buffer.Buffer()
  let status = try {
    guard command.timeout_ms > 0 && command.output_limit > 0 else {
      fail("process budgets must be positive")
    }
    let code = @async.with_timeout(command.timeout_ms, () => {
      let (out_read, out_write) = @process.read_from_process()
      defer out_read.close()
      defer out_write.close()
      let (err_read, err_write) = @process.read_from_process()
      defer err_read.close()
      defer err_write.close()
      let input = @process.redirect_from_file("/dev/null")
      @async.with_task_group(group => {
        let child = group.spawn(() => {
          @process.run(
            command.program,
            command.args,
            cwd=command.cwd,
            stdin=input,
            stdout=out_write,
            stderr=err_write,
            cancel_handler=@process.hard_cancel(),
          )
        })
        group.spawn_bg(() => collect(out_read, stdout, command.output_limit))
        group.spawn_bg(() => collect(err_read, stderr, command.output_limit))
        child.wait()
      })
    })
    @contracts.Exited(code)
  } catch {
    @async.TimeoutError => @contracts.TimedOut
    OutputExceeded => @contracts.OutputLimit
    e => @contracts.HostError(e.to_string())
  }
  {
    status,
    stdout: @utf8.decode_lossy(stdout.to_bytes()),
    stderr: @utf8.decode_lossy(stderr.to_bytes()),
  }
}
