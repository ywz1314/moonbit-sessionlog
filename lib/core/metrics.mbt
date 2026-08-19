///|
/// The coarse-grained interpretation of a VAS pain score.
pub(all) enum PainBand {
  None
  Mild
  Moderate
  Severe
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn pain_band(score : Int) -> PainBand {
  if score <= 0 {
    PainBand::None
  } else if score <= 3 {
    PainBand::Mild
  } else if score <= 6 {
    PainBand::Moderate
  } else {
    PainBand::Severe
  }
}

///|
pub fn PainBand::label(self : PainBand) -> String {
  match self {
    PainBand::None => "none"
    PainBand::Mild => "mild"
    PainBand::Moderate => "moderate"
    PainBand::Severe => "severe"
  }
}

///|
/// The coarse-grained interpretation of a perceived exertion score.
pub(all) enum EffortBand {
  VeryEasy
  Easy
  Moderate
  Hard
  VeryHard
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn effort_band(score : Int) -> EffortBand {
  if score <= 2 {
    EffortBand::VeryEasy
  } else if score <= 4 {
    EffortBand::Easy
  } else if score <= 6 {
    EffortBand::Moderate
  } else if score <= 8 {
    EffortBand::Hard
  } else {
    EffortBand::VeryHard
  }
}

///|
pub fn EffortBand::label(self : EffortBand) -> String {
  match self {
    EffortBand::VeryEasy => "very_easy"
    EffortBand::Easy => "easy"
    EffortBand::Moderate => "moderate"
    EffortBand::Hard => "hard"
    EffortBand::VeryHard => "very_hard"
  }
}

///|
/// Return the effective completed repetitions for a set.
pub fn Set::effective_reps(self : Set) -> Int {
  (self.reps.to_double() * self.completion).round().to_int()
}

///|
/// Return a workload unit that remains meaningful when resistance is text.
pub fn Set::work_units(self : Set) -> Int {
  self.reps * (self.hold_time + 1)
}

///|
pub fn Set::is_complete(self : Set, threshold? : Double = 0.95) -> Bool {
  self.completion >= threshold
}

///|
pub fn Set::completion_percent(self : Set) -> Int {
  (self.completion * 100.0).round().to_int()
}

///|
pub fn Movement::total_reps(self : Movement) -> Int {
  self.sets.fold(init=0, (total, set) => total + set.reps)
}

///|
pub fn Movement::effective_reps(self : Movement) -> Int {
  self.sets.fold(init=0, (total, set) => total + set.effective_reps())
}

///|
pub fn Movement::total_hold_time(self : Movement) -> Int {
  self.sets.fold(init=0, (total, set) => total + set.hold_time)
}

///|
pub fn Movement::work_units(self : Movement) -> Int {
  self.sets.fold(init=0, (total, set) => total + set.work_units())
}

///|
pub fn Movement::total_completion(self : Movement) -> Double {
  self.sets.fold(init=0.0, (total, set) => total + set.completion)
}

///|
pub fn Movement::average_completion(self : Movement) -> Double {
  if self.sets.is_empty() {
    0.0
  } else {
    self.total_completion() / self.sets.length().to_double()
  }
}

///|
pub fn Movement::average_reps(self : Movement) -> Double {
  if self.sets.is_empty() {
    0.0
  } else {
    self.total_reps().to_double() / self.sets.length().to_double()
  }
}

///|
pub fn Movement::pain_band(self : Movement) -> PainBand {
  pain_band(self.pain)
}

///|
pub fn Movement::effort_band(self : Movement) -> EffortBand {
  effort_band(self.rpe)
}

///|
pub fn Movement::dominant_resistance(self : Movement) -> String {
  match self.sets.get(0) {
    Some(set) => set.resistance
    None => ""
  }
}

///|
pub fn Movement::completed_set_count(self : Movement) -> Int {
  self.sets.count_if(set => set.is_complete())
}

///|
pub fn Movement::has_incomplete_set(self : Movement) -> Bool {
  self.sets.any(set => !set.is_complete())
}

///|
pub fn Movement::highest_completion(self : Movement) -> Double {
  self.sets.fold(init=0.0, (highest, set) => {
    Double::max(highest, set.completion)
  })
}

///|
pub fn Movement::lowest_completion(self : Movement) -> Double {
  self.sets.fold(init=1.0, (lowest, set) => Double::min(lowest, set.completion))
}

///|
pub fn Movement::rep_range(self : Movement) -> (Int, Int) {
  if self.sets.is_empty() {
    (0, 0)
  } else {
    let first = self.sets[0].reps
    self.sets.fold(init=(first, first), (range, set) => {
      (Int::min(range.0, set.reps), Int::max(range.1, set.reps))
    })
  }
}

///|
pub fn Movement::resistances(self : Movement) -> Array[String] {
  let values = self.sets.map(set => set.resistance)
  values.dedup()
  values
}
