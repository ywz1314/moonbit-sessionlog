///|
test "workload handles empty values and ramp limits" {
  assert_eq(acute_load([], 7), 0.0)
  assert_eq(chronic_load([], 28), 0.0)
  assert_true(
    (safe_next_load(100.0, maximum_ramp=10.0) - 110.0).abs() < 0.00001,
  )
  assert_eq(ramp_percent(100.0, 120.0), 20.0)
}

///|
test "workload assessment exposes ratio and flags" {
  let session = @core.Session::{
    id: "load",
    date: "2026-02-20",
    duration: 40,
    pain_before: 2,
    pain_after: 3,
    movements: [
      @core.Movement::{
        name: "squat",
        pain: 3,
        rpe: 8,
        sets: [
          @core.Set::{
            reps: 10,
            hold_time: 0,
            resistance: "body",
            completion: 1.0,
          },
        ],
      },
    ],
    notes: "",
  }
  let assessment = assess(
    [from_session(session)],
    acute_days=7,
    chronic_days=28,
    ramp_limit=10.0,
  )
  assert_true(assessment.acute() >= 0.0)
  assert_true(assessment.recommendation().length() > 0)
}
