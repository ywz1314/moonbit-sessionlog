///|
/// Guardrails turn safety reports into executable import and scheduling
/// decisions.  They are deliberately fail-safe when evidence is incomplete.
pub(all) enum GuardrailDecision {
  Allow
  AllowWithReview
  Hold
  Reject
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn GuardrailDecision::label(self : GuardrailDecision) -> String {
  match self {
    Allow => "allow"
    AllowWithReview => "allow_with_review"
    Hold => "hold"
    Reject => "reject"
  }
}

///|
pub(all) struct GuardrailPolicy {
  allow_amber : Bool
  maximum_red_score : Int
  require_notes_for_high_pain : Bool
  maximum_duration : Int
  maximum_movements : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_guardrail_policy() -> GuardrailPolicy {
  GuardrailPolicy::{
    allow_amber: true,
    maximum_red_score: 40,
    require_notes_for_high_pain: true,
    maximum_duration: 480,
    maximum_movements: 30,
  }
}

///|
pub fn GuardrailPolicy::validate(self : GuardrailPolicy) -> Array[String] {
  let errors = []
  if self.maximum_red_score < 0 {
    errors.push("maximum_red_score must be non-negative")
  }
  if self.maximum_duration <= 0 {
    errors.push("maximum_duration must be positive")
  }
  if self.maximum_movements <= 0 {
    errors.push("maximum_movements must be positive")
  }
  errors
}

///|
pub(all) struct GuardrailResult {
  session_id : String
  decision : GuardrailDecision
  safety : SafetyReport
  blockers : Array[String]
  warnings : Array[String]
  next_action : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn GuardrailResult::session_id(self : GuardrailResult) -> String {
  self.session_id
}

///|
pub fn GuardrailResult::decision(self : GuardrailResult) -> GuardrailDecision {
  self.decision
}

///|
pub fn GuardrailResult::safety(self : GuardrailResult) -> SafetyReport {
  self.safety
}

///|
pub fn GuardrailResult::blockers(self : GuardrailResult) -> Array[String] {
  self.blockers.copy()
}

///|
pub fn GuardrailResult::warnings(self : GuardrailResult) -> Array[String] {
  self.warnings.copy()
}

///|
pub fn GuardrailResult::next_action(self : GuardrailResult) -> String {
  self.next_action
}

///|
pub fn apply_guardrails(
  session : @core.Session,
  policy : GuardrailPolicy,
) -> GuardrailResult {
  let safety = evaluate(session)
  let blockers = []
  let warnings = []
  if safety.level() == SafetyLevel::Red {
    blockers.push("safety report is red")
  }
  if safety.score() > policy.maximum_red_score {
    blockers.push("safety score exceeds policy")
  }
  if session.duration > policy.maximum_duration {
    blockers.push("duration exceeds policy")
  }
  if session.movements.length() > policy.maximum_movements {
    blockers.push("movement count exceeds policy")
  }
  if policy.require_notes_for_high_pain &&
    session.pain_after >= 7 &&
    session.notes.trim().is_empty() {
    blockers.push("high pain requires notes")
  }
  if safety.level() == SafetyLevel::Amber {
    warnings.push("amber findings require review")
  }
  let decision = if !blockers.is_empty() {
    GuardrailDecision::Reject
  } else if safety.level() == SafetyLevel::Amber {
    if policy.allow_amber {
      GuardrailDecision::AllowWithReview
    } else {
      GuardrailDecision::Hold
    }
  } else {
    GuardrailDecision::Allow
  }
  let next_action = match decision {
    GuardrailDecision::Allow => "continue normal processing"
    GuardrailDecision::AllowWithReview => "process and create review task"
    GuardrailDecision::Hold => "hold until safety review"
    GuardrailDecision::Reject => "reject and request corrected record"
  }
  GuardrailResult::{
    session_id: session.id,
    decision,
    safety,
    blockers,
    warnings,
    next_action,
  }
}

///|
pub fn guardrail_safe(value : GuardrailResult) -> Bool {
  value.decision == GuardrailDecision::Allow ||
  value.decision == GuardrailDecision::AllowWithReview
}

///|
pub fn guardrail_hold(value : GuardrailResult) -> Bool {
  value.decision == GuardrailDecision::Hold ||
  value.decision == GuardrailDecision::Reject
}

///|
pub fn guardrail_many(
  sessions : Array[@core.Session],
  policy : GuardrailPolicy,
) -> Array[GuardrailResult] {
  sessions.map(session => apply_guardrails(session, policy))
}

///|
pub fn guardrail_blocked(
  values : Array[GuardrailResult],
) -> Array[GuardrailResult] {
  values.filter(value => guardrail_hold(value))
}

///|
pub fn guardrail_review(
  values : Array[GuardrailResult],
) -> Array[GuardrailResult] {
  values.filter(value => value.decision == GuardrailDecision::AllowWithReview)
}

///|
pub fn guardrail_decision_counts(
  values : Array[GuardrailResult],
) -> Array[(String, Int)] {
  let counts : Array[(String, Int)] = []
  for value in values {
    let label = value.decision.label()
    match counts.search_by(item => item.0 == label) {
      Some(index) => {
        let old = counts[index]
        counts[index] = (old.0, old.1 + 1)
      }
      None => counts.push((label, 1))
    }
  }
  counts
}

///|
pub fn guardrail_text(value : GuardrailResult) -> String {
  value.session_id +
  " " +
  value.decision.label() +
  " blockers=" +
  value.blockers.length().to_string() +
  " warnings=" +
  value.warnings.length().to_string() +
  " action=" +
  value.next_action
}

///|
pub fn guardrail_report_text(values : Array[GuardrailResult]) -> String {
  "records=" +
  values.length().to_string() +
  ", blocked=" +
  guardrail_blocked(values).length().to_string() +
  ", review=" +
  guardrail_review(values).length().to_string() +
  ", safe=" +
  values.count_if(value => guardrail_safe(value)).to_string()
}
