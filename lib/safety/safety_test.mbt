///|
test "safety report separates clean and risky sessions" {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 1.0,
  }
  let clean = @core.Session::{
    id: "clean",
    date: "2026-08-19",
    duration: 20,
    pain_before: 2,
    pain_after: 1,
    movements: [@core.Movement::{ name: "move", sets: [set], pain: 1, rpe: 3 }],
    notes: "",
  }
  let risky = @core.Session::{
    id: "risky",
    date: "2026-08-19",
    duration: -1,
    pain_before: 5,
    pain_after: 8,
    movements: [@core.Movement::{ name: "move", sets: [set], pain: 8, rpe: 10 }],
    notes: "",
  }
  assert_eq(@safety.evaluate(clean).level(), @safety.SafetyLevel::Green)
  assert_true(@safety.evaluate(risky).level() != @safety.SafetyLevel::Green)
  assert_true(@safety.text(@safety.evaluate(risky)).contains("pain"))
}
