///|
pub(all) enum ProgressionState {
  Progression
  Maintenance
  Regression
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for ProgressionState with fn output(self, logger) {
  match self {
    Progression => logger.write_string("Progression")
    Maintenance => logger.write_string("Maintenance")
    Regression => logger.write_string("Regression")
  }
}

///|
pub(all) struct ProgressionAdvice {
  movement_name : String
  state : ProgressionState
  reason : String
  suggested_reps : Int
  suggested_sets : Int
  suggested_resistance : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for ProgressionAdvice with fn output(self, logger) {
  logger.write_string("ProgressionAdvice{")
  logger.write_string("movement_name: " + self.movement_name + ", ")
  logger.write_string("state: ")
  self.state.output(logger)
  logger.write_string(", reason: " + self.reason + ", ")
  logger.write_string(
    "suggested_reps: " + self.suggested_reps.to_string() + ", ",
  )
  logger.write_string(
    "suggested_sets: " + self.suggested_sets.to_string() + ", ",
  )
  logger.write_string(
    "suggested_resistance: " + self.suggested_resistance + "}",
  )
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn analyze_progression(movement : @core.Movement) -> ProgressionAdvice {
  let current_sets = movement.sets.length()
  let current_reps = if current_sets > 0 { movement.sets[0].reps } else { 10 }
  let current_res = if current_sets > 0 {
    movement.sets[0].resistance
  } else {
    "Bodyweight"
  }

  // Calculate average completion
  let mut total_completion = 0.0
  if current_sets > 0 {
    for set in movement.sets {
      total_completion = total_completion + set.completion
    }
  } else {
    total_completion = 1.0
  }
  let avg_completion = if current_sets > 0 {
    total_completion / current_sets.to_double()
  } else {
    1.0
  }

  let mut state = ProgressionState::Maintenance
  let mut reason = ""
  let mut sug_reps = current_reps
  let mut sug_sets = current_sets
  let sug_res = current_res

  if avg_completion < 0.75 {
    state = Regression
    reason = "Completion rate is too low (" +
      (avg_completion * 100.0).to_int().to_string() +
      "%). Recommend reducing target sets/reps."
    sug_reps = max_int(5, current_reps - 2)
    sug_sets = max_int(1, current_sets - 1)
  } else if movement.pain >= 7 || movement.rpe >= 9 {
    state = Regression
    reason = "High pain (VAS=" +
      movement.pain.to_string() +
      ") or extreme effort (RPE=" +
      movement.rpe.to_string() +
      "). Recommend reducing load to recover."
    sug_reps = max_int(5, current_reps - 2)
    sug_sets = max_int(1, current_sets - 1)
  } else if movement.pain >= 4 || movement.rpe >= 7 {
    state = Maintenance
    reason = "Moderate pain (VAS=" +
      movement.pain.to_string() +
      ") or moderate effort (RPE=" +
      movement.rpe.to_string() +
      "). Suggest maintaining current load."
    sug_reps = current_reps
    sug_sets = max_int(1, current_sets)
  } else {
    state = Progression
    reason = "Pain is low (VAS=" +
      movement.pain.to_string() +
      ") and effort is comfortable (RPE=" +
      movement.rpe.to_string() +
      "). Ready to progress."
    if current_reps < 12 {
      sug_reps = current_reps + 2
      sug_sets = max_int(1, current_sets)
    } else {
      sug_reps = 8
      sug_sets = min_int(5, current_sets + 1)
    }
  }

  ProgressionAdvice::{
    movement_name: movement.name,
    state,
    reason,
    suggested_reps: sug_reps,
    suggested_sets: sug_sets,
    suggested_resistance: sug_res,
  }
}

///|
/// Policy knobs make the recommendation engine suitable for different
/// rehabilitation protocols without changing the core data model.
pub(all) struct ProgressionPolicy {
  completion_target : Double
  progress_pain_limit : Int
  progress_rpe_limit : Int
  regression_pain_limit : Int
  regression_rpe_limit : Int
  rep_step : Int
  set_step : Int
  minimum_reps : Int
  maximum_reps : Int
  maximum_sets : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_policy() -> ProgressionPolicy {
  ProgressionPolicy::{
    completion_target: 0.75,
    progress_pain_limit: 3,
    progress_rpe_limit: 6,
    regression_pain_limit: 7,
    regression_rpe_limit: 9,
    rep_step: 2,
    set_step: 1,
    minimum_reps: 1,
    maximum_reps: 30,
    maximum_sets: 8,
  }
}

///|
pub fn conservative_policy() -> ProgressionPolicy {
  ProgressionPolicy::{
    completion_target: 0.85,
    progress_pain_limit: 2,
    progress_rpe_limit: 5,
    regression_pain_limit: 6,
    regression_rpe_limit: 8,
    rep_step: 1,
    set_step: 0,
    minimum_reps: 1,
    maximum_reps: 20,
    maximum_sets: 6,
  }
}

///|
pub fn performance_policy() -> ProgressionPolicy {
  ProgressionPolicy::{
    completion_target: 0.70,
    progress_pain_limit: 4,
    progress_rpe_limit: 7,
    regression_pain_limit: 8,
    regression_rpe_limit: 10,
    rep_step: 3,
    set_step: 1,
    minimum_reps: 2,
    maximum_reps: 40,
    maximum_sets: 10,
  }
}

///|
pub(all) struct ProgressionDecision {
  movement_name : String
  state : ProgressionState
  readiness : Int
  current_reps : Int
  suggested_reps : Int
  current_sets : Int
  suggested_sets : Int
  completion : Double
  pain : Int
  rpe : Int
  rationale : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ProgressionDecision::movement_name(self : ProgressionDecision) -> String {
  self.movement_name
}

///|
pub fn ProgressionDecision::state(
  self : ProgressionDecision,
) -> ProgressionState {
  self.state
}

///|
pub fn ProgressionDecision::readiness(self : ProgressionDecision) -> Int {
  self.readiness
}

///|
pub fn ProgressionDecision::current_reps(self : ProgressionDecision) -> Int {
  self.current_reps
}

///|
pub fn ProgressionDecision::suggested_reps(self : ProgressionDecision) -> Int {
  self.suggested_reps
}

///|
pub fn ProgressionDecision::current_sets(self : ProgressionDecision) -> Int {
  self.current_sets
}

///|
pub fn ProgressionDecision::suggested_sets(self : ProgressionDecision) -> Int {
  self.suggested_sets
}

///|
pub fn ProgressionDecision::completion(self : ProgressionDecision) -> Double {
  self.completion
}

///|
pub fn ProgressionDecision::pain(self : ProgressionDecision) -> Int {
  self.pain
}

///|
pub fn ProgressionDecision::rpe(self : ProgressionDecision) -> Int {
  self.rpe
}

///|
pub fn ProgressionDecision::rationale(self : ProgressionDecision) -> String {
  self.rationale
}

///|
fn clamp(value : Int, minimum : Int, maximum : Int) -> Int {
  Int::max(minimum, Int::min(maximum, value))
}

///|
fn readiness_for(movement : @core.Movement, policy : ProgressionPolicy) -> Int {
  let completion = (movement.average_completion() * 60.0).round().to_int()
  let pain = Int::max(0, 30 - movement.pain * 4)
  let effort = Int::max(0, 30 - movement.rpe * 3)
  let target_bonus = if movement.average_completion() >=
    policy.completion_target {
    5
  } else {
    0
  }
  clamp(completion + pain + effort + target_bonus, 0, 100)
}

///|
pub fn analyze_with_policy(
  movement : @core.Movement,
  policy : ProgressionPolicy,
) -> ProgressionDecision {
  let current_sets = movement.sets.length()
  let current_reps = match movement.sets.get(0) {
    Some(set) => set.reps
    None => policy.minimum_reps
  }
  let completion = movement.average_completion()
  let is_regression = completion < policy.completion_target ||
    movement.pain >= policy.regression_pain_limit ||
    movement.rpe >= policy.regression_rpe_limit
  let is_progression = completion >= policy.completion_target &&
    movement.pain <= policy.progress_pain_limit &&
    movement.rpe <= policy.progress_rpe_limit
  let state = if is_regression {
    ProgressionState::Regression
  } else if is_progression {
    ProgressionState::Progression
  } else {
    ProgressionState::Maintenance
  }
  let suggested_reps = match state {
    ProgressionState::Regression =>
      clamp(
        current_reps - policy.rep_step,
        policy.minimum_reps,
        policy.maximum_reps,
      )
    ProgressionState::Progression =>
      clamp(
        current_reps + policy.rep_step,
        policy.minimum_reps,
        policy.maximum_reps,
      )
    ProgressionState::Maintenance => current_reps
  }
  let suggested_sets = match state {
    ProgressionState::Regression => Int::max(1, current_sets - policy.set_step)
    ProgressionState::Progression =>
      clamp(Int::max(1, current_sets + policy.set_step), 1, policy.maximum_sets)
    ProgressionState::Maintenance => current_sets
  }
  let rationale = match state {
    ProgressionState::Regression =>
      "Reduce exposure until pain, effort, or completion recovers."
    ProgressionState::Progression =>
      "Target met with a comfortable pain and effort profile."
    ProgressionState::Maintenance =>
      "Hold the current dose and collect another stable observation."
  }
  ProgressionDecision::{
    movement_name: movement.name,
    state,
    readiness: readiness_for(movement, policy),
    current_reps,
    suggested_reps,
    current_sets,
    suggested_sets,
    completion,
    pain: movement.pain,
    rpe: movement.rpe,
    rationale,
  }
}

///|
pub fn plan_session(
  session : @core.Session,
  policy? : ProgressionPolicy = default_policy(),
) -> Array[ProgressionDecision] {
  session.movements.map(movement => analyze_with_policy(movement, policy))
}

///|
pub fn plan_states(
  plan : Array[ProgressionDecision],
) -> Array[ProgressionState] {
  plan.map(item => item.state)
}

///|
pub fn plan_summary(plan : Array[ProgressionDecision]) -> (Int, Int, Int) {
  let mut progress = 0
  let mut maintenance = 0
  let mut regression = 0
  for item in plan {
    match item.state {
      ProgressionState::Progression => progress += 1
      ProgressionState::Maintenance => maintenance += 1
      ProgressionState::Regression => regression += 1
    }
  }
  (progress, maintenance, regression)
}

///|
pub fn plan_readiness(plan : Array[ProgressionDecision]) -> Int {
  if plan.is_empty() {
    0
  } else {
    plan.fold(init=0, (total, item) => total + item.readiness) / plan.length()
  }
}

///|
pub fn decisions_requiring_attention(
  plan : Array[ProgressionDecision],
) -> Array[ProgressionDecision] {
  plan.filter(item => item.state == ProgressionState::Regression)
}

///|
pub fn decisions_ready_to_progress(
  plan : Array[ProgressionDecision],
) -> Array[ProgressionDecision] {
  plan.filter(item => item.state == ProgressionState::Progression)
}

///|
pub fn compare_movements(
  before : @core.Movement,
  after : @core.Movement,
) -> (Double, Int, Int) {
  (
    after.average_completion() - before.average_completion(),
    after.pain - before.pain,
    after.work_units() - before.work_units(),
  )
}

///|
pub fn stable_for_progression(
  movements : Array[@core.Movement],
  policy? : ProgressionPolicy = default_policy(),
) -> Bool {
  !movements.is_empty() &&
  movements.all(movement => {
    analyze_with_policy(movement, policy).state == ProgressionState::Progression
  })
}

///|
pub fn average_readiness(
  movements : Array[@core.Movement],
  policy? : ProgressionPolicy = default_policy(),
) -> Double {
  if movements.is_empty() {
    0.0
  } else {
    movements
    .fold(init=0, (total, movement) => total + readiness_for(movement, policy))
    .to_double() /
    movements.length().to_double()
  }
}

///|
pub fn safe_repetition_target(
  movement : @core.Movement,
  policy? : ProgressionPolicy = default_policy(),
) -> Int {
  analyze_with_policy(movement, policy).suggested_reps
}

///|
pub fn safe_set_target(
  movement : @core.Movement,
  policy? : ProgressionPolicy = default_policy(),
) -> Int {
  analyze_with_policy(movement, policy).suggested_sets
}

///|
pub fn explain_state(state : ProgressionState) -> String {
  match state {
    ProgressionState::Progression => "increase gradually"
    ProgressionState::Maintenance => "hold the current dose"
    ProgressionState::Regression => "reduce dose and review symptoms"
  }
}
