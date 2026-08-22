///|
/// Explanations make automated insights auditable by exposing evidence,
/// confidence, and a suggested next action alongside the headline.
pub(all) enum ExplanationAction {
  Monitor
  VerifyData
  ReduceLoad
  ReviewClinically
  ContinuePlan
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ExplanationAction::label(self : ExplanationAction) -> String {
  match self {
    Monitor => "monitor"
    VerifyData => "verify_data"
    ReduceLoad => "reduce_load"
    ReviewClinically => "review_clinically"
    ContinuePlan => "continue_plan"
  }
}

///|
pub(all) struct Evidence {
  metric : String
  observed : Double
  threshold : Double
  direction : String
  source_session_ids : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Evidence::metric(self : Evidence) -> String {
  self.metric
}

///|
pub fn Evidence::observed(self : Evidence) -> Double {
  self.observed
}

///|
pub fn Evidence::threshold(self : Evidence) -> Double {
  self.threshold
}

///|
pub fn Evidence::direction(self : Evidence) -> String {
  self.direction
}

///|
pub fn Evidence::source_session_ids(self : Evidence) -> Array[String] {
  self.source_session_ids.copy()
}

///|
pub(all) struct ExplainedInsight {
  code : String
  severity : InsightSeverity
  kind : InsightKind
  title : String
  detail : String
  action : ExplanationAction
  confidence : Double
  evidence : Array[Evidence]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ExplainedInsight::code(self : ExplainedInsight) -> String {
  self.code
}

///|
pub fn ExplainedInsight::severity(self : ExplainedInsight) -> InsightSeverity {
  self.severity
}

///|
pub fn ExplainedInsight::kind(self : ExplainedInsight) -> InsightKind {
  self.kind
}

///|
pub fn ExplainedInsight::title(self : ExplainedInsight) -> String {
  self.title
}

///|
pub fn ExplainedInsight::detail(self : ExplainedInsight) -> String {
  self.detail
}

///|
pub fn ExplainedInsight::action(self : ExplainedInsight) -> ExplanationAction {
  self.action
}

///|
pub fn ExplainedInsight::confidence(self : ExplainedInsight) -> Double {
  self.confidence
}

///|
pub fn ExplainedInsight::evidence(self : ExplainedInsight) -> Array[Evidence] {
  self.evidence.copy()
}

///|
fn action_for(
  kind : InsightKind,
  severity : InsightSeverity,
) -> ExplanationAction {
  if severity == InsightSeverity::Critical {
    return ExplanationAction::ReviewClinically
  }
  match kind {
    InsightKind::Pain => ExplanationAction::ReduceLoad
    InsightKind::Completion => ExplanationAction::Monitor
    InsightKind::Effort => ExplanationAction::ReduceLoad
    InsightKind::DataQuality => ExplanationAction::VerifyData
    InsightKind::Adherence => ExplanationAction::Monitor
    InsightKind::Progression => ExplanationAction::ContinuePlan
  }
}

///|
fn confidence_for(insight : Insight) -> Double {
  let base = match insight.severity {
    InsightSeverity::Critical => 0.95
    InsightSeverity::Warning => 0.85
    InsightSeverity::Notice => 0.70
    InsightSeverity::Info => 0.55
  }
  if insight.metric == 0.0 {
    base - 0.10
  } else {
    base
  }
}

///|
fn evidence_for(
  insight : Insight,
  session_ids : Array[String],
) -> Array[Evidence] {
  let threshold = match insight.kind {
    InsightKind::Pain => 7.0
    InsightKind::Completion => 0.5
    InsightKind::Effort => 8.0
    _ => 0.0
  }
  [
    Evidence::{
      metric: insight.kind.label(),
      observed: insight.metric,
      threshold,
      direction: if insight.metric >= threshold {
        "above"
      } else {
        "below"
      },
      source_session_ids: session_ids,
    },
  ]
}

///|
pub fn explain(
  insight : Insight,
  session_ids : Array[String],
) -> ExplainedInsight {
  ExplainedInsight::{
    code: insight.code,
    severity: insight.severity,
    kind: insight.kind,
    title: insight.title,
    detail: insight.detail,
    action: action_for(insight.kind, insight.severity),
    confidence: confidence_for(insight),
    evidence: evidence_for(insight, session_ids),
  }
}

///|
pub fn explain_all(report : InsightReport) -> Array[ExplainedInsight] {
  let ids = report.insights.map(insight => insight.session_id)
  report.insights.map(insight => explain(insight, ids))
}

///|
pub fn high_confidence(
  values : Array[ExplainedInsight],
  minimum : Double,
) -> Array[ExplainedInsight] {
  values.filter(value => value.confidence >= minimum)
}

///|
pub fn by_action(
  values : Array[ExplainedInsight],
  action : ExplanationAction,
) -> Array[ExplainedInsight] {
  values.filter(value => value.action == action)
}

///|
pub fn by_kind(
  values : Array[ExplainedInsight],
  kind : InsightKind,
) -> Array[ExplainedInsight] {
  values.filter(value => value.kind == kind)
}

///|
pub fn explanation_coverage(report : InsightReport) -> Double {
  if report.insights.is_empty() {
    1.0
  } else {
    explain_all(report).length().to_double() /
    report.insights.length().to_double()
  }
}

///|
pub fn explanation_text(value : ExplainedInsight) -> String {
  value.severity.label() +
  " " +
  value.title +
  " action=" +
  value.action.label() +
  " confidence=" +
  value.confidence.to_string() +
  " evidence=" +
  value.evidence.length().to_string()
}

///|
pub fn explanation_report_text(values : Array[ExplainedInsight]) -> String {
  let actions : Array[String] = []
  for value in values {
    let label = value.action.label()
    if !actions.contains(label) {
      actions.push(label)
    }
  }
  "insights=" +
  values.length().to_string() +
  ", actions=" +
  actions.join(",") +
  ", high_confidence=" +
  high_confidence(values, 0.8).length().to_string()
}

///|
pub fn evidence_text(value : Evidence) -> String {
  value.metric +
  "=" +
  value.observed.to_string() +
  " threshold=" +
  value.threshold.to_string() +
  " direction=" +
  value.direction +
  " sessions=" +
  value.source_session_ids.length().to_string()
}

///|
pub fn explanation_checksum(values : Array[ExplainedInsight]) -> Int {
  values.fold(init=23, (total, value) => {
    total * 31 + value.code.length() + value.evidence.length()
  })
}
