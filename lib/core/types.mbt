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
