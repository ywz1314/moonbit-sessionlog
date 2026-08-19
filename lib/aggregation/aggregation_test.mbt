///|
test "movement aggregation is deterministic across sessions" {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 0.8,
  }
  let movement = @core.Movement::{ name: "squat", sets: [set], pain: 2, rpe: 4 }
  let first = @core.Session::{
    id: "a",
    date: "2026-08-01",
    duration: 20,
    pain_before: 2,
    pain_after: 1,
    movements: [movement],
    notes: "",
  }
  let second = @core.Session::{
    id: "b",
    date: "2026-08-02",
    duration: 20,
    pain_before: 2,
    pain_after: 1,
    movements: [movement],
    notes: "",
  }
  let items = @aggregation.aggregate_all([first, second])
  assert_eq(items.length(), 1)
  assert_eq(items[0].session_count(), 2)
  assert_eq(items[0].total_reps(), 20)
  assert_eq(items[0].effective_reps(), 16)
  assert_eq(items[0].first_date(), "2026-08-01")
  assert_eq(@aggregation.total_work_units(items), 120)
  assert_true(@aggregation.aggregate_text(items).contains("squat"))
}
