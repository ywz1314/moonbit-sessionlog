///|
/// Plan optimization proposes bounded adjustments from observed performance;
/// it never mutates the caller's plan and returns reasons for every change.
pub(all) enum AdjustmentKind {
  IncreaseVolume
  DecreaseVolume
  IncreaseRecovery
  ReducePainExposure
  KeepStable
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn AdjustmentKind::label(self : AdjustmentKind) -> String {
  match self {
    IncreaseVolume => "increase_volume"
    DecreaseVolume => "decrease_volume"
    IncreaseRecovery => "increase_recovery"
    ReducePainExposure => "reduce_pain_exposure"
    KeepStable => "keep_stable"
  }
}

///|
pub(all) struct PlanAdjustment {
  movement_name : String
  kind : AdjustmentKind
  current_sets : Int
  proposed_sets : Int
  current_reps : Int
  proposed_reps : Int
  confidence : Double
  reasons : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn PlanAdjustment::movement_name(self : PlanAdjustment) -> String {
  self.movement_name
}

///|
pub fn PlanAdjustment::kind(self : PlanAdjustment) -> AdjustmentKind {
  self.kind
}

///|
pub fn PlanAdjustment::current_sets(self : PlanAdjustment) -> Int {
  self.current_sets
}

///|
pub fn PlanAdjustment::proposed_sets(self : PlanAdjustment) -> Int {
  self.proposed_sets
}

///|
pub fn PlanAdjustment::current_reps(self : PlanAdjustment) -> Int {
  self.current_reps
}

///|
pub fn PlanAdjustment::proposed_reps(self : PlanAdjustment) -> Int {
  self.proposed_reps
}

///|
pub fn PlanAdjustment::confidence(self : PlanAdjustment) -> Double {
  self.confidence
}

///|
pub fn PlanAdjustment::reasons(self : PlanAdjustment) -> Array[String] {
  self.reasons.copy()
}

///|
pub(all) struct OptimizationOptions {
  increase_completion : Double
  reduce_completion : Double
  pain_limit : Int
  maximum_set_change : Int
  maximum_rep_change : Int
  minimum_observations : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_optimization_options() -> OptimizationOptions {
  OptimizationOptions::{
    increase_completion: 0.9,
    reduce_completion: 0.5,
    pain_limit: 6,
    maximum_set_change: 1,
    maximum_rep_change: 2,
    minimum_observations: 1,
  }
}

///|
pub fn OptimizationOptions::validate(
  self : OptimizationOptions,
) -> Array[String] {
  let errors = []
  if self.increase_completion < self.reduce_completion {
    errors.push("increase threshold must not be lower")
  }
  if self.pain_limit < 0 || self.pain_limit > 10 {
    errors.push("pain_limit must be 0..10")
  }
  if self.maximum_set_change < 0 || self.maximum_rep_change < 0 {
    errors.push("change limits must be non-negative")
  }
  if self.minimum_observations <= 0 {
    errors.push("minimum_observations must be positive")
  }
  errors
}

///|
fn observed_for(
  sessions : Array[@core.Session],
  movement_name : String,
) -> (@core.Movement?, Int) {
  let observations : Array[@core.Movement] = []
  for session in sessions {
    match session.movement(movement_name) {
      Some(value) => observations.push(value)
      None => ()
    }
  }
  let last = observations.last()
  (last, observations.length())
}

///|
pub fn propose_adjustment(
  item : PlanItem,
  sessions : Array[@core.Session],
  options : OptimizationOptions,
) -> PlanAdjustment {
  let target = item.target()
  let (observed, count) = observed_for(sessions, item.movement_name())
  let reasons = []
  let mut kind = AdjustmentKind::KeepStable
  let mut sets = target.target_sets()
  let mut reps = target.target_reps()
  let mut confidence = 0.25
  match observed {
    Some(movement) => {
      confidence = Double::min(1.0, count.to_double() / 5.0)
      let completion = movement.total_completion()
      if movement.pain >= options.pain_limit {
        kind = AdjustmentKind::ReducePainExposure
        sets = Int::max(1, sets - options.maximum_set_change)
        reps = Int::max(1, reps - options.maximum_rep_change)
        reasons.push("observed pain is at or above limit")
      } else if completion >= options.increase_completion {
        kind = AdjustmentKind::IncreaseVolume
        sets += options.maximum_set_change
        reasons.push("completion supports a small progression")
      } else if completion < options.reduce_completion {
        kind = AdjustmentKind::DecreaseVolume
        sets = Int::max(1, sets - options.maximum_set_change)
        reps = Int::max(1, reps - options.maximum_rep_change)
        reasons.push("completion is below the recovery threshold")
      } else {
        reasons.push("observed performance is within target band")
      }
    }
    None => {
      kind = AdjustmentKind::IncreaseRecovery
      reasons.push("no observation for movement")
    }
  }
  PlanAdjustment::{
    movement_name: item.movement_name(),
    kind,
    current_sets: target.target_sets(),
    proposed_sets: sets,
    current_reps: target.target_reps(),
    proposed_reps: reps,
    confidence,
    reasons,
  }
}

///|
pub fn optimize_plan(
  plan : TrainingPlan,
  sessions : Array[@core.Session],
  options : OptimizationOptions,
) -> Result[Array[PlanAdjustment], String] {
  let errors = options.validate()
  if !errors.is_empty() {
    return Err(errors.join("; "))
  }
  let result = []
  for item in plan.items() {
    result.push(propose_adjustment(item, sessions, options))
  }
  Ok(result)
}

///|
pub fn adjustments_by_kind(
  values : Array[PlanAdjustment],
  kind : AdjustmentKind,
) -> Array[PlanAdjustment] {
  values.filter(value => value.kind == kind)
}

///|
pub fn net_set_change(values : Array[PlanAdjustment]) -> Int {
  values.fold(init=0, (total, value) => {
    total + value.proposed_sets - value.current_sets
  })
}

///|
pub fn net_rep_change(values : Array[PlanAdjustment]) -> Int {
  values.fold(init=0, (total, value) => {
    total + value.proposed_reps - value.current_reps
  })
}

///|
pub fn optimization_safe(
  values : Array[PlanAdjustment],
  maximum_net_change : Int,
) -> Bool {
  net_set_change(values).abs() <= maximum_net_change &&
  net_rep_change(values).abs() <= maximum_net_change * 4
}

///|
pub fn adjustment_text(value : PlanAdjustment) -> String {
  value.movement_name +
  " " +
  value.kind.label() +
  " sets=" +
  value.current_sets.to_string() +
  "->" +
  value.proposed_sets.to_string() +
  " reps=" +
  value.current_reps.to_string() +
  "->" +
  value.proposed_reps.to_string() +
  " confidence=" +
  value.confidence.to_string()
}

///|
pub fn optimization_text(values : Array[PlanAdjustment]) -> String {
  "adjustments=" +
  values.length().to_string() +
  ", increase=" +
  adjustments_by_kind(values, AdjustmentKind::IncreaseVolume)
  .length()
  .to_string() +
  ", decrease=" +
  adjustments_by_kind(values, AdjustmentKind::DecreaseVolume)
  .length()
  .to_string() +
  ", recovery=" +
  adjustments_by_kind(values, AdjustmentKind::IncreaseRecovery)
  .length()
  .to_string() +
  ", net_sets=" +
  net_set_change(values).to_string()
}
