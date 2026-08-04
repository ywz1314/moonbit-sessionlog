///|
test "validate valid session" {
  let set1 = @core.Set::{ reps: 12, hold_time: 10, resistance: "Red Band", completion: 0.9 }
  let mv1 = @core.Movement::{ name: "Leg Raise", sets: [set1], pain: 2, rpe: 5 }
  let session = @core.Session::{
    id: "s-valid",
    date: "2026-08-04",
    duration: 45,
    pain_before: 4,
    pain_after: 3,
    movements: [mv1],
    notes: "Normal session"
  }
  
  let errors = validate_session(session)
  assert_eq(errors.length(), 0)
}

///|
test "validate invalid session" {
  let set_invalid = @core.Set::{ reps: -5, hold_time: -2, resistance: "Red Band", completion: 1.5 }
  let mv_invalid = @core.Movement::{ name: "Leg Raise", sets: [set_invalid], pain: 12, rpe: 0 }
  let session = @core.Session::{
    id: "s-invalid",
    date: "2026/08/04", // Invalid date format
    duration: -10, // Invalid duration
    pain_before: 11, // Invalid pain
    pain_after: -1, // Invalid pain
    movements: [mv_invalid],
    notes: "Invalid session"
  }
  
  let errors = validate_session(session)
  assert_eq(errors.length(), 9)
}
