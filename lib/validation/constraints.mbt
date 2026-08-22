///|
/// Domain constraints that can be enabled independently from the strict parser.
pub(all) enum ConstraintCode {
  SessionIdentity
  SessionDate
  SessionDuration
  PainRange
  EffortRange
  SetQuantity
  CompletionRange
  MovementName
  ResistanceName
  NotesLength
  DuplicateMovement
  MonotonicSessionId
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ConstraintCode::label(self : ConstraintCode) -> String {
  match self {
    SessionIdentity => "session_identity"
    SessionDate => "session_date"
    SessionDuration => "session_duration"
    PainRange => "pain_range"
    EffortRange => "effort_range"
    SetQuantity => "set_quantity"
    CompletionRange => "completion_range"
    MovementName => "movement_name"
    ResistanceName => "resistance_name"
    NotesLength => "notes_length"
    DuplicateMovement => "duplicate_movement"
    MonotonicSessionId => "monotonic_session_id"
  }
}

///|
pub(all) enum ConstraintSeverity {
  Advisory
  Invalid
  Unsafe
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ConstraintSeverity::label(self : ConstraintSeverity) -> String {
  match self {
    Advisory => "advisory"
    Invalid => "invalid"
    Unsafe => "unsafe"
  }
}

///|
pub fn ConstraintSeverity::rank(self : ConstraintSeverity) -> Int {
  match self {
    Advisory => 0
    Invalid => 1
    Unsafe => 2
  }
}

///|
pub(all) struct Constraint {
  code : ConstraintCode
  severity : ConstraintSeverity
  path : String
  message : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Constraint::code(self : Constraint) -> ConstraintCode {
  self.code
}

///|
pub fn Constraint::severity(self : Constraint) -> ConstraintSeverity {
  self.severity
}

///|
pub fn Constraint::path(self : Constraint) -> String {
  self.path
}

///|
pub fn Constraint::message(self : Constraint) -> String {
  self.message
}

///|
fn constraint(
  code : ConstraintCode,
  severity : ConstraintSeverity,
  path : String,
  message : String,
) -> Constraint {
  Constraint::{ code, severity, path, message }
}

///|
pub(all) struct ConstraintPolicy {
  maximum_notes_length : Int
  require_notes : Bool
  require_resistance : Bool
  allow_duplicate_movements : Bool
  require_positive_duration : Bool
  require_nonempty_id : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_constraint_policy() -> ConstraintPolicy {
  ConstraintPolicy::{
    maximum_notes_length: 2000,
    require_notes: false,
    require_resistance: true,
    allow_duplicate_movements: false,
    require_positive_duration: true,
    require_nonempty_id: true,
  }
}

///|
pub fn strict_constraint_policy() -> ConstraintPolicy {
  ConstraintPolicy::{
    maximum_notes_length: 500,
    require_notes: true,
    require_resistance: true,
    allow_duplicate_movements: false,
    require_positive_duration: true,
    require_nonempty_id: true,
  }
}

///|
pub fn with_notes_limit(
  policy : ConstraintPolicy,
  limit : Int,
) -> ConstraintPolicy {
  ConstraintPolicy::{
    maximum_notes_length: Int::max(1, limit),
    require_notes: policy.require_notes,
    require_resistance: policy.require_resistance,
    allow_duplicate_movements: policy.allow_duplicate_movements,
    require_positive_duration: policy.require_positive_duration,
    require_nonempty_id: policy.require_nonempty_id,
  }
}

///|
pub fn evaluate_constraints(
  session : @core.Session,
  policy? : ConstraintPolicy = default_constraint_policy(),
) -> Array[Constraint] {
  let issues = []
  if policy.require_nonempty_id && session.id.trim().is_empty() {
    issues.push(
      constraint(
        ConstraintCode::SessionIdentity,
        ConstraintSeverity::Unsafe,
        "id",
        "Session id is required.",
      ),
    )
  }
  if !is_calendar_date(session.date) {
    issues.push(
      constraint(
        ConstraintCode::SessionDate,
        ConstraintSeverity::Unsafe,
        "date",
        "Date must use a valid YYYY-MM-DD value.",
      ),
    )
  }
  if policy.require_positive_duration && session.duration <= 0 {
    issues.push(
      constraint(
        ConstraintCode::SessionDuration,
        ConstraintSeverity::Invalid,
        "duration",
        "Duration must be positive.",
      ),
    )
  }
  if session.pain_before < 0 ||
    session.pain_before > 10 ||
    session.pain_after < 0 ||
    session.pain_after > 10 {
    issues.push(
      constraint(
        ConstraintCode::PainRange,
        ConstraintSeverity::Unsafe,
        "pain",
        "Pain must be between 0 and 10.",
      ),
    )
  }
  if policy.require_notes && session.notes.trim().is_empty() {
    issues.push(
      constraint(
        ConstraintCode::NotesLength,
        ConstraintSeverity::Advisory,
        "notes",
        "A note is required by the selected policy.",
      ),
    )
  }
  if session.notes.length() > policy.maximum_notes_length {
    issues.push(
      constraint(
        ConstraintCode::NotesLength,
        ConstraintSeverity::Invalid,
        "notes",
        "Notes exceed the configured length limit.",
      ),
    )
  }
  let names = []
  for movement in session.movements {
    if movement.name.trim().is_empty() {
      issues.push(
        constraint(
          ConstraintCode::MovementName,
          ConstraintSeverity::Invalid,
          "movement.name",
          "Movement name must not be empty.",
        ),
      )
    }
    if !policy.allow_duplicate_movements && names.contains(movement.name) {
      issues.push(
        constraint(
          ConstraintCode::DuplicateMovement,
          ConstraintSeverity::Advisory,
          "movement.name",
          "Movement name is duplicated.",
        ),
      )
    }
    names.push(movement.name)
    if movement.pain < 0 || movement.pain > 10 {
      issues.push(
        constraint(
          ConstraintCode::PainRange,
          ConstraintSeverity::Unsafe,
          "movement.pain",
          "Movement pain must be between 0 and 10.",
        ),
      )
    }
    if movement.rpe < 1 || movement.rpe > 10 {
      issues.push(
        constraint(
          ConstraintCode::EffortRange,
          ConstraintSeverity::Unsafe,
          "movement.rpe",
          "RPE must be between 1 and 10.",
        ),
      )
    }
    for index, set in movement.sets {
      if set.reps < 0 || set.hold_time < 0 {
        issues.push(
          constraint(
            ConstraintCode::SetQuantity,
            ConstraintSeverity::Invalid,
            "movement[" + index.to_string() + "].set",
            "Set quantity must not be negative.",
          ),
        )
      }
      if set.completion < 0.0 || set.completion > 1.0 {
        issues.push(
          constraint(
            ConstraintCode::CompletionRange,
            ConstraintSeverity::Unsafe,
            "movement[" + index.to_string() + "].completion",
            "Completion must be between 0 and 1.",
          ),
        )
      }
      if policy.require_resistance && set.resistance.trim().is_empty() {
        issues.push(
          constraint(
            ConstraintCode::ResistanceName,
            ConstraintSeverity::Advisory,
            "movement[" + index.to_string() + "].resistance",
            "Resistance is empty.",
          ),
        )
      }
    }
  }
  issues
}

///|
pub fn unsafe_constraints(items : Array[Constraint]) -> Array[Constraint] {
  items.filter(item => item.severity == ConstraintSeverity::Unsafe)
}

///|
pub fn invalid_constraints(items : Array[Constraint]) -> Array[Constraint] {
  items.filter(item => {
    item.severity.rank() >= ConstraintSeverity::Invalid.rank()
  })
}

///|
pub fn constraint_codes(items : Array[Constraint]) -> Array[String] {
  let result = []
  for item in items {
    let label = item.code.label()
    if !result.contains(label) {
      result.push(label)
    }
  }
  result
}

///|
pub fn constraint_summary(items : Array[Constraint]) -> (Int, Int, Int) {
  (
    items.count_if(item => item.severity == ConstraintSeverity::Advisory),
    items.count_if(item => item.severity == ConstraintSeverity::Invalid),
    items.count_if(item => item.severity == ConstraintSeverity::Unsafe),
  )
}

///|
pub(all) struct BatchConstraintSummary {
  sessions : Int
  affected_sessions : Int
  issue_count : Int
  unsafe_count : Int
  invalid_count : Int
  advisory_count : Int
  clean_percent : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn BatchConstraintSummary::sessions(self : BatchConstraintSummary) -> Int {
  self.sessions
}

///|
pub fn BatchConstraintSummary::affected_sessions(
  self : BatchConstraintSummary,
) -> Int {
  self.affected_sessions
}

///|
pub fn BatchConstraintSummary::issue_count(
  self : BatchConstraintSummary,
) -> Int {
  self.issue_count
}

///|
pub fn BatchConstraintSummary::unsafe_count(
  self : BatchConstraintSummary,
) -> Int {
  self.unsafe_count
}

///|
pub fn BatchConstraintSummary::invalid_count(
  self : BatchConstraintSummary,
) -> Int {
  self.invalid_count
}

///|
pub fn BatchConstraintSummary::advisory_count(
  self : BatchConstraintSummary,
) -> Int {
  self.advisory_count
}

///|
pub fn BatchConstraintSummary::clean_percent(
  self : BatchConstraintSummary,
) -> Double {
  self.clean_percent
}

///|
pub fn summarize_constraints(
  sessions : Array[@core.Session],
  policy? : ConstraintPolicy = default_constraint_policy(),
) -> BatchConstraintSummary {
  let all = []
  let mut affected = 0
  for session in sessions {
    let current = evaluate_constraints(session, policy~)
    if !current.is_empty() {
      affected += 1
    }
    all.append(current)
  }
  let unsafe_count = all.count_if(item => {
    item.severity == ConstraintSeverity::Unsafe
  })
  let invalid_count = all.count_if(item => {
    item.severity == ConstraintSeverity::Invalid
  })
  let advisory_count = all.count_if(item => {
    item.severity == ConstraintSeverity::Advisory
  })
  BatchConstraintSummary::{
    sessions: sessions.length(),
    affected_sessions: affected,
    issue_count: all.length(),
    unsafe_count,
    invalid_count,
    advisory_count,
    clean_percent: if sessions.is_empty() {
      0.0
    } else {
      (sessions.length() - affected).to_double() *
      100.0 /
      sessions.length().to_double()
    },
  }
}

///|
pub fn session_passes(
  session : @core.Session,
  policy? : ConstraintPolicy = default_constraint_policy(),
) -> Bool {
  invalid_constraints(evaluate_constraints(session, policy~)).is_empty()
}

///|
pub fn session_is_safe(
  session : @core.Session,
  policy? : ConstraintPolicy = default_constraint_policy(),
) -> Bool {
  unsafe_constraints(evaluate_constraints(session, policy~)).is_empty()
}

///|
pub fn constraint_text(item : Constraint) -> String {
  item.severity.label() +
  " " +
  item.code.label() +
  " at " +
  item.path +
  ": " +
  item.message
}

///|
pub fn batch_text(value : BatchConstraintSummary) -> String {
  "sessions=" +
  value.sessions.to_string() +
  ", clean=" +
  value.clean_percent.to_string() +
  "%, issues=" +
  value.issue_count.to_string() +
  ", unsafe=" +
  value.unsafe_count.to_string()
}
