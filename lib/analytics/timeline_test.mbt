///|
fn sample_session(
  id : String,
  date : String,
  pain : Int,
  completion : Double,
) -> @core.Session {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "band",
    completion,
  }
  let movement = @core.Movement::{ name: "squat", sets: [set], pain, rpe: 5 }
  @core.Session::{
    id,
    date,
    duration: 30,
    pain_before: pain + 1,
    pain_after: pain,
    movements: [movement],
    notes: "",
  }
}

///|
test "snapshot and report expose usable trends" {
  let a = sample_session("a", "2026-08-01", 6, 0.6)
  let b = sample_session("b", "2026-08-02", 2, 1.0)
  let item = snapshot(a)
  assert_eq(item.total_reps(), 10)
  assert_eq(item.total_sets(), 1)
  assert_eq(item.pain_delta(), -1)
  assert_eq(item.recovery(), RecoveryStatus::Deload)
  assert_true(item.flags().contains("completion_below_target"))

  let report = analyze([a, b])
  assert_eq(report.session_count(), 2)
  assert_eq(report.total_reps(), 20)
  assert_eq(report.first_date(), "2026-08-01")
  assert_eq(report.last_date(), "2026-08-02")
  assert_eq(report.pain_direction(), TrendDirection::Improving)
  assert_eq(report.completion_direction(), TrendDirection::Improving)
  assert_eq(report.adherence_percent(), 66.66666666666667)
}

///|
test "analytics boundary helpers are deterministic" {
  let empty : Array[@core.Session] = []
  assert_eq(analyze(empty).pain_direction(), TrendDirection::InsufficientData)
  assert_eq(moving_average([1.0, 2.0, 3.0], 2), [1.0, 1.5, 2.5])
  assert_eq(moving_average([1.0], 0), [])
  assert_eq(
    longest_ready_streak([
      sample_session("a", "1", 1, 1.0),
      sample_session("b", "2", 1, 1.0),
    ]),
    2,
  )
  assert_eq(
    select_recent(
      [sample_session("a", "1", 1, 1.0), sample_session("b", "2", 1, 1.0)],
      1,
    )[0].id,
    "b",
  )
  assert_eq(
    unique_session_ids([
      sample_session("a", "1", 1, 1.0),
      sample_session("a", "2", 1, 1.0),
    ]),
    ["a"],
  )
}
