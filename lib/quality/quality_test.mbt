///|
test "quality scoring distinguishes complete and incomplete records" {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 1.0,
  }
  let movement = @core.Movement::{ name: "squat", sets: [set], pain: 1, rpe: 3 }
  let good = @core.Session::{
    id: "good",
    date: "2026-08-19",
    duration: 30,
    pain_before: 2,
    pain_after: 1,
    movements: [movement],
    notes: "recorded",
  }
  let bad = @core.Session::{
    id: "",
    date: "bad",
    duration: 0,
    pain_before: 20,
    pain_after: -1,
    movements: [],
    notes: "",
  }
  assert_true(@quality.score(good).score() > @quality.score(bad).score())
  assert_true(@quality.quality_failures([bad]).length() == 1)
  assert_eq(@quality.valid_ratio([good, bad]), 50.0)
  assert_eq(@quality.empty_resistance_count(good), 0)
  assert_true(@quality.quality_text(@quality.score(bad)).contains("validity"))
}
