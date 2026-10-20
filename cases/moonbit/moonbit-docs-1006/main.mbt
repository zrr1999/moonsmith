fn main {
  let word = "moon"
  guard word is [.., last] else { return }
  println(last)
}
