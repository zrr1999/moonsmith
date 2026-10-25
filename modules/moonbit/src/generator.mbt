///|
pub(all) enum Generator {
  ScalarV1
  CompositeV2
} derive(Eq, @debug.Debug)

///|
pub fn Generator::default() -> Generator {
  CompositeV2
}

///|
pub fn Generator::identifier(self : Generator) -> String {
  match self {
    ScalarV1 => "template-rules-v1"
    CompositeV2 => "template-rules-v2"
  }
}

///|
fn generators() -> Array[Generator] {
  [ScalarV1, CompositeV2]
}

///|
pub fn generator_identifiers() -> Array[String] {
  generators().map(generator => generator.identifier())
}

///|
pub fn parse_generator(identifier : String) -> Generator? {
  for generator in generators() {
    if generator.identifier() == identifier {
      return Some(generator)
    }
  }
  None
}

///|
pub extend Generator with Eq::{equal, not_equal}

///|
pub extend Generator with @debug.Debug::{to_repr}
