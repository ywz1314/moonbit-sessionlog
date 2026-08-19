///|
pub(all) struct MovementAggregate {
  name : String
  session_count : Int
  set_count : Int
  total_reps : Int
  effective_reps : Int
  total_work_units : Int
  average_completion : Double
  average_pain : Double
  average_rpe : Double
  first_date : String
  last_date : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MovementAggregate::name(self : MovementAggregate) -> String {
  self.name
}

///|
pub fn MovementAggregate::session_count(self : MovementAggregate) -> Int {
  self.session_count
}

///|
pub fn MovementAggregate::set_count(self : MovementAggregate) -> Int {
  self.set_count
}

///|
pub fn MovementAggregate::total_reps(self : MovementAggregate) -> Int {
  self.total_reps
}

///|
pub fn MovementAggregate::effective_reps(self : MovementAggregate) -> Int {
  self.effective_reps
}

///|
pub fn MovementAggregate::total_work_units(self : MovementAggregate) -> Int {
  self.total_work_units
}

///|
pub fn MovementAggregate::average_completion(
  self : MovementAggregate,
) -> Double {
  self.average_completion
}

///|
pub fn MovementAggregate::average_pain(self : MovementAggregate) -> Double {
  self.average_pain
}

///|
pub fn MovementAggregate::average_rpe(self : MovementAggregate) -> Double {
  self.average_rpe
}

///|
pub fn MovementAggregate::first_date(self : MovementAggregate) -> String {
  self.first_date
}

///|
pub fn MovementAggregate::last_date(self : MovementAggregate) -> String {
  self.last_date
}

///|
fn make_aggregate(
  name : String,
  movements : Array[@core.Movement],
  dates : Array[String],
) -> MovementAggregate {
  let sets = movements.fold(init=0, (total, movement) => {
    total + movement.sets.length()
  })
  let reps = movements.fold(init=0, (total, movement) => {
    total + movement.total_reps()
  })
  let effective = movements.fold(init=0, (total, movement) => {
    total + movement.effective_reps()
  })
  let work = movements.fold(init=0, (total, movement) => {
    total + movement.work_units()
  })
  let completion = movements.fold(init=0.0, (total, movement) => {
    total + movement.average_completion()
  })
  let pain = movements.fold(init=0, (total, movement) => total + movement.pain)
  let rpe = movements.fold(init=0, (total, movement) => total + movement.rpe)
  let count = movements.length()
  let ordered_dates = dates.copy()
  ordered_dates.sort()
  MovementAggregate::{
    name,
    session_count: count,
    set_count: sets,
    total_reps: reps,
    effective_reps: effective,
    total_work_units: work,
    average_completion: if count == 0 {
      0.0
    } else {
      completion / count.to_double()
    },
    average_pain: if count == 0 {
      0.0
    } else {
      pain.to_double() / count.to_double()
    },
    average_rpe: if count == 0 {
      0.0
    } else {
      rpe.to_double() / count.to_double()
    },
    first_date: match ordered_dates.get(0) {
      Some(date) => date
      None => ""
    },
    last_date: match ordered_dates.last() {
      Some(date) => date
      None => ""
    },
  }
}

///|
pub fn aggregate_movement(
  sessions : Array[@core.Session],
  name : String,
) -> MovementAggregate {
  let movements = []
  let dates = []
  for session in sessions {
    for movement in session.movements {
      if movement.name == name {
        movements.push(movement)
        dates.push(session.date)
      }
    }
  }
  make_aggregate(name, movements, dates)
}

///|
pub fn aggregate_all(
  sessions : Array[@core.Session],
) -> Array[MovementAggregate] {
  let names = []
  for session in sessions {
    for movement in session.movements {
      if !names.contains(movement.name) {
        names.push(movement.name)
      }
    }
  }
  names.map(name => aggregate_movement(sessions, name))
}

///|
pub fn strongest_movement(
  aggregates : Array[MovementAggregate],
) -> MovementAggregate? {
  let mut best : MovementAggregate? = None
  let mut score = -1
  for item in aggregates {
    if item.effective_reps > score {
      best = Some(item)
      score = item.effective_reps
    }
  }
  best
}

///|
pub fn most_consistent_movement(
  aggregates : Array[MovementAggregate],
) -> MovementAggregate? {
  let mut best : MovementAggregate? = None
  let mut score = -1.0
  for item in aggregates {
    if item.average_completion > score {
      best = Some(item)
      score = item.average_completion
    }
  }
  best
}

///|
pub fn total_effective_reps(aggregates : Array[MovementAggregate]) -> Int {
  aggregates.fold(init=0, (total, item) => total + item.effective_reps)
}

///|
pub fn total_work_units(aggregates : Array[MovementAggregate]) -> Int {
  aggregates.fold(init=0, (total, item) => total + item.total_work_units)
}

///|
pub fn average_completion(aggregates : Array[MovementAggregate]) -> Double {
  if aggregates.is_empty() {
    0.0
  } else {
    aggregates.fold(init=0.0, (total, item) => total + item.average_completion) /
    aggregates.length().to_double()
  }
}

///|
pub fn sort_by_work(
  aggregates : Array[MovementAggregate],
) -> Array[MovementAggregate] {
  let output = aggregates.copy()
  output.sort_by((left, right) => right.total_work_units - left.total_work_units)
  output
}

///|
pub fn sort_by_completion(
  aggregates : Array[MovementAggregate],
) -> Array[MovementAggregate] {
  let output = aggregates.copy()
  output.sort_by((left, right) => {
    right.average_completion.compare(left.average_completion)
  })
  output
}

///|
pub fn aggregate_text(aggregates : Array[MovementAggregate]) -> String {
  let output = StringBuilder()
  for item in sort_by_work(aggregates) {
    output.write_string(
      item.name +
      ": sessions=" +
      item.session_count.to_string() +
      ", reps=" +
      item.total_reps.to_string() +
      ", work=" +
      item.total_work_units.to_string() +
      "\n",
    )
  }
  output.to_string()
}
