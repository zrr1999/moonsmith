///|
pub async fn mkdir(path : String) -> Unit {
  @fs.mkdir(path, recursive=true, allow_exist=true)
}

///|
pub async fn new_directory(prefix : String) -> String {
  guard @env.rand(16) is Some(nonce) else { fail("system entropy unavailable") }
  let directory = prefix + @hex.encode(nonce)
  @fs.mkdir(directory, permission=0o700, allow_exist=false)
  @fs.realpath(directory)
}

///|
pub async fn canonical(path : String) -> String {
  @fs.realpath(path)
}

///|
pub async fn write_new(path : String, text : String) -> Unit {
  @fs.write_file(path, text, create_mode=CreateNew)
}

///|
pub async fn read_text(path : String) -> String {
  @fs.read_file(path).text()
}

///|
pub async fn list_directory(path : String) -> Array[String] {
  @fs.readdir(path, sort=true)
}

///|
pub async fn exists(path : String) -> Bool {
  @fs.exists(path)
}

///|
pub async fn remove_tree(path : String) -> Unit {
  @fs.rmdir(path, recursive=true)
}

///|
pub fn arguments() -> Array[String] {
  @env.args()
}

///|
pub fn current_directory() -> String {
  @env.current_dir().unwrap_or(".")
}

///|
pub fn random_seed() -> Int raise {
  guard @env.rand(4) is Some(bytes) else { fail("system entropy unavailable") }
  bytes[0].to_int() |
  (bytes[1].to_int() << 8) |
  (bytes[2].to_int() << 16) |
  (bytes[3].to_int() << 24)
}

///|
pub async fn platform() -> @contracts.ProcessEvidence {
  let command : @contracts.Command = {
    program: "uname",
    args: ["-srm"],
    cwd: current_directory(),
    timeout_ms: 10000,
    output_limit: 65536,
  }
  { command, output: execute(command), }
}

///|
pub extern "c" fn exit(code : Int) = "exit"
