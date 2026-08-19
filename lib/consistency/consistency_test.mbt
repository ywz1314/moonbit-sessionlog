///|
test "consistency compares repeated movement observations" {
  let a = @core.Movement::{
    name: "move",
    sets: [
      @core.Set::{ reps: 10, hold_time: 1, resistance: "body", completion: 0.9 },
    ],
    pain: 2,
    rpe: 4,
  }
  let b = @core.Movement::{
    name: "move",
    sets: [
      @core.Set::{
        reps: 10,
        hold_time: 1,
        resistance: "body",
        completion: 0.95,
      },
    ],
    pain: 3,
    rpe: 4,
  }
  let item = @consistency.compare_movement("move", [a, b])
  assert_true(item.stable())
  assert_eq(item.observations(), 2)
  assert_eq(
    @consistency.compare_all([
      @core.Session::{
        id: "a",
        date: "1",
        duration: 1,
        pain_before: 1,
        pain_after: 1,
        movements: [a],
        notes: "",
      },
      @core.Session::{
        id: "b",
        date: "2",
        duration: 1,
        pain_before: 1,
        pain_after: 1,
        movements: [b],
        notes: "",
      },
    ]).length(),
    1,
  )
}
