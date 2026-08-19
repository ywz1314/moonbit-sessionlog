///|
pub(all) struct Dashboard {
  session_count : Int
  total_reps : Int
  total_work_units : Int
  average_pain : Double
  average_completion : Double
  adherence_percent : Double
  quality_score : Double
  alert_count : Int
  critical_alert_count : Int
  risk_score : Int
  forecast_confidence : Double
  headline : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Dashboard::session_count(self : Dashboard) -> Int {
  self.session_count
}

///|
pub fn Dashboard::total_reps(self : Dashboard) -> Int {
  self.total_reps
}

///|
pub fn Dashboard::total_work_units(self : Dashboard) -> Int {
  self.total_work_units
}

///|
pub fn Dashboard::average_pain(self : Dashboard) -> Double {
  self.average_pain
}

///|
pub fn Dashboard::average_completion(self : Dashboard) -> Double {
  self.average_completion
}

///|
pub fn Dashboard::adherence_percent(self : Dashboard) -> Double {
  self.adherence_percent
}

///|
pub fn Dashboard::quality_score(self : Dashboard) -> Double {
  self.quality_score
}

///|
pub fn Dashboard::alert_count(self : Dashboard) -> Int {
  self.alert_count
}

///|
pub fn Dashboard::critical_alert_count(self : Dashboard) -> Int {
  self.critical_alert_count
}

///|
pub fn Dashboard::risk_score(self : Dashboard) -> Int {
  self.risk_score
}

///|
pub fn Dashboard::forecast_confidence(self : Dashboard) -> Double {
  self.forecast_confidence
}

///|
pub fn Dashboard::headline(self : Dashboard) -> String {
  self.headline
}

///|
fn headline(
  sessions : Array[@core.Session],
  alerts : Array[@alerts.SessionAlert],
  risk : Int,
) -> String {
  if sessions.is_empty() {
    "No sessions recorded yet."
  } else if @alerts.has_critical(alerts) || risk >= 70 {
    "Review the highest severity signals before increasing load."
  } else if @analytics.analyze(sessions).completion_direction() ==
    @analytics.TrendDirection::Improving {
    "Completion is improving across the recorded history."
  } else {
    "Keep the current dose stable and collect another comparable session."
  }
}

///|
pub fn build(sessions : Array[@core.Session]) -> Dashboard {
  let trends = @analytics.analyze(sessions)
  let alerts = @alerts.evaluate_series(sessions)
  let quality = @quality.average_score(sessions)
  let forecast = @forecast.forecast(sessions, 3)
  let critical = @alerts.filter_severity(
    alerts,
    @alerts.AlertSeverity::Critical,
  ).length()
  let risk = if sessions.is_empty() {
    0
  } else {
    let mut total = 0
    for session in sessions {
      total += @alerts.evaluate(session).fold(init=0, (score, item) => {
        match item.severity {
          @alerts.AlertSeverity::Notice => score + 1
          @alerts.AlertSeverity::Warning => score + 5
          @alerts.AlertSeverity::Critical => score + 15
        }
      })
    }
    Int::min(100, total)
  }
  Dashboard::{
    session_count: trends.session_count(),
    total_reps: trends.total_reps(),
    total_work_units: trends.total_work_units(),
    average_pain: trends.average_pain(),
    average_completion: trends.average_completion(),
    adherence_percent: trends.adherence_percent(),
    quality_score: quality,
    alert_count: alerts.length(),
    critical_alert_count: critical,
    risk_score: risk,
    forecast_confidence: forecast.confidence(),
    headline: headline(sessions, alerts, risk),
  }
}

///|
pub fn status(dashboard : Dashboard) -> String {
  if dashboard.critical_alert_count > 0 {
    "critical"
  } else if dashboard.risk_score >= 70 {
    "high_risk"
  } else if dashboard.average_completion < 0.75 {
    "needs_review"
  } else {
    "stable"
  }
}

///|
pub fn to_text(dashboard : Dashboard) -> String {
  let output = StringBuilder()
  output.write_string("status: " + status(dashboard) + "\n")
  output.write_string("sessions: " + dashboard.session_count.to_string() + "\n")
  output.write_string("reps: " + dashboard.total_reps.to_string() + "\n")
  output.write_string(
    "work units: " + dashboard.total_work_units.to_string() + "\n",
  )
  output.write_string(
    "average pain: " + dashboard.average_pain.to_string() + "\n",
  )
  output.write_string(
    "completion: " + dashboard.average_completion.to_string() + "\n",
  )
  output.write_string("quality: " + dashboard.quality_score.to_string() + "\n")
  output.write_string("alerts: " + dashboard.alert_count.to_string() + "\n")
  output.write_string("risk: " + dashboard.risk_score.to_string() + "\n")
  output.write_string("headline: " + dashboard.headline + "\n")
  output.to_string()
}

///|
pub fn empty() -> Dashboard {
  build([])
}

///|
pub fn compare(left : Dashboard, right : Dashboard) -> (Int, Int, Int, Double) {
  (
    right.total_reps - left.total_reps,
    right.total_work_units - left.total_work_units,
    right.alert_count - left.alert_count,
    right.average_completion - left.average_completion,
  )
}

///|
pub fn is_improving(dashboard : Dashboard) -> Bool {
  dashboard.average_completion >= 0.75 &&
  dashboard.average_pain <= 3.0 &&
  dashboard.critical_alert_count == 0
}
