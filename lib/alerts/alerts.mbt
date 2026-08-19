///|
pub(all) enum AlertType {
  PainThreshold
  PainIncrease
  EffortThreshold
  CompletionDrop
  InvalidData
  MissingMovement
  LoadSpike
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn AlertType::label(self : AlertType) -> String {
  match self {
    PainThreshold => "pain_threshold"
    PainIncrease => "pain_increase"
    EffortThreshold => "effort_threshold"
    CompletionDrop => "completion_drop"
    InvalidData => "invalid_data"
    MissingMovement => "missing_movement"
    LoadSpike => "load_spike"
  }
}

///|
pub(all) enum AlertSeverity {
  Notice
  Warning
  Critical
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn AlertSeverity::label(self : AlertSeverity) -> String {
  match self {
    Notice => "notice"
    Warning => "warning"
    Critical => "critical"
  }
}

///|
pub(all) struct AlertPolicy {
  pain_threshold : Int
  effort_threshold : Int
  completion_threshold : Double
  load_spike_ratio : Double
  check_invalid_data : Bool
  check_empty_movement : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_alert_policy() -> AlertPolicy {
  AlertPolicy::{
    pain_threshold: 7,
    effort_threshold: 9,
    completion_threshold: 0.75,
    load_spike_ratio: 1.5,
    check_invalid_data: true,
    check_empty_movement: true,
  }
}

///|
pub(all) struct SessionAlert {
  session_id : String
  date : String
  alert_type : AlertType
  severity : AlertSeverity
  message : String
  metric : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SessionAlert::session_id(self : SessionAlert) -> String {
  self.session_id
}

///|
pub fn SessionAlert::date(self : SessionAlert) -> String {
  self.date
}

///|
pub fn SessionAlert::alert_type(self : SessionAlert) -> AlertType {
  self.alert_type
}

///|
pub fn SessionAlert::severity(self : SessionAlert) -> AlertSeverity {
  self.severity
}

///|
pub fn SessionAlert::message(self : SessionAlert) -> String {
  self.message
}

///|
pub fn SessionAlert::metric(self : SessionAlert) -> Double {
  self.metric
}

///|
fn alert(
  session : @core.Session,
  alert_type : AlertType,
  severity : AlertSeverity,
  message : String,
  metric : Double,
) -> SessionAlert {
  SessionAlert::{
    session_id: session.id,
    date: session.date,
    alert_type,
    severity,
    message,
    metric,
  }
}

///|
pub fn evaluate(
  session : @core.Session,
  policy? : AlertPolicy = default_alert_policy(),
) -> Array[SessionAlert] {
  let alerts = []
  let pain = session.average_pain_during()
  if pain >= policy.pain_threshold.to_double() {
    alerts.push(
      alert(
        session,
        AlertType::PainThreshold,
        if pain >= 9.0 {
          AlertSeverity::Critical
        } else {
          AlertSeverity::Warning
        },
        "Average movement pain reached the configured threshold.",
        pain,
      ),
    )
  }
  if session.pain_delta() > 0 {
    alerts.push(
      alert(
        session,
        AlertType::PainIncrease,
        AlertSeverity::Warning,
        "Reported pain increased during the session.",
        session.pain_delta().to_double(),
      ),
    )
  }
  if session.movements.any(movement => movement.rpe >= policy.effort_threshold) {
    alerts.push(
      alert(
        session,
        AlertType::EffortThreshold,
        AlertSeverity::Warning,
        "At least one movement reached the effort threshold.",
        policy.effort_threshold.to_double(),
      ),
    )
  }
  if session.average_completion() < policy.completion_threshold {
    alerts.push(
      alert(
        session,
        AlertType::CompletionDrop,
        AlertSeverity::Notice,
        "Average completion is below the configured target.",
        session.average_completion(),
      ),
    )
  }
  if policy.check_invalid_data && !@validation.is_valid(session) {
    alerts.push(
      alert(
        session,
        AlertType::InvalidData,
        AlertSeverity::Warning,
        "The session contains fields that failed validation.",
        @validation.validate_session(session).length().to_double(),
      ),
    )
  }
  if policy.check_empty_movement && session.movements.is_empty() {
    alerts.push(
      alert(
        session,
        AlertType::MissingMovement,
        AlertSeverity::Notice,
        "The session has no movement observations.",
        0.0,
      ),
    )
  }
  alerts
}

///|
pub fn load_spike(
  previous : @core.Session,
  current : @core.Session,
  policy? : AlertPolicy = default_alert_policy(),
) -> SessionAlert? {
  let previous_work = previous.movements.fold(init=0, (total, movement) => {
    total + movement.work_units()
  })
  let current_work = current.movements.fold(init=0, (total, movement) => {
    total + movement.work_units()
  })
  if previous_work <= 0 ||
    current_work.to_double() <=
    previous_work.to_double() * policy.load_spike_ratio {
    None
  } else {
    Some(
      alert(
        current,
        AlertType::LoadSpike,
        AlertSeverity::Warning,
        "Work units increased faster than the configured ratio.",
        current_work.to_double() / previous_work.to_double(),
      ),
    )
  }
}

///|
pub fn evaluate_series(
  sessions : Array[@core.Session],
  policy? : AlertPolicy = default_alert_policy(),
) -> Array[SessionAlert] {
  let alerts = []
  for i, session in sessions {
    alerts.append(evaluate(session, policy~))
    if i > 0 {
      match load_spike(sessions[i - 1], session, policy~) {
        Some(value) => alerts.push(value)
        None => ()
      }
    }
  }
  let trend = @analytics.analyze(sessions)
  if trend.pain_direction() == @analytics.TrendDirection::Worsening {
    for session in sessions {
      alerts.push(
        alert(
          session,
          AlertType::PainIncrease,
          AlertSeverity::Warning,
          "The ordered history shows worsening average pain.",
          trend.average_pain(),
        ),
      )
    }
  }
  alerts
}

///|
pub fn filter_severity(
  alerts : Array[SessionAlert],
  severity : AlertSeverity,
) -> Array[SessionAlert] {
  alerts.filter(item => item.severity == severity)
}

///|
pub fn filter_type(
  alerts : Array[SessionAlert],
  alert_type : AlertType,
) -> Array[SessionAlert] {
  alerts.filter(item => item.alert_type == alert_type)
}

///|
pub fn has_critical(alerts : Array[SessionAlert]) -> Bool {
  alerts.any(item => item.severity == AlertSeverity::Critical)
}

///|
pub fn counts(alerts : Array[SessionAlert]) -> (Int, Int, Int) {
  let mut notice = 0
  let mut warning = 0
  let mut critical = 0
  for item in alerts {
    match item.severity {
      AlertSeverity::Notice => notice += 1
      AlertSeverity::Warning => warning += 1
      AlertSeverity::Critical => critical += 1
    }
  }
  (notice, warning, critical)
}

///|
pub fn text(alerts : Array[SessionAlert]) -> String {
  let output = StringBuilder()
  for item in alerts {
    output.write_string(
      "[" +
      item.severity.label() +
      "] " +
      item.session_id +
      " " +
      item.alert_type.label() +
      ": " +
      item.message +
      "\n",
    )
  }
  output.to_string()
}
