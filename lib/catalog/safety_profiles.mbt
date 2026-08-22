///|
/// Safety metadata is intentionally separate from the exercise name so a
/// catalog can be adapted to local protocols without changing session data.
pub(all) enum SafetyConstraint {
  AvoidHighPain
  AvoidHighEffort
  LimitVolume
  RequireWarmup
  RequireNotes
  RequireReview
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SafetyConstraint::label(self : SafetyConstraint) -> String {
  match self {
    AvoidHighPain => "avoid_high_pain"
    AvoidHighEffort => "avoid_high_effort"
    LimitVolume => "limit_volume"
    RequireWarmup => "require_warmup"
    RequireNotes => "require_notes"
    RequireReview => "require_review"
  }
}

///|
pub(all) struct SafetyProfile {
  movement_name : String
  maximum_pain : Int
  maximum_rpe : Int
  maximum_sets : Int
  maximum_reps : Int
  constraints : Array[SafetyConstraint]
  rationale : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SafetyProfile::movement_name(self : SafetyProfile) -> String {
  self.movement_name
}

///|
pub fn SafetyProfile::maximum_pain(self : SafetyProfile) -> Int {
  self.maximum_pain
}

///|
pub fn SafetyProfile::maximum_rpe(self : SafetyProfile) -> Int {
  self.maximum_rpe
}

///|
pub fn SafetyProfile::maximum_sets(self : SafetyProfile) -> Int {
  self.maximum_sets
}

///|
pub fn SafetyProfile::maximum_reps(self : SafetyProfile) -> Int {
  self.maximum_reps
}

///|
pub fn SafetyProfile::constraints(
  self : SafetyProfile,
) -> Array[SafetyConstraint] {
  self.constraints
}

///|
pub fn SafetyProfile::rationale(self : SafetyProfile) -> String {
  self.rationale
}

///|
pub fn profile(
  name : String,
  maximum_pain : Int,
  maximum_rpe : Int,
  maximum_sets : Int,
  maximum_reps : Int,
  constraints : Array[SafetyConstraint],
  rationale : String,
) -> SafetyProfile {
  SafetyProfile::{
    movement_name: name,
    maximum_pain: Int::max(0, Int::min(10, maximum_pain)),
    maximum_rpe: Int::max(1, Int::min(10, maximum_rpe)),
    maximum_sets: Int::max(1, maximum_sets),
    maximum_reps: Int::max(1, maximum_reps),
    constraints,
    rationale,
  }
}

///|
pub fn conservative_profile(name : String) -> SafetyProfile {
  profile(
    name,
    4,
    6,
    4,
    20,
    [
      SafetyConstraint::AvoidHighPain,
      SafetyConstraint::AvoidHighEffort,
      SafetyConstraint::RequireNotes,
    ],
    "Use a lower dose until repeated observations are comfortable.",
  )
}

///|
pub fn standard_profile(name : String) -> SafetyProfile {
  profile(
    name,
    6,
    8,
    6,
    30,
    [SafetyConstraint::AvoidHighPain, SafetyConstraint::RequireNotes],
    "Use the standard dose and review symptoms after each session.",
  )
}

///|
pub fn performance_profile(name : String) -> SafetyProfile {
  profile(
    name,
    7,
    9,
    8,
    40,
    [SafetyConstraint::AvoidHighPain, SafetyConstraint::RequireReview],
    "Allow a wider dose only when the record remains complete and stable.",
  )
}

///|
pub(all) enum SafetyDecision {
  Allowed
  Reduce
  Review
  Blocked
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SafetyDecision::label(self : SafetyDecision) -> String {
  match self {
    Allowed => "allowed"
    Reduce => "reduce"
    Review => "review"
    Blocked => "blocked"
  }
}

///|
pub(all) struct SafetyCheck {
  movement_name : String
  decision : SafetyDecision
  violations : Array[String]
  observed_pain : Int
  observed_rpe : Int
  observed_sets : Int
  observed_reps : Int
  recommendation : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SafetyCheck::movement_name(self : SafetyCheck) -> String {
  self.movement_name
}

///|
pub fn SafetyCheck::decision(self : SafetyCheck) -> SafetyDecision {
  self.decision
}

///|
pub fn SafetyCheck::violations(self : SafetyCheck) -> Array[String] {
  self.violations
}

///|
pub fn SafetyCheck::observed_pain(self : SafetyCheck) -> Int {
  self.observed_pain
}

///|
pub fn SafetyCheck::observed_rpe(self : SafetyCheck) -> Int {
  self.observed_rpe
}

///|
pub fn SafetyCheck::observed_sets(self : SafetyCheck) -> Int {
  self.observed_sets
}

///|
pub fn SafetyCheck::observed_reps(self : SafetyCheck) -> Int {
  self.observed_reps
}

///|
pub fn SafetyCheck::recommendation(self : SafetyCheck) -> String {
  self.recommendation
}

///|
pub fn check(
  value : SafetyProfile,
  movement : @core.Movement,
  notes : String,
) -> SafetyCheck {
  let violations = []
  if movement.pain > value.maximum_pain {
    violations.push("pain")
  }
  if movement.rpe > value.maximum_rpe {
    violations.push("rpe")
  }
  if movement.sets.length() > value.maximum_sets {
    violations.push("sets")
  }
  if movement.total_reps() > value.maximum_reps {
    violations.push("reps")
  }
  if value.constraints.contains(SafetyConstraint::RequireNotes) &&
    notes.trim().is_empty() {
    violations.push("notes")
  }
  let hard = movement.pain > value.maximum_pain + 2 ||
    movement.rpe > value.maximum_rpe + 1
  let decision = if hard {
    SafetyDecision::Blocked
  } else if violations.contains("pain") || violations.contains("rpe") {
    SafetyDecision::Review
  } else if !violations.is_empty() {
    SafetyDecision::Reduce
  } else {
    SafetyDecision::Allowed
  }
  let recommendation = match decision {
    SafetyDecision::Allowed => "Continue and record the next response."
    SafetyDecision::Reduce =>
      "Reduce volume or improve documentation before repeating the dose."
    SafetyDecision::Review => "Review symptoms and effort before progression."
    SafetyDecision::Blocked => "Do not progress this movement without review."
  }
  SafetyCheck::{
    movement_name: movement.name,
    decision,
    violations,
    observed_pain: movement.pain,
    observed_rpe: movement.rpe,
    observed_sets: movement.sets.length(),
    observed_reps: movement.total_reps(),
    recommendation,
  }
}

///|
pub fn check_session(
  value : SafetyProfile,
  session : @core.Session,
) -> Array[SafetyCheck] {
  session.movements.map(movement => check(value, movement, session.notes))
}

///|
pub fn blocked(checks : Array[SafetyCheck]) -> Array[SafetyCheck] {
  checks.filter(item => item.decision == SafetyDecision::Blocked)
}

///|
pub fn needs_review(checks : Array[SafetyCheck]) -> Array[SafetyCheck] {
  checks.filter(item => {
    item.decision == SafetyDecision::Review ||
    item.decision == SafetyDecision::Blocked
  })
}

///|
pub fn all_allowed(checks : Array[SafetyCheck]) -> Bool {
  checks.all(item => item.decision == SafetyDecision::Allowed)
}

///|
pub fn violation_counts(checks : Array[SafetyCheck]) -> Array[(String, Int)] {
  let counts : Map[String, Int] = Map([])
  for item in checks {
    for violation in item.violations {
      counts.update_or_default(violation, 1, value => value + 1)
    }
  }
  counts.to_array()
}

///|
pub fn profile_text(value : SafetyProfile) -> String {
  value.movement_name +
  ": pain<=" +
  value.maximum_pain.to_string() +
  ", rpe<=" +
  value.maximum_rpe.to_string() +
  ", sets<=" +
  value.maximum_sets.to_string() +
  ", reps<=" +
  value.maximum_reps.to_string() +
  "\n" +
  value.rationale
}

///|
pub fn check_text(value : SafetyCheck) -> String {
  value.movement_name +
  " " +
  value.decision.label() +
  " violations=" +
  value.violations.join(",") +
  " — " +
  value.recommendation
}
