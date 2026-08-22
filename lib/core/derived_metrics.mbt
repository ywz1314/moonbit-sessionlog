///|
/// A movement-level load profile used by downstream analytics packages.
pub(all) struct MovementLoad {
  movement_name : String
  sets : Int
  reps : Int
  effective_reps : Int
  hold_time : Int
  work_units : Int
  completion : Double
  pain : Int
  rpe : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MovementLoad::movement_name(self : MovementLoad) -> String {
  self.movement_name
}

///|
pub fn MovementLoad::sets(self : MovementLoad) -> Int {
  self.sets
}

///|
pub fn MovementLoad::reps(self : MovementLoad) -> Int {
  self.reps
}

///|
pub fn MovementLoad::effective_reps(self : MovementLoad) -> Int {
  self.effective_reps
}

///|
pub fn MovementLoad::hold_time(self : MovementLoad) -> Int {
  self.hold_time
}

///|
pub fn MovementLoad::work_units(self : MovementLoad) -> Int {
  self.work_units
}

///|
pub fn MovementLoad::completion(self : MovementLoad) -> Double {
  self.completion
}

///|
pub fn MovementLoad::pain(self : MovementLoad) -> Int {
  self.pain
}

///|
pub fn MovementLoad::rpe(self : MovementLoad) -> Int {
  self.rpe
}

///|
pub fn MovementLoad::intensity(self : MovementLoad) -> Double {
  self.completion * (11 - self.rpe).to_double() / 10.0
}

///|
pub fn MovementLoad::symptom_burden(self : MovementLoad) -> Double {
  (self.pain * self.rpe).to_double() / 10.0
}

///|
pub fn Movement::load_profile(self : Movement) -> MovementLoad {
  MovementLoad::{
    movement_name: self.name,
    sets: self.sets.length(),
    reps: self.total_reps(),
    effective_reps: self.effective_reps(),
    hold_time: self.total_hold_time(),
    work_units: self.work_units(),
    completion: self.average_completion(),
    pain: self.pain,
    rpe: self.rpe,
  }
}

///|
pub fn Set::volume(self : Set) -> Int {
  self.reps * Int::max(1, self.hold_time)
}

///|
pub fn Set::uncompleted_reps(self : Set) -> Int {
  Int::max(0, self.reps - self.effective_reps())
}

///|
pub fn Set::symptom_adjusted_work(self : Set, pain : Int, rpe : Int) -> Double {
  self.work_units().to_double() *
  (1.0 + pain.to_double() / 10.0) *
  (1.0 + rpe.to_double() / 20.0)
}

///|
pub fn Set::is_valid_measurement(self : Set) -> Bool {
  self.reps >= 0 &&
  self.hold_time >= 0 &&
  self.completion >= 0.0 &&
  self.completion <= 1.0
}

///|
pub fn Movement::peak_reps(self : Movement) -> Int {
  self.sets.fold(init=0, (peak, set) => Int::max(peak, set.reps))
}

///|
pub fn Movement::peak_hold_time(self : Movement) -> Int {
  self.sets.fold(init=0, (peak, set) => Int::max(peak, set.hold_time))
}

///|
pub fn Movement::total_volume(self : Movement) -> Int {
  self.sets.fold(init=0, (total, set) => total + set.volume())
}

///|
pub fn Movement::uncompleted_reps(self : Movement) -> Int {
  self.sets.fold(init=0, (total, set) => total + set.uncompleted_reps())
}

///|
pub fn Movement::valid_set_count(self : Movement) -> Int {
  self.sets.count_if(set => set.is_valid_measurement())
}

///|
pub fn Movement::invalid_set_count(self : Movement) -> Int {
  self.sets.length() - self.valid_set_count()
}

///|
pub fn Movement::resistance_changes(self : Movement) -> Int {
  if self.sets.length() < 2 {
    0
  } else {
    let mut changes = 0
    for index in 1..<self.sets.length() {
      if self.sets[index].resistance != self.sets[index - 1].resistance {
        changes += 1
      }
    }
    changes
  }
}

///|
pub fn Movement::consistent_resistance(self : Movement) -> Bool {
  self.resistance_changes() == 0
}

///|
pub fn Movement::pain_adjusted_completion(self : Movement) -> Double {
  self.average_completion() * (1.0 - self.pain.to_double() / 20.0)
}

///|
pub fn Movement::load_score(self : Movement) -> Double {
  self.work_units().to_double() *
  self.average_completion() *
  (11 - self.rpe).to_double() /
  10.0
}

///|
pub fn Session::peak_pain(self : Session) -> Int {
  self.movements.fold(init=Int::max(self.pain_before, self.pain_after), (
    peak,
    movement,
  ) => Int::max(peak, movement.pain))
}

///|
pub fn Session::peak_rpe(self : Session) -> Int {
  self.movements.fold(init=0, (peak, movement) => Int::max(peak, movement.rpe))
}

///|
pub fn Session::total_effective_reps(self : Session) -> Int {
  self.movements.fold(init=0, (total, movement) => {
    total + movement.effective_reps()
  })
}

///|
pub fn Session::total_work_units(self : Session) -> Int {
  self.movements.fold(init=0, (total, movement) => total + movement.work_units())
}

///|
pub fn Session::total_volume(self : Session) -> Int {
  self.movements.fold(init=0, (total, movement) => {
    total + movement.total_volume()
  })
}

///|
pub fn Session::movement_count_with_sets(self : Session) -> Int {
  self.movements.count_if(movement => !movement.sets.is_empty())
}

///|
pub fn Session::movement_at(self : Session, index : Int) -> Movement? {
  self.movements.get(index)
}

///|
pub fn Session::has_movement(self : Session, name : String) -> Bool {
  self.movements.any(movement => movement.name == name)
}

///|
pub fn Session::resistances(self : Session) -> Array[String] {
  let values = []
  for movement in self.movements {
    for resistance in movement.resistances() {
      if !values.contains(resistance) {
        values.push(resistance)
      }
    }
  }
  values
}

///|
pub fn Session::average_rpe(self : Session) -> Double {
  if self.movements.is_empty() {
    0.0
  } else {
    self.movements
    .fold(init=0, (total, movement) => total + movement.rpe)
    .to_double() /
    self.movements.length().to_double()
  }
}

///|
pub fn Session::intensity(self : Session) -> Double {
  if self.movements.is_empty() {
    0.0
  } else {
    self.average_completion() * (11.0 - self.average_rpe()) / 10.0
  }
}

///|
pub fn Session::density(self : Session) -> Double {
  if self.duration <= 0 {
    0.0
  } else {
    self.total_work_units().to_double() / self.duration.to_double()
  }
}

///|
pub fn Session::symptom_burden(self : Session) -> Double {
  self.average_pain_during() * (1.0 + self.average_rpe() / 10.0)
}

///|
pub fn Session::data_completeness(self : Session) -> Double {
  let checks = [
    !self.id.trim().is_empty(),
    !self.date.trim().is_empty(),
    self.duration > 0,
    !self.movements.is_empty(),
    !self.notes.trim().is_empty(),
  ]
  checks.count_if(value => value).to_double() *
  100.0 /
  checks.length().to_double()
}

///|
pub(all) struct SessionDigest {
  session_id : String
  date : String
  work_units : Int
  effective_reps : Int
  intensity : Double
  density : Double
  peak_pain : Int
  peak_rpe : Int
  completeness : Double
  resistances : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SessionDigest::session_id(self : SessionDigest) -> String {
  self.session_id
}

///|
pub fn SessionDigest::date(self : SessionDigest) -> String {
  self.date
}

///|
pub fn SessionDigest::work_units(self : SessionDigest) -> Int {
  self.work_units
}

///|
pub fn SessionDigest::effective_reps(self : SessionDigest) -> Int {
  self.effective_reps
}

///|
pub fn SessionDigest::intensity(self : SessionDigest) -> Double {
  self.intensity
}

///|
pub fn SessionDigest::density(self : SessionDigest) -> Double {
  self.density
}

///|
pub fn SessionDigest::peak_pain(self : SessionDigest) -> Int {
  self.peak_pain
}

///|
pub fn SessionDigest::peak_rpe(self : SessionDigest) -> Int {
  self.peak_rpe
}

///|
pub fn SessionDigest::completeness(self : SessionDigest) -> Double {
  self.completeness
}

///|
pub fn SessionDigest::resistances(self : SessionDigest) -> Array[String] {
  self.resistances
}

///|
pub fn Session::digest(self : Session) -> SessionDigest {
  SessionDigest::{
    session_id: self.id,
    date: self.date,
    work_units: self.total_work_units(),
    effective_reps: self.total_effective_reps(),
    intensity: self.intensity(),
    density: self.density(),
    peak_pain: self.peak_pain(),
    peak_rpe: self.peak_rpe(),
    completeness: self.data_completeness(),
    resistances: self.resistances(),
  }
}

///|
pub fn digests(sessions : Array[Session]) -> Array[SessionDigest] {
  sessions.map(session => session.digest())
}

///|
pub fn peak_work_session(sessions : Array[Session]) -> Session? {
  sessions.fold(init=None, (best, session) => {
    match best {
      None => Some(session)
      Some(previous) =>
        if session.total_work_units() > previous.total_work_units() {
          Some(session)
        } else {
          Some(previous)
        }
    }
  })
}

///|
pub fn highest_symptom_session(sessions : Array[Session]) -> Session? {
  sessions.fold(init=None, (best, session) => {
    match best {
      None => Some(session)
      Some(previous) =>
        if session.symptom_burden() > previous.symptom_burden() {
          Some(session)
        } else {
          Some(previous)
        }
    }
  })
}
