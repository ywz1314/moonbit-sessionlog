///|
/// Multi-dimensional load values used to detect abrupt dose changes.
pub(all) struct LoadVector {
  date : String
  session_id : String
  reps : Int
  work_units : Int
  duration : Int
  pain : Double
  rpe : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn LoadVector::date(self : LoadVector) -> String {
  self.date
}

///|
pub fn LoadVector::session_id(self : LoadVector) -> String {
  self.session_id
}

///|
pub fn LoadVector::reps(self : LoadVector) -> Int {
  self.reps
}

///|
pub fn LoadVector::work_units(self : LoadVector) -> Int {
  self.work_units
}

///|
pub fn LoadVector::duration(self : LoadVector) -> Int {
  self.duration
}

///|
pub fn LoadVector::pain(self : LoadVector) -> Double {
  self.pain
}

///|
pub fn LoadVector::rpe(self : LoadVector) -> Double {
  self.rpe
}

///|
pub fn LoadVector::load(self : LoadVector) -> Double {
  self.work_units.to_double() * (1.0 + self.rpe / 10.0)
}

///|
pub fn LoadVector::symptom_adjusted_load(self : LoadVector) -> Double {
  self.load() * (1.0 + self.pain / 10.0)
}

///|
pub fn from_session(session : @core.Session) -> LoadVector {
  let mut rpe = 0
  for movement in session.movements {
    rpe = Int::max(rpe, movement.rpe)
  }
  LoadVector::{
    date: session.date,
    session_id: session.id,
    reps: session.total_reps(),
    work_units: session.movements.fold(init=0, (total, movement) => {
      total + movement.work_units()
    }),
    duration: session.duration,
    pain: session.average_pain_during(),
    rpe: rpe.to_double(),
  }
}

///|
pub fn from_sessions(sessions : Array[@core.Session]) -> Array[LoadVector] {
  sessions.map(from_session)
}

///|
pub(all) struct LoadWindow {
  start_date : String
  end_date : String
  values : Array[LoadVector]
  total_load : Double
  average_load : Double
  peak_load : Double
  standard_deviation : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn LoadWindow::start_date(self : LoadWindow) -> String {
  self.start_date
}

///|
pub fn LoadWindow::end_date(self : LoadWindow) -> String {
  self.end_date
}

///|
pub fn LoadWindow::values(self : LoadWindow) -> Array[LoadVector] {
  self.values
}

///|
pub fn LoadWindow::total_load(self : LoadWindow) -> Double {
  self.total_load
}

///|
pub fn LoadWindow::average_load(self : LoadWindow) -> Double {
  self.average_load
}

///|
pub fn LoadWindow::peak_load(self : LoadWindow) -> Double {
  self.peak_load
}

///|
pub fn LoadWindow::standard_deviation(self : LoadWindow) -> Double {
  self.standard_deviation
}

///|
pub fn LoadWindow::session_count(self : LoadWindow) -> Int {
  self.values.length()
}

///|
pub fn window(
  values : Array[LoadVector],
  start_date : String,
  end_date : String,
) -> LoadWindow {
  let selected = values.filter(item => {
    item.date >= start_date && item.date <= end_date
  })
  let loads = selected.map(item => item.load())
  LoadWindow::{
    start_date,
    end_date,
    values: selected,
    total_load: @statistics.sum(loads),
    average_load: @statistics.mean(loads),
    peak_load: @statistics.maximum(loads),
    standard_deviation: @statistics.standard_deviation(loads),
  }
}

///|
pub fn daily_load(values : Array[LoadVector]) -> Array[(String, Double)] {
  let grouped : Map[String, Double] = Map([])
  for item in values {
    grouped.update_or_default(item.date, item.load(), value => {
      value + item.load()
    })
  }
  grouped.to_array()
}

///|
pub fn daily_average_load(
  values : Array[LoadVector],
) -> Array[(String, Double)] {
  let grouped : Map[String, (Double, Int)] = Map([])
  for item in values {
    match grouped.get(item.date) {
      Some(previous) =>
        grouped[item.date] = (previous.0 + item.load(), previous.1 + 1)
      None => grouped[item.date] = (item.load(), 1)
    }
  }
  grouped.to_array().map(item => (item.0, item.1.0 / item.1.1.to_double()))
}

///|
pub fn acute_load(values : Array[LoadVector], recent_days : Int) -> Double {
  if values.is_empty() || recent_days <= 0 {
    0.0
  } else {
    let ordered = values.copy()
    ordered.sort_by((left, right) => right.date.compare(left.date))
    ordered[:Int::min(recent_days, ordered.length())]
    .to_owned()
    .fold(init=0.0, (total, item) => total + item.load())
  }
}

///|
pub fn chronic_load(values : Array[LoadVector], days : Int) -> Double {
  if values.is_empty() || days <= 0 {
    0.0
  } else {
    let ordered = values.copy()
    ordered.sort_by((left, right) => right.date.compare(left.date))
    let size = Int::min(days, ordered.length())
    ordered[:size]
    .to_owned()
    .fold(init=0.0, (total, item) => total + item.load()) /
    days.to_double()
  }
}

///|
pub fn acute_chronic_ratio(
  values : Array[LoadVector],
  acute_days : Int,
  chronic_days : Int,
) -> Double {
  let chronic = chronic_load(values, chronic_days)
  if chronic == 0.0 {
    0.0
  } else {
    acute_load(values, acute_days) / chronic
  }
}

///|
pub fn monotony(values : Array[LoadVector]) -> Double {
  let daily = daily_average_load(values).map(item => item.1)
  let deviation = @statistics.standard_deviation(daily)
  if deviation == 0.0 {
    0.0
  } else {
    @statistics.mean(daily) / deviation
  }
}

///|
pub fn strain(values : Array[LoadVector]) -> Double {
  let daily = daily_load(values).map(item => item.1)
  @statistics.sum(daily) * monotony(values)
}

///|
pub fn ramp_percent(previous : Double, current : Double) -> Double {
  if previous == 0.0 {
    if current == 0.0 {
      0.0
    } else {
      100.0
    }
  } else {
    (current - previous) / previous * 100.0
  }
}

///|
pub(all) enum LoadFlag {
  VeryLow
  Balanced
  RapidIncrease
  RapidDecrease
  Monotonous
  SymptomHeavy
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn LoadFlag::label(self : LoadFlag) -> String {
  match self {
    VeryLow => "very_low"
    Balanced => "balanced"
    RapidIncrease => "rapid_increase"
    RapidDecrease => "rapid_decrease"
    Monotonous => "monotonous"
    SymptomHeavy => "symptom_heavy"
  }
}

///|
pub(all) struct LoadAssessment {
  acute : Double
  chronic : Double
  ratio : Double
  monotony : Double
  strain : Double
  flags : Array[LoadFlag]
  recommendation : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn LoadAssessment::acute(self : LoadAssessment) -> Double {
  self.acute
}

///|
pub fn LoadAssessment::chronic(self : LoadAssessment) -> Double {
  self.chronic
}

///|
pub fn LoadAssessment::ratio(self : LoadAssessment) -> Double {
  self.ratio
}

///|
pub fn LoadAssessment::monotony(self : LoadAssessment) -> Double {
  self.monotony
}

///|
pub fn LoadAssessment::strain(self : LoadAssessment) -> Double {
  self.strain
}

///|
pub fn LoadAssessment::flags(self : LoadAssessment) -> Array[LoadFlag] {
  self.flags
}

///|
pub fn LoadAssessment::recommendation(self : LoadAssessment) -> String {
  self.recommendation
}

///|
fn recommendation(flags : Array[LoadFlag]) -> String {
  if flags.contains(LoadFlag::RapidIncrease) {
    "Reduce the next dose and compare symptoms before progressing."
  } else if flags.contains(LoadFlag::SymptomHeavy) {
    "Review pain and effort before interpreting workload gains."
  } else if flags.contains(LoadFlag::Monotonous) {
    "Vary the schedule or add recovery between comparable sessions."
  } else if flags.contains(LoadFlag::VeryLow) {
    "Collect enough sessions before drawing a workload conclusion."
  } else {
    "Workload is within the configured monitoring range."
  }
}

///|
pub fn assess(
  values : Array[LoadVector],
  acute_days? : Int = 7,
  chronic_days? : Int = 28,
  ramp_limit? : Double = 20.0,
) -> LoadAssessment {
  let acute = acute_load(values, acute_days)
  let chronic = chronic_load(values, chronic_days)
  let ratio = acute_chronic_ratio(values, acute_days, chronic_days)
  let mono = monotony(values)
  let strain_value = strain(values)
  let flags = []
  if values.length() < 3 {
    flags.push(LoadFlag::VeryLow)
  }
  if ratio > 1.0 + ramp_limit / 100.0 {
    flags.push(LoadFlag::RapidIncrease)
  }
  if ratio > 0.0 && ratio < 1.0 - ramp_limit / 100.0 {
    flags.push(LoadFlag::RapidDecrease)
  }
  if mono >= 2.0 {
    flags.push(LoadFlag::Monotonous)
  }
  if values.any(item => item.pain >= 7.0 || item.rpe >= 9.0) {
    flags.push(LoadFlag::SymptomHeavy)
  }
  LoadAssessment::{
    acute,
    chronic,
    ratio,
    monotony: mono,
    strain: strain_value,
    flags,
    recommendation: recommendation(flags),
  }
}

///|
pub fn compare(
  previous : LoadAssessment,
  current : LoadAssessment,
) -> (Double, Double, Double) {
  (
    current.acute - previous.acute,
    current.chronic - previous.chronic,
    current.ratio - previous.ratio,
  )
}

///|
pub fn safe_next_load(
  current : Double,
  maximum_ramp? : Double = 10.0,
) -> Double {
  current * (1.0 + Double::max(0.0, maximum_ramp) / 100.0)
}

///|
pub fn load_text(value : LoadAssessment) -> String {
  let output = StringBuilder()
  output.write_string(
    "acute=" +
    value.acute.to_string() +
    " chronic=" +
    value.chronic.to_string() +
    " ratio=" +
    value.ratio.to_string() +
    "\n",
  )
  output.write_string(
    "monotony=" +
    value.monotony.to_string() +
    " strain=" +
    value.strain.to_string() +
    "\n",
  )
  for flag in value.flags {
    output.write_string("- " + flag.label() + "\n")
  }
  output.write_string(value.recommendation + "\n")
  output.to_string()
}
