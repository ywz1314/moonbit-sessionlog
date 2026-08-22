///|
/// Escalation metadata converts raw alerts into a bounded review workflow.
pub(all) enum EscalationAction {
  Log
  Notify
  ReviewToday
  PauseProgression
  EscalateNow
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn EscalationAction::label(self : EscalationAction) -> String {
  match self {
    Log => "log"
    Notify => "notify"
    ReviewToday => "review_today"
    PauseProgression => "pause_progression"
    EscalateNow => "escalate_now"
  }
}

///|
pub fn EscalationAction::rank(self : EscalationAction) -> Int {
  match self {
    Log => 0
    Notify => 1
    ReviewToday => 2
    PauseProgression => 3
    EscalateNow => 4
  }
}

///|
pub(all) struct EscalationStep {
  threshold : Int
  action : EscalationAction
  owner : String
  response_hours : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn EscalationStep::threshold(self : EscalationStep) -> Int {
  self.threshold
}

///|
pub fn EscalationStep::action(self : EscalationStep) -> EscalationAction {
  self.action
}

///|
pub fn EscalationStep::owner(self : EscalationStep) -> String {
  self.owner
}

///|
pub fn EscalationStep::response_hours(self : EscalationStep) -> Int {
  self.response_hours
}

///|
pub fn default_escalation_steps() -> Array[EscalationStep] {
  [
    EscalationStep::{
      threshold: 0,
      action: EscalationAction::Log,
      owner: "system",
      response_hours: 72,
    },
    EscalationStep::{
      threshold: 1,
      action: EscalationAction::Notify,
      owner: "care-team",
      response_hours: 24,
    },
    EscalationStep::{
      threshold: 2,
      action: EscalationAction::ReviewToday,
      owner: "clinician",
      response_hours: 8,
    },
    EscalationStep::{
      threshold: 3,
      action: EscalationAction::PauseProgression,
      owner: "clinician",
      response_hours: 2,
    },
    EscalationStep::{
      threshold: 4,
      action: EscalationAction::EscalateNow,
      owner: "on-call",
      response_hours: 1,
    },
  ]
}

///|
pub fn escalation_score(alerts : Array[SessionAlert]) -> Int {
  alerts.fold(init=0, (total, alert) => {
    let value = match alert.severity {
      AlertSeverity::Notice => 1
      AlertSeverity::Warning => 2
      AlertSeverity::Critical => 4
    }
    total + value
  })
}

///|
pub fn escalation_action(
  score : Int,
  steps? : Array[EscalationStep] = default_escalation_steps(),
) -> EscalationStep {
  steps.fold(init=steps[0], (best, candidate) => {
    if score >= candidate.threshold && candidate.threshold >= best.threshold {
      candidate
    } else {
      best
    }
  })
}

///|
pub(all) struct EscalationPlan {
  session_id : String
  score : Int
  action : EscalationAction
  owner : String
  response_hours : Int
  alerts : Array[SessionAlert]
  rationale : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn EscalationPlan::session_id(self : EscalationPlan) -> String {
  self.session_id
}

///|
pub fn EscalationPlan::score(self : EscalationPlan) -> Int {
  self.score
}

///|
pub fn EscalationPlan::action(self : EscalationPlan) -> EscalationAction {
  self.action
}

///|
pub fn EscalationPlan::owner(self : EscalationPlan) -> String {
  self.owner
}

///|
pub fn EscalationPlan::response_hours(self : EscalationPlan) -> Int {
  self.response_hours
}

///|
pub fn EscalationPlan::alerts(self : EscalationPlan) -> Array[SessionAlert] {
  self.alerts
}

///|
pub fn EscalationPlan::rationale(self : EscalationPlan) -> String {
  self.rationale
}

///|
pub fn plan(
  alerts : Array[SessionAlert],
  steps? : Array[EscalationStep] = default_escalation_steps(),
) -> EscalationPlan {
  let score = escalation_score(alerts)
  let selected = escalation_action(score, steps~)
  let session_id = alerts.get(0).map(item => item.session_id).unwrap_or("")
  EscalationPlan::{
    session_id,
    score,
    action: selected.action,
    owner: selected.owner,
    response_hours: selected.response_hours,
    alerts,
    rationale: if score == 0 {
      "No alert requires action."
    } else {
      "Alert score " +
      score.to_string() +
      " selects " +
      selected.action.label() +
      "."
    },
  }
}

///|
pub fn deduplicate(alerts : Array[SessionAlert]) -> Array[SessionAlert] {
  let keys = []
  let result = []
  for alert in alerts {
    let key = alert.session_id + "|" + alert.alert_type.label()
    if !keys.contains(key) {
      keys.push(key)
      result.push(alert)
    }
  }
  result
}

///|
pub fn group_by_session(
  alerts : Array[SessionAlert],
) -> Array[(String, Array[SessionAlert])] {
  let groups : Map[String, Array[SessionAlert]] = Map([])
  for alert in alerts {
    match groups.get(alert.session_id) {
      Some(items) => items.push(alert)
      None => groups[alert.session_id] = [alert]
    }
  }
  groups.to_array()
}

///|
pub fn plans(alerts : Array[SessionAlert]) -> Array[EscalationPlan] {
  group_by_session(deduplicate(alerts)).map(item => plan(item.1))
}

///|
pub fn highest_priority(plans : Array[EscalationPlan]) -> EscalationPlan? {
  plans.fold(init=None, (best, value) => {
    match best {
      None => Some(value)
      Some(previous) =>
        if value.action.rank() > previous.action.rank() {
          Some(value)
        } else {
          Some(previous)
        }
    }
  })
}

///|
pub fn owner_counts(plans : Array[EscalationPlan]) -> Array[(String, Int)] {
  let counts : Map[String, Int] = Map([])
  for value in plans {
    counts.update_or_default(value.owner, 1, item => item + 1)
  }
  counts.to_array()
}

///|
pub fn action_counts(plans : Array[EscalationPlan]) -> Array[(String, Int)] {
  let counts : Map[String, Int] = Map([])
  for value in plans {
    counts.update_or_default(value.action.label(), 1, item => item + 1)
  }
  counts.to_array()
}

///|
pub fn requires_immediate(plans : Array[EscalationPlan]) -> Bool {
  plans.any(item => item.action == EscalationAction::EscalateNow)
}

///|
pub fn escalation_text(value : EscalationPlan) -> String {
  value.session_id +
  " score=" +
  value.score.to_string() +
  " action=" +
  value.action.label() +
  " owner=" +
  value.owner +
  " response=" +
  value.response_hours.to_string() +
  "h\n" +
  value.rationale
}
