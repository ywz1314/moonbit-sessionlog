///|
/// Direction of a metric over an ordered session series.
pub(all) enum TrendDirection {
  Improving
  Stable
  Worsening
  InsufficientData
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn TrendDirection::label(self : TrendDirection) -> String {
  match self {
    Improving => "improving"
    Stable => "stable"
    Worsening => "worsening"
    InsufficientData => "insufficient_data"
  }
}

///|
/// A conservative recovery classification derived from reported session data.
pub(all) enum RecoveryStatus {
  Ready
  Caution
  Deload
  Unknown
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RecoveryStatus::label(self : RecoveryStatus) -> String {
  match self {
    Ready => "ready"
    Caution => "caution"
    Deload => "deload"
    Unknown => "unknown"
  }
}

///|
pub(all) struct AnalyticsOptions {
  pain_improvement_threshold : Int
  completion_target : Double
  ready_pain_limit : Int
  ready_rpe_limit : Int
  expected_sessions : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_analytics_options() -> AnalyticsOptions {
  AnalyticsOptions::{
    pain_improvement_threshold: 1,
    completion_target: 0.75,
    ready_pain_limit: 3,
    ready_rpe_limit: 6,
    expected_sessions: 3,
  }
}

///|
pub(all) struct DailySnapshot {
  date : String
  session_id : String
  total_reps : Int
  total_sets : Int
  work_units : Int
  average_pain : Double
  average_completion : Double
  pain_delta : Int
  readiness_score : Int
  recovery : RecoveryStatus
  flags : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn DailySnapshot::date(self : DailySnapshot) -> String {
  self.date
}

///|
pub fn DailySnapshot::session_id(self : DailySnapshot) -> String {
  self.session_id
}

///|
pub fn DailySnapshot::total_reps(self : DailySnapshot) -> Int {
  self.total_reps
}

///|
pub fn DailySnapshot::total_sets(self : DailySnapshot) -> Int {
  self.total_sets
}

///|
pub fn DailySnapshot::work_units(self : DailySnapshot) -> Int {
  self.work_units
}

///|
pub fn DailySnapshot::average_pain(self : DailySnapshot) -> Double {
  self.average_pain
}

///|
pub fn DailySnapshot::average_completion(self : DailySnapshot) -> Double {
  self.average_completion
}

///|
pub fn DailySnapshot::pain_delta(self : DailySnapshot) -> Int {
  self.pain_delta
}

///|
pub fn DailySnapshot::readiness_score(self : DailySnapshot) -> Int {
  self.readiness_score
}

///|
pub fn DailySnapshot::recovery(self : DailySnapshot) -> RecoveryStatus {
  self.recovery
}

///|
pub fn DailySnapshot::flags(self : DailySnapshot) -> Array[String] {
  self.flags
}

///|
pub(all) struct TrendReport {
  snapshots : Array[DailySnapshot]
  session_count : Int
  total_reps : Int
  total_work_units : Int
  average_pain : Double
  average_completion : Double
  pain_direction : TrendDirection
  completion_direction : TrendDirection
  load_direction : TrendDirection
  first_date : String
  last_date : String
  adherence_percent : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn TrendReport::snapshots(self : TrendReport) -> Array[DailySnapshot] {
  self.snapshots
}

///|
pub fn TrendReport::session_count(self : TrendReport) -> Int {
  self.session_count
}

///|
pub fn TrendReport::total_reps(self : TrendReport) -> Int {
  self.total_reps
}

///|
pub fn TrendReport::total_work_units(self : TrendReport) -> Int {
  self.total_work_units
}

///|
pub fn TrendReport::average_pain(self : TrendReport) -> Double {
  self.average_pain
}

///|
pub fn TrendReport::average_completion(self : TrendReport) -> Double {
  self.average_completion
}

///|
pub fn TrendReport::pain_direction(self : TrendReport) -> TrendDirection {
  self.pain_direction
}

///|
pub fn TrendReport::completion_direction(self : TrendReport) -> TrendDirection {
  self.completion_direction
}

///|
pub fn TrendReport::load_direction(self : TrendReport) -> TrendDirection {
  self.load_direction
}

///|
pub fn TrendReport::first_date(self : TrendReport) -> String {
  self.first_date
}

///|
pub fn TrendReport::last_date(self : TrendReport) -> String {
  self.last_date
}

///|
pub fn TrendReport::adherence_percent(self : TrendReport) -> Double {
  self.adherence_percent
}

///|
pub fn readiness_score(
  session : @core.Session,
  options : AnalyticsOptions,
) -> Int {
  let pain_penalty = session.average_pain_during().round().to_int() * 6
  let effort_penalty = session.movements.fold(init=0, (total, movement) => {
    total + movement.rpe
  })
  let effort_average = if session.movements.is_empty() {
    0
  } else {
    effort_penalty / session.movements.length()
  }
  let completion_bonus = (session.average_completion() * 30.0).round().to_int()
  let readiness_adjustment = if options.ready_pain_limit <= 3 { 0 } else { -2 }
  let raw = 100 -
    pain_penalty -
    effort_average * 4 +
    completion_bonus +
    readiness_adjustment
  Int::max(0, Int::min(100, raw))
}

///|
pub fn classify_recovery(
  session : @core.Session,
  options : AnalyticsOptions,
) -> RecoveryStatus {
  if session.movements.is_empty() {
    RecoveryStatus::Unknown
  } else if session.average_pain_during() > options.ready_pain_limit.to_double() ||
    session.movements.any(movement => movement.rpe >= 9) {
    RecoveryStatus::Deload
  } else if session.average_completion() < options.completion_target ||
    session.average_pain_during() > 3.0 {
    RecoveryStatus::Caution
  } else {
    RecoveryStatus::Ready
  }
}

///|
fn make_flags(
  session : @core.Session,
  options : AnalyticsOptions,
) -> Array[String] {
  let flags = []
  if session.pain_before < session.pain_after {
    flags.push("pain_increased")
  }
  if session.average_completion() < options.completion_target {
    flags.push("completion_below_target")
  }
  if session.movements.any(movement => movement.pain >= 7) {
    flags.push("severe_pain")
  }
  if session.movements.any(movement => movement.rpe >= 9) {
    flags.push("very_high_effort")
  }
  if session.movements.is_empty() {
    flags.push("no_movements")
  }
  flags
}

///|
pub fn snapshot(
  session : @core.Session,
  options? : AnalyticsOptions = default_analytics_options(),
) -> DailySnapshot {
  DailySnapshot::{
    date: session.date,
    session_id: session.id,
    total_reps: session.total_reps(),
    total_sets: session.total_sets(),
    work_units: session.movements.fold(init=0, (total, movement) => {
      total + movement.work_units()
    }),
    average_pain: session.average_pain_during(),
    average_completion: session.average_completion(),
    pain_delta: session.pain_delta(),
    readiness_score: readiness_score(session, options),
    recovery: classify_recovery(session, options),
    flags: make_flags(session, options),
  }
}

///|
fn direction(
  first : Double,
  last : Double,
  lower_is_better : Bool,
  threshold : Double,
) -> TrendDirection {
  if first == last || (first - last).abs() < threshold {
    TrendDirection::Stable
  } else if lower_is_better {
    if last < first {
      TrendDirection::Improving
    } else {
      TrendDirection::Worsening
    }
  } else if last > first {
    TrendDirection::Improving
  } else {
    TrendDirection::Worsening
  }
}

///|
pub fn analyze(
  sessions : Array[@core.Session],
  options? : AnalyticsOptions = default_analytics_options(),
) -> TrendReport {
  let snapshots = sessions.map(session => snapshot(session, options~))
  let count = snapshots.length()
  let total_reps = snapshots.fold(init=0, (total, item) => {
    total + item.total_reps
  })
  let total_work = snapshots.fold(init=0, (total, item) => {
    total + item.work_units
  })
  let pain_sum = snapshots.fold(init=0.0, (total, item) => {
    total + item.average_pain
  })
  let completion_sum = snapshots.fold(init=0.0, (total, item) => {
    total + item.average_completion
  })
  let average_pain = if count == 0 { 0.0 } else { pain_sum / count.to_double() }
  let average_completion = if count == 0 {
    0.0
  } else {
    completion_sum / count.to_double()
  }
  let first = snapshots.get(0)
  let last = snapshots.get(count - 1)
  let first_date = match first {
    Some(item) => item.date
    None => ""
  }
  let last_date = match last {
    Some(item) => item.date
    None => ""
  }
  let pain_direction = match (first, last) {
    (Some(a), Some(b)) => direction(a.average_pain, b.average_pain, true, 0.5)
    _ => TrendDirection::InsufficientData
  }
  let completion_direction = match (first, last) {
    (Some(a), Some(b)) =>
      direction(a.average_completion, b.average_completion, false, 0.05)
    _ => TrendDirection::InsufficientData
  }
  let load_direction = match (first, last) {
    (Some(a), Some(b)) =>
      direction(a.work_units.to_double(), b.work_units.to_double(), false, 1.0)
    _ => TrendDirection::InsufficientData
  }
  let adherence = if options.expected_sessions <= 0 {
    0.0
  } else {
    Double::min(
      100.0,
      count.to_double() * 100.0 / options.expected_sessions.to_double(),
    )
  }
  TrendReport::{
    snapshots,
    session_count: count,
    total_reps,
    total_work_units: total_work,
    average_pain,
    average_completion,
    pain_direction,
    completion_direction,
    load_direction,
    first_date,
    last_date,
    adherence_percent: adherence,
  }
}

///|
pub fn moving_average_pain(
  sessions : Array[@core.Session],
  window : Int,
) -> Array[Double] {
  let values = sessions.map(session => session.average_pain_during())
  moving_average(values, window)
}

///|
pub fn moving_average_completion(
  sessions : Array[@core.Session],
  window : Int,
) -> Array[Double] {
  let values = sessions.map(session => session.average_completion())
  moving_average(values, window)
}

///|
pub fn moving_average(values : Array[Double], window : Int) -> Array[Double] {
  if window <= 0 || values.is_empty() {
    []
  } else {
    let output = []
    for i in 0..<values.length() {
      let start = Int::max(0, i - window + 1)
      let mut total = 0.0
      let mut count = 0
      for j in start..<=i {
        total += values[j]
        count += 1
      }
      output.push(total / count.to_double())
    }
    output
  }
}

///|
pub fn longest_ready_streak(
  sessions : Array[@core.Session],
  options? : AnalyticsOptions = default_analytics_options(),
) -> Int {
  let mut best = 0
  let mut current = 0
  for session in sessions {
    if classify_recovery(session, options) == RecoveryStatus::Ready {
      current += 1
      best = Int::max(best, current)
    } else {
      current = 0
    }
  }
  best
}

///|
pub fn pain_improved(
  session : @core.Session,
  options? : AnalyticsOptions = default_analytics_options(),
) -> Bool {
  session.pain_delta() <= -options.pain_improvement_threshold
}

///|
pub fn completion_target_met(
  session : @core.Session,
  options? : AnalyticsOptions = default_analytics_options(),
) -> Bool {
  session.average_completion() >= options.completion_target
}

///|
pub fn sessions_with_flag(
  sessions : Array[@core.Session],
  flag : String,
  options? : AnalyticsOptions = default_analytics_options(),
) -> Array[@core.Session] {
  sessions.filter(session => snapshot(session, options~).flags.contains(flag))
}

///|
pub fn readiness_scores(
  sessions : Array[@core.Session],
  options? : AnalyticsOptions = default_analytics_options(),
) -> Array[Int] {
  sessions.map(session => readiness_score(session, options))
}

///|
pub fn total_work_units(sessions : Array[@core.Session]) -> Int {
  sessions.fold(init=0, (total, session) => {
    total +
    session.movements.fold(init=0, (movement_total, movement) => {
      movement_total + movement.work_units()
    })
  })
}

///|
pub fn average_session_duration(sessions : Array[@core.Session]) -> Double {
  if sessions.is_empty() {
    0.0
  } else {
    sessions
    .fold(init=0, (total, session) => total + session.duration)
    .to_double() /
    sessions.length().to_double()
  }
}

///|
pub fn best_completion_session(
  sessions : Array[@core.Session],
) -> @core.Session? {
  let mut best : @core.Session? = None
  let mut best_score = -1.0
  for session in sessions {
    let score = session.average_completion()
    if score > best_score {
      best = Some(session)
      best_score = score
    }
  }
  best
}

///|
pub fn lowest_pain_session(sessions : Array[@core.Session]) -> @core.Session? {
  let mut best : @core.Session? = None
  let mut best_score = 11.0
  for session in sessions {
    let score = session.average_pain_during()
    if score < best_score {
      best = Some(session)
      best_score = score
    }
  }
  best
}

///|
pub fn recovery_counts(
  sessions : Array[@core.Session],
  options? : AnalyticsOptions = default_analytics_options(),
) -> (Int, Int, Int, Int) {
  let mut ready = 0
  let mut caution = 0
  let mut deload = 0
  let mut unknown = 0
  for session in sessions {
    match classify_recovery(session, options) {
      RecoveryStatus::Ready => ready += 1
      RecoveryStatus::Caution => caution += 1
      RecoveryStatus::Deload => deload += 1
      RecoveryStatus::Unknown => unknown += 1
    }
  }
  (ready, caution, deload, unknown)
}

///|
pub fn compare_completion(
  first : @core.Session,
  last : @core.Session,
) -> Double {
  last.average_completion() - first.average_completion()
}

///|
pub fn compare_pain(first : @core.Session, last : @core.Session) -> Double {
  last.average_pain_during() - first.average_pain_during()
}

///|
pub fn compare_work(first : @core.Session, last : @core.Session) -> Int {
  let first_work = first.movements.fold(init=0, (total, movement) => {
    total + movement.work_units()
  })
  let last_work = last.movements.fold(init=0, (total, movement) => {
    total + movement.work_units()
  })
  last_work - first_work
}

///|
pub fn select_recent(
  sessions : Array[@core.Session],
  count : Int,
) -> Array[@core.Session] {
  if count <= 0 {
    []
  } else if count >= sessions.length() {
    sessions.copy()
  } else {
    sessions[sessions.length() - count:].to_owned()
  }
}

///|
pub fn select_by_date(
  sessions : Array[@core.Session],
  start_date : String,
  end_date : String,
) -> Array[@core.Session] {
  sessions.filter(session => {
    session.date >= start_date && session.date <= end_date
  })
}

///|
pub fn unique_session_ids(sessions : Array[@core.Session]) -> Array[String] {
  let ids = []
  for session in sessions {
    if !ids.contains(session.id) {
      ids.push(session.id)
    }
  }
  ids
}

///|
pub fn merge_by_id(
  first : Array[@core.Session],
  second : Array[@core.Session],
) -> Array[@core.Session] {
  let merged = first.copy()
  for incoming in second {
    let existing = merged.search_by(session => session.id == incoming.id)
    match existing {
      Some(index) => merged[index] = incoming
      None => merged.push(incoming)
    }
  }
  merged
}
