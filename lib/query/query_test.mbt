///|
test "session queries compose filters" {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 1.0,
  }
  let low = @core.Session::{
    id: "alpha",
    date: "2026-08-01",
    duration: 30,
    pain_before: 1,
    pain_after: 1,
    movements: [@core.Movement::{ name: "squat", sets: [set], pain: 1, rpe: 3 }],
    notes: "",
  }
  let high = @core.Session::{
    id: "beta",
    date: "2026-08-10",
    duration: 10,
    pain_before: 8,
    pain_after: 8,
    movements: [@core.Movement::{ name: "press", sets: [set], pain: 8, rpe: 9 }],
    notes: "",
  }
  let query = @query.by_movement(
    @query.by_date_range(@query.empty_query(), "2026-08-01", "2026-08-05"),
    "squat",
  )
  assert_eq(@query.filter([low, high], query).map(session => session.id), [
    "alpha",
  ])
  assert_eq(@query.total_reps([low, high], query), 10)
  assert_eq(@query.describe(query), "movement='squat', date range")
  assert_eq(@query.sort_by_pain([high, low])[0].id, "alpha")
}
