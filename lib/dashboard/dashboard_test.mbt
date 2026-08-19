///|
test "dashboard combines analytics quality alerts and forecast" {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 1.0,
  }
  let movement = @core.Movement::{ name: "move", sets: [set], pain: 1, rpe: 3 }
  let session = @core.Session::{
    id: "s",
    date: "2026-08-19",
    duration: 20,
    pain_before: 2,
    pain_after: 1,
    movements: [movement],
    notes: "",
  }
  let dashboard = @dashboard.build([session])
  assert_eq(dashboard.session_count(), 1)
  assert_eq(dashboard.total_reps(), 10)
  assert_eq(@dashboard.status(dashboard), "stable")
  assert_true(@dashboard.to_text(dashboard).contains("headline:"))
  assert_true(@dashboard.is_improving(dashboard))
  assert_eq(@dashboard.empty().session_count(), 0)
}
