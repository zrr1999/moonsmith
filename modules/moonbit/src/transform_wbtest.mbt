///|
test "equivalent variants preserve checked types determinism and the original snapshot" {
  for seed in -10..<100 {
    let program = synthesize(seed).program
    let source = program.emit()
    let variants = program.equivalent_variants()
    @debug.assert_eq(variants.length(), 2)
    for variant in variants {
      @debug.assert_eq(variant.result_type(), program.result_type())
      assert_true(variant.emit() != source)
    }
    @debug.assert_eq(program.emit(), source)
    @debug.assert_eq(program.equivalent_variants(), variants)
  }
}
