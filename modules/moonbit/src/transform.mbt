///|
/// Pure output-preserving variants, independently checked; generation budgets do not apply.
pub fn CompleteProgram::equivalent_variants(
  self : CompleteProgram,
) -> Array[CompleteProgram] raise StructureError {
  let result = self.syntax.result
  let neutral : Expr = match self.result_ty {
    Int => Add(result, IntLiteral(0))
    Bool => Not(Not(result))
  }
  [
    { ..self.syntax, result: neutral, }.finish(),
    {
      ..self.syntax,
      result: If(BoolLiteral(true), result, self.result_ty.zero()),
    }.finish(),
  ]
}
