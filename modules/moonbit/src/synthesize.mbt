///|
pub(all) struct GenerationLimits {
  max_nodes : Int
  max_depth : Int
  max_attempts : Int
} derive(Eq, @debug.Debug)

///|
pub fn GenerationLimits::default() -> GenerationLimits {
  { max_nodes: 128, max_depth: 6, max_attempts: 256, }
}

///|
pub(all) suberror GenerationError {
  InvalidLimits(String)
  AttemptsExhausted(Int)
} derive(Eq, @debug.Debug)

///|
pub fn GenerationLimits::validate(
  self : GenerationLimits,
) -> Unit raise GenerationError {
  guard self.max_nodes >= 1 && self.max_nodes <= 2048 else {
    raise InvalidLimits("max_nodes must be between 1 and 2048")
  }
  guard self.max_depth >= 0 && self.max_depth <= 16 else {
    raise InvalidLimits("max_depth must be between 0 and 16")
  }
  guard self.max_attempts >= 1 && self.max_attempts <= 8192 else {
    raise InvalidLimits("max_attempts must be between 1 and 8192")
  }
}

///|
pub(all) struct GeneratedProgram {
  program : CompleteProgram
  construction_attempts : Int
}

///|
priv struct Construction {
  rng : @random.Rand
  limits : GenerationLimits
  // Existing holes reserve a node, so closing them never needs more space.
  mut nodes : Int
  mut attempts : Int
}

///|
fn Construction::new(seed : Int, limits : GenerationLimits) -> Construction {
  let bytes = Bytes::makei(32, i => {
    if i < 4 {
      (seed >> (i * 8)).to_byte()
    } else {
      0
    }
  })
  { rng: @random.Rand::chacha8(seed=bytes), limits, nodes: 1, attempts: 0, }
}

///|
fn Construction::attempt(self : Construction) -> Unit raise GenerationError {
  guard self.attempts < self.limits.max_attempts else {
    raise AttemptsExhausted(self.attempts)
  }
  self.attempts += 1
}

///|
fn Construction::ty(self : Construction) -> Ty {
  if self.rng.boolean() {
    Int
  } else {
    Bool
  }
}

///|
priv enum Rule {
  Terminal
  Binding
  Branch
  Invoke(Int)
  Plus
  Minus
  Compare
  Negate
}

///|
fn Construction::terminal(
  self : Construction,
  ty : Ty,
  scope : Array[Binder],
  template : Bool,
) -> Expr {
  let visible = scope.filter(binder => binder.ty == ty)
  if !visible.is_empty() && self.rng.boolean() {
    return Ref(visible[self.rng.int(limit=visible.length())].id)
  }
  if template {
    return Hole(ty)
  }
  match ty {
    Bool => BoolLiteral(self.rng.boolean())
    Int => {
      let boundaries = [
        -2147483648, -2147483647, -1, 0, 1, 2147483646, 2147483647,
      ]
      IntLiteral(
        if self.rng.boolean() {
          boundaries[self.rng.int(limit=boundaries.length())]
        } else {
          self.rng.int(limit=17) - 8
        },
      )
    }
  }
}

///|
/// Both passes use one typed rule set and charge the same construction budget.
fn Construction::expand(
  self : Construction,
  ty : Ty,
  scope : Array[Binder],
  functions : Array[Function],
  room : Int,
  template : Bool,
) -> Expr raise GenerationError {
  self.attempt()
  let rules = [Terminal]
  let remaining = self.limits.max_nodes - self.nodes
  if room > 0 {
    if remaining >= 2 {
      rules.push(Binding)
    }
    if remaining >= 3 {
      rules.push(Branch)
    }
    for id, function in functions {
      if function.returns == ty && remaining >= function.parameters.length() {
        rules.push(Invoke(id))
      }
    }
    if !template {
      match ty {
        Int =>
          if remaining >= 2 {
            rules.push(Plus)
            rules.push(Minus)
          }
        Bool => {
          if remaining >= 2 {
            rules.push(Compare)
          }
          if remaining >= 1 {
            rules.push(Negate)
          }
        }
      }
    }
  }
  let expression = match rules[self.rng.int(limit=rules.length())] {
    Terminal => return self.terminal(ty, scope, template)
    Binding => {
      let binder = {
        id: scope.fold(init=-1, (id, binder) => id.max(binder.id)) + 1,
        ty: self.ty(),
      }
      Let(binder, Hole(binder.ty), Hole(ty))
    }
    Branch => If(Hole(Bool), Hole(ty), Hole(ty))
    Invoke(id) => Call(id, functions[id].parameters.map(p => Hole(p.ty)))
    Plus => Add(Hole(Int), Hole(Int))
    Minus => Subtract(Hole(Int), Hole(Int))
    Compare => Less(Hole(Int), Hole(Int))
    Negate => Not(Hole(Bool))
  }
  self.nodes += expression.size() - 1
  self.fill(expression, scope, functions, room, template)
}

///|
fn Construction::fill(
  self : Construction,
  expression : Expr,
  scope : Array[Binder],
  functions : Array[Function],
  room : Int,
  template : Bool,
) -> Expr raise GenerationError {
  match expression {
    Hole(ty) => self.expand(ty, scope, functions, room, template)
    IntLiteral(_) | BoolLiteral(_) | Ref(_) => expression
    Let(binder, value, body) => {
      let value = self.fill(value, scope, functions, room - 1, template)
      let nested = scope.copy()
      nested.push(binder)
      Let(binder, value, self.fill(body, nested, functions, room - 1, template))
    }
    Add(a, b) =>
      Add(
        self.fill(a, scope, functions, room - 1, template),
        self.fill(b, scope, functions, room - 1, template),
      )
    Subtract(a, b) =>
      Subtract(
        self.fill(a, scope, functions, room - 1, template),
        self.fill(b, scope, functions, room - 1, template),
      )
    Less(a, b) =>
      Less(
        self.fill(a, scope, functions, room - 1, template),
        self.fill(b, scope, functions, room - 1, template),
      )
    Not(e) => Not(self.fill(e, scope, functions, room - 1, template))
    If(condition, yes, no) =>
      If(
        self.fill(condition, scope, functions, room - 1, template),
        self.fill(yes, scope, functions, room - 1, template),
        self.fill(no, scope, functions, room - 1, template),
      )
    Call(id, arguments) =>
      Call(
        id,
        arguments.map(e => self.fill(e, scope, functions, room - 1, template)),
      )
  }
}

///|
fn Construction::compose_template(
  self : Construction,
) -> Template raise GenerationError {
  let functions : Array[Function] = []
  let count = if self.limits.max_depth == 0 { 0 } else { self.rng.int(limit=4) }
  for _ in 0..<count {
    let parameters = Array::makei(self.rng.int(limit=3), id => Binder::{
      id,
      ty: self.ty(),
    })
    let cost = 2 + parameters.length()
    if self.nodes + cost > self.limits.max_nodes {
      break
    }
    self.attempt()
    self.nodes += cost
    let returns = self.ty()
    functions.push({ parameters, returns, body: Hole(returns), })
  }
  // Only preceding signatures are visible to a function; cycles cannot be constructed.
  let room = self.limits.max_depth.min(3)
  for id, function in functions {
    functions[id] = {
      ..function,
      body: self.fill(
        function.body,
        function.parameters,
        functions[:id].to_owned(),
        room,
        true,
      ),
    }
  }
  { functions, result: self.expand(self.ty(), [], functions, room, true), }
}

///|
fn Construction::complete(
  self : Construction,
  template : Template,
) -> CompleteProgram raise {
  let functions : Array[Function] = []
  for id, function in template.functions {
    functions.push({
      ..function,
      body: self.fill(
        function.body,
        function.parameters,
        template.functions[:id].to_owned(),
        self.limits.max_depth,
        false,
      ),
    })
  }
  let result = self.fill(
    template.result,
    [],
    functions,
    self.limits.max_depth,
    false,
  )
  Template::{ functions, result, }.finish()
}

///|
/// template-rules-v1: deterministic Int/Bool expressions with wrapping Int arithmetic.
pub fn synthesize(
  seed : Int,
  limits? : GenerationLimits = GenerationLimits::default(),
) -> GeneratedProgram raise {
  limits.validate()
  let state = Construction::new(seed, limits)
  let template = state.compose_template()
  let program = state.complete(template)
  { program, construction_attempts: state.attempts, }
}

///|
pub extend GenerationLimits with Eq::{equal, not_equal}

///|
pub extend GenerationLimits with @debug.Debug::{to_repr}

///|
pub extend GenerationError with Eq::{equal, not_equal}

///|
pub extend GenerationError with @debug.Debug::{to_repr}
