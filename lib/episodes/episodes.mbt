///|
/// A configurable boundary detector for longitudinal rehabilitation records.
pub(all) struct EpisodeOptions {
  gap_days : Int
  minimum_sessions : Int
  include_invalid_dates : Bool
  stable_pain_delta : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_episode_options() -> EpisodeOptions {
  EpisodeOptions::{
    gap_days: 19,
    minimum_sessions: 1,
    include_invalid_dates: true,
    stable_pain_delta: 1,
  }
}

///|
pub fn EpisodeOptions::gap_days(self : EpisodeOptions) -> Int {
  self.gap_days
}

///|
pub fn EpisodeOptions::minimum_sessions(self : EpisodeOptions) -> Int {
  self.minimum_sessions
}

///|
pub fn EpisodeOptions::include_invalid_dates(self : EpisodeOptions) -> Bool {
  self.include_invalid_dates
}

///|
pub fn EpisodeOptions::stable_pain_delta(self : EpisodeOptions) -> Int {
  self.stable_pain_delta
}

///|
pub fn with_gap_days(options : EpisodeOptions, days : Int) -> EpisodeOptions {
  EpisodeOptions::{
    gap_days: Int::max(1, days),
    minimum_sessions: options.minimum_sessions,
    include_invalid_dates: options.include_invalid_dates,
    stable_pain_delta: options.stable_pain_delta,
  }
}

///|
pub fn with_minimum_sessions(
  options : EpisodeOptions,
  count : Int,
) -> EpisodeOptions {
  EpisodeOptions::{
    gap_days: options.gap_days,
    minimum_sessions: Int::max(1, count),
    include_invalid_dates: options.include_invalid_dates,
    stable_pain_delta: options.stable_pain_delta,
  }
}

///|
pub fn with_invalid_dates(
  options : EpisodeOptions,
  value : Bool,
) -> EpisodeOptions {
  EpisodeOptions::{
    gap_days: options.gap_days,
    minimum_sessions: options.minimum_sessions,
    include_invalid_dates: value,
    stable_pain_delta: options.stable_pain_delta,
  }
}

///|
pub fn with_stable_pain_delta(
  options : EpisodeOptions,
  delta : Int,
) -> EpisodeOptions {
  EpisodeOptions::{
    gap_days: options.gap_days,
    minimum_sessions: options.minimum_sessions,
    include_invalid_dates: options.include_invalid_dates,
    stable_pain_delta: Int::max(0, delta),
  }
}

///|
pub fn validate_options(options : EpisodeOptions) -> Array[String] {
  let errors = []
  if options.gap_days <= 0 {
    errors.push("gap_days must be positive")
  }
  if options.minimum_sessions <= 0 {
    errors.push("minimum_sessions must be positive")
  }
  if options.stable_pain_delta < 0 {
    errors.push("stable_pain_delta must not be negative")
  }
  errors
}

///|
pub(all) enum EpisodeStatus {
  Emerging
  Active
  Stable
  Interrupted
  Completed
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn EpisodeStatus::label(self : EpisodeStatus) -> String {
  match self {
    Emerging => "emerging"
    Active => "active"
    Stable => "stable"
    Interrupted => "interrupted"
    Completed => "completed"
  }
}

///|
pub(all) struct SessionGap {
  previous_id : String
  next_id : String
  previous_date : String
  next_date : String
  days : Int
  boundary : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SessionGap::previous_id(self : SessionGap) -> String {
  self.previous_id
}

///|
pub fn SessionGap::next_id(self : SessionGap) -> String {
  self.next_id
}

///|
pub fn SessionGap::previous_date(self : SessionGap) -> String {
  self.previous_date
}

///|
pub fn SessionGap::next_date(self : SessionGap) -> String {
  self.next_date
}

///|
pub fn SessionGap::days(self : SessionGap) -> Int {
  self.days
}

///|
pub fn SessionGap::boundary(self : SessionGap) -> Bool {
  self.boundary
}

///|
pub(all) struct Episode {
  id : String
  sessions : Array[@core.Session]
  gaps : Array[SessionGap]
  start_date : String
  end_date : String
  total_work_units : Int
  average_pain : Double
  average_completion : Double
  cadence_per_week : Double
  status : EpisodeStatus
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Episode::id(self : Episode) -> String {
  self.id
}

///|
pub fn Episode::sessions(self : Episode) -> Array[@core.Session] {
  self.sessions
}

///|
pub fn Episode::gaps(self : Episode) -> Array[SessionGap] {
  self.gaps
}

///|
pub fn Episode::start_date(self : Episode) -> String {
  self.start_date
}

///|
pub fn Episode::end_date(self : Episode) -> String {
  self.end_date
}

///|
pub fn Episode::total_work_units(self : Episode) -> Int {
  self.total_work_units
}

///|
pub fn Episode::average_pain(self : Episode) -> Double {
  self.average_pain
}

///|
pub fn Episode::average_completion(self : Episode) -> Double {
  self.average_completion
}

///|
pub fn Episode::cadence_per_week(self : Episode) -> Double {
  self.cadence_per_week
}

///|
pub fn Episode::status(self : Episode) -> EpisodeStatus {
  self.status
}

///|
pub fn Episode::session_count(self : Episode) -> Int {
  self.sessions.length()
}

///|
pub fn Episode::duration_days(self : Episode) -> Int {
  match (@calendar.parse(self.start_date), @calendar.parse(self.end_date)) {
    (Some(start), Some(end)) => @calendar.days_between(start, end) + 1
    _ => self.sessions.length()
  }
}

///|
pub fn Episode::has_boundary(self : Episode) -> Bool {
  self.gaps.any(gap => gap.boundary)
}

///|
pub fn Episode::last_session(self : Episode) -> @core.Session? {
  self.sessions.get(self.sessions.length() - 1)
}

///|
pub fn Episode::first_session(self : Episode) -> @core.Session? {
  self.sessions.get(0)
}

///|
pub fn Episode::movement_names(self : Episode) -> Array[String] {
  let names = []
  for session in self.sessions {
    for name in session.movement_names() {
      if !names.contains(name) {
        names.push(name)
      }
    }
  }
  names
}

///|
pub fn Episode::pain_change(self : Episode) -> Int {
  match (self.first_session(), self.last_session()) {
    (Some(first), Some(last)) => last.pain_after - first.pain_before
    _ => 0
  }
}

///|
pub fn Episode::completion_change(self : Episode) -> Double {
  match (self.first_session(), self.last_session()) {
    (Some(first), Some(last)) =>
      last.average_completion() - first.average_completion()
    _ => 0.0
  }
}

///|
pub fn Episode::summary(self : Episode) -> String {
  self.id +
  " " +
  self.start_date +
  ".." +
  self.end_date +
  " sessions=" +
  self.session_count().to_string() +
  " work=" +
  self.total_work_units.to_string() +
  " status=" +
  self.status.label()
}

///|
fn compare_session(left : @core.Session, right : @core.Session) -> Int {
  let date_order = left.date.compare(right.date)
  if date_order == 0 {
    left.id.compare(right.id)
  } else {
    date_order
  }
}

///|
pub fn chronological(sessions : Array[@core.Session]) -> Array[@core.Session] {
  let result = sessions.copy()
  result.sort_by(compare_session)
  result
}

///|
pub fn valid_date_sessions(
  sessions : Array[@core.Session],
) -> Array[@core.Session] {
  sessions.filter(session => @calendar.parse(session.date) is Some(_))
}

///|
pub fn invalid_date_sessions(
  sessions : Array[@core.Session],
) -> Array[@core.Session] {
  sessions.filter(session => @calendar.parse(session.date) is None)
}

///|
pub fn gap_days(previous : @core.Session, next : @core.Session) -> Int? {
  match (@calendar.parse(previous.date), @calendar.parse(next.date)) {
    (Some(left), Some(right)) => Some(@calendar.days_between(left, right).abs())
    _ => None
  }
}

///|
pub fn session_gaps(
  sessions : Array[@core.Session],
  boundary_days : Int,
) -> Array[SessionGap] {
  let ordered = chronological(sessions)
  let result = []
  if ordered.length() >= 2 {
    for index in 1..<ordered.length() {
      let previous = ordered[index - 1]
      let next = ordered[index]
      match gap_days(previous, next) {
        Some(days) =>
          result.push(SessionGap::{
            previous_id: previous.id,
            next_id: next.id,
            previous_date: previous.date,
            next_date: next.date,
            days,
            boundary: days >= boundary_days,
          })
        None =>
          result.push(SessionGap::{
            previous_id: previous.id,
            next_id: next.id,
            previous_date: previous.date,
            next_date: next.date,
            days: 0,
            boundary: true,
          })
      }
    }
  }
  result
}

///|
fn average_pain(sessions : Array[@core.Session]) -> Double {
  if sessions.is_empty() {
    0.0
  } else {
    sessions.fold(init=0.0, (total, item) => total + item.average_pain_during()) /
    sessions.length().to_double()
  }
}

///|
fn average_completion(sessions : Array[@core.Session]) -> Double {
  if sessions.is_empty() {
    0.0
  } else {
    sessions.fold(init=0.0, (total, item) => total + item.average_completion()) /
    sessions.length().to_double()
  }
}

///|
fn work_units(sessions : Array[@core.Session]) -> Int {
  sessions.fold(init=0, (total, item) => {
    total +
    item.movements.fold(init=0, (inner, movement) => {
      inner + movement.work_units()
    })
  })
}

///|
fn cadence(sessions : Array[@core.Session]) -> Double {
  if sessions.length() < 2 {
    sessions.length().to_double()
  } else {
    let ordered = chronological(sessions)
    match
      (
        @calendar.parse(ordered[0].date),
        @calendar.parse(ordered[ordered.length() - 1].date),
      ) {
      (Some(start), Some(end)) =>
        sessions.length().to_double() *
        7.0 /
        Int::max(1, @calendar.days_between(start, end) + 1).to_double()
      _ => 0.0
    }
  }
}

///|
fn status_for(
  sessions : Array[@core.Session],
  gaps : Array[SessionGap],
  options : EpisodeOptions,
) -> EpisodeStatus {
  if sessions.length() < options.minimum_sessions {
    EpisodeStatus::Emerging
  } else if gaps.any(gap => gap.boundary) {
    EpisodeStatus::Interrupted
  } else if sessions.length() >= 3 {
    let pain = sessions.map(item => item.average_pain_during())
    if @statistics.stable(pain, options.stable_pain_delta.to_double()) {
      EpisodeStatus::Stable
    } else {
      EpisodeStatus::Active
    }
  } else {
    EpisodeStatus::Active
  }
}

///|
fn make_episode(
  number : Int,
  sessions : Array[@core.Session],
  options : EpisodeOptions,
) -> Episode {
  let ordered = chronological(sessions)
  let gaps = session_gaps(ordered, options.gap_days)
  let first_date = ordered.get(0).map(item => item.date).unwrap_or("")
  let last_date = ordered
    .get(ordered.length() - 1)
    .map(item => item.date)
    .unwrap_or("")
  Episode::{
    id: "episode-" + (number + 1).to_string(),
    sessions: ordered,
    gaps,
    start_date: first_date,
    end_date: last_date,
    total_work_units: work_units(ordered),
    average_pain: average_pain(ordered),
    average_completion: average_completion(ordered),
    cadence_per_week: cadence(ordered),
    status: status_for(ordered, gaps, options),
  }
}

///|
/// Split an unordered set of sessions whenever the calendar gap exceeds the configured boundary.
pub fn segment(
  sessions : Array[@core.Session],
  options? : EpisodeOptions = default_episode_options(),
) -> Array[Episode] {
  let candidates = if options.include_invalid_dates {
    chronological(sessions)
  } else {
    chronological(valid_date_sessions(sessions))
  }
  let episodes = []
  let mut current = []
  let mut number = 0
  for session in candidates {
    match current.get(current.length() - 1) {
      None => current.push(session)
      Some(previous) =>
        match gap_days(previous, session) {
          Some(days) =>
            if days > options.gap_days {
              episodes.push(make_episode(number, current, options))
              number += 1
              current = [session]
            } else {
              current.push(session)
            }
          None =>
            if options.include_invalid_dates {
              current.push(session)
            } else {
              ()
            }
        }
    }
  }
  if !current.is_empty() {
    episodes.push(make_episode(number, current, options))
  }
  episodes
}

///|
pub fn segment_valid(
  sessions : Array[@core.Session],
  options? : EpisodeOptions = default_episode_options(),
) -> Array[Episode] {
  segment(
    valid_date_sessions(sessions),
    options=with_invalid_dates(options, false),
  )
}

///|
pub fn episode_for_session(
  episodes : Array[Episode],
  session_id : String,
) -> Episode? {
  for episode in episodes {
    if episode.sessions.any(session => session.id == session_id) {
      return Some(episode)
    }
  }
  None
}

///|
pub fn episode_index(episodes : Array[Episode], session_id : String) -> Int? {
  for index, episode in episodes {
    if episode.sessions.any(session => session.id == session_id) {
      return Some(index)
    }
  }
  None
}

///|
pub fn session_position(episode : Episode, session_id : String) -> Int? {
  for index, session in episode.sessions {
    if session.id == session_id {
      return Some(index)
    }
  }
  None
}

///|
pub fn flatten(episodes : Array[Episode]) -> Array[@core.Session] {
  let result = []
  for episode in episodes {
    result.append(episode.sessions)
  }
  result
}

///|
pub fn active(episodes : Array[Episode]) -> Episode? {
  for episode in episodes {
    if episode.status == EpisodeStatus::Active ||
      episode.status == EpisodeStatus::Stable {
      return Some(episode)
    }
  }
  None
}

///|
pub fn completed(episodes : Array[Episode]) -> Array[Episode] {
  episodes.filter(episode => episode.status == EpisodeStatus::Completed)
}

///|
pub fn interrupted(episodes : Array[Episode]) -> Array[Episode] {
  episodes.filter(episode => episode.status == EpisodeStatus::Interrupted)
}

///|
pub fn total_sessions(episodes : Array[Episode]) -> Int {
  episodes.fold(init=0, (total, episode) => total + episode.session_count())
}

///|
pub fn average_cadence(episodes : Array[Episode]) -> Double {
  if episodes.is_empty() {
    0.0
  } else {
    episodes.fold(init=0.0, (total, episode) => {
      total + episode.cadence_per_week()
    }) /
    episodes.length().to_double()
  }
}

///|
pub fn overall_work_units(episodes : Array[Episode]) -> Int {
  episodes.fold(init=0, (total, episode) => total + episode.total_work_units)
}

///|
pub fn sort_by_duration(episodes : Array[Episode]) -> Array[Episode] {
  let result = episodes.copy()
  result.sort_by((left, right) => right.duration_days() - left.duration_days())
  result
}

///|
pub fn sort_by_work(episodes : Array[Episode]) -> Array[Episode] {
  let result = episodes.copy()
  result.sort_by((left, right) => right.total_work_units - left.total_work_units)
  result
}

///|
pub fn merge(
  episodes : Array[Episode],
  options : EpisodeOptions,
) -> Array[Episode] {
  segment(flatten(episodes), options~)
}

///|
pub fn sessions_in_window(
  sessions : Array[@core.Session],
  start_date : String,
  end_date : String,
) -> Array[@core.Session] {
  sessions.filter(session => {
    session.date >= start_date && session.date <= end_date
  })
}

///|
pub fn episode_window(
  episode : Episode,
  start_date : String,
  end_date : String,
) -> Episode? {
  let selected = sessions_in_window(episode.sessions, start_date, end_date)
  if selected.is_empty() {
    None
  } else {
    Some(make_episode(0, selected, default_episode_options()))
  }
}

///|
pub fn boundary_count(episodes : Array[Episode]) -> Int {
  episodes.fold(init=0, (total, episode) => {
    total + episode.gaps.count_if(gap => gap.boundary)
  })
}

///|
pub fn longest_gap(episodes : Array[Episode]) -> SessionGap? {
  let gaps = []
  for episode in episodes {
    gaps.append(episode.gaps)
  }
  gaps.fold(init=None, (best, candidate) => {
    match best {
      None => Some(candidate)
      Some(previous) =>
        if candidate.days > previous.days {
          Some(candidate)
        } else {
          Some(previous)
        }
    }
  })
}

///|
pub fn episode_text(episodes : Array[Episode]) -> String {
  let output = StringBuilder()
  for episode in episodes {
    output.write_string(episode.summary() + "\n")
  }
  output.to_string()
}

///|
pub fn boundary_text(episodes : Array[Episode]) -> String {
  let output = StringBuilder()
  for episode in episodes {
    for gap in episode.gaps {
      if gap.boundary {
        output.write_string(
          gap.previous_date +
          " -> " +
          gap.next_date +
          ": " +
          gap.days.to_string() +
          " days\n",
        )
      }
    }
  }
  output.to_string()
}
