///|
test "core metrics cover empty and populated records" {
  let empty = Movement::{ name: "rest", sets: [], pain: 0, rpe: 1 }
  assert_eq(empty.total_reps(), 0)
  assert_eq(empty.effective_reps(), 0)
  assert_eq(empty.average_completion(), 0.0)
  assert_eq(empty.rep_range(), (0, 0))
  assert_eq(empty.dominant_resistance(), "")

  let a = Set::{ reps: 10, hold_time: 5, resistance: "band", completion: 0.8 }
  let b = Set::{ reps: 8, hold_time: 10, resistance: "band", completion: 1.0 }
  let movement = Movement::{ name: "squat", sets: [a, b], pain: 5, rpe: 7 }
  assert_eq(a.effective_reps(), 8)
  assert_eq(a.work_units(), 60)
  assert_eq(a.completion_percent(), 80)
  assert_eq(movement.total_reps(), 18)
  assert_eq(movement.effective_reps(), 16)
  assert_eq(movement.total_hold_time(), 15)
  assert_eq(movement.work_units(), 148)
  assert_eq(movement.completed_set_count(), 1)
  assert_true(movement.has_incomplete_set())
  assert_eq(movement.rep_range(), (8, 10))
  assert_eq(movement.resistances(), ["band"])
  assert_eq(movement.pain_band(), PainBand::Moderate)
  assert_eq(movement.effort_band(), EffortBand::Hard)
}

///|
test "pain and effort bands are stable at boundaries" {
  assert_eq(pain_band(-1), PainBand::None)
  assert_eq(pain_band(0), PainBand::None)
  assert_eq(pain_band(3), PainBand::Mild)
  assert_eq(pain_band(4), PainBand::Moderate)
  assert_eq(pain_band(6), PainBand::Moderate)
  assert_eq(pain_band(7), PainBand::Severe)
  assert_eq(effort_band(2), EffortBand::VeryEasy)
  assert_eq(effort_band(3), EffortBand::Easy)
  assert_eq(effort_band(5), EffortBand::Moderate)
  assert_eq(effort_band(7), EffortBand::Hard)
  assert_eq(effort_band(9), EffortBand::VeryHard)
}
