fn high_bit(value : Int) -> UInt? {
  if value < 0 { None } else { Some(0x80000000U | value.reinterpret_as_uint()) }
}

fn main {
  match high_bit(3) {
    Some(value) => println((value >> 1).to_uint64())
    None => println(0)
  }
}
