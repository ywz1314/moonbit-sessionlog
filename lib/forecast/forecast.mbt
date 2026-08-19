///|
pub(all) enum ForecastBand {
  Stable
  Improving
  Caution
  Uncertain
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ForecastBand::label(self : ForecastBand) -> String {
  match self {
    Stable => "stable"
    Improving => "improving"
    Caution => "caution"
    Uncertain => "uncertain"
  }
}

///|
pub(all) struct ForecastPoint {
  step : Int
  expected_completion : Double
  expected_pain : Double
  expected_work_units : Int
  band : ForecastBand
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ForecastPoint::step(self : ForecastPoint) -> Int {
  self.step
}

///|
pub fn ForecastPoint::expected_completion(self : ForecastPoint) -> Double {
  self.expected_completion
}

///|
pub fn ForecastPoint::expected_pain(self : ForecastPoint) -> Double {
  self.expected_pain
}

///|
pub fn ForecastPoint::expected_work_units(self : ForecastPoint) -> Int {
  self.expected_work_units
}

///|
pub fn ForecastPoint::band(self : ForecastPoint) -> ForecastBand {
  self.band
}

///|
pub(all) struct ForecastReport {
  points : Array[ForecastPoint]
  baseline_completion : Double
  baseline_pain : Double
  baseline_work_units : Int
  completion_slope : Double
  pain_slope : Double
  confidence : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ForecastReport::points(self : ForecastReport) -> Array[ForecastPoint] {
  self.points
}

///|
pub fn ForecastReport::baseline_completion(self : ForecastReport) -> Double {
  self.baseline_completion
}

///|
pub fn ForecastReport::baseline_pain(self : ForecastReport) -> Double {
  self.baseline_pain
}

///|
pub fn ForecastReport::baseline_work_units(self : ForecastReport) -> Int {
  self.baseline_work_units
}

///|
pub fn ForecastReport::completion_slope(self : ForecastReport) -> Double {
  self.completion_slope
}

///|
pub fn ForecastReport::pain_slope(self : ForecastReport) -> Double {
  self.pain_slope
}

///|
pub fn ForecastReport::confidence(self : ForecastReport) -> Double {
  self.confidence
}

///|
fn slope(values : Array[Double]) -> Double {
  if values.length() < 2 {
    0.0
  } else {
    (values[values.length() - 1] - values[0]) /
    (values.length() - 1).to_double()
  }
}

///|
fn work_units(session : @core.Session) -> Int {
  session.movements.fold(init=0, (total, movement) => {
    total + movement.work_units()
  })
}

///|
pub fn forecast(
  sessions : Array[@core.Session],
  horizon : Int,
) -> ForecastReport {
  let completions = sessions.map(session => session.average_completion())
  let pains = sessions.map(session => session.average_pain_during())
  let works = sessions.map(session => work_units(session))
  let completion_slope = slope(completions)
  let pain_slope = slope(pains)
  let baseline_completion = if completions.is_empty() {
    0.0
  } else {
    completions.last().unwrap()
  }
  let baseline_pain = if pains.is_empty() { 0.0 } else { pains.last().unwrap() }
  let baseline_work = if works.is_empty() { 0 } else { works.last().unwrap() }
  let confidence = Double::min(1.0, sessions.length().to_double() / 10.0)
  let points = []
  if horizon > 0 {
    for step in 1..<=horizon {
      let expected_completion = Double::max(
        0.0,
        Double::min(
          1.0,
          baseline_completion + completion_slope * step.to_double(),
        ),
      )
      let expected_pain = Double::max(
        0.0,
        baseline_pain + pain_slope * step.to_double(),
      )
      let expected_work = Int::max(
        0,
        baseline_work +
        (completion_slope * baseline_work.to_double() * step.to_double()).to_int(),
      )
      let band = if sessions.is_empty() {
        ForecastBand::Uncertain
      } else if expected_pain >= 6.0 || expected_completion < 0.6 {
        ForecastBand::Caution
      } else if completion_slope > 0.02 && pain_slope <= 0.0 {
        ForecastBand::Improving
      } else {
        ForecastBand::Stable
      }
      points.push(ForecastPoint::{
        step,
        expected_completion,
        expected_pain,
        expected_work_units: expected_work,
        band,
      })
    }
  }
  ForecastReport::{
    points,
    baseline_completion,
    baseline_pain,
    baseline_work_units: baseline_work,
    completion_slope,
    pain_slope,
    confidence,
  }
}

///|
pub fn forecast_from_aggregates(
  sessions : Array[@core.Session],
  horizon : Int,
) -> ForecastReport {
  let aggregates = @aggregation.aggregate_all(sessions)
  if aggregates.is_empty() {
    forecast(sessions, horizon)
  } else {
    forecast(sessions, horizon)
  }
}

///|
pub fn expected_completion_at(report : ForecastReport, step : Int) -> Double {
  match report.points.get(Int::max(0, step - 1)) {
    Some(point) => point.expected_completion
    None => report.baseline_completion
  }
}

///|
pub fn expected_pain_at(report : ForecastReport, step : Int) -> Double {
  match report.points.get(Int::max(0, step - 1)) {
    Some(point) => point.expected_pain
    None => report.baseline_pain
  }
}

///|
pub fn max_expected_work(report : ForecastReport) -> Int {
  report.points.fold(init=report.baseline_work_units, (maximum, point) => {
    Int::max(maximum, point.expected_work_units)
  })
}

///|
pub fn has_caution(report : ForecastReport) -> Bool {
  report.points.any(point => point.band == ForecastBand::Caution)
}

///|
pub fn report_text(report : ForecastReport) -> String {
  let output = StringBuilder()
  output.write_string("confidence=" + report.confidence.to_string() + "\n")
  output.write_string(
    "completion slope=" + report.completion_slope.to_string() + "\n",
  )
  output.write_string("pain slope=" + report.pain_slope.to_string() + "\n")
  for point in report.points {
    output.write_string(
      "step " +
      point.step.to_string() +
      ": completion=" +
      point.expected_completion.to_string() +
      ", pain=" +
      point.expected_pain.to_string() +
      ", band=" +
      point.band.label() +
      "\n",
    )
  }
  output.to_string()
}
