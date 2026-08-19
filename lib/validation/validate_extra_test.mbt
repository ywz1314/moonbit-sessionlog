///|
test "calendar validation handles leap years and malformed digits" {
  assert_true(is_calendar_date("2024-02-29"))
  assert_true(is_calendar_date("2026-08-19"))
  assert_true(!is_calendar_date("2023-02-29"))
  assert_true(!is_calendar_date("2026-04-31"))
  assert_true(!is_calendar_date("2026-13-01"))
  assert_true(!is_calendar_date("2026-8-01"))
  assert_eq(days_in_month(2024, 2), 29)
  assert_eq(days_in_month(2023, 2), 28)
}

///|
test "strict validation reports actionable paths" {
  let set = @core.Set::{
    reps: 501,
    hold_time: 0,
    resistance: "",
    completion: 1.0,
  }
  let movement = @core.Movement::{ name: "", sets: [set], pain: 1, rpe: 3 }
  let session = @core.Session::{
    id: "",
    date: "2026-08-19",
    duration: 300,
    pain_before: 2,
    pain_after: 5,
    movements: [movement],
    notes: "",
  }
  let options = @validation.ValidationOptions::{
    require_id: true,
    require_movement_name: true,
    require_resistance: true,
    reject_empty_notes: true,
    reject_pain_worsening: true,
    max_duration: 240,
    max_sets_per_movement: 0,
    max_reps_per_set: 500,
  }
  let summary = @validation.summarize(session, options~)
  assert_true(!summary.valid())
  assert_true(summary.codes().contains("invalid_id"))
  assert_true(summary.codes().contains("invalid_movement_name"))
  assert_true(summary.codes().contains("invalid_resistance"))
  assert_true(summary.codes().contains("pain_worsened"))
  assert_true(summary.paths().contains("notes"))
  assert_eq(
    @validation.validation_error_code(@validation.InvalidDuration(300)),
    "invalid_duration",
  )
}
