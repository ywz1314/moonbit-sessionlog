///|
/// Scenario parameters make forecast assumptions explicit rather than hidden in a formula.
pub(all) struct ScenarioInput {
  name : String
  completion_delta : Double
  pain_delta : Double
  work_multiplier : Double
  recovery_factor : Double
  horizon : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ScenarioInput::name(self : ScenarioInput) -> String {
  self.name
}

///|
pub fn ScenarioInput::completion_delta(self : ScenarioInput) -> Double {
  self.completion_delta
}

///|
pub fn ScenarioInput::pain_delta(self : ScenarioInput) -> Double {
  self.pain_delta
}

///|
pub fn ScenarioInput::work_multiplier(self : ScenarioInput) -> Double {
  self.work_multiplier
}

///|
pub fn ScenarioInput::recovery_factor(self : ScenarioInput) -> Double {
  self.recovery_factor
}

///|
pub fn ScenarioInput::horizon(self : ScenarioInput) -> Int {
  self.horizon
}

///|
pub fn scenario(
  name : String,
  completion_delta : Double,
  pain_delta : Double,
  work_multiplier : Double,
  recovery_factor : Double,
  horizon : Int,
) -> ScenarioInput {
  ScenarioInput::{
    name,
    completion_delta,
    pain_delta,
    work_multiplier: Double::max(0.0, work_multiplier),
    recovery_factor: Double::max(0.0, Double::min(1.0, recovery_factor)),
    horizon: Int::max(1, horizon),
  }
}

///|
pub fn conservative_scenario(horizon : Int) -> ScenarioInput {
  scenario("conservative", 0.01, -0.1, 0.95, 0.9, horizon)
}

///|
pub fn maintenance_scenario(horizon : Int) -> ScenarioInput {
  scenario("maintenance", 0.0, 0.0, 1.0, 0.8, horizon)
}

///|
pub fn progression_scenario(horizon : Int) -> ScenarioInput {
  scenario("progression", 0.03, 0.1, 1.1, 0.7, horizon)
}

///|
pub fn recovery_scenario(horizon : Int) -> ScenarioInput {
  scenario("recovery", 0.015, -0.3, 0.8, 1.0, horizon)
}

///|
pub(all) struct ScenarioPoint {
  step : Int
  completion : Double
  pain : Double
  work_units : Int
  readiness : Double
  band : ForecastBand
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ScenarioPoint::step(self : ScenarioPoint) -> Int {
  self.step
}

///|
pub fn ScenarioPoint::completion(self : ScenarioPoint) -> Double {
  self.completion
}

///|
pub fn ScenarioPoint::pain(self : ScenarioPoint) -> Double {
  self.pain
}

///|
pub fn ScenarioPoint::work_units(self : ScenarioPoint) -> Int {
  self.work_units
}

///|
pub fn ScenarioPoint::readiness(self : ScenarioPoint) -> Double {
  self.readiness
}

///|
pub fn ScenarioPoint::band(self : ScenarioPoint) -> ForecastBand {
  self.band
}

///|
pub(all) struct ScenarioReport {
  input : ScenarioInput
  baseline : ForecastReport
  points : Array[ScenarioPoint]
  final_completion : Double
  final_pain : Double
  final_work_units : Int
  confidence : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ScenarioReport::input(self : ScenarioReport) -> ScenarioInput {
  self.input
}

///|
pub fn ScenarioReport::baseline(self : ScenarioReport) -> ForecastReport {
  self.baseline
}

///|
pub fn ScenarioReport::points(self : ScenarioReport) -> Array[ScenarioPoint] {
  self.points
}

///|
pub fn ScenarioReport::final_completion(self : ScenarioReport) -> Double {
  self.final_completion
}

///|
pub fn ScenarioReport::final_pain(self : ScenarioReport) -> Double {
  self.final_pain
}

///|
pub fn ScenarioReport::final_work_units(self : ScenarioReport) -> Int {
  self.final_work_units
}

///|
pub fn ScenarioReport::confidence(self : ScenarioReport) -> Double {
  self.confidence
}

///|
fn band(completion : Double, pain : Double, readiness : Double) -> ForecastBand {
  if readiness < 35.0 || pain >= 7.0 {
    ForecastBand::Caution
  } else if completion >= 0.8 && pain <= 3.0 {
    ForecastBand::Improving
  } else if completion <= 0.5 {
    ForecastBand::Uncertain
  } else {
    ForecastBand::Stable
  }
}

///|
pub fn run_scenario(
  sessions : Array[@core.Session],
  input : ScenarioInput,
) -> ScenarioReport {
  let baseline = forecast(sessions, input.horizon)
  let base_completion = baseline.baseline_completion
  let base_pain = baseline.baseline_pain
  let base_work = baseline.baseline_work_units
  let points = []
  let mut completion = base_completion
  let mut pain = base_pain
  let mut work = base_work.to_double()
  for step in 1..<=input.horizon {
    completion = Double::max(
      0.0,
      Double::min(
        1.0,
        completion + input.completion_delta * input.recovery_factor,
      ),
    )
    pain = Double::max(
      0.0,
      pain + input.pain_delta * (2.0 - input.recovery_factor),
    )
    work = Double::max(0.0, work * input.work_multiplier)
    let readiness = Double::max(
      0.0,
      Double::min(100.0, completion * 70.0 + (10.0 - pain) * 3.0),
    )
    points.push(ScenarioPoint::{
      step,
      completion,
      pain,
      work_units: work.round().to_int(),
      readiness,
      band: band(completion, pain, readiness),
    })
  }
  let last = points.last()
  ScenarioReport::{
    input,
    baseline,
    points,
    final_completion: last
    .map(item => item.completion)
    .unwrap_or(base_completion),
    final_pain: last.map(item => item.pain).unwrap_or(base_pain),
    final_work_units: last.map(item => item.work_units).unwrap_or(base_work),
    confidence: baseline.confidence * input.recovery_factor,
  }
}

///|
pub fn run_standard_scenarios(
  sessions : Array[@core.Session],
  horizon : Int,
) -> Array[ScenarioReport] {
  [
    conservative_scenario(horizon),
    maintenance_scenario(horizon),
    progression_scenario(horizon),
    recovery_scenario(horizon),
  ].map(input => run_scenario(sessions, input))
}

///|
pub fn best_completion(reports : Array[ScenarioReport]) -> ScenarioReport? {
  reports.fold(init=None, (best, report) => {
    match best {
      None => Some(report)
      Some(previous) =>
        if report.final_completion > previous.final_completion {
          Some(report)
        } else {
          Some(previous)
        }
    }
  })
}

///|
pub fn safest_pain(reports : Array[ScenarioReport]) -> ScenarioReport? {
  reports.fold(init=None, (best, report) => {
    match best {
      None => Some(report)
      Some(previous) =>
        if report.final_pain < previous.final_pain {
          Some(report)
        } else {
          Some(previous)
        }
    }
  })
}

///|
pub fn lowest_work(reports : Array[ScenarioReport]) -> ScenarioReport? {
  reports.fold(init=None, (best, report) => {
    match best {
      None => Some(report)
      Some(previous) =>
        if report.final_work_units < previous.final_work_units {
          Some(report)
        } else {
          Some(previous)
        }
    }
  })
}

///|
pub fn compare_scenarios(
  left : ScenarioReport,
  right : ScenarioReport,
) -> (Double, Double, Int) {
  (
    right.final_completion - left.final_completion,
    right.final_pain - left.final_pain,
    right.final_work_units - left.final_work_units,
  )
}

///|
pub fn scenario_delta(report : ScenarioReport) -> (Double, Double, Int) {
  (
    report.final_completion - report.baseline.baseline_completion,
    report.final_pain - report.baseline.baseline_pain,
    report.final_work_units - report.baseline.baseline_work_units,
  )
}

///|
pub fn caution_steps(report : ScenarioReport) -> Array[Int] {
  report.points
  .filter(item => item.band == ForecastBand::Caution)
  .map(item => item.step)
}

///|
pub fn confidence_band(report : ScenarioReport) -> String {
  if report.confidence >= 0.75 {
    "high"
  } else if report.confidence >= 0.4 {
    "medium"
  } else {
    "low"
  }
}

///|
pub fn scenario_text(report : ScenarioReport) -> String {
  let output = StringBuilder()
  output.write_string(
    report.input.name + " confidence=" + report.confidence.to_string() + "\n",
  )
  output.write_string(
    "final completion=" +
    report.final_completion.to_string() +
    ", pain=" +
    report.final_pain.to_string() +
    ", work=" +
    report.final_work_units.to_string() +
    "\n",
  )
  for point in report.points {
    output.write_string(
      "step " + point.step.to_string() + ": " + point.band.label() + "\n",
    )
  }
  output.to_string()
}
