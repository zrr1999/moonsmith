///|
fn gen_int(rng : @random.Rand, depth : Int, scope : Int) -> IntExpr {
  if depth == 0 {
    if scope > 0 && rng.boolean() {
      Variable(rng.int(limit=scope))
    } else {
      Literal(rng.int(limit=17) - 8)
    }
  } else {
    match rng.int(limit=4) {
      0 => gen_int(rng, 0, scope)
      1 => Add(gen_int(rng, depth - 1, scope), gen_int(rng, depth - 1, scope))
      2 =>
        Subtract(gen_int(rng, depth - 1, scope), gen_int(rng, depth - 1, scope))
      _ =>
        Choose(
          gen_bool(rng, depth - 1, scope),
          gen_int(rng, depth - 1, scope),
          gen_int(rng, depth - 1, scope),
        )
    }
  }
}

///|
fn gen_bool(rng : @random.Rand, depth : Int, scope : Int) -> BoolExpr {
  if depth == 0 {
    Boolean(rng.boolean())
  } else if rng.boolean() {
    Less(gen_int(rng, depth - 1, scope), gen_int(rng, depth - 1, scope))
  } else {
    Not(gen_bool(rng, depth - 1, scope))
  }
}

///|
/// int-bool-v1: finite trees, three sequential bindings, no overflow or recursion.
pub fn generate(seed : Int, depth? : Int = 3) -> Program? {
  guard depth >= 0 && depth <= 4 else { return None }
  let bytes = Bytes::makei(32, i => {
    if i < 4 {
      (seed >> (i * 8)).to_byte()
    } else {
      0
    }
  })
  let rng = @random.Rand::chacha8(seed=bytes)
  let bindings = Array::makei(3, i => gen_int(rng, depth, i))
  let result = Choose(
    Less(Variable(0), Variable(1)),
    Add(Variable(2), gen_int(rng, depth, 3)),
    Subtract(Variable(2), gen_int(rng, depth, 3)),
  )
  Some({ bindings, result, })
}
