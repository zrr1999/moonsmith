///|
async fn main {
  let args = @host.arguments()
  let code = @app.cli(args[1:].to_owned()) catch {
    error => {
      println("MoonSmith: \{error}")
      1
    }
  }
  @host.exit(code)
}
