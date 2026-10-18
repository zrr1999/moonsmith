fn main {
  let choose_negative = false
  let zero = if choose_negative { -0.0 } else { 0.0 }
  println(zero.reinterpret_as_int64())
}
