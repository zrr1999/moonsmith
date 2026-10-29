///|
fn[T] without_index(values : Array[T], removed : Int32) -> Array[T] {
  values[:removed].to_owned() + values[removed + 1:].to_owned()
}

///|
fn Expr::rewrite_tree(self : Expr, rewrite : (Expr) -> Expr) -> Expr {
  rewrite(self.map_children(child => child.rewrite_tree(rewrite)))
}

///|
fn Template::rewrite_all(self : Template, rewrite : (Expr) -> Expr) -> Template {
  {
    ..self,
    functions: self.functions.map(f => {
      ..f,
      body: f.body.rewrite_tree(rewrite),
    }),
    result: self.result.rewrite_tree(rewrite),
  }
}

///|
fn Expr::uses_variant(
  self : Expr,
  enum_id : Int32,
  variant_tag : Int32,
) -> Bool {
  let mut used = false
  ignore(
    self.rewrite_tree(expr => {
      if expr is Variant(id, tag, _) && id == enum_id && tag == variant_tag {
        used = true
      }
      expr
    }),
  )
  used
}

///|
fn Template::coordinated_templates(self : Template) -> Array[Template] {
  let candidates : Array[Template] = []
  for id, function in self.functions {
    for removed in 0..<function.parameters.length() {
      let functions = self.functions.copy()
      functions[id] = {
        ..function,
        parameters: without_index(function.parameters, removed),
      }
      candidates.push(
        { ..self, functions, }.rewrite_all(expr => {
          match expr {
            Call(callee, arguments) if callee == id =>
              Call(callee, without_index(arguments, removed))
            _ => expr
          }
        }),
      )
    }
  }
  for id, definition in self.enums {
    for tag, fields in definition.variants {
      let used = self.result.uses_variant(id, tag) ||
        self.functions.any(f => f.body.uses_variant(id, tag))
      if definition.variants.length() > 1 && !used {
        let enums = self.enums.copy()
        enums[id] = { variants: without_index(definition.variants, tag), }
        candidates.push(
          { ..self, enums, }.rewrite_all(expr => {
            match expr {
              Variant(enum_id, variant_tag, arguments) if enum_id == id &&
                variant_tag > tag =>
                Variant(enum_id, variant_tag - 1, arguments)
              Match(enum_id, value, arms) if enum_id == id =>
                Match(enum_id, value, without_index(arms, tag))
              _ => expr
            }
          }),
        )
      }
      for removed in 0..<fields.length() {
        let enums = self.enums.copy()
        let variants = definition.variants.copy()
        variants[tag] = without_index(fields, removed)
        enums[id] = { variants, }
        candidates.push(
          { ..self, enums, }.rewrite_all(expr => {
            match expr {
              Variant(enum_id, variant_tag, arguments) if enum_id == id &&
                variant_tag == tag =>
                Variant(enum_id, variant_tag, without_index(arguments, removed))
              Match(enum_id, value, arms) if enum_id == id => {
                let smaller = arms.copy()
                smaller[tag] = {
                  ..arms[tag],
                  parameters: without_index(arms[tag].parameters, removed),
                }
                Match(enum_id, value, smaller)
              }
              _ => expr
            }
          }),
        )
      }
    }
  }
  candidates
}
