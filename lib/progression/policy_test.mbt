///|
test "policy engine respects progression and safety caps" {
  let easy_set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 1.0,
  }
  let easy = @core.Movement::{
    name: "squat",
    sets: [easy_set],
    pain: 1,
    rpe: 4,
  }
  let hard_set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 0.5,
  }
  let hard = @core.Movement::{
    name: "squat",
    sets: [hard_set],
    pain: 8,
    rpe: 9,
  }
  let progress = @progression.analyze_with_policy(
    easy,
    @progression.default_policy(),
  )
  let regression = @progression.analyze_with_policy(
    hard,
    @progression.conservative_policy(),
  )
  assert_eq(progress.state(), @progression.ProgressionState::Progression)
  assert_eq(progress.suggested_reps(), 12)
  assert_eq(regression.state(), @progression.ProgressionState::Regression)
  assert_eq(regression.suggested_reps(), 9)
  assert_true(progress.readiness() > regression.readiness())
  assert_eq(@progression.explain_state(progress.state()), "increase gradually")
}

///|
test "session planning separates actionable decisions" {
  let set = @core.Set::{
    reps: 8,
    hold_time: 5,
    resistance: "body",
    completion: 1.0,
  }
  let a = @core.Movement::{ name: "a", sets: [set], pain: 1, rpe: 3 }
  let b = @core.Movement::{ name: "b", sets: [set], pain: 8, rpe: 9 }
  let session = @core.Session::{
    id: "s",
    date: "2026-08-19",
    duration: 20,
    pain_before: 4,
    pain_after: 3,
    movements: [a, b],
    notes: "",
  }
  let plan = @progression.plan_session(session)
  assert_eq(plan.length(), 2)
  assert_eq(@progression.plan_summary(plan), (1, 0, 1))
  assert_eq(@progression.decisions_requiring_attention(plan).length(), 1)
  assert_eq(@progression.decisions_ready_to_progress(plan).length(), 1)
  assert_eq(
    @progression.plan_readiness(plan),
    (plan[0].readiness() + plan[1].readiness()) / 2,
  )
}
