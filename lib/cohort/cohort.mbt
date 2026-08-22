///|
/// Dimensions supported by the cohort aggregator.
pub(all) enum CohortDimension {
  Month
  Quarter
  Movement
  PainBand
  Weekday
  DurationBand
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CohortDimension::label(self : CohortDimension) -> String {
  match self {
    Month => "month"
    Quarter => "quarter"
    Movement => "movement"
    PainBand => "pain_band"
    Weekday => "weekday"
    DurationBand => "duration_band"
  }
}

///|
pub(all) struct CohortKey {
  dimension : CohortDimension
  value : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CohortKey::dimension(self : CohortKey) -> CohortDimension {
  self.dimension
}

///|
pub fn CohortKey::value(self : CohortKey) -> String {
  self.value
}

///|
pub fn CohortKey::label(self : CohortKey) -> String {
  self.dimension.label() + ":" + self.value
}

///|
pub(all) struct CohortSlice {
  key : CohortKey
  sessions : Array[@core.Session]
  session_count : Int
  unique_ids : Int
  total_reps : Int
  total_work_units : Int
  average_pain : Double
  average_completion : Double
  average_duration : Double
  share : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CohortSlice::key(self : CohortSlice) -> CohortKey {
  self.key
}

///|
pub fn CohortSlice::sessions(self : CohortSlice) -> Array[@core.Session] {
  self.sessions
}

///|
pub fn CohortSlice::session_count(self : CohortSlice) -> Int {
  self.session_count
}

///|
pub fn CohortSlice::unique_ids(self : CohortSlice) -> Int {
  self.unique_ids
}

///|
pub fn CohortSlice::total_reps(self : CohortSlice) -> Int {
  self.total_reps
}

///|
pub fn CohortSlice::total_work_units(self : CohortSlice) -> Int {
  self.total_work_units
}

///|
pub fn CohortSlice::average_pain(self : CohortSlice) -> Double {
  self.average_pain
}

///|
pub fn CohortSlice::average_completion(self : CohortSlice) -> Double {
  self.average_completion
}

///|
pub fn CohortSlice::average_duration(self : CohortSlice) -> Double {
  self.average_duration
}

///|
pub fn CohortSlice::share(self : CohortSlice) -> Double {
  self.share
}

///|
pub(all) struct CohortReport {
  dimension : CohortDimension
  slices : Array[CohortSlice]
  total_sessions : Int
  total_work_units : Int
  average_pain : Double
  average_completion : Double
  concentration : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CohortReport::dimension(self : CohortReport) -> CohortDimension {
  self.dimension
}

///|
pub fn CohortReport::slices(self : CohortReport) -> Array[CohortSlice] {
  self.slices
}

///|
pub fn CohortReport::total_sessions(self : CohortReport) -> Int {
  self.total_sessions
}

///|
pub fn CohortReport::total_work_units(self : CohortReport) -> Int {
  self.total_work_units
}

///|
pub fn CohortReport::average_pain(self : CohortReport) -> Double {
  self.average_pain
}

///|
pub fn CohortReport::average_completion(self : CohortReport) -> Double {
  self.average_completion
}

///|
pub fn CohortReport::concentration(self : CohortReport) -> Double {
  self.concentration
}

///|
fn unique_count(sessions : Array[@core.Session]) -> Int {
  let ids = []
  for session in sessions {
    if !ids.contains(session.id) {
      ids.push(session.id)
    }
  }
  ids.length()
}

///|
fn work_units(sessions : Array[@core.Session]) -> Int {
  sessions.fold(init=0, (total, session) => {
    total +
    session.movements.fold(init=0, (inner, movement) => {
      inner + movement.work_units()
    })
  })
}

///|
fn month_value(session : @core.Session) -> String {
  if session.date.length() >= 7 {
    session.date[:7].to_owned().to_string()
  } else {
    "unknown"
  }
}

///|
fn quarter_value(session : @core.Session) -> String {
  if session.date.length() < 7 {
    "unknown"
  } else {
    let month = match session.date[5] {
      '1' => 1
      '2' => 2
      '3' => 3
      '4' => 4
      '5' => 5
      '6' => 6
      '7' => 7
      '8' => 8
      '9' => 9
      _ => 0
    }
    let quarter = if month <= 3 {
      1
    } else if month <= 6 {
      2
    } else if month <= 9 {
      3
    } else {
      4
    }
    session.date[:4].to_owned().to_string() + "-Q" + quarter.to_string()
  }
}

///|
fn pain_value(session : @core.Session) -> String {
  @core.pain_band(session.pain_after).label()
}

///|
fn weekday_value(session : @core.Session) -> String {
  match @calendar.parse(session.date) {
    Some(date) =>
      match @calendar.weekday(date) {
        0 => "Sunday"
        1 => "Monday"
        2 => "Tuesday"
        3 => "Wednesday"
        4 => "Thursday"
        5 => "Friday"
        _ => "Saturday"
      }
    None => "unknown"
  }
}

///|
fn duration_value(session : @core.Session) -> String {
  if session.duration <= 0 {
    "unknown"
  } else if session.duration < 20 {
    "short"
  } else if session.duration < 45 {
    "standard"
  } else if session.duration < 75 {
    "long"
  } else {
    "extended"
  }
}

///|
fn key_for(session : @core.Session, dimension : CohortDimension) -> String {
  match dimension {
    CohortDimension::Month => month_value(session)
    CohortDimension::Quarter => quarter_value(session)
    CohortDimension::Movement =>
      session.movement_names().get(0).unwrap_or("unknown")
    CohortDimension::PainBand => pain_value(session)
    CohortDimension::Weekday => weekday_value(session)
    CohortDimension::DurationBand => duration_value(session)
  }
}

///|
fn build_slice(
  dimension : CohortDimension,
  value : String,
  sessions : Array[@core.Session],
  total : Int,
) -> CohortSlice {
  let pains = sessions.map(session => session.average_pain_during())
  let completions = sessions.map(session => session.average_completion())
  let durations = sessions.map(session => session.duration.to_double())
  CohortSlice::{
    key: CohortKey::{ dimension, value },
    sessions,
    session_count: sessions.length(),
    unique_ids: unique_count(sessions),
    total_reps: sessions.fold(init=0, (sum, session) => {
      sum + session.total_reps()
    }),
    total_work_units: work_units(sessions),
    average_pain: @statistics.mean(pains),
    average_completion: @statistics.mean(completions),
    average_duration: @statistics.mean(durations),
    share: if total == 0 {
      0.0
    } else {
      sessions.length().to_double() * 100.0 / total.to_double()
    },
  }
}

///|
fn group_by(
  sessions : Array[@core.Session],
  key_fn : (@core.Session) -> String,
) -> Array[(String, Array[@core.Session])] {
  let groups : Map[String, Array[@core.Session]] = Map([])
  for session in sessions {
    let key = key_fn(session)
    match groups.get(key) {
      Some(items) => items.push(session)
      None => groups[key] = [session]
    }
  }
  groups.to_array()
}

///|
pub fn group(
  sessions : Array[@core.Session],
  dimension : CohortDimension,
) -> CohortReport {
  let groups = group_by(sessions, session => key_for(session, dimension))
  let slices = groups.map(item => {
    build_slice(dimension, item.0, item.1, sessions.length())
  })
  let values = slices.map(item => {
    item.session_count.to_double() / Int::max(1, sessions.length()).to_double()
  })
  CohortReport::{
    dimension,
    slices,
    total_sessions: sessions.length(),
    total_work_units: work_units(sessions),
    average_pain: @statistics.mean(
      sessions.map(session => session.average_pain_during()),
    ),
    average_completion: @statistics.mean(
      sessions.map(session => session.average_completion()),
    ),
    concentration: values.fold(init=0.0, (total, share) => total + share * share),
  }
}

///|
pub fn by_month(sessions : Array[@core.Session]) -> CohortReport {
  group(sessions, CohortDimension::Month)
}

///|
pub fn by_quarter(sessions : Array[@core.Session]) -> CohortReport {
  group(sessions, CohortDimension::Quarter)
}

///|
pub fn by_movement(sessions : Array[@core.Session]) -> CohortReport {
  group(sessions, CohortDimension::Movement)
}

///|
pub fn by_pain_band(sessions : Array[@core.Session]) -> CohortReport {
  group(sessions, CohortDimension::PainBand)
}

///|
pub fn by_weekday(sessions : Array[@core.Session]) -> CohortReport {
  group(sessions, CohortDimension::Weekday)
}

///|
pub fn by_duration(sessions : Array[@core.Session]) -> CohortReport {
  group(sessions, CohortDimension::DurationBand)
}

///|
pub fn top_slice(report : CohortReport) -> CohortSlice? {
  report.slices.fold(init=None, (best, item) => {
    match best {
      None => Some(item)
      Some(previous) =>
        if item.session_count > previous.session_count {
          Some(item)
        } else {
          Some(previous)
        }
    }
  })
}

///|
pub fn top_by_work(report : CohortReport) -> CohortSlice? {
  report.slices.fold(init=None, (best, item) => {
    match best {
      None => Some(item)
      Some(previous) =>
        if item.total_work_units > previous.total_work_units {
          Some(item)
        } else {
          Some(previous)
        }
    }
  })
}

///|
pub fn lowest_pain(report : CohortReport) -> CohortSlice? {
  report.slices.fold(init=None, (best, item) => {
    match best {
      None => Some(item)
      Some(previous) =>
        if item.average_pain < previous.average_pain {
          Some(item)
        } else {
          Some(previous)
        }
    }
  })
}

///|
pub fn highest_completion(report : CohortReport) -> CohortSlice? {
  report.slices.fold(init=None, (best, item) => {
    match best {
      None => Some(item)
      Some(previous) =>
        if item.average_completion > previous.average_completion {
          Some(item)
        } else {
          Some(previous)
        }
    }
  })
}

///|
pub fn sort_by_count(report : CohortReport) -> Array[CohortSlice] {
  let result = report.slices.copy()
  result.sort_by((left, right) => right.session_count - left.session_count)
  result
}

///|
pub fn sort_by_completion(report : CohortReport) -> Array[CohortSlice] {
  let result = report.slices.copy()
  result.sort_by((left, right) => {
    right.average_completion.compare(left.average_completion)
  })
  result
}

///|
pub fn sort_by_pain(report : CohortReport) -> Array[CohortSlice] {
  let result = report.slices.copy()
  result.sort_by((left, right) => left.average_pain.compare(right.average_pain))
  result
}

///|
pub fn slice(report : CohortReport, value : String) -> CohortSlice? {
  for item in report.slices {
    if item.key.value == value {
      return Some(item)
    }
  }
  None
}

///|
pub fn values(report : CohortReport) -> Array[String] {
  report.slices.map(item => item.key.value)
}

///|
pub fn shares(report : CohortReport) -> Array[Double] {
  report.slices.map(item => item.share)
}

///|
pub fn compare_slices(
  left : CohortSlice,
  right : CohortSlice,
) -> (Double, Double, Int) {
  (
    right.average_completion - left.average_completion,
    right.average_pain - left.average_pain,
    right.total_work_units - left.total_work_units,
  )
}

///|
pub fn retention_at(report : CohortReport, minimum_sessions : Int) -> Double {
  if report.total_sessions == 0 {
    0.0
  } else {
    report.slices
    .count_if(item => item.unique_ids >= minimum_sessions)
    .to_double() *
    100.0 /
    report.slices.length().to_double()
  }
}

///|
pub fn average_share(report : CohortReport) -> Double {
  @statistics.mean(shares(report))
}

///|
pub fn report_text(report : CohortReport) -> String {
  let output = StringBuilder()
  output.write_string(
    report.dimension.label() +
    " cohorts=" +
    report.slices.length().to_string() +
    " sessions=" +
    report.total_sessions.to_string() +
    "\n",
  )
  for item in sort_by_count(report) {
    output.write_string(
      item.key.label() +
      ": n=" +
      item.session_count.to_string() +
      ", pain=" +
      item.average_pain.to_string() +
      ", completion=" +
      item.average_completion.to_string() +
      "\n",
    )
  }
  output.to_string()
}
