///|
test "progression advice: ready to progress" {
  let set1 = @core.Set::{ reps: 10, hold_time: 5, resistance: "Yellow Band", completion: 1.0 }
  let mv = @core.Movement::{ name: "Squat", sets: [set1], pain: 2, rpe: 4 }
  
  let advice = @progression.analyze_progression(mv)
  assert_eq(advice.state, @progression.ProgressionState::Progression)
  assert_eq(advice.suggested_reps, 12)
  assert_eq(advice.suggested_sets, 1)
}

///|
test "progression advice: maintenance needed" {
  let set1 = @core.Set::{ reps: 10, hold_time: 5, resistance: "Yellow Band", completion: 1.0 }
  let mv = @core.Movement::{ name: "Squat", sets: [set1], pain: 5, rpe: 5 }
  
  let advice = @progression.analyze_progression(mv)
  assert_eq(advice.state, @progression.ProgressionState::Maintenance)
  assert_eq(advice.suggested_reps, 10)
  assert_eq(advice.suggested_sets, 1)
}

///|
test "progression advice: regression needed due to pain" {
  let set1 = @core.Set::{ reps: 10, hold_time: 5, resistance: "Yellow Band", completion: 1.0 }
  let mv = @core.Movement::{ name: "Squat", sets: [set1], pain: 8, rpe: 4 }
  
  let advice = @progression.analyze_progression(mv)
  assert_eq(advice.state, @progression.ProgressionState::Regression)
  assert_eq(advice.suggested_reps, 8)
  assert_eq(advice.suggested_sets, 1)
}

///|
test "progression advice: regression needed due to low completion" {
  let set1 = @core.Set::{ reps: 10, hold_time: 5, resistance: "Yellow Band", completion: 0.5 }
  let mv = @core.Movement::{ name: "Squat", sets: [set1], pain: 1, rpe: 3 }
  
  let advice = @progression.analyze_progression(mv)
  assert_eq(advice.state, @progression.ProgressionState::Regression)
  assert_eq(advice.suggested_reps, 8)
  assert_eq(advice.suggested_sets, 1)
}
