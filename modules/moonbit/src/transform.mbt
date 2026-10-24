///|
/// Pure output-preserving variants, independently checked; generation budgets do not apply.
pub fn CompleteProgram::equivalent_variants(
  self : CompleteProgram,
) -> Array[CompleteProgram] raise StructureError {
  let result = self.syntax.result
  let variants : Array[Expr] = []
  match self.result_ty {
    Int => variants.push(Add(result, IntLiteral(0)))
    Bool => variants.push(Not(Not(result)))
    _ => ()
  }
  variants.push(
    If(BoolLiteral(true), result, self.result_ty.zero(self.syntax.enums)),
  )
  variants.map(result => { ..self.syntax, result, }.finish())
}
