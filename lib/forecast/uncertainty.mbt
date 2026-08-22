///|
/// Uncertainty helpers keep forecast point estimates separate from intervals.
/// They are intentionally conservative and expose the assumptions used by a
/// report rather than hiding them in a single confidence number.
pub(all) enum IntervalKind {
  Prediction
  Credible
  Tolerance
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn IntervalKind::label(self : IntervalKind) -> String {
  match self {
    Prediction => "prediction"
    Credible => "credible"
    Tolerance => "tolerance"
  }
}

///|
pub(all) struct ForecastInterval {
  step : Int
  metric : String
  expected : Double
  lower : Double
  upper : Double
  width : Double
  level : Double
  kind : IntervalKind
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ForecastInterval::step(self : ForecastInterval) -> Int {
  self.step
}

///|
pub fn ForecastInterval::metric(self : ForecastInterval) -> String {
  self.metric
}

///|
pub fn ForecastInterval::expected(self : ForecastInterval) -> Double {
  self.expected
}

///|
pub fn ForecastInterval::lower(self : ForecastInterval) -> Double {
  self.lower
}

///|
pub fn ForecastInterval::upper(self : ForecastInterval) -> Double {
  self.upper
}

///|
pub fn ForecastInterval::width(self : ForecastInterval) -> Double {
  self.width
}

///|
pub fn ForecastInterval::level(self : ForecastInterval) -> Double {
  self.level
}

///|
pub fn ForecastInterval::kind(self : ForecastInterval) -> IntervalKind {
  self.kind
}

///|
pub fn interval(
  step : Int,
  metric : String,
  expected : Double,
  spread : Double,
  level : Double,
  kind : IntervalKind,
) -> Result[ForecastInterval, String] {
  if step < 0 {
    return Err("step must be non-negative")
  }
  if spread < 0.0 {
    return Err("spread must be non-negative")
  }
  if level <= 0.0 || level >= 1.0 {
    return Err("level must be between 0 and 1")
  }
  let half_width = spread * (1.0 + level)
  Ok(ForecastInterval::{
    step,
    metric,
    expected,
    lower: expected - half_width,
    upper: expected + half_width,
    width: half_width * 2.0,
    level,
    kind,
  })
}

///|
pub fn interval_contains(
  value : ForecastInterval,
  observation : Double,
) -> Bool {
  observation >= value.lower && observation <= value.upper
}

///|
pub fn interval_relative_width(value : ForecastInterval) -> Double {
  if value.expected.abs() < 0.000001 {
    value.width
  } else {
    value.width / value.expected.abs()
  }
}

///|
pub fn interval_is_wide(value : ForecastInterval, threshold : Double) -> Bool {
  interval_relative_width(value) >= threshold
}

///|
pub fn intervals_for_report(
  report : ForecastReport,
  completion_spread : Double,
  pain_spread : Double,
  level : Double,
) -> Result[Array[ForecastInterval], String] {
  let result = []
  for point in report.points() {
    match
      interval(
        point.step(),
        "completion",
        point.expected_completion(),
        completion_spread,
        level,
        IntervalKind::Prediction,
      ) {
      Ok(value) => result.push(value)
      Err(error) => return Err(error)
    }
    match
      interval(
        point.step(),
        "pain",
        point.expected_pain(),
        pain_spread,
        level,
        IntervalKind::Prediction,
      ) {
      Ok(value) => result.push(value)
      Err(error) => return Err(error)
    }
  }
  Ok(result)
}

///|
pub fn intervals_for_scenario(
  report : ScenarioReport,
  completion_spread : Double,
  pain_spread : Double,
  level : Double,
) -> Result[Array[ForecastInterval], String] {
  let result = []
  for point in report.points() {
    match
      interval(
        point.step(),
        "completion",
        point.completion(),
        completion_spread,
        level,
        IntervalKind::Prediction,
      ) {
      Ok(value) => result.push(value)
      Err(error) => return Err(error)
    }
    match
      interval(
        point.step(),
        "pain",
        point.pain(),
        pain_spread,
        level,
        IntervalKind::Prediction,
      ) {
      Ok(value) => result.push(value)
      Err(error) => return Err(error)
    }
  }
  Ok(result)
}

///|
pub(all) struct CalibrationReport {
  observations : Int
  covered : Int
  coverage : Double
  target_level : Double
  calibration_error : Double
  mean_width : Double
  overconfident : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CalibrationReport::observations(self : CalibrationReport) -> Int {
  self.observations
}

///|
pub fn CalibrationReport::covered(self : CalibrationReport) -> Int {
  self.covered
}

///|
pub fn CalibrationReport::coverage(self : CalibrationReport) -> Double {
  self.coverage
}

///|
pub fn CalibrationReport::target_level(self : CalibrationReport) -> Double {
  self.target_level
}

///|
pub fn CalibrationReport::calibration_error(self : CalibrationReport) -> Double {
  self.calibration_error
}

///|
pub fn CalibrationReport::mean_width(self : CalibrationReport) -> Double {
  self.mean_width
}

///|
pub fn CalibrationReport::overconfident(self : CalibrationReport) -> Bool {
  self.overconfident
}

///|
pub fn calibrate(
  intervals : Array[ForecastInterval],
  observations : Array[Double],
  target_level : Double,
) -> Result[CalibrationReport, String] {
  if intervals.length() != observations.length() {
    return Err("interval and observation counts must match")
  }
  if target_level <= 0.0 || target_level >= 1.0 {
    return Err("target_level must be between 0 and 1")
  }
  let mut covered = 0
  let mut width = 0.0
  for index, value in observations {
    if interval_contains(intervals[index], value) {
      covered += 1
    }
    width += intervals[index].width
  }
  let coverage = if observations.is_empty() {
    0.0
  } else {
    covered.to_double() / observations.length().to_double()
  }
  CalibrationReport::{
    observations: observations.length(),
    covered,
    coverage,
    target_level,
    calibration_error: coverage - target_level,
    mean_width: if intervals.is_empty() {
      0.0
    } else {
      width / intervals.length().to_double()
    },
    overconfident: coverage < target_level,
  }
  |> Ok
}

///|
pub fn calibration_text(value : CalibrationReport) -> String {
  "coverage=" +
  value.coverage.to_string() +
  ", target=" +
  value.target_level.to_string() +
  ", error=" +
  value.calibration_error.to_string() +
  ", mean_width=" +
  value.mean_width.to_string()
}

///|
pub(all) struct QuantileBand {
  step : Int
  metric : String
  q10 : Double
  q25 : Double
  q50 : Double
  q75 : Double
  q90 : Double
  sample_count : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn QuantileBand::step(self : QuantileBand) -> Int {
  self.step
}

///|
pub fn QuantileBand::metric(self : QuantileBand) -> String {
  self.metric
}

///|
pub fn QuantileBand::q10(self : QuantileBand) -> Double {
  self.q10
}

///|
pub fn QuantileBand::q25(self : QuantileBand) -> Double {
  self.q25
}

///|
pub fn QuantileBand::q50(self : QuantileBand) -> Double {
  self.q50
}

///|
pub fn QuantileBand::q75(self : QuantileBand) -> Double {
  self.q75
}

///|
pub fn QuantileBand::q90(self : QuantileBand) -> Double {
  self.q90
}

///|
pub fn QuantileBand::sample_count(self : QuantileBand) -> Int {
  self.sample_count
}

///|
pub fn quantile_band(
  step : Int,
  metric : String,
  samples : Array[Double],
) -> QuantileBand {
  QuantileBand::{
    step,
    metric,
    q10: @statistics.percentile(samples, 0.10),
    q25: @statistics.percentile(samples, 0.25),
    q50: @statistics.percentile(samples, 0.50),
    q75: @statistics.percentile(samples, 0.75),
    q90: @statistics.percentile(samples, 0.90),
    sample_count: samples.length(),
  }
}

///|
pub fn quantile_band_text(value : QuantileBand) -> String {
  value.metric +
  "@" +
  value.step.to_string() +
  " [" +
  value.q10.to_string() +
  "," +
  value.q90.to_string() +
  "]"
}

///|
pub(all) struct ForecastRisk {
  interval_count : Int
  wide_count : Int
  negative_completion_count : Int
  high_pain_count : Int
  mean_width : Double
  score : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ForecastRisk::interval_count(self : ForecastRisk) -> Int {
  self.interval_count
}

///|
pub fn ForecastRisk::wide_count(self : ForecastRisk) -> Int {
  self.wide_count
}

///|
pub fn ForecastRisk::negative_completion_count(self : ForecastRisk) -> Int {
  self.negative_completion_count
}

///|
pub fn ForecastRisk::high_pain_count(self : ForecastRisk) -> Int {
  self.high_pain_count
}

///|
pub fn ForecastRisk::mean_width(self : ForecastRisk) -> Double {
  self.mean_width
}

///|
pub fn ForecastRisk::score(self : ForecastRisk) -> Double {
  self.score
}

///|
pub fn assess_forecast_risk(
  intervals : Array[ForecastInterval],
  width_threshold : Double,
) -> ForecastRisk {
  let mut wide = 0
  let mut negative_completion = 0
  let mut high_pain = 0
  let mut width = 0.0
  for value in intervals {
    width += value.width
    if interval_is_wide(value, width_threshold) {
      wide += 1
    }
    if value.metric == "completion" && value.lower < 0.0 {
      negative_completion += 1
    }
    if value.metric == "pain" && value.upper >= 7.0 {
      high_pain += 1
    }
  }
  let count = intervals.length()
  let mean_width = if count == 0 { 0.0 } else { width / count.to_double() }
  let score = if count == 0 {
    0.0
  } else {
    (wide + negative_completion * 2 + high_pain * 2).to_double() /
    count.to_double()
  }
  ForecastRisk::{
    interval_count: count,
    wide_count: wide,
    negative_completion_count: negative_completion,
    high_pain_count: high_pain,
    mean_width,
    score,
  }
}

///|
pub fn forecast_risk_text(value : ForecastRisk) -> String {
  "intervals=" +
  value.interval_count.to_string() +
  ", wide=" +
  value.wide_count.to_string() +
  ", negative_completion=" +
  value.negative_completion_count.to_string() +
  ", high_pain=" +
  value.high_pain_count.to_string() +
  ", score=" +
  value.score.to_string()
}
