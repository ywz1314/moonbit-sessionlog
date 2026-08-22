///|
/// A small state machine for moving a rehabilitation case from intake to
/// closure.  The model is storage-agnostic and suitable for dashboards,
/// queue workers, or a command-line review tool.
pub(all) enum CaseState {
  Intake
  Active
  Paused
  Review
  Completed
  Archived
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CaseState::label(self : CaseState) -> String {
  match self {
    Intake => "intake"
    Active => "active"
    Paused => "paused"
    Review => "review"
    Completed => "completed"
    Archived => "archived"
  }
}

///|
pub fn CaseState::terminal(self : CaseState) -> Bool {
  self == CaseState::Completed || self == CaseState::Archived
}

///|
pub fn CaseState::open(self : CaseState) -> Bool {
  !self.terminal()
}

///|
pub(all) enum CaseEvent {
  Created
  SessionRecorded
  SessionImported
  RiskRaised
  QualityBlocked
  ProgressReviewed
  PausedByUser
  ResumedByUser
  CompletedByUser
  ArchivedByUser
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CaseEvent::label(self : CaseEvent) -> String {
  match self {
    Created => "created"
    SessionRecorded => "session_recorded"
    SessionImported => "session_imported"
    RiskRaised => "risk_raised"
    QualityBlocked => "quality_blocked"
    ProgressReviewed => "progress_reviewed"
    PausedByUser => "paused_by_user"
    ResumedByUser => "resumed_by_user"
    CompletedByUser => "completed_by_user"
    ArchivedByUser => "archived_by_user"
  }
}

///|
pub(all) enum TransitionError {
  TerminalCase
  InvalidState
  MissingReason
  MissingSession
  QualityGate
  RiskGate
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn TransitionError::label(self : TransitionError) -> String {
  match self {
    TerminalCase => "terminal_case"
    InvalidState => "invalid_state"
    MissingReason => "missing_reason"
    MissingSession => "missing_session"
    QualityGate => "quality_gate"
    RiskGate => "risk_gate"
  }
}

///|
pub fn TransitionError::message(self : TransitionError) -> String {
  match self {
    TerminalCase => "terminal cases cannot transition"
    InvalidState => "the requested transition is not allowed"
    MissingReason => "a reason is required"
    MissingSession => "at least one session is required"
    QualityGate => "quality gate is not satisfied"
    RiskGate => "risk gate requires review"
  }
}

///|
pub(all) struct CasePolicy {
  minimum_sessions_for_review : Int
  require_quality_pass : Bool
  maximum_review_risk : @risk.RiskLevel
  require_completion_reason : Bool
  allow_archive_from_paused : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_case_policy() -> CasePolicy {
  CasePolicy::{
    minimum_sessions_for_review: 1,
    require_quality_pass: true,
    maximum_review_risk: @risk.RiskLevel::Elevated,
    require_completion_reason: true,
    allow_archive_from_paused: true,
  }
}

///|
pub fn permissive_case_policy() -> CasePolicy {
  CasePolicy::{
    minimum_sessions_for_review: 0,
    require_quality_pass: false,
    maximum_review_risk: @risk.RiskLevel::Critical,
    require_completion_reason: false,
    allow_archive_from_paused: true,
  }
}

///|
pub fn CasePolicy::validate(self : CasePolicy) -> Array[String] {
  let errors = []
  if self.minimum_sessions_for_review < 0 {
    errors.push("minimum_sessions_for_review must be non-negative")
  }
  errors
}

///|
pub(all) struct CaseTransition {
  from : CaseState
  to : CaseState
  event : CaseEvent
  reason : String
  revision : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CaseTransition::from(self : CaseTransition) -> CaseState {
  self.from
}

///|
pub fn CaseTransition::to(self : CaseTransition) -> CaseState {
  self.to
}

///|
pub fn CaseTransition::event(self : CaseTransition) -> CaseEvent {
  self.event
}

///|
pub fn CaseTransition::reason(self : CaseTransition) -> String {
  self.reason
}

///|
pub fn CaseTransition::revision(self : CaseTransition) -> Int {
  self.revision
}

///|
pub(all) struct WorkflowCase {
  id : String
  subject_id : String
  state : CaseState
  created_date : String
  updated_date : String
  session_ids : Array[String]
  transitions : Array[CaseTransition]
  last_risk : @risk.RiskLevel
  quality_passed : Bool
  revision : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn WorkflowCase::id(self : WorkflowCase) -> String {
  self.id
}

///|
pub fn WorkflowCase::subject_id(self : WorkflowCase) -> String {
  self.subject_id
}

///|
pub fn WorkflowCase::state(self : WorkflowCase) -> CaseState {
  self.state
}

///|
pub fn WorkflowCase::created_date(self : WorkflowCase) -> String {
  self.created_date
}

///|
pub fn WorkflowCase::updated_date(self : WorkflowCase) -> String {
  self.updated_date
}

///|
pub fn WorkflowCase::session_ids(self : WorkflowCase) -> Array[String] {
  self.session_ids.copy()
}

///|
pub fn WorkflowCase::transitions(self : WorkflowCase) -> Array[CaseTransition] {
  self.transitions.copy()
}

///|
pub fn WorkflowCase::last_risk(self : WorkflowCase) -> @risk.RiskLevel {
  self.last_risk
}

///|
pub fn WorkflowCase::quality_passed(self : WorkflowCase) -> Bool {
  self.quality_passed
}

///|
pub fn WorkflowCase::revision(self : WorkflowCase) -> Int {
  self.revision
}

///|
pub fn WorkflowCase::session_count(self : WorkflowCase) -> Int {
  self.session_ids.length()
}

///|
pub fn new_case(
  id : String,
  subject_id : String,
  date : String,
) -> Result[WorkflowCase, String] {
  if id.trim().is_empty() {
    return Err("case id is required")
  }
  if subject_id.trim().is_empty() {
    return Err("subject id is required")
  }
  Ok(WorkflowCase::{
    id,
    subject_id,
    state: CaseState::Intake,
    created_date: date,
    updated_date: date,
    session_ids: [],
    transitions: [],
    last_risk: @risk.RiskLevel::Low,
    quality_passed: false,
    revision: 0,
  })
}

///|
pub fn case_with_quality(value : WorkflowCase, passed : Bool) -> WorkflowCase {
  WorkflowCase::{
    id: value.id,
    subject_id: value.subject_id,
    state: value.state,
    created_date: value.created_date,
    updated_date: value.updated_date,
    session_ids: value.session_ids,
    transitions: value.transitions,
    last_risk: value.last_risk,
    quality_passed: passed,
    revision: value.revision,
  }
}

///|
pub fn case_with_risk(
  value : WorkflowCase,
  risk : @risk.RiskLevel,
) -> WorkflowCase {
  WorkflowCase::{
    id: value.id,
    subject_id: value.subject_id,
    state: value.state,
    created_date: value.created_date,
    updated_date: value.updated_date,
    session_ids: value.session_ids,
    transitions: value.transitions,
    last_risk: risk,
    quality_passed: value.quality_passed,
    revision: value.revision,
  }
}

///|
pub fn case_add_session(
  value : WorkflowCase,
  session_id : String,
) -> WorkflowCase {
  let ids = value.session_ids.copy()
  if !session_id.trim().is_empty() && !ids.contains(session_id) {
    ids.push(session_id)
  }
  WorkflowCase::{
    id: value.id,
    subject_id: value.subject_id,
    state: value.state,
    created_date: value.created_date,
    updated_date: value.updated_date,
    session_ids: ids,
    transitions: value.transitions,
    last_risk: value.last_risk,
    quality_passed: value.quality_passed,
    revision: value.revision,
  }
}

///|
fn can_move(from : CaseState, to : CaseState, policy : CasePolicy) -> Bool {
  match (from, to) {
    (CaseState::Intake, CaseState::Active) => true
    (CaseState::Intake, CaseState::Archived) => true
    (CaseState::Active, CaseState::Paused) => true
    (CaseState::Active, CaseState::Review) => true
    (CaseState::Active, CaseState::Completed) => true
    (CaseState::Active, CaseState::Archived) => true
    (CaseState::Paused, CaseState::Active) => true
    (CaseState::Paused, CaseState::Review) => true
    (CaseState::Paused, CaseState::Archived) => policy.allow_archive_from_paused
    (CaseState::Review, CaseState::Active) => true
    (CaseState::Review, CaseState::Completed) => true
    (CaseState::Review, CaseState::Paused) => true
    (CaseState::Review, CaseState::Archived) => true
    _ => false
  }
}

///|
fn transition_event(to : CaseState) -> CaseEvent {
  match to {
    CaseState::Active => CaseEvent::ResumedByUser
    CaseState::Paused => CaseEvent::PausedByUser
    CaseState::Review => CaseEvent::ProgressReviewed
    CaseState::Completed => CaseEvent::CompletedByUser
    CaseState::Archived => CaseEvent::ArchivedByUser
    CaseState::Intake => CaseEvent::Created
  }
}

///|
pub fn transition(
  value : WorkflowCase,
  to : CaseState,
  date : String,
  reason : String,
  policy : CasePolicy,
) -> Result[WorkflowCase, TransitionError] {
  if value.state.terminal() {
    return Err(TransitionError::TerminalCase)
  }
  if !can_move(value.state, to, policy) {
    return Err(TransitionError::InvalidState)
  }
  if policy.require_completion_reason &&
    to == CaseState::Completed &&
    reason.trim().is_empty() {
    return Err(TransitionError::MissingReason)
  }
  if to == CaseState::Review &&
    value.session_count() < policy.minimum_sessions_for_review {
    return Err(TransitionError::MissingSession)
  }
  if to == CaseState::Review &&
    policy.require_quality_pass &&
    !value.quality_passed {
    return Err(TransitionError::QualityGate)
  }
  if to == CaseState::Completed &&
    value.last_risk.rank() > policy.maximum_review_risk.rank() {
    return Err(TransitionError::RiskGate)
  }
  let revision = value.revision + 1
  let event = transition_event(to)
  let history = value.transitions.copy()
  history.push(CaseTransition::{
    from: value.state,
    to,
    event,
    reason,
    revision,
  })
  Ok(WorkflowCase::{
    id: value.id,
    subject_id: value.subject_id,
    state: to,
    created_date: value.created_date,
    updated_date: date,
    session_ids: value.session_ids,
    transitions: history,
    last_risk: value.last_risk,
    quality_passed: value.quality_passed,
    revision,
  })
}

///|
pub fn record_session(
  value : WorkflowCase,
  session : @core.Session,
  imported : Bool,
) -> WorkflowCase {
  let next = case_add_session(value, session.id)
  let history = next.transitions.copy()
  history.push(CaseTransition::{
    from: next.state,
    to: next.state,
    event: if imported {
      CaseEvent::SessionImported
    } else {
      CaseEvent::SessionRecorded
    },
    reason: "session=" + session.id,
    revision: next.revision + 1,
  })
  WorkflowCase::{
    id: next.id,
    subject_id: next.subject_id,
    state: next.state,
    created_date: next.created_date,
    updated_date: session.date,
    session_ids: next.session_ids,
    transitions: history,
    last_risk: next.last_risk,
    quality_passed: next.quality_passed,
    revision: next.revision + 1,
  }
}

///|
pub fn case_is_ready_for_review(
  value : WorkflowCase,
  policy : CasePolicy,
) -> Bool {
  value.session_count() >= policy.minimum_sessions_for_review &&
  (!policy.require_quality_pass || value.quality_passed) &&
  value.last_risk.rank() <= policy.maximum_review_risk.rank()
}

///|
pub fn case_is_ready_for_completion(
  value : WorkflowCase,
  policy : CasePolicy,
) -> Bool {
  case_is_ready_for_review(value, policy) && value.state == CaseState::Review
}

///|
pub fn case_next_actions(
  value : WorkflowCase,
  policy : CasePolicy,
) -> Array[String] {
  let actions = []
  match value.state {
    CaseState::Intake => actions.push("activate")
    CaseState::Active => {
      actions.push("record_session")
      actions.push("pause")
      if case_is_ready_for_review(value, policy) {
        actions.push("review")
      }
    }
    CaseState::Paused => {
      actions.push("resume")
      if case_is_ready_for_review(value, policy) {
        actions.push("review")
      }
      if policy.allow_archive_from_paused {
        actions.push("archive")
      }
    }
    CaseState::Review => {
      actions.push("resume")
      if case_is_ready_for_completion(value, policy) {
        actions.push("complete")
      }
      actions.push("pause")
      actions.push("archive")
    }
    CaseState::Completed => actions.push("archive")
    CaseState::Archived => ()
  }
  actions
}

///|
pub(all) struct GateReport {
  case_id : String
  state : CaseState
  ready_for_review : Bool
  ready_for_completion : Bool
  quality_passed : Bool
  risk_acceptable : Bool
  session_count : Int
  blockers : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn GateReport::case_id(self : GateReport) -> String {
  self.case_id
}

///|
pub fn GateReport::state(self : GateReport) -> CaseState {
  self.state
}

///|
pub fn GateReport::ready_for_review(self : GateReport) -> Bool {
  self.ready_for_review
}

///|
pub fn GateReport::ready_for_completion(self : GateReport) -> Bool {
  self.ready_for_completion
}

///|
pub fn GateReport::quality_passed(self : GateReport) -> Bool {
  self.quality_passed
}

///|
pub fn GateReport::risk_acceptable(self : GateReport) -> Bool {
  self.risk_acceptable
}

///|
pub fn GateReport::session_count(self : GateReport) -> Int {
  self.session_count
}

///|
pub fn GateReport::blockers(self : GateReport) -> Array[String] {
  self.blockers.copy()
}

///|
pub fn gate_report(value : WorkflowCase, policy : CasePolicy) -> GateReport {
  let blockers = []
  let enough_sessions = value.session_count() >=
    policy.minimum_sessions_for_review
  let quality_ok = !policy.require_quality_pass || value.quality_passed
  let risk_ok = value.last_risk.rank() <= policy.maximum_review_risk.rank()
  if !enough_sessions {
    blockers.push("minimum_sessions")
  }
  if !quality_ok {
    blockers.push("quality")
  }
  if !risk_ok {
    blockers.push("risk")
  }
  if value.state == CaseState::Intake {
    blockers.push("activate_case")
  }
  GateReport::{
    case_id: value.id,
    state: value.state,
    ready_for_review: enough_sessions && quality_ok && risk_ok,
    ready_for_completion: enough_sessions &&
    quality_ok &&
    risk_ok &&
    value.state == CaseState::Review,
    quality_passed: value.quality_passed,
    risk_acceptable: risk_ok,
    session_count: value.session_count(),
    blockers,
  }
}

///|
pub fn gate_report_text(value : GateReport) -> String {
  "case=" +
  value.case_id +
  " state=" +
  value.state.label() +
  " review=" +
  value.ready_for_review.to_string() +
  " complete=" +
  value.ready_for_completion.to_string() +
  " blockers=" +
  value.blockers.join(",")
}

///|
pub fn transition_error_text(error : TransitionError) -> String {
  error.label() + ": " + error.message()
}

///|
pub fn transition_text(value : CaseTransition) -> String {
  "#" +
  value.revision.to_string() +
  " " +
  value.from.label() +
  " -> " +
  value.to.label() +
  " " +
  value.event.label() +
  " " +
  value.reason
}

///|
pub fn case_timeline(value : WorkflowCase) -> Array[String] {
  value.transitions.map(transition_text)
}

///|
pub fn case_timeline_text(value : WorkflowCase) -> String {
  case_timeline(value).join("\n")
}

///|
pub fn case_has_event(value : WorkflowCase, event : CaseEvent) -> Bool {
  value.transitions.any(transition => transition.event == event)
}

///|
pub fn case_event_count(value : WorkflowCase, event : CaseEvent) -> Int {
  value.transitions.count_if(transition => transition.event == event)
}

///|
pub fn case_last_transition(value : WorkflowCase) -> CaseTransition? {
  value.transitions.last()
}

///|
pub fn case_transition_count(value : WorkflowCase) -> Int {
  value.transitions.length()
}

///|
pub fn case_is_stale(value : WorkflowCase, latest_revision : Int) -> Bool {
  latest_revision > value.revision
}

///|
pub fn case_merge(
  value : WorkflowCase,
  other : WorkflowCase,
) -> Result[WorkflowCase, String] {
  if value.id != other.id {
    return Err("cannot merge different cases")
  }
  if value.subject_id != other.subject_id {
    return Err("case subject differs")
  }
  let winner = if other.revision > value.revision { other } else { value }
  let ids = value.session_ids.copy()
  for id in other.session_ids {
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  let transitions = value.transitions.copy()
  for transition in other.transitions {
    if !transitions.contains(transition) {
      transitions.push(transition)
    }
  }
  transitions.sort_by((left, right) => left.revision - right.revision)
  Ok(WorkflowCase::{
    id: winner.id,
    subject_id: winner.subject_id,
    state: winner.state,
    created_date: if value.created_date < other.created_date {
      value.created_date
    } else {
      other.created_date
    },
    updated_date: if value.updated_date > other.updated_date {
      value.updated_date
    } else {
      other.updated_date
    },
    session_ids: ids,
    transitions,
    last_risk: winner.last_risk,
    quality_passed: value.quality_passed || other.quality_passed,
    revision: Int::max(value.revision, other.revision),
  })
}

///|
pub(all) struct CaseQueueSummary {
  total : Int
  intake : Int
  active : Int
  paused : Int
  review : Int
  completed : Int
  archived : Int
  blocked : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn summarize_cases(
  cases : Array[WorkflowCase],
  policy : CasePolicy,
) -> CaseQueueSummary {
  let mut intake = 0
  let mut active = 0
  let mut paused = 0
  let mut review = 0
  let mut completed = 0
  let mut archived = 0
  let mut blocked = 0
  for value in cases {
    match value.state {
      CaseState::Intake => intake += 1
      CaseState::Active => active += 1
      CaseState::Paused => paused += 1
      CaseState::Review => review += 1
      CaseState::Completed => completed += 1
      CaseState::Archived => archived += 1
    }
    if !gate_report(value, policy).blockers.is_empty() {
      blocked += 1
    }
  }
  CaseQueueSummary::{
    total: cases.length(),
    intake,
    active,
    paused,
    review,
    completed,
    archived,
    blocked,
  }
}

///|
pub fn queue_summary_text(value : CaseQueueSummary) -> String {
  "total=" +
  value.total.to_string() +
  " active=" +
  value.active.to_string() +
  " review=" +
  value.review.to_string() +
  " blocked=" +
  value.blocked.to_string() +
  " completed=" +
  value.completed.to_string()
}
