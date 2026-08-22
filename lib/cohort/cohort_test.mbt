///|
test "cohorts group dates and preserve totals" {
  let first = @core.Session::{
    id: "a",
    date: "2026-01-03",
    duration: 30,
    pain_before: 2,
    pain_after: 1,
    movements: [],
    notes: "",
  }
  let second = @core.Session::{
    id: "b",
    date: "2026-01-20",
    duration: 45,
    pain_before: 4,
    pain_after: 3,
    movements: [],
    notes: "",
  }
  let report = by_month([first, second])
  assert_eq(report.total_sessions(), 2)
  assert_eq(report.slices().length(), 1)
  assert_eq(report.slices()[0].session_count(), 2)
  assert_true(report.concentration() > 0.9)
}

///|
test "cohort empty input is safe" {
  let report = by_duration([])
  assert_eq(report.total_sessions(), 0)
  assert_eq(report.slices().length(), 0)
  assert_eq(top_slice(report), None)
}
