///|
test "protocol validates goals and evaluates progress" {
  let value = new_protocol("recovery", ProtocolPhase::Assessment).add_goal(
    goal(
      "g1",
      "reduce pain",
      GoalMetric::PainAfter,
      2.0,
      0.5,
      "2026-12-31",
      ProtocolPhase::Assessment,
      1,
    ),
  )
  assert_eq(value.validate(), [])
  let session = @core.Session::{
    id: "p1",
    date: "2026-02-20",
    duration: 30,
    pain_before: 4,
    pain_after: 2,
    movements: [],
    notes: "",
  }
  let progress = evaluate_goals(value, [session])
  assert_eq(progress.length(), 1)
  assert_true(progress[0].met())
}

///|
test "protocol phase boundaries are stable" {
  assert_eq(
    previous_phase(ProtocolPhase::Assessment),
    ProtocolPhase::Assessment,
  )
  assert_eq(next_phase(ProtocolPhase::Maintenance), ProtocolPhase::Maintenance)
}
