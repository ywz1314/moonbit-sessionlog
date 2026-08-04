///|
pub(all) enum ProgressionState {
  Progression
  Maintenance
  Regression
} derive(Debug, Eq, ToJson, FromJson)

///|
pub impl Show for ProgressionState with output(self, logger) {
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
pub impl Show for ProgressionAdvice with output(self, logger) {
  logger.write_string("ProgressionAdvice{")
  logger.write_string("movement_name: " + self.movement_name + ", ")
  logger.write_string("state: ")
  self.state.output(logger)
  logger.write_string(", reason: " + self.reason + ", ")
  logger.write_string("suggested_reps: " + self.suggested_reps.to_string() + ", ")
  logger.write_string("suggested_sets: " + self.suggested_sets.to_string() + ", ")
  logger.write_string("suggested_resistance: " + self.suggested_resistance + "}")
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b { a } else { b }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b { a } else { b }
}

///|
pub fn analyze_progression(movement : @core.Movement) -> ProgressionAdvice {
  let current_sets = movement.sets.length()
  let current_reps = if current_sets > 0 { movement.sets[0].reps } else { 10 }
  let current_res = if current_sets > 0 { movement.sets[0].resistance } else { "Bodyweight" }
  
  // Calculate average completion
  let mut total_completion = 0.0
  if current_sets > 0 {
    for set in movement.sets {
      total_completion = total_completion + set.completion
    }
  } else {
    total_completion = 1.0
  }
  let avg_completion = if current_sets > 0 { total_completion / current_sets.to_double() } else { 1.0 }
  
  let mut state = ProgressionState::Maintenance
  let mut reason = ""
  let mut sug_reps = current_reps
  let mut sug_sets = current_sets
  let sug_res = current_res
  
  if avg_completion < 0.75 {
    state = Regression
    reason = "Completion rate is too low (" + ((avg_completion * 100.0).to_int()).to_string() + "%). Recommend reducing target sets/reps."
    sug_reps = max_int(5, current_reps - 2)
    sug_sets = max_int(1, current_sets - 1)
  } else if movement.pain >= 7 || movement.rpe >= 9 {
    state = Regression
    reason = "High pain (VAS=" + movement.pain.to_string() + ") or extreme effort (RPE=" + movement.rpe.to_string() + "). Recommend reducing load to recover."
    sug_reps = max_int(5, current_reps - 2)
    sug_sets = max_int(1, current_sets - 1)
  } else if movement.pain >= 4 || movement.rpe >= 7 {
    state = Maintenance
    reason = "Moderate pain (VAS=" + movement.pain.to_string() + ") or moderate effort (RPE=" + movement.rpe.to_string() + "). Suggest maintaining current load."
    sug_reps = current_reps
    sug_sets = max_int(1, current_sets)
  } else {
    state = Progression
    reason = "Pain is low (VAS=" + movement.pain.to_string() + ") and effort is comfortable (RPE=" + movement.rpe.to_string() + "). Ready to progress."
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
    state: state,
    reason: reason,
    suggested_reps: sug_reps,
    suggested_sets: sug_sets,
    suggested_resistance: sug_res
  }
}
