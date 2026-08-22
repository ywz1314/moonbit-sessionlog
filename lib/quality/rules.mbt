///|
/// Machine-readable data quality rules with a remediation-oriented result.
pub(all) enum RuleSeverity {
  Info
  Warning
  Error
  Blocking
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RuleSeverity::label(self : RuleSeverity) -> String {
  match self {
    Info => "info"
    Warning => "warning"
    Error => "error"
    Blocking => "blocking"
  }
}

///|
pub fn RuleSeverity::rank(self : RuleSeverity) -> Int {
  match self {
    Info => 0
    Warning => 1
    Error => 2
    Blocking => 3
  }
}

///|
pub(all) enum QualityRule {
  RequiredIdentity
  ValidCalendarDate
  PositiveDuration
  CompleteMovement
  CompleteSet
  SafePainRange
  SafeEffortRange
  CompletionRange
  NotesForHighPain
  UniqueMovementNames
  ResistanceConsistency
  WorkloadOutlier
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn QualityRule::code(self : QualityRule) -> String {
  match self {
    RequiredIdentity => "required_identity"
    ValidCalendarDate => "valid_calendar_date"
    PositiveDuration => "positive_duration"
    CompleteMovement => "complete_movement"
    CompleteSet => "complete_set"
    SafePainRange => "safe_pain_range"
    SafeEffortRange => "safe_effort_range"
    CompletionRange => "completion_range"
    NotesForHighPain => "notes_for_high_pain"
    UniqueMovementNames => "unique_movement_names"
    ResistanceConsistency => "resistance_consistency"
    WorkloadOutlier => "workload_outlier"
  }
}

///|
pub fn QualityRule::default_severity(self : QualityRule) -> RuleSeverity {
  match self {
    RequiredIdentity => RuleSeverity::Blocking
    ValidCalendarDate => RuleSeverity::Blocking
    PositiveDuration => RuleSeverity::Error
    CompleteMovement => RuleSeverity::Error
    CompleteSet => RuleSeverity::Error
    SafePainRange => RuleSeverity::Blocking
    SafeEffortRange => RuleSeverity::Blocking
    CompletionRange => RuleSeverity::Blocking
    NotesForHighPain => RuleSeverity::Warning
    UniqueMovementNames => RuleSeverity::Warning
    ResistanceConsistency => RuleSeverity::Info
    WorkloadOutlier => RuleSeverity::Warning
  }
}

///|
pub(all) struct QualityIssue {
  rule : QualityRule
  severity : RuleSeverity
  session_id : String
  field : String
  message : String
  remediation : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn QualityIssue::rule(self : QualityIssue) -> QualityRule {
  self.rule
}

///|
pub fn QualityIssue::severity(self : QualityIssue) -> RuleSeverity {
  self.severity
}

///|
pub fn QualityIssue::session_id(self : QualityIssue) -> String {
  self.session_id
}

///|
pub fn QualityIssue::field(self : QualityIssue) -> String {
  self.field
}

///|
pub fn QualityIssue::message(self : QualityIssue) -> String {
  self.message
}

///|
pub fn QualityIssue::remediation(self : QualityIssue) -> String {
  self.remediation
}

///|
fn issue(
  rule : QualityRule,
  session : @core.Session,
  field : String,
  message : String,
  remediation : String,
) -> QualityIssue {
  QualityIssue::{
    rule,
    severity: rule.default_severity(),
    session_id: session.id,
    field,
    message,
    remediation,
  }
}

///|
pub fn evaluate_rules(session : @core.Session) -> Array[QualityIssue] {
  let issues = []
  if session.id.trim().is_empty() {
    issues.push(
      issue(
        QualityRule::RequiredIdentity,
        session,
        "id",
        "Session id is empty.",
        "Assign a stable external id before export.",
      ),
    )
  }
  if @calendar.parse(session.date) is None {
    issues.push(
      issue(
        QualityRule::ValidCalendarDate,
        session,
        "date",
        "Date is not a valid YYYY-MM-DD value.",
        "Normalize the date before analytics.",
      ),
    )
  }
  if session.duration <= 0 {
    issues.push(
      issue(
        QualityRule::PositiveDuration,
        session,
        "duration",
        "Duration must be positive.",
        "Record elapsed minutes or mark the session as unobserved.",
      ),
    )
  }
  if session.pain_before < 0 ||
    session.pain_before > 10 ||
    session.pain_after < 0 ||
    session.pain_after > 10 {
    issues.push(
      issue(
        QualityRule::SafePainRange,
        session,
        "pain",
        "Pain must be in the 0..10 VAS range.",
        "Review the source value and preserve the raw record separately.",
      ),
    )
  }
  let names = []
  for movement in session.movements {
    if movement.name.trim().is_empty() {
      issues.push(
        issue(
          QualityRule::CompleteMovement,
          session,
          "movement.name",
          "Movement name is empty.",
          "Use a catalog identifier or an explicit unknown label.",
        ),
      )
    }
    if names.contains(movement.name) {
      issues.push(
        issue(
          QualityRule::UniqueMovementNames,
          session,
          "movement.name",
          "Movement name occurs more than once.",
          "Merge duplicate rows or add a stable movement instance id.",
        ),
      )
    } else {
      names.push(movement.name)
    }
    if movement.pain < 0 || movement.pain > 10 {
      issues.push(
        issue(
          QualityRule::SafePainRange,
          session,
          "movement.pain",
          "Movement pain is outside 0..10.",
          "Correct the value before calculating risk.",
        ),
      )
    }
    if movement.rpe < 1 || movement.rpe > 10 {
      issues.push(
        issue(
          QualityRule::SafeEffortRange,
          session,
          "movement.rpe",
          "RPE is outside 1..10.",
          "Correct the value before progression analysis.",
        ),
      )
    }
    if movement.sets.is_empty() {
      issues.push(
        issue(
          QualityRule::CompleteMovement,
          session,
          "movement.sets",
          "Movement has no sets.",
          "Record at least one set or omit the movement.",
        ),
      )
    }
    if movement.sets.length() > 0 {
      let first = movement.sets[0].resistance
      if movement.sets.any(set => set.resistance != first) {
        issues.push(
          issue(
            QualityRule::ResistanceConsistency,
            session,
            "set.resistance",
            "Resistance changes within a movement.",
            "Confirm whether the change is intentional and preserve set-level detail.",
          ),
        )
      }
    }
    for set in movement.sets {
      if set.reps < 0 || set.hold_time < 0 {
        issues.push(
          issue(
            QualityRule::CompleteSet,
            session,
            "set.quantity",
            "Set quantity is negative.",
            "Correct repetitions and hold time at ingestion.",
          ),
        )
      }
      if set.completion < 0.0 || set.completion > 1.0 {
        issues.push(
          issue(
            QualityRule::CompletionRange,
            session,
            "set.completion",
            "Completion must be between 0 and 1.",
            "Convert percentages to a fractional completion value.",
          ),
        )
      }
    }
  }
  if session.peak_pain() >= 7 && session.notes.trim().is_empty() {
    issues.push(
      issue(
        QualityRule::NotesForHighPain,
        session,
        "notes",
        "High pain has no explanatory note.",
        "Ask for a symptom or intervention note before progression.",
      ),
    )
  }
  issues
}

///|
pub(all) struct QualityProfile {
  session_count : Int
  issue_count : Int
  blocking_count : Int
  error_count : Int
  warning_count : Int
  compliance : Double
  issue_rate : Double
  top_rules : Array[(String, Int)]
  sessions_with_issues : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn QualityProfile::session_count(self : QualityProfile) -> Int {
  self.session_count
}

///|
pub fn QualityProfile::issue_count(self : QualityProfile) -> Int {
  self.issue_count
}

///|
pub fn QualityProfile::blocking_count(self : QualityProfile) -> Int {
  self.blocking_count
}

///|
pub fn QualityProfile::error_count(self : QualityProfile) -> Int {
  self.error_count
}

///|
pub fn QualityProfile::warning_count(self : QualityProfile) -> Int {
  self.warning_count
}

///|
pub fn QualityProfile::compliance(self : QualityProfile) -> Double {
  self.compliance
}

///|
pub fn QualityProfile::issue_rate(self : QualityProfile) -> Double {
  self.issue_rate
}

///|
pub fn QualityProfile::top_rules(self : QualityProfile) -> Array[(String, Int)] {
  self.top_rules
}

///|
pub fn QualityProfile::sessions_with_issues(self : QualityProfile) -> Int {
  self.sessions_with_issues
}

///|
pub fn issues(sessions : Array[@core.Session]) -> Array[QualityIssue] {
  let result = []
  for session in sessions {
    result.append(evaluate_rules(session))
  }
  result
}

///|
pub fn rule_counts(items : Array[QualityIssue]) -> Array[(String, Int)] {
  let counts : Map[String, Int] = Map([])
  for item in items {
    counts.update_or_default(item.rule.code(), 1, value => value + 1)
  }
  let result = counts.to_array()
  result.sort_by((left, right) => right.1 - left.1)
  result
}

///|
pub fn profile(sessions : Array[@core.Session]) -> QualityProfile {
  let all = issues(sessions)
  let blocking = all.count_if(item => item.severity == RuleSeverity::Blocking)
  let errors = all.count_if(item => item.severity == RuleSeverity::Error)
  let warnings = all.count_if(item => item.severity == RuleSeverity::Warning)
  let affected = sessions.count_if(session => {
    evaluate_rules(session).length() > 0
  })
  QualityProfile::{
    session_count: sessions.length(),
    issue_count: all.length(),
    blocking_count: blocking,
    error_count: errors,
    warning_count: warnings,
    compliance: if sessions.is_empty() {
      0.0
    } else {
      (sessions.length() - affected).to_double() *
      100.0 /
      sessions.length().to_double()
    },
    issue_rate: if sessions.is_empty() {
      0.0
    } else {
      all.length().to_double() / sessions.length().to_double()
    },
    top_rules: rule_counts(all)[:10].to_owned(),
    sessions_with_issues: affected,
  }
}

///|
pub fn blocking(items : Array[QualityIssue]) -> Array[QualityIssue] {
  items.filter(item => item.severity == RuleSeverity::Blocking)
}

///|
pub fn errors(items : Array[QualityIssue]) -> Array[QualityIssue] {
  items.filter(item => item.severity == RuleSeverity::Error)
}

///|
pub fn warnings(items : Array[QualityIssue]) -> Array[QualityIssue] {
  items.filter(item => item.severity == RuleSeverity::Warning)
}

///|
pub fn for_session(
  items : Array[QualityIssue],
  session_id : String,
) -> Array[QualityIssue] {
  items.filter(item => item.session_id == session_id)
}

///|
pub fn affected_session_ids(items : Array[QualityIssue]) -> Array[String] {
  let result = []
  for item in items {
    if !result.contains(item.session_id) {
      result.push(item.session_id)
    }
  }
  result
}

///|
pub fn passes(items : Array[QualityIssue]) -> Bool {
  items.all(item => item.severity != RuleSeverity::Blocking)
}

///|
pub fn needs_manual_review(items : Array[QualityIssue]) -> Bool {
  items.any(item => item.severity.rank() >= RuleSeverity::Error.rank())
}

///|
pub fn quality_delta(
  before : QualityProfile,
  after : QualityProfile,
) -> (Double, Int, Int) {
  (
    after.compliance - before.compliance,
    after.issue_count - before.issue_count,
    after.blocking_count - before.blocking_count,
  )
}

///|
pub fn issue_text(item : QualityIssue) -> String {
  item.session_id +
  " " +
  item.severity.label() +
  " " +
  item.rule.code() +
  ": " +
  item.message +
  " Fix: " +
  item.remediation
}

///|
pub fn profile_text(value : QualityProfile) -> String {
  let output = StringBuilder()
  output.write_string(
    "sessions=" +
    value.session_count.to_string() +
    ", compliance=" +
    value.compliance.to_string() +
    "%, issues=" +
    value.issue_count.to_string() +
    "\n",
  )
  for rule in value.top_rules {
    output.write_string(rule.0 + ": " + rule.1.to_string() + "\n")
  }
  output.to_string()
}
