///|
test "session series preserves deltas and extrema" {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 0.8,
  }
  let movement = @core.Movement::{ name: "move", sets: [set], pain: 2, rpe: 4 }
  let a = @core.Session::{
    id: "a",
    date: "2026-08-02",
    duration: 20,
    pain_before: 2,
    pain_after: 1,
    movements: [movement],
    notes: "",
  }
  let b = @core.Session::{
    id: "b",
    date: "2026-08-01",
    duration: 20,
    pain_before: 4,
    pain_after: 3,
    movements: [movement],
    notes: "",
  }
  let series = @series.from_sessions([a, b])
  assert_eq(@series.count(series), 2)
  assert_eq(@series.first(@series.sorted(series)).unwrap().date(), "2026-08-01")
  assert_eq(@series.total_reps(series), 20)
  assert_eq(@series.work_delta(series), 0)
  assert_eq(@series.above_pain(series, 1.0).length(), 2)
  assert_true(@series.text(series).contains("2026-08-01"))
}
