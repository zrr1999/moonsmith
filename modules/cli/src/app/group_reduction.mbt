///|
fn group_assessment(
  run : DifferentialRun,
  relations : Array[(String, String)],
) -> @contracts.Assessment {
  guard run.group is Some(group) &&
    group.record.members.map(entry => (entry.id, entry.transformation)) ==
    relations &&
    run.equivalents is Some(comparison) else {
    return @contracts.Assessment::new([])
  }
  @engine.differential_assessment(
    comparison.configurations,
    comparison.observations,
    normalize=value => {
      match @moonbit.parse_result_protocol(run.case.result_protocol) {
        Some(ty) => ty.normalize_output(value)
        None => None
      }
    },
  )
}

///|
async fn reduce_equivalent_group(
  original : DifferentialRun,
  group : @moonbit.EquivalentGroup,
  limit : Int32,
  evaluate~ : async (@moonbit.EquivalentGroup, String) -> DifferentialRun = (
    group,
    purpose,
  ) => execute_equivalent_group(original, group, "group-\{purpose}"),
) -> DifferentialRun {
  guard execution_error(original) is None &&
    original.group is Some(saved) &&
    original.comparison() is Difference(first, second) else {
    return original
  }
  let relations = group.relations()
  let assess = run => group_assessment(run, relations)
  let predicate = @engine.difference_predicate(first, second)
  let (result, progress) = drive_reduction(
    original,
    group.cost(),
    limit,
    predicate,
    assess,
    search=() => {
      @engine.Reducer::new(
        group,
        assess(original),
        predicate,
        id=saved.directory,
        limit~,
        better=(candidate, incumbent) => candidate.is_smaller_than(incumbent),
        valid=candidate => {
          candidate.result_type() == group.result_type() &&
          candidate.relations() == relations
        },
        operations=[g => g.structural_candidates(), g => g.integer_candidates()],
      )
    },
    cost_model=@moonbit.group_cost_model(),
    cost=g => g.cost(),
    execute=evaluate,
    material=group_material,
  )
  finish_group_reduction(result, {
    format_version: 1,
    first_configuration: first,
    second_configuration: second,
    relations,
    progress,
  })
}

///|
async fn finish_group_reduction(
  original : DifferentialRun,
  reduction : @contracts.EquivalentGroupReduction,
) -> DifferentialRun {
  let save_error = try {
    @artifacts.save_group_reduction(group_material(original), reduction)
    original.save_error
  } catch {
    error => Some(error.to_string())
  }
  { ..original, group_reduction: Some(reduction), save_error, }
}
