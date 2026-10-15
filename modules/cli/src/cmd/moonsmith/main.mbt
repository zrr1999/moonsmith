///|
async fn main {
  let args = @host.arguments()
  let code = cli(args[1:].to_owned())
  @host.exit(code)
}
