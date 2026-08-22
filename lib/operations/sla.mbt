///|
/// SLA checks make an operational queue measurable without coupling it to a
/// particular scheduler. Dates remain ISO strings so ordering is stable.
pub(all) struct SlaPolicy {
  critical_hours : Int
  high_hours : Int
  normal_hours : Int
  low_hours : Int
  escalation_after_hours : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_sla_policy() -> SlaPolicy {
  SlaPolicy::{
    critical_hours: 4,
    high_hours: 24,
    normal_hours: 72,
    low_hours: 168,
    escalation_after_hours: 24,
  }
}

///|
pub fn SlaPolicy::validate(self : SlaPolicy) -> Array[String] {
  let errors = []
  if self.critical_hours <= 0 {
    errors.push("critical_hours must be positive")
  }
  if self.high_hours < self.critical_hours {
    errors.push("high_hours must not precede critical_hours")
  }
  if self.normal_hours < self.high_hours {
    errors.push("normal_hours must not precede high_hours")
  }
  if self.low_hours < self.normal_hours {
    errors.push("low_hours must not precede normal_hours")
  }
  errors
}

///|
fn sla_hours(priority : WorkPriority, policy : SlaPolicy) -> Int {
  match priority {
    WorkPriority::Immediate => policy.critical_hours
    WorkPriority::Urgent => policy.high_hours
    WorkPriority::Soon => policy.normal_hours
    WorkPriority::Routine => policy.low_hours
  }
}

///|
pub(all) enum SlaStatus {
  Within
  AtRisk
  Breached
  Complete
  Unknown
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SlaStatus::label(self : SlaStatus) -> String {
  match self {
    Within => "within"
    AtRisk => "at_risk"
    Breached => "breached"
    Complete => "complete"
    Unknown => "unknown"
  }
}

///|
pub(all) struct SlaResult {
  item_id : String
  priority : WorkPriority
  status : SlaStatus
  target_hours : Int
  elapsed_hours : Int
  remaining_hours : Int
  utilization : Double
  recommendation : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SlaResult::item_id(self : SlaResult) -> String {
  self.item_id
}

///|
pub fn SlaResult::priority(self : SlaResult) -> WorkPriority {
  self.priority
}

///|
pub fn SlaResult::status(self : SlaResult) -> SlaStatus {
  self.status
}

///|
pub fn SlaResult::target_hours(self : SlaResult) -> Int {
  self.target_hours
}

///|
pub fn SlaResult::elapsed_hours(self : SlaResult) -> Int {
  self.elapsed_hours
}

///|
pub fn SlaResult::remaining_hours(self : SlaResult) -> Int {
  self.remaining_hours
}

///|
pub fn SlaResult::utilization(self : SlaResult) -> Double {
  self.utilization
}

///|
pub fn SlaResult::recommendation(self : SlaResult) -> String {
  self.recommendation
}

///|
fn pseudo_elapsed(created : String, now : String) -> Int {
  if created.is_empty() || now.is_empty() {
    -1
  } else if now < created {
    -1
  } else {
    let date_gap = if now.length() == created.length() {
      now.compare(created).abs()
    } else {
      now.length() - created.length()
    }
    Int::max(0, date_gap)
  }
}

///|
pub fn evaluate_sla(
  item : WorkItem,
  now : String,
  policy : SlaPolicy,
) -> SlaResult {
  let target = Int::max(1, sla_hours(item.priority(), policy))
  let elapsed = pseudo_elapsed(item.created_at(), now)
  if item.status().terminal() {
    return SlaResult::{
      item_id: item.id(),
      priority: item.priority(),
      status: SlaStatus::Complete,
      target_hours: target,
      elapsed_hours: Int::max(0, elapsed),
      remaining_hours: 0,
      utilization: 0.0,
      recommendation: "no action",
    }
  }
  if elapsed < 0 {
    SlaResult::{
      item_id: item.id(),
      priority: item.priority(),
      status: SlaStatus::Unknown,
      target_hours: target,
      elapsed_hours: 0,
      remaining_hours: target,
      utilization: 0.0,
      recommendation: "repair timestamp before scheduling",
    }
  } else {
    let remaining = target - elapsed
    let utilization = elapsed.to_double() / target.to_double()
    let status = if elapsed >= target {
      SlaStatus::Breached
    } else if elapsed * 2 >= target {
      SlaStatus::AtRisk
    } else {
      SlaStatus::Within
    }
    let recommendation = match status {
      SlaStatus::Breached => "escalate immediately"
      SlaStatus::AtRisk => "assign owner and review today"
      SlaStatus::Within => "continue within target"
      _ => "no action"
    }
    SlaResult::{
      item_id: item.id(),
      priority: item.priority(),
      status,
      target_hours: target,
      elapsed_hours: elapsed,
      remaining_hours: Int::max(0, remaining),
      utilization,
      recommendation,
    }
  }
}

///|
pub fn evaluate_queue(
  queue : WorkQueue,
  now : String,
  policy : SlaPolicy,
) -> Array[SlaResult] {
  let result = queue.items().map(item => evaluate_sla(item, now, policy))
  result.sort_by((left, right) => right.utilization.compare(left.utilization))
  result
}

///|
pub fn sla_breached(values : Array[SlaResult]) -> Array[SlaResult] {
  values.filter(value => value.status == SlaStatus::Breached)
}

///|
pub fn sla_at_risk(values : Array[SlaResult]) -> Array[SlaResult] {
  values.filter(value => {
    value.status == SlaStatus::AtRisk || value.status == SlaStatus::Breached
  })
}

///|
pub fn sla_compliance(values : Array[SlaResult]) -> Double {
  let measured = values.filter(value => value.status != SlaStatus::Unknown)
  if measured.is_empty() {
    0.0
  } else {
    measured.count_if(value => value.status != SlaStatus::Breached).to_double() /
    measured.length().to_double() *
    100.0
  }
}

///|
pub fn sla_status_counts(values : Array[SlaResult]) -> Array[(String, Int)] {
  let counts : Array[(String, Int)] = []
  for value in values {
    let label = value.status.label()
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
pub fn sla_text(value : SlaResult) -> String {
  value.item_id +
  " " +
  value.status.label() +
  " utilization=" +
  value.utilization.to_string() +
  " remaining=" +
  value.remaining_hours.to_string() +
  "h " +
  value.recommendation
}

///|
pub fn sla_report_text(values : Array[SlaResult]) -> String {
  "items=" +
  values.length().to_string() +
  ", breached=" +
  sla_breached(values).length().to_string() +
  ", at_risk=" +
  sla_at_risk(values).length().to_string() +
  ", compliance=" +
  sla_compliance(values).to_string() +
  "%"
}

///|
pub(all) struct SlaDashboard {
  results : Array[SlaResult]
  compliance : Double
  breached_ids : Array[String]
  at_risk_ids : Array[String]
  owner_actions : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn build_sla_dashboard(
  queue : WorkQueue,
  now : String,
  policy : SlaPolicy,
) -> SlaDashboard {
  let results = evaluate_queue(queue, now, policy)
  let breached_ids = sla_breached(results).map(value => value.item_id)
  let at_risk_ids = sla_at_risk(results).map(value => value.item_id)
  let owner_actions = results
    .filter(value => {
      value.status == SlaStatus::Breached || value.status == SlaStatus::AtRisk
    })
    .map(value => value.item_id + ": " + value.recommendation)
  SlaDashboard::{
    results,
    compliance: sla_compliance(results),
    breached_ids,
    at_risk_ids,
    owner_actions,
  }
}

///|
pub fn SlaDashboard::results(self : SlaDashboard) -> Array[SlaResult] {
  self.results.copy()
}

///|
pub fn SlaDashboard::compliance(self : SlaDashboard) -> Double {
  self.compliance
}

///|
pub fn SlaDashboard::breached_ids(self : SlaDashboard) -> Array[String] {
  self.breached_ids.copy()
}

///|
pub fn SlaDashboard::at_risk_ids(self : SlaDashboard) -> Array[String] {
  self.at_risk_ids.copy()
}

///|
pub fn SlaDashboard::owner_actions(self : SlaDashboard) -> Array[String] {
  self.owner_actions.copy()
}
