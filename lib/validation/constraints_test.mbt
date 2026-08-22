///|
test "constraints reject unsafe boundary values" {
  let session = @core.Session::{
    id: "",
    date: "2026-02-30",
    duration: 0,
    pain_before: 11,
    pain_after: -1,
    movements: [
      @core.Movement::{
        name: "",
        pain: 11,
        rpe: 0,
        sets: [
          @core.Set::{
            reps: -1,
            hold_time: -2,
            resistance: "",
            completion: 2.0,
          },
        ],
      },
    ],
    notes: "",
  }
  let issues = evaluate_constraints(session)
  assert_true(issues.length() >= 8)
  assert_true(!session_passes(session))
  assert_true(!session_is_safe(session))
  assert_true(constraint_codes(issues).contains("pain_range"))
}

///|
test "constraint batch summary handles clean input" {
  let session = @core.Session::{
    id: "ok",
    date: "2026-02-20",
    duration: 30,
    pain_before: 2,
    pain_after: 1,
    movements: [],
    notes: "routine",
  }
  let summary = summarize_constraints([session])
  assert_eq(summary.sessions(), 1)
  assert_eq(summary.affected_sessions(), 0)
  assert_eq(summary.clean_percent(), 100.0)
}
