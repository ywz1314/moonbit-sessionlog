///|
/// The disposition of a session during a retention pass.
pub(all) enum RetentionAction {
  Keep
  Archive
  Review
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RetentionAction::label(self : RetentionAction) -> String {
  match self {
    Keep => "keep"
    Archive => "archive"
    Review => "review"
  }
}

///|
/// Why a session received its retention disposition.
pub(all) enum RetentionReason {
  WithinWindow
  OlderThanWindow
  CapacityExceeded
  Duplicate
  HighPain
  HasClinicalNotes
  LowQuality
  InvalidData
  ManualReview
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RetentionReason::label(self : RetentionReason) -> String {
  match self {
    WithinWindow => "within_window"
    OlderThanWindow => "older_than_window"
    CapacityExceeded => "capacity_exceeded"
    Duplicate => "duplicate"
    HighPain => "high_pain"
    HasClinicalNotes => "has_clinical_notes"
    LowQuality => "low_quality"
    InvalidData => "invalid_data"
    ManualReview => "manual_review"
  }
}

///|
/// Policy values use zero to disable a limit. This makes the default policy
/// safe for callers that only want a report and do not want data removed.
pub(all) struct RetentionPolicy {
  mut max_age_days : Int
  mut max_sessions : Int
  mut high_pain_threshold : Int
  mut minimum_quality_score : Int
  mut keep_high_pain : Bool
  mut keep_notes : Bool
  mut keep_invalid : Bool
  mut deduplicate : Bool
  mut redact_notes : Bool
  mut anonymize_ids : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_policy() -> RetentionPolicy {
  RetentionPolicy::{
    max_age_days: 0,
    max_sessions: 0,
    high_pain_threshold: 7,
    minimum_quality_score: 0,
    keep_high_pain: true,
    keep_notes: true,
    keep_invalid: false,
    deduplicate: true,
    redact_notes: false,
    anonymize_ids: false,
  }
}

///|
pub fn archival_policy(max_age_days : Int) -> RetentionPolicy {
  let policy = default_policy()
  policy.max_age_days = Int::max(0, max_age_days)
  policy
}

///|
pub fn privacy_policy() -> RetentionPolicy {
  let policy = default_policy()
  policy.redact_notes = true
  policy.anonymize_ids = true
  policy.keep_notes = false
  policy
}

///|
pub fn bounded_policy(max_sessions : Int) -> RetentionPolicy {
  let policy = default_policy()
  policy.max_sessions = Int::max(0, max_sessions)
  policy
}

///|
pub fn policy_with_quality(minimum_quality_score : Int) -> RetentionPolicy {
  let policy = default_policy()
  policy.minimum_quality_score = minimum_quality_score.clamp(min=0, max=100)
  policy
}

///|
/// A deterministic summary for one planned disposition.
pub(all) struct RetentionDecision {
  session_id : String
  action : RetentionAction
  reason : RetentionReason
  age_days : Int
  quality_score : Int
  fingerprint : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RetentionDecision::session_id(self : RetentionDecision) -> String {
  self.session_id
}

///|
pub fn RetentionDecision::action(self : RetentionDecision) -> RetentionAction {
  self.action
}

///|
pub fn RetentionDecision::reason(self : RetentionDecision) -> RetentionReason {
  self.reason
}

///|
pub fn RetentionDecision::age_days(self : RetentionDecision) -> Int {
  self.age_days
}

///|
pub fn RetentionDecision::quality_score(self : RetentionDecision) -> Int {
  self.quality_score
}

///|
pub fn RetentionDecision::fingerprint(self : RetentionDecision) -> String {
  self.fingerprint
}

///|
pub fn RetentionDecision::is_archive(self : RetentionDecision) -> Bool {
  self.action == RetentionAction::Archive
}

///|
pub fn RetentionDecision::is_review(self : RetentionDecision) -> Bool {
  self.action == RetentionAction::Review
}

///|
pub(all) struct RetentionPlan {
  reference_date : String
  decisions : Array[RetentionDecision]
  kept_count : Int
  archived_count : Int
  review_count : Int
  duplicate_count : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RetentionPlan::reference_date(self : RetentionPlan) -> String {
  self.reference_date
}

///|
pub fn RetentionPlan::decisions(
  self : RetentionPlan,
) -> Array[RetentionDecision] {
  self.decisions.copy()
}

///|
pub fn RetentionPlan::kept_count(self : RetentionPlan) -> Int {
  self.kept_count
}

///|
pub fn RetentionPlan::archived_count(self : RetentionPlan) -> Int {
  self.archived_count
}

///|
pub fn RetentionPlan::review_count(self : RetentionPlan) -> Int {
  self.review_count
}

///|
pub fn RetentionPlan::duplicate_count(self : RetentionPlan) -> Int {
  self.duplicate_count
}

///|
fn stable_hash(value : String) -> Int {
  let mut hash = 216613626
  for code in value.code_units() {
    hash = (hash ^ code.to_int()) * 16777619
  }
  if hash < 0 {
    -hash
  } else {
    hash
  }
}

///|
/// Build an order-preserving fingerprint. It intentionally includes the full
/// clinical payload so records with the same id but different measurements do
/// not collapse into one archive item.
pub fn fingerprint(session : @core.Session) -> String {
  let builder = StringBuilder()
  builder.write_string(session.id)
  builder.write_string("|")
  builder.write_string(session.date)
  builder.write_string("|")
  builder.write_string(session.duration.to_string())
  builder.write_string("|")
  builder.write_string(session.pain_before.to_string())
  builder.write_string("|")
  builder.write_string(session.pain_after.to_string())
  for movement in session.movements {
    builder.write_string("|m:")
    builder.write_string(movement.name)
    builder.write_string(":")
    builder.write_string(movement.pain.to_string())
    builder.write_string(":")
    builder.write_string(movement.rpe.to_string())
    for set in movement.sets {
      builder.write_string("|s:")
      builder.write_string(set.reps.to_string())
      builder.write_string(":")
      builder.write_string(set.hold_time.to_string())
      builder.write_string(":")
      builder.write_string(set.resistance)
      builder.write_string(":")
      builder.write_string(set.completion.to_string())
    }
  }
  "fp-" + stable_hash(builder.to_string()).to_string()
}

///|
fn parse_age(session : @core.Session, reference_date : String) -> Int? {
  match (@calendar.parse(session.date), @calendar.parse(reference_date)) {
    (Some(session_date), Some(reference)) =>
      Some(@calendar.days_between(session_date, reference))
    _ => None
  }
}

///|
fn has_clinical_notes(session : @core.Session) -> Bool {
  !session.notes.trim().is_empty()
}

///|
fn first_reason(
  session : @core.Session,
  age_days : Int?,
  quality : Int,
  policy : RetentionPolicy,
) -> (RetentionAction, RetentionReason, Int) {
  let age = match age_days {
    Some(value) => value
    None => 0
  }
  if !@validation.is_valid(session) && !policy.keep_invalid {
    (RetentionAction::Review, RetentionReason::InvalidData, age)
  } else if policy.keep_high_pain &&
    session.average_pain_during() >= policy.high_pain_threshold.to_double() {
    (RetentionAction::Keep, RetentionReason::HighPain, age)
  } else if policy.keep_notes && has_clinical_notes(session) {
    (RetentionAction::Keep, RetentionReason::HasClinicalNotes, age)
  } else if policy.minimum_quality_score > 0 &&
    quality < policy.minimum_quality_score {
    (RetentionAction::Review, RetentionReason::LowQuality, age)
  } else if policy.max_age_days > 0 && age > policy.max_age_days {
    (RetentionAction::Archive, RetentionReason::OlderThanWindow, age)
  } else {
    (RetentionAction::Keep, RetentionReason::WithinWindow, age)
  }
}

///|
pub fn decide(
  session : @core.Session,
  reference_date : String,
  policy : RetentionPolicy,
) -> RetentionDecision {
  let quality = @quality.score(session).score()
  let (action, reason, age) = first_reason(
    session,
    parse_age(session, reference_date),
    quality,
    policy,
  )
  RetentionDecision::{
    session_id: session.id,
    action,
    reason,
    age_days: age,
    quality_score: quality,
    fingerprint: fingerprint(session),
  }
}

///|
fn mark_duplicate(decision : RetentionDecision) -> RetentionDecision {
  RetentionDecision::{
    session_id: decision.session_id,
    action: RetentionAction::Archive,
    reason: RetentionReason::Duplicate,
    age_days: decision.age_days,
    quality_score: decision.quality_score,
    fingerprint: decision.fingerprint,
  }
}

///|
pub fn plan(
  sessions : Array[@core.Session],
  reference_date : String,
  policy : RetentionPolicy,
) -> RetentionPlan {
  let decisions = []
  let fingerprints = []
  let mut kept_count = 0
  let mut duplicate_count = 0
  for session in sessions {
    let initial = decide(session, reference_date, policy)
    let decision = if policy.deduplicate &&
      fingerprints.contains(initial.fingerprint) {
      mark_duplicate(initial)
    } else {
      fingerprints.push(initial.fingerprint)
      initial
    }
    decisions.push(decision)
    match decision.action {
      RetentionAction::Keep => kept_count += 1
      RetentionAction::Archive | RetentionAction::Review => ()
    }
    if decision.reason == RetentionReason::Duplicate {
      duplicate_count += 1
    }
  }
  let limited = if policy.max_sessions > 0 && kept_count > policy.max_sessions {
    apply_capacity(decisions, policy.max_sessions)
  } else {
    decisions
  }
  let final_kept = limited.count_if(item => item.action == RetentionAction::Keep)
  let final_archived = limited.count_if(item => {
    item.action == RetentionAction::Archive
  })
  let final_review = limited.count_if(item => {
    item.action == RetentionAction::Review
  })
  RetentionPlan::{
    reference_date,
    decisions: limited,
    kept_count: final_kept,
    archived_count: final_archived,
    review_count: final_review,
    duplicate_count,
  }
}

///|
fn capacity_mark(decision : RetentionDecision) -> RetentionDecision {
  RetentionDecision::{
    session_id: decision.session_id,
    action: RetentionAction::Archive,
    reason: RetentionReason::CapacityExceeded,
    age_days: decision.age_days,
    quality_score: decision.quality_score,
    fingerprint: decision.fingerprint,
  }
}

///|
fn apply_capacity(
  decisions : Array[RetentionDecision],
  max_sessions : Int,
) -> Array[RetentionDecision] {
  let mut kept = 0
  decisions.map(decision => {
    if decision.action == RetentionAction::Keep {
      if kept < max_sessions {
        kept += 1
        decision
      } else {
        capacity_mark(decision)
      }
    } else {
      decision
    }
  })
}

///|
pub fn kept_sessions(
  sessions : Array[@core.Session],
  retention_plan : RetentionPlan,
) -> Array[@core.Session] {
  let kept_ids = retention_plan.decisions
    .filter(item => item.action == RetentionAction::Keep)
    .map(item => item.session_id)
  sessions.filter(session => kept_ids.contains(session.id))
}

///|
pub fn archived_sessions(
  sessions : Array[@core.Session],
  retention_plan : RetentionPlan,
) -> Array[@core.Session] {
  let ids = retention_plan.decisions
    .filter(item => item.action == RetentionAction::Archive)
    .map(item => item.session_id)
  sessions.filter(session => ids.contains(session.id))
}

///|
pub fn review_sessions(
  sessions : Array[@core.Session],
  retention_plan : RetentionPlan,
) -> Array[@core.Session] {
  let ids = retention_plan.decisions
    .filter(item => item.action == RetentionAction::Review)
    .map(item => item.session_id)
  sessions.filter(session => ids.contains(session.id))
}

///|
fn privacy_id(id : String) -> String {
  "session-" + stable_hash(id).to_string()
}

///|
pub fn redact_session(
  session : @core.Session,
  policy : RetentionPolicy,
) -> @core.Session {
  let movements = session.movements.map(movement => @core.Movement::{
    name: movement.name,
    sets: movement.sets.copy(),
    pain: movement.pain,
    rpe: movement.rpe,
  })
  @core.Session::{
    id: if policy.anonymize_ids {
      privacy_id(session.id)
    } else {
      session.id
    },
    date: session.date,
    duration: session.duration,
    pain_before: session.pain_before,
    pain_after: session.pain_after,
    movements,
    notes: if policy.redact_notes {
      "[redacted]"
    } else {
      session.notes
    },
  }
}

///|
pub(all) struct ArchiveEntry {
  session : @core.Session
  archived_on : String
  reason : RetentionReason
  age_days : Int
  fingerprint : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ArchiveEntry::session(self : ArchiveEntry) -> @core.Session {
  self.session
}

///|
pub fn ArchiveEntry::archived_on(self : ArchiveEntry) -> String {
  self.archived_on
}

///|
pub fn ArchiveEntry::reason(self : ArchiveEntry) -> RetentionReason {
  self.reason
}

///|
pub fn ArchiveEntry::age_days(self : ArchiveEntry) -> Int {
  self.age_days
}

///|
pub fn ArchiveEntry::fingerprint(self : ArchiveEntry) -> String {
  self.fingerprint
}

///|
pub(all) struct Archive {
  mut entries : Array[ArchiveEntry]
  mut revision : Int
} derive(Debug, Eq)

///|
pub fn Archive::new() -> Archive {
  Archive::{ entries: [], revision: 0 }
}

///|
pub fn Archive::revision(self : Archive) -> Int {
  self.revision
}

///|
pub fn Archive::count(self : Archive) -> Int {
  self.entries.length()
}

///|
pub fn Archive::is_empty(self : Archive) -> Bool {
  self.entries.is_empty()
}

///|
pub fn Archive::entries(self : Archive) -> Array[ArchiveEntry] {
  self.entries.copy()
}

///|
pub fn Archive::contains_id(self : Archive, id : String) -> Bool {
  self.entries.any(item => item.session.id == id)
}

///|
pub fn Archive::contains_fingerprint(self : Archive, value : String) -> Bool {
  self.entries.any(item => item.fingerprint == value)
}

///|
pub fn Archive::find(self : Archive, id : String) -> ArchiveEntry? {
  match self.entries.search_by(item => item.session.id == id) {
    Some(index) => Some(self.entries[index])
    None => None
  }
}

///|
pub fn Archive::by_reason(
  self : Archive,
  reason : RetentionReason,
) -> Array[ArchiveEntry] {
  self.entries.filter(item => item.reason == reason)
}

///|
pub fn Archive::add(
  self : Archive,
  session : @core.Session,
  archived_on : String,
  decision : RetentionDecision,
  policy : RetentionPolicy,
) -> Result[Unit, String] {
  if self.contains_fingerprint(decision.fingerprint) {
    Err("archive entry already exists: " + decision.fingerprint)
  } else {
    self.entries.push(ArchiveEntry::{
      session: redact_session(session, policy),
      archived_on,
      reason: decision.reason,
      age_days: decision.age_days,
      fingerprint: decision.fingerprint,
    })
    self.revision += 1
    Ok(())
  }
}

///|
pub fn Archive::remove(self : Archive, id : String) -> Bool {
  match self.entries.search_by(item => item.session.id == id) {
    Some(index) => {
      ignore(self.entries.remove(index))
      self.revision += 1
      true
    }
    None => false
  }
}

///|
pub fn Archive::clear(self : Archive) -> Unit {
  if !self.entries.is_empty() {
    self.entries.clear()
    self.revision += 1
  }
}

///|
pub fn Archive::restore_all(self : Archive) -> Array[@core.Session] {
  self.entries.map(item => item.session)
}

///|
pub fn Archive::restore_ids(
  self : Archive,
  ids : Array[String],
) -> Array[@core.Session] {
  self.entries
  .filter(item => ids.contains(item.session.id))
  .map(item => item.session)
}

///|
pub fn Archive::duplicate_groups(self : Archive) -> Array[Array[ArchiveEntry]] {
  let groups : Array[Array[ArchiveEntry]] = []
  let seen = []
  for entry in self.entries {
    if !seen.contains(entry.fingerprint) {
      let group = self.entries.filter(item => {
        item.fingerprint == entry.fingerprint
      })
      if group.length() > 1 {
        groups.push(group)
      }
      seen.push(entry.fingerprint)
    }
  }
  groups
}

///|
pub fn Archive::json(self : Archive) -> String {
  @json.to_json(self.entries).stringify()
}

///|
pub fn Archive::pretty_json(self : Archive) -> String {
  @json.to_json(self.entries).stringify(indent=2)
}

///|
pub fn parse_archive(json : String) -> Result[Archive, String] {
  try {
    let entries : Array[ArchiveEntry] = @json.from_json(@json.parse(json))
    Ok(Archive::{ entries, revision: 0 })
  } catch {
    error => Err("invalid archive JSON: " + error.to_string())
  }
}

///|
pub fn archive_plan(
  archive : Archive,
  sessions : Array[@core.Session],
  retention_plan : RetentionPlan,
  archived_on : String,
  policy : RetentionPolicy,
) -> (Archive, Array[String]) {
  let failures = []
  let result = archive
  for session in archived_sessions(sessions, retention_plan) {
    match decision_for(retention_plan, session.id) {
      Some(decision) =>
        match result.add(session, archived_on, decision, policy) {
          Ok(_) => ()
          Err(error) => failures.push(error)
        }
      None => failures.push("missing retention decision: " + session.id)
    }
  }
  (result, failures)
}

///|
pub fn archive_report(retention_plan : RetentionPlan) -> String {
  let output = StringBuilder()
  output.write_string("retention reference: ")
  output.write_string(retention_plan.reference_date)
  output.write_string("\nkeep: ")
  output.write_string(retention_plan.kept_count.to_string())
  output.write_string("\narchive: ")
  output.write_string(retention_plan.archived_count.to_string())
  output.write_string("\nreview: ")
  output.write_string(retention_plan.review_count.to_string())
  output.write_string("\nduplicates: ")
  output.write_string(retention_plan.duplicate_count.to_string())
  output.write_string("\n")
  for decision in retention_plan.decisions {
    output.write_string(decision.session_id)
    output.write_string(" | ")
    output.write_string(decision.action.label())
    output.write_string(" | ")
    output.write_string(decision.reason.label())
    output.write_string(" | age=")
    output.write_string(decision.age_days.to_string())
    output.write_string(" | quality=")
    output.write_string(decision.quality_score.to_string())
    output.write_string("\n")
  }
  output.to_string()
}

///|
pub fn reason_counts(
  decisions : Array[RetentionDecision],
) -> Array[(RetentionReason, Int)] {
  let result : Array[(RetentionReason, Int)] = []
  let reasons = [
    RetentionReason::WithinWindow,
    RetentionReason::OlderThanWindow,
    RetentionReason::CapacityExceeded,
    RetentionReason::Duplicate,
    RetentionReason::HighPain,
    RetentionReason::HasClinicalNotes,
    RetentionReason::LowQuality,
    RetentionReason::InvalidData,
    RetentionReason::ManualReview,
  ]
  for reason in reasons {
    let count = decisions.count_if(item => item.reason == reason)
    if count > 0 {
      result.push((reason, count))
    }
  }
  result
}

///|
pub fn action_counts(decisions : Array[RetentionDecision]) -> (Int, Int, Int) {
  (
    decisions.count_if(item => item.action == RetentionAction::Keep),
    decisions.count_if(item => item.action == RetentionAction::Archive),
    decisions.count_if(item => item.action == RetentionAction::Review),
  )
}

///|
pub fn validate_policy(policy : RetentionPolicy) -> Array[String] {
  let errors = []
  if policy.max_age_days < 0 {
    errors.push("max_age_days must be non-negative")
  }
  if policy.max_sessions < 0 {
    errors.push("max_sessions must be non-negative")
  }
  if policy.high_pain_threshold < 0 || policy.high_pain_threshold > 10 {
    errors.push("high_pain_threshold must be between 0 and 10")
  }
  if policy.minimum_quality_score < 0 || policy.minimum_quality_score > 100 {
    errors.push("minimum_quality_score must be between 0 and 100")
  }
  errors
}

///|
pub fn safe_plan(
  sessions : Array[@core.Session],
  reference_date : String,
  policy : RetentionPolicy,
) -> Result[RetentionPlan, String] {
  let policy_errors = validate_policy(policy)
  if !policy_errors.is_empty() {
    Err(policy_errors.join("; "))
  } else if @calendar.parse(reference_date) is None {
    Err("reference_date must use YYYY-MM-DD")
  } else {
    Ok(plan(sessions, reference_date, policy))
  }
}

///|
pub fn decision_for(
  retention_plan : RetentionPlan,
  id : String,
) -> RetentionDecision? {
  match retention_plan.decisions.search_by(item => item.session_id == id) {
    Some(index) => Some(retention_plan.decisions[index])
    None => None
  }
}

///|
pub fn older_than(
  sessions : Array[@core.Session],
  reference_date : String,
  days : Int,
) -> Array[@core.Session] {
  let policy = archival_policy(days)
  let retention_plan = plan(sessions, reference_date, policy)
  archived_sessions(sessions, retention_plan)
}

///|
pub fn high_pain_sessions(
  sessions : Array[@core.Session],
  threshold : Int,
) -> Array[@core.Session] {
  sessions.filter(session => {
    session.average_pain_during() >= threshold.to_double()
  })
}

///|
pub fn archive_size_by_reason(archive : Archive) -> Array[(String, Int)] {
  reason_counts(
    archive.entries.map(item => RetentionDecision::{
      session_id: item.session.id,
      action: RetentionAction::Archive,
      reason: item.reason,
      age_days: item.age_days,
      quality_score: 0,
      fingerprint: item.fingerprint,
    }),
  ).map(item => (item.0.label(), item.1))
}

///|
pub fn retention_checksum(retention_plan : RetentionPlan) -> Int {
  retention_plan.decisions.fold(init=19, (value, decision) => {
    value * 31 +
    stable_hash(decision.session_id) +
    decision.age_days +
    decision.quality_score
  })
}
