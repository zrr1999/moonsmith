fn f0(v0 : Bool) -> Bool {
  { let v1 : Int = (if (if (if false { ({ let v1 : Int = 4; 2147483647 } < ((-6) + (-2147483648))) } else { { let v1 : Bool = { let v1 : Int = (-4); v0 }; ((-1) < 6) } }) { v0 } else { v0 }) { { let v1 : Int = (((if v0 { 1 } else { (-7) }) + ((-4) - 2147483647)) + (-2147483648)); v1 } } else { { let v1 : Bool = v0; ({ let v2 : Bool = (2 < 2147483647); ((-2147483647) - 0) } - (if (!false) { 2 } else { (0 + (-1)) })) } }); { let v2 : Bool = { let v2 : Bool = v0; (if (!(v1 < 2147483646)) { (if { let v3 : Int = v1; true } { (!false) } else { (!v0) }) } else { { let v3 : Bool = true; { let v4 : Bool = false; true } } }) }; (if false { ({ let v3 : Int = (v1 + (-1)); { let v4 : Int = v1; v3 } } < (2147483647 + v1)) } else { { let v3 : Bool = (if v2 { { let v3 : Bool = v2; v2 } } else { (if false { v2 } else { true }) }); { let v4 : Int = (if true { 2147483647 } else { v1 }); (!v2) } } }) } }
}

fn f1() -> Bool {
  (if { let v0 : Int = { let v0 : Int = (if f0(true) { 2147483646 } else { (-1) }); v0 }; { let v1 : Int = v0; false } } { (if f0(true) { f0(true) } else { (if true { false } else { false }) }) } else { f0(false) })
}

fn main {
  println(f1())
}
