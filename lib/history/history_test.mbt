///|
test "history log records an auditable sequence" {
  let set = @core.Set::{
    reps: 5,
    hold_time: 1,
    resistance: "body",
    completion: 1.0,
  }
  let session = @core.Session::{
    id: "s",
    date: "2026-08-19",
    duration: 10,
    pain_before: 1,
    pain_after: 1,
    movements: [@core.Movement::{ name: "walk", sets: [set], pain: 1, rpe: 2 }],
    notes: "",
  }
  let log = @history.new_history()
  assert_eq(log.record_added(session).revision(), 1)
  assert_eq(log.record_updated(session).revision(), 2)
  assert_eq(log.record_removed("s", session.date).revision(), 3)
  assert_eq(log.count(), 3)
  assert_eq(log.for_session("s").length(), 3)
  assert_eq(log.since(2).length(), 2)
  assert_eq(log.event_counts().0, 1)
  assert_true(log.to_text().contains("session_removed"))
}
