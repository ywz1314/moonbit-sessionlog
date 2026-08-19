///|
pub(all) struct Set {
  reps : Int
  hold_time : Int // in seconds
  resistance : String
  completion : Double // completion rate (0.0 to 1.0)
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct Movement {
  name : String
  sets : Array[Set]
  pain : Int // VAS pain scale (0 to 10)
  rpe : Int // RPE scale (1 to 10)
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct Session {
  id : String
  date : String
  duration : Int // in minutes
  pain_before : Int // VAS pain scale (0 to 10)
  pain_after : Int // VAS pain scale (0 to 10)
  movements : Array[Movement]
  notes : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Session::total_reps(self : Session) -> Int {
  let mut total = 0
  for m in self.movements {
    for s in m.sets {
      total = total + s.reps
    }
  }
  total
}

///|
pub fn Session::average_pain_during(self : Session) -> Double {
  if self.movements.length() == 0 {
    return 0.0
  }
  let mut sum = 0
  for m in self.movements {
    sum = sum + m.pain
  }
  sum.to_double() / self.movements.length().to_double()
}

///|
/// Return the pain change from the beginning to the end of a session.
/// A negative value means that the reported pain improved.
pub fn Session::pain_delta(self : Session) -> Int {
  self.pain_after - self.pain_before
}

///|
/// Return the total number of recorded sets in the session.
pub fn Session::total_sets(self : Session) -> Int {
  self.movements.fold(init=0, (total, movement) => {
    total + movement.sets.length()
  })
}

///|
/// Return the sum of hold time across all recorded sets.
pub fn Session::total_hold_time(self : Session) -> Int {
  self.movements.fold(init=0, (total, movement) => {
    total + movement.total_hold_time()
  })
}

///|
/// Return the average set completion across all sets.
pub fn Session::average_completion(self : Session) -> Double {
  let total_sets = self.total_sets()
  if total_sets == 0 {
    0.0
  } else {
    let total = self.movements.fold(init=0.0, (sum, movement) => {
      sum + movement.total_completion()
    })
    total / total_sets.to_double()
  }
}

///|
/// Return the number of movements whose pain is at or below a threshold.
pub fn Session::movements_at_or_below_pain(
  self : Session,
  threshold : Int,
) -> Int {
  self.movements.count_if(movement => movement.pain <= threshold)
}

///|
/// Find a movement by its exact display name.
pub fn Session::movement(self : Session, name : String) -> Movement? {
  let mut result : Movement? = None
  for movement in self.movements {
    if movement.name == name {
      result = Some(movement)
    }
  }
  result
}

///|
/// Return a stable list of movement names in their recorded order.
pub fn Session::movement_names(self : Session) -> Array[String] {
  self.movements.map(movement => movement.name)
}

///|
/// A compact, derived view used by dashboards and report writers.
pub(all) struct SessionMetrics {
  session_id : String
  movement_count : Int
  set_count : Int
  total_reps : Int
  total_hold_time : Int
  average_completion : Double
  average_pain : Double
  pain_delta : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Session::metrics(self : Session) -> SessionMetrics {
  SessionMetrics::{
    session_id: self.id,
    movement_count: self.movements.length(),
    set_count: self.total_sets(),
    total_reps: self.total_reps(),
    total_hold_time: self.total_hold_time(),
    average_completion: self.average_completion(),
    average_pain: self.average_pain_during(),
    pain_delta: self.pain_delta(),
  }
}

///|
pub fn SessionMetrics::session_id(self : SessionMetrics) -> String {
  self.session_id
}

///|
pub fn SessionMetrics::movement_count(self : SessionMetrics) -> Int {
  self.movement_count
}

///|
pub fn SessionMetrics::set_count(self : SessionMetrics) -> Int {
  self.set_count
}

///|
pub fn SessionMetrics::total_reps(self : SessionMetrics) -> Int {
  self.total_reps
}

///|
pub fn SessionMetrics::total_hold_time(self : SessionMetrics) -> Int {
  self.total_hold_time
}

///|
pub fn SessionMetrics::average_completion(self : SessionMetrics) -> Double {
  self.average_completion
}

///|
pub fn SessionMetrics::average_pain(self : SessionMetrics) -> Double {
  self.average_pain
}

///|
pub fn SessionMetrics::pain_delta(self : SessionMetrics) -> Int {
  self.pain_delta
}
