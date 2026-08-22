///|
/// Population-level outcome summaries that preserve enough detail for audit and reporting.
pub(all) struct PopulationSummary {
  session_count : Int
  participant_count : Int
  total_reps : Int
  total_work_units : Int
  mean_pain : Double
  median_pain : Double
  mean_completion : Double
  median_completion : Double
  pain_improved_percent : Double
  completion_target_percent : Double
  mean_duration : Double
  pain_trend : Double
  completion_trend : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn PopulationSummary::session_count(self : PopulationSummary) -> Int {
  self.session_count
}

///|
pub fn PopulationSummary::participant_count(self : PopulationSummary) -> Int {
  self.participant_count
}

///|
pub fn PopulationSummary::total_reps(self : PopulationSummary) -> Int {
  self.total_reps
}

///|
pub fn PopulationSummary::total_work_units(self : PopulationSummary) -> Int {
  self.total_work_units
}

///|
pub fn PopulationSummary::mean_pain(self : PopulationSummary) -> Double {
  self.mean_pain
}

///|
pub fn PopulationSummary::median_pain(self : PopulationSummary) -> Double {
  self.median_pain
}

///|
pub fn PopulationSummary::mean_completion(self : PopulationSummary) -> Double {
  self.mean_completion
}

///|
pub fn PopulationSummary::median_completion(self : PopulationSummary) -> Double {
  self.median_completion
}

///|
pub fn PopulationSummary::pain_improved_percent(
  self : PopulationSummary,
) -> Double {
  self.pain_improved_percent
}

///|
pub fn PopulationSummary::completion_target_percent(
  self : PopulationSummary,
) -> Double {
  self.completion_target_percent
}

///|
pub fn PopulationSummary::mean_duration(self : PopulationSummary) -> Double {
  self.mean_duration
}

///|
pub fn PopulationSummary::pain_trend(self : PopulationSummary) -> Double {
  self.pain_trend
}

///|
pub fn PopulationSummary::completion_trend(self : PopulationSummary) -> Double {
  self.completion_trend
}

///|
pub fn participant_count(sessions : Array[@core.Session]) -> Int {
  let ids = []
  for session in sessions {
    let id = session.id
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  ids.length()
}

///|
pub fn summarize_population(
  sessions : Array[@core.Session],
  completion_target? : Double = 0.8,
) -> PopulationSummary {
  let pains = sessions.map(session => session.average_pain_during())
  let completions = sessions.map(session => session.average_completion())
  let durations = sessions.map(session => session.duration.to_double())
  PopulationSummary::{
    session_count: sessions.length(),
    participant_count: participant_count(sessions),
    total_reps: sessions.fold(init=0, (total, session) => {
      total + session.total_reps()
    }),
    total_work_units: sessions.fold(init=0, (total, session) => {
      total + session.total_work_units()
    }),
    mean_pain: @statistics.mean(pains),
    median_pain: @statistics.median(pains),
    mean_completion: @statistics.mean(completions),
    median_completion: @statistics.median(completions),
    pain_improved_percent: if sessions.is_empty() {
      0.0
    } else {
      sessions.count_if(session => session.pain_delta() < 0).to_double() *
      100.0 /
      sessions.length().to_double()
    },
    completion_target_percent: if sessions.is_empty() {
      0.0
    } else {
      sessions
      .count_if(session => session.average_completion() >= completion_target)
      .to_double() *
      100.0 /
      sessions.length().to_double()
    },
    mean_duration: @statistics.mean(durations),
    pain_trend: @statistics.slope(pains),
    completion_trend: @statistics.slope(completions),
  }
}

///|
pub(all) struct MovementTrajectory {
  movement_name : String
  observations : Int
  first_completion : Double
  last_completion : Double
  completion_change : Double
  first_pain : Double
  last_pain : Double
  pain_change : Double
  work_units : Int
  completion_trend : Double
  pain_trend : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MovementTrajectory::movement_name(self : MovementTrajectory) -> String {
  self.movement_name
}

///|
pub fn MovementTrajectory::observations(self : MovementTrajectory) -> Int {
  self.observations
}

///|
pub fn MovementTrajectory::first_completion(
  self : MovementTrajectory,
) -> Double {
  self.first_completion
}

///|
pub fn MovementTrajectory::last_completion(self : MovementTrajectory) -> Double {
  self.last_completion
}

///|
pub fn MovementTrajectory::completion_change(
  self : MovementTrajectory,
) -> Double {
  self.completion_change
}

///|
pub fn MovementTrajectory::first_pain(self : MovementTrajectory) -> Double {
  self.first_pain
}

///|
pub fn MovementTrajectory::last_pain(self : MovementTrajectory) -> Double {
  self.last_pain
}

///|
pub fn MovementTrajectory::pain_change(self : MovementTrajectory) -> Double {
  self.pain_change
}

///|
pub fn MovementTrajectory::work_units(self : MovementTrajectory) -> Int {
  self.work_units
}

///|
pub fn MovementTrajectory::completion_trend(
  self : MovementTrajectory,
) -> Double {
  self.completion_trend
}

///|
pub fn MovementTrajectory::pain_trend(self : MovementTrajectory) -> Double {
  self.pain_trend
}

///|
fn trajectory_for(
  name : String,
  sessions : Array[@core.Session],
) -> MovementTrajectory {
  let ordered = sessions.copy()
  ordered.sort_by((left, right) => left.date.compare(right.date))
  let movements = []
  for session in ordered {
    match session.movement(name) {
      Some(movement) =>
        movements.push(
          (
            movement.average_completion(),
            movement.pain.to_double(),
            movement.work_units(),
          ),
        )
      None => ()
    }
  }
  let completions = movements.map(item => item.0)
  let pains = movements.map(item => item.1)
  MovementTrajectory::{
    movement_name: name,
    observations: movements.length(),
    first_completion: completions.get(0).unwrap_or(0.0),
    last_completion: completions.get(completions.length() - 1).unwrap_or(0.0),
    completion_change: completions.get(completions.length() - 1).unwrap_or(0.0) -
    completions.get(0).unwrap_or(0.0),
    first_pain: pains.get(0).unwrap_or(0.0),
    last_pain: pains.get(pains.length() - 1).unwrap_or(0.0),
    pain_change: pains.get(pains.length() - 1).unwrap_or(0.0) -
    pains.get(0).unwrap_or(0.0),
    work_units: movements.fold(init=0, (total, item) => total + item.2),
    completion_trend: @statistics.slope(completions),
    pain_trend: @statistics.slope(pains),
  }
}

///|
pub fn movement_trajectories(
  sessions : Array[@core.Session],
) -> Array[MovementTrajectory] {
  let names = []
  for session in sessions {
    for name in session.movement_names() {
      if !names.contains(name) {
        names.push(name)
      }
    }
  }
  names.map(name => trajectory_for(name, sessions))
}

///|
pub fn improving_trajectories(
  items : Array[MovementTrajectory],
) -> Array[MovementTrajectory] {
  items.filter(item => {
    item.completion_change() > 0.0 && item.pain_change() <= 0.0
  })
}

///|
pub fn stalled_trajectories(
  items : Array[MovementTrajectory],
  tolerance? : Double = 0.02,
) -> Array[MovementTrajectory] {
  items.filter(item => {
    item.completion_change().abs() <= tolerance &&
    item.pain_change().abs() <= tolerance
  })
}

///|
pub fn worsening_trajectories(
  items : Array[MovementTrajectory],
) -> Array[MovementTrajectory] {
  items.filter(item => {
    item.completion_change() < 0.0 || item.pain_change() > 0.0
  })
}

///|
pub fn period_compare(
  baseline : Array[@core.Session],
  current : Array[@core.Session],
) -> (Double, Double, Double) {
  let before = summarize_population(baseline)
  let after = summarize_population(current)
  (
    after.mean_pain - before.mean_pain,
    after.mean_completion - before.mean_completion,
    after.total_work_units.to_double() - before.total_work_units.to_double(),
  )
}

///|
pub fn effect_size(
  baseline : Array[@core.Session],
  current : Array[@core.Session],
) -> Double {
  let before = baseline.map(session => session.average_pain_during())
  let after = current.map(session => session.average_pain_during())
  let pooled = ((@statistics.variance(before) + @statistics.variance(after)) /
  2.0).sqrt()
  if pooled == 0.0 {
    0.0
  } else {
    (@statistics.mean(after) - @statistics.mean(before)) / pooled
  }
}

///|
pub fn bootstrap_like_delta(
  values : Array[Double],
  block_size : Int,
) -> Array[Double] {
  if values.is_empty() || block_size <= 0 {
    []
  } else {
    let result = []
    let mut index = 0
    while index < values.length() {
      let end = Int::min(values.length(), index + block_size)
      result.push(@statistics.mean(values[index:end].to_owned()))
      index += block_size
    }
    result
  }
}

///|
pub fn population_text(summary : PopulationSummary) -> String {
  "sessions=" +
  summary.session_count.to_string() +
  ", participants=" +
  summary.participant_count.to_string() +
  ", pain=" +
  summary.mean_pain.to_string() +
  ", completion=" +
  summary.mean_completion.to_string() +
  ", improved=" +
  summary.pain_improved_percent.to_string() +
  "%"
}

///|
pub fn trajectory_text(items : Array[MovementTrajectory]) -> String {
  let output = StringBuilder()
  for item in items {
    output.write_string(
      item.movement_name +
      ": n=" +
      item.observations.to_string() +
      ", completion_delta=" +
      item.completion_change.to_string() +
      ", pain_delta=" +
      item.pain_change.to_string() +
      "\n",
    )
  }
  output.to_string()
}
