///|
test "alert policy detects pain effort and completion risks" {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 0.5,
  }
  let session = @core.Session::{
    id: "alert",
    date: "2026-08-19",
    duration: 20,
    pain_before: 5,
    pain_after: 7,
    movements: [@core.Movement::{ name: "squat", sets: [set], pain: 9, rpe: 9 }],
    notes: "",
  }
  let alerts = @alerts.evaluate(session)
  assert_true(alerts.length() >= 4)
  assert_true(@alerts.has_critical(alerts))
  assert_true(@alerts.text(alerts).contains("pain_threshold"))
  assert_true(
    @alerts.filter_type(alerts, @alerts.AlertType::CompletionDrop).length() == 1,
  )
}
