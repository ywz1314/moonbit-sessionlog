///|
pub(all) struct MovementConsistency {
  name : String
  observations : Int
  completion_range : Double
  pain_range : Int
  reps_range : Int
  stable : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MovementConsistency::name(self : MovementConsistency) -> String {
  self.name
}

///|
pub fn MovementConsistency::observations(self : MovementConsistency) -> Int {
  self.observations
}

///|
pub fn MovementConsistency::completion_range(
  self : MovementConsistency,
) -> Double {
  self.completion_range
}

///|
pub fn MovementConsistency::pain_range(self : MovementConsistency) -> Int {
  self.pain_range
}

///|
pub fn MovementConsistency::reps_range(self : MovementConsistency) -> Int {
  self.reps_range
}

///|
pub fn MovementConsistency::stable(self : MovementConsistency) -> Bool {
  self.stable
}

///|
pub fn compare_movement(
  name : String,
  observations : Array[@core.Movement],
) -> MovementConsistency {
  let completions = observations.map(item => item.average_completion())
  let pains = observations.map(item => item.pain)
  let reps = observations.map(item => item.total_reps())
  let min_completion = completions.fold(init=1.0, (value, item) => {
    Double::min(value, item)
  })
  let max_completion = completions.fold(init=0.0, (value, item) => {
    Double::max(value, item)
  })
  let min_pain = pains.fold(init=10, (value, item) => Int::min(value, item))
  let max_pain = pains.fold(init=0, (value, item) => Int::max(value, item))
  let min_reps = reps.fold(init=2147483647, (value, item) => {
    Int::min(value, item)
  })
  let max_reps = reps.fold(init=0, (value, item) => Int::max(value, item))
  MovementConsistency::{
    name,
    observations: observations.length(),
    completion_range: max_completion - min_completion,
    pain_range: max_pain - min_pain,
    reps_range: if observations.is_empty() {
      0
    } else {
      max_reps - min_reps
    },
    stable: observations.length() >= 2 &&
    max_completion - min_completion <= 0.1 &&
    max_pain - min_pain <= 2,
  }
}

///|
pub fn compare_all(
  sessions : Array[@core.Session],
) -> Array[MovementConsistency] {
  let names = []
  for session in sessions {
    for movement in session.movements {
      if !names.contains(movement.name) {
        names.push(movement.name)
      }
    }
  }
  names.map(name => {
    let observations = []
    for session in sessions {
      for movement in session.movements {
        if movement.name == name {
          observations.push(movement)
        }
      }
    }
    compare_movement(name, observations)
  })
}

///|
pub fn stable_items(
  items : Array[MovementConsistency],
) -> Array[MovementConsistency] {
  items.filter(item => item.stable)
}

///|
pub fn unstable_items(
  items : Array[MovementConsistency],
) -> Array[MovementConsistency] {
  items.filter(item => !item.stable)
}

///|
pub fn consistency_text(items : Array[MovementConsistency]) -> String {
  let output = StringBuilder()
  for item in items {
    output.write_string(
      item.name +
      ": stable=" +
      item.stable.to_string() +
      ", observations=" +
      item.observations.to_string() +
      "\n",
    )
  }
  output.to_string()
}
