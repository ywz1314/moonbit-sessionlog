///|
/// Audit records capture what a data operation observed and decided without
/// storing credentials or relying on wall-clock APIs.
pub(all) enum AuditOperation {
  Ingest
  Normalize
  Validate
  Store
  Update
  Delete
  Export
  Review
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn AuditOperation::label(self : AuditOperation) -> String {
  match self {
    Ingest => "ingest"
    Normalize => "normalize"
    Validate => "validate"
    Store => "store"
    Update => "update"
    Delete => "delete"
    Export => "export"
    Review => "review"
  }
}

///|
pub(all) enum AuditOutcome {
  Accepted
  AcceptedWithWarnings
  Rejected
  Failed
  Skipped
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn AuditOutcome::label(self : AuditOutcome) -> String {
  match self {
    Accepted => "accepted"
    AcceptedWithWarnings => "accepted_with_warnings"
    Rejected => "rejected"
    Failed => "failed"
    Skipped => "skipped"
  }
}

///|
pub fn AuditOutcome::successful(self : AuditOutcome) -> Bool {
  self == AuditOutcome::Accepted || self == AuditOutcome::AcceptedWithWarnings
}

///|
pub(all) struct AuditRecord {
  sequence : Int
  operation : AuditOperation
  outcome : AuditOutcome
  session_id : String
  input_fingerprint : String
  output_fingerprint : String
  warning_count : Int
  issue_count : Int
  message : String
  actor : String
  source : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn AuditRecord::sequence(self : AuditRecord) -> Int {
  self.sequence
}

///|
pub fn AuditRecord::operation(self : AuditRecord) -> AuditOperation {
  self.operation
}

///|
pub fn AuditRecord::outcome(self : AuditRecord) -> AuditOutcome {
  self.outcome
}

///|
pub fn AuditRecord::session_id(self : AuditRecord) -> String {
  self.session_id
}

///|
pub fn AuditRecord::input_fingerprint(self : AuditRecord) -> String {
  self.input_fingerprint
}

///|
pub fn AuditRecord::output_fingerprint(self : AuditRecord) -> String {
  self.output_fingerprint
}

///|
pub fn AuditRecord::warning_count(self : AuditRecord) -> Int {
  self.warning_count
}

///|
pub fn AuditRecord::issue_count(self : AuditRecord) -> Int {
  self.issue_count
}

///|
pub fn AuditRecord::message(self : AuditRecord) -> String {
  self.message
}

///|
pub fn AuditRecord::actor(self : AuditRecord) -> String {
  self.actor
}

///|
pub fn AuditRecord::source(self : AuditRecord) -> String {
  self.source
}

///|
pub(all) struct AuditTrail {
  mut records : Array[AuditRecord]
  mut next_sequence : Int
  source : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn new_audit(source : String) -> AuditTrail {
  AuditTrail::{ records: [], next_sequence: 1, source }
}

///|
pub fn AuditTrail::records(self : AuditTrail) -> Array[AuditRecord] {
  self.records.copy()
}

///|
pub fn AuditTrail::count(self : AuditTrail) -> Int {
  self.records.length()
}

///|
pub fn AuditTrail::source(self : AuditTrail) -> String {
  self.source
}

///|
pub fn AuditTrail::append(
  self : AuditTrail,
  operation : AuditOperation,
  outcome : AuditOutcome,
  session_id : String,
  input_fingerprint : String,
  output_fingerprint : String,
  warning_count : Int,
  issue_count : Int,
  message : String,
  actor : String,
) -> AuditRecord {
  let record = AuditRecord::{
    sequence: self.next_sequence,
    operation,
    outcome,
    session_id,
    input_fingerprint,
    output_fingerprint,
    warning_count,
    issue_count,
    message,
    actor,
    source: self.source,
  }
  self.records.push(record)
  self.next_sequence += 1
  record
}

///|
pub fn AuditTrail::ingest(
  self : AuditTrail,
  session : @core.Session,
  actor : String,
) -> AuditRecord {
  let fingerprint = @retention.fingerprint(session)
  self.append(
    AuditOperation::Ingest,
    AuditOutcome::Accepted,
    session.id,
    fingerprint,
    fingerprint,
    0,
    0,
    "session observed",
    actor,
  )
}

///|
pub fn AuditTrail::normalize(
  self : AuditTrail,
  before : @core.Session,
  result : @normalization.NormalizationResult,
  actor : String,
) -> AuditRecord {
  let report = result.report()
  let outcome = if report.warning_count() == 0 {
    AuditOutcome::Accepted
  } else {
    AuditOutcome::AcceptedWithWarnings
  }
  self.append(
    AuditOperation::Normalize,
    outcome,
    before.id,
    report.original_fingerprint(),
    report.normalized_fingerprint(),
    report.warning_count(),
    0,
    "normalization completed",
    actor,
  )
}

///|
pub fn AuditTrail::validate(
  self : AuditTrail,
  session : @core.Session,
  issues : Array[@validation.Constraint],
  actor : String,
) -> AuditRecord {
  let outcome = if @validation.invalid_constraints(issues).is_empty() {
    if issues.is_empty() {
      AuditOutcome::Accepted
    } else {
      AuditOutcome::AcceptedWithWarnings
    }
  } else {
    AuditOutcome::Rejected
  }
  let fingerprint = @retention.fingerprint(session)
  self.append(
    AuditOperation::Validate,
    outcome,
    session.id,
    fingerprint,
    fingerprint,
    issues.count_if(issue => {
      issue.severity() == @validation.ConstraintSeverity::Advisory
    }),
    issues.length(),
    "constraint evaluation completed",
    actor,
  )
}

///|
pub fn AuditTrail::store(
  self : AuditTrail,
  session : @core.Session,
  actor : String,
) -> AuditRecord {
  let fingerprint = @retention.fingerprint(session)
  self.append(
    AuditOperation::Store,
    AuditOutcome::Accepted,
    session.id,
    fingerprint,
    fingerprint,
    0,
    0,
    "session stored",
    actor,
  )
}

///|
pub fn AuditTrail::reject(
  self : AuditTrail,
  session_id : String,
  message : String,
  actor : String,
) -> AuditRecord {
  self.append(
    AuditOperation::Validate,
    AuditOutcome::Rejected,
    session_id,
    "",
    "",
    0,
    1,
    message,
    actor,
  )
}

///|
pub fn AuditTrail::reset(self : AuditTrail) -> Unit {
  self.records.clear()
  self.next_sequence = 1
}

///|
pub(all) struct AuditSummary {
  total : Int
  successful : Int
  warnings : Int
  rejected : Int
  failed : Int
  unique_sessions : Int
  first_sequence : Int
  last_sequence : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn AuditSummary::total(self : AuditSummary) -> Int {
  self.total
}

///|
pub fn AuditSummary::successful(self : AuditSummary) -> Int {
  self.successful
}

///|
pub fn AuditSummary::warnings(self : AuditSummary) -> Int {
  self.warnings
}

///|
pub fn AuditSummary::rejected(self : AuditSummary) -> Int {
  self.rejected
}

///|
pub fn AuditSummary::failed(self : AuditSummary) -> Int {
  self.failed
}

///|
pub fn AuditSummary::unique_sessions(self : AuditSummary) -> Int {
  self.unique_sessions
}

///|
pub fn AuditSummary::first_sequence(self : AuditSummary) -> Int {
  self.first_sequence
}

///|
pub fn AuditSummary::last_sequence(self : AuditSummary) -> Int {
  self.last_sequence
}

///|
pub fn summarize_audit(trail : AuditTrail) -> AuditSummary {
  let records = trail.records()
  let sessions = []
  let mut successful = 0
  let mut warnings = 0
  let mut rejected = 0
  let mut failed = 0
  for record in records {
    if !sessions.contains(record.session_id) && !record.session_id.is_empty() {
      sessions.push(record.session_id)
    }
    match record.outcome {
      AuditOutcome::Accepted => successful += 1
      AuditOutcome::AcceptedWithWarnings => {
        successful += 1
        warnings += 1
      }
      AuditOutcome::Rejected => rejected += 1
      AuditOutcome::Failed => failed += 1
      AuditOutcome::Skipped => ()
    }
  }
  AuditSummary::{
    total: records.length(),
    successful,
    warnings,
    rejected,
    failed,
    unique_sessions: sessions.length(),
    first_sequence: if records.is_empty() {
      0
    } else {
      records[0].sequence
    },
    last_sequence: match records.last() {
      Some(value) => value.sequence
      None => 0
    },
  }
}

///|
pub fn AuditSummary::success_rate(self : AuditSummary) -> Double {
  if self.total == 0 {
    0.0
  } else {
    self.successful.to_double() / self.total.to_double()
  }
}

///|
pub fn audit_summary_text(value : AuditSummary) -> String {
  "records=" +
  value.total.to_string() +
  ", success=" +
  value.successful.to_string() +
  ", warnings=" +
  value.warnings.to_string() +
  ", rejected=" +
  value.rejected.to_string() +
  ", sessions=" +
  value.unique_sessions.to_string()
}
