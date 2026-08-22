///|
test "risk prioritizes high pain and worsening symptoms" {
  let movement = @core.Movement::{
    name: "step",
    pain: 9,
    rpe: 10,
    sets: [
      @core.Set::{ reps: 2, hold_time: 0, resistance: "band", completion: 0.2 },
    ],
  }
  let session = @core.Session::{
    id: "risk",
    date: "2026-02-20",
    duration: 20,
    pain_before: 2,
    pain_after: 9,
    movements: [movement],
    notes: "pain spike",
  }
  let score = evaluate(session)
  assert_true(score.score() > 0)
  assert_true(score.has_factor(RiskFactorKind::HighPain))
  assert_true(score.has_factor(RiskFactorKind::WorseningPain))
  assert_true(score.level().rank() >= RiskLevel::High.rank())
}

///|
test "risk options validate impossible thresholds" {
  let options = RiskOptions::{
    pain_threshold: 11,
    worsening_delta: -1,
    completion_threshold: 2.0,
    effort_threshold: 0,
    workload_spike_ratio: 0.5,
    invalid_penalty: 1,
    missing_penalty: 1,
    unstable_penalty: 1,
  }
  assert_true(validate_options(options).length() >= 4)
}
