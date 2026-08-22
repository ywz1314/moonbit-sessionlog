///|
/// Comparison helpers quantify change between two reporting cohorts without
/// assuming that their sessions are paired one-to-one.
pub(all) struct AggregateComparison {
  baseline_count : Int
  current_count : Int
  baseline_reps : Int
  current_reps : Int
  baseline_work : Int
  current_work : Int
  baseline_pain : Double
  current_pain : Double
  baseline_completion : Double
  current_completion : Double
  reps_delta : Int
  work_delta : Int
  pain_delta : Double
  completion_delta : Double
  effect_direction : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn AggregateComparison::baseline_count(self : AggregateComparison) -> Int {
  self.baseline_count
}

///|
pub fn AggregateComparison::current_count(self : AggregateComparison) -> Int {
  self.current_count
}

///|
pub fn AggregateComparison::baseline_reps(self : AggregateComparison) -> Int {
  self.baseline_reps
}

///|
pub fn AggregateComparison::current_reps(self : AggregateComparison) -> Int {
  self.current_reps
}

///|
pub fn AggregateComparison::baseline_work(self : AggregateComparison) -> Int {
  self.baseline_work
}

///|
pub fn AggregateComparison::current_work(self : AggregateComparison) -> Int {
  self.current_work
}

///|
pub fn AggregateComparison::baseline_pain(self : AggregateComparison) -> Double {
  self.baseline_pain
}

///|
pub fn AggregateComparison::current_pain(self : AggregateComparison) -> Double {
  self.current_pain
}

///|
pub fn AggregateComparison::baseline_completion(
  self : AggregateComparison,
) -> Double {
  self.baseline_completion
}

///|
pub fn AggregateComparison::current_completion(
  self : AggregateComparison,
) -> Double {
  self.current_completion
}

///|
pub fn AggregateComparison::reps_delta(self : AggregateComparison) -> Int {
  self.reps_delta
}

///|
pub fn AggregateComparison::work_delta(self : AggregateComparison) -> Int {
  self.work_delta
}

///|
pub fn AggregateComparison::pain_delta(self : AggregateComparison) -> Double {
  self.pain_delta
}

///|
pub fn AggregateComparison::completion_delta(
  self : AggregateComparison,
) -> Double {
  self.completion_delta
}

///|
pub fn AggregateComparison::effect_direction(
  self : AggregateComparison,
) -> String {
  self.effect_direction
}

///|
fn cohort_values(
  sessions : Array[@core.Session],
) -> (Int, Int, Int, Double, Double) {
  let count = sessions.length()
  let reps = sessions.fold(init=0, (total, session) => {
    total + session.total_reps()
  })
  let work = sessions.fold(init=0, (total, session) => {
    total +
    session.movements.fold(init=0, (sum, movement) => {
      sum + movement.work_units()
    })
  })
  let pain = sessions.fold(init=0.0, (total, session) => {
    total + session.average_pain_during()
  })
  let completion = sessions.fold(init=0.0, (total, session) => {
    total + session.average_completion()
  })
  if count == 0 {
    (0, reps, work, 0.0, 0.0)
  } else {
    (
      count,
      reps,
      work,
      pain / count.to_double(),
      completion / count.to_double(),
    )
  }
}

///|
pub fn compare_cohorts(
  baseline : Array[@core.Session],
  current : Array[@core.Session],
) -> AggregateComparison {
  let left = cohort_values(baseline)
  let right = cohort_values(current)
  let pain_delta = right.3 - left.3
  let completion_delta = right.4 - left.4
  let effect_direction = if completion_delta >= 0.05 && pain_delta <= 0.0 {
    "improving"
  } else if completion_delta <= -0.05 || pain_delta >= 1.0 {
    "worsening"
  } else {
    "stable"
  }
  AggregateComparison::{
    baseline_count: left.0,
    current_count: right.0,
    baseline_reps: left.1,
    current_reps: right.1,
    baseline_work: left.2,
    current_work: right.2,
    baseline_pain: left.3,
    current_pain: right.3,
    baseline_completion: left.4,
    current_completion: right.4,
    reps_delta: right.1 - left.1,
    work_delta: right.2 - left.2,
    pain_delta,
    completion_delta,
    effect_direction,
  }
}

///|
pub fn relative_change(before : Double, after : Double) -> Double {
  if before.abs() < 0.000001 {
    after
  } else {
    (after - before) / before.abs()
  }
}

///|
pub fn comparison_effect_size(value : AggregateComparison) -> Double {
  value.completion_delta - value.pain_delta / 10.0
}

///|
pub fn comparison_reliable(
  value : AggregateComparison,
  minimum_count : Int,
) -> Bool {
  value.baseline_count >= minimum_count && value.current_count >= minimum_count
}

///|
pub fn comparison_flags(value : AggregateComparison) -> Array[String] {
  let flags = []
  if value.pain_delta >= 1.0 {
    flags.push("pain_increase")
  }
  if value.completion_delta <= -0.05 {
    flags.push("completion_decline")
  }
  if value.work_delta < 0 {
    flags.push("work_decline")
  }
  if value.current_count < value.baseline_count {
    flags.push("fewer_sessions")
  }
  flags
}

///|
pub fn comparison_text(value : AggregateComparison) -> String {
  "direction=" +
  value.effect_direction +
  ", sessions=" +
  value.baseline_count.to_string() +
  "->" +
  value.current_count.to_string() +
  ", pain=" +
  value.pain_delta.to_string() +
  ", completion=" +
  value.completion_delta.to_string() +
  ", effect=" +
  comparison_effect_size(value).to_string()
}

///|
pub fn compare_by_movement(
  baseline : Array[@core.Session],
  current : Array[@core.Session],
) -> Array[(String, AggregateComparison)] {
  let names = []
  for session in baseline {
    for movement in session.movements {
      if !names.contains(movement.name) {
        names.push(movement.name)
      }
    }
  }
  for session in current {
    for movement in session.movements {
      if !names.contains(movement.name) {
        names.push(movement.name)
      }
    }
  }
  let result : Array[(String, AggregateComparison)] = []
  for name in names {
    let left = baseline.filter(session => session.movement(name) is Some(_))
    let right = current.filter(session => session.movement(name) is Some(_))
    result.push((name, compare_cohorts(left, right)))
  }
  result.sort_by((left, right) => {
    comparison_effect_size(right.1).compare(comparison_effect_size(left.1))
  })
  result
}

///|
pub fn comparison_report_text(
  values : Array[(String, AggregateComparison)],
) -> String {
  values.map(value => value.0 + " " + comparison_text(value.1)).join("\n")
}
