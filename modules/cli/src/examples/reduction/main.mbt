///|
async fn main {
  defer @coverage.end()
  let run = @app.run_differential(
    seed=7,
    generator=@moonbit.ScalarV1,
    base="runs/reduction-demo",
    injected=true,
  )
  println(@app.describe_differential(run))
  guard run.save_error is None &&
    run.reduction is Some(reduction) &&
    reduction.error is None &&
    reduction.confirmation is Some(Preserved) &&
    reduction.confirmation_attempt is Some(material) else {
    fail("reduction demonstration did not produce confirmed, saved evidence")
  }
  let replay = @app.replay_differential(material)
  println(@app.describe_differential(replay))
  guard replay.save_error is None &&
    replay.attempt.comparison == run.attempt.comparison else {
    fail("reduction replay did not preserve the selected difference")
  }
}
