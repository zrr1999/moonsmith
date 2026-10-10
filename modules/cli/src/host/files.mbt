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
pub extern "c" fn exit(code : Int) = "exit"
