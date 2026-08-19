///|
pub(all) enum InsightSeverity {
  Info
  Notice
  Warning
  Critical
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn InsightSeverity::rank(self : InsightSeverity) -> Int {
  match self {
    Info => 0
    Notice => 1
    Warning => 2
    Critical => 3
  }
}

///|
pub fn InsightSeverity::label(self : InsightSeverity) -> String {
  match self {
    Info => "info"
    Notice => "notice"
    Warning => "warning"
    Critical => "critical"
  }
}

///|
pub(all) enum InsightKind {
  Pain
  Completion
  Effort
  DataQuality
  Adherence
  Progression
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn InsightKind::label(self : InsightKind) -> String {
  match self {
    Pain => "pain"
    Completion => "completion"
    Effort => "effort"
    DataQuality => "data_quality"
    Adherence => "adherence"
    Progression => "progression"
  }
}

///|
pub(all) struct Insight {
  code : String
  severity : InsightSeverity
  kind : InsightKind
  session_id : String
  title : String
  detail : String
  metric : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Insight::code(self : Insight) -> String {
  self.code
}

///|
pub fn Insight::severity(self : Insight) -> InsightSeverity {
  self.severity
}

///|
pub fn Insight::kind(self : Insight) -> InsightKind {
  self.kind
}

///|
pub fn Insight::session_id(self : Insight) -> String {
  self.session_id
}

///|
pub fn Insight::title(self : Insight) -> String {
  self.title
}

///|
pub fn Insight::detail(self : Insight) -> String {
  self.detail
}

///|
pub fn Insight::metric(self : Insight) -> Double {
  self.metric
}

///|
pub(all) struct InsightReport {
  session_count : Int
  risk_score : Int
  insights : Array[Insight]
  recommendation : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn InsightReport::session_count(self : InsightReport) -> Int {
  self.session_count
}

///|
pub fn InsightReport::risk_score(self : InsightReport) -> Int {
  self.risk_score
}

///|
pub fn InsightReport::insights(self : InsightReport) -> Array[Insight] {
  self.insights
}

///|
pub fn InsightReport::recommendation(self : InsightReport) -> String {
  self.recommendation
}

///|
fn make(
  code : String,
  severity : InsightSeverity,
  kind : InsightKind,
  session_id : String,
  title : String,
  detail : String,
  metric : Double,
) -> Insight {
  Insight::{ code, severity, kind, session_id, title, detail, metric }
}

///|
pub fn risk_score(session : @core.Session) -> Int {
  let pain = (session.average_pain_during() * 6.0).round().to_int()
  let effort = session.movements.fold(init=0, (total, movement) => {
    total + movement.rpe
  })
  let effort_average = if session.movements.is_empty() {
    0
  } else {
    effort / session.movements.length()
  }
  let completion = ((1.0 - session.average_completion()) * 40.0)
    .round()
    .to_int()
  Int::min(100, Int::max(0, pain + effort_average * 3 + completion))
}

///|
pub fn history_risk_score(sessions : Array[@core.Session]) -> Int {
  if sessions.is_empty() {
    0
  } else {
    let latest = match sessions.last() {
      Some(session) => risk_score(session)
      None => 0
    }
    let trend = @analytics.analyze(sessions)
    let worsening_penalty = if trend.pain_direction() ==
      @analytics.TrendDirection::Worsening {
      15
    } else {
      0
    }
    Int::min(100, latest + worsening_penalty)
  }
}

///|
pub fn session_insights(session : @core.Session) -> Array[Insight] {
  let insights = []
  let score = risk_score(session)
  if session.average_pain_during() >= 7.0 {
    insights.push(
      make(
        "pain_high",
        InsightSeverity::Critical,
        InsightKind::Pain,
        session.id,
        "High reported pain",
        "The session contains severe reported pain; review the load before repeating it.",
        session.average_pain_during(),
      ),
    )
  } else if session.average_pain_during() >= 4.0 {
    insights.push(
      make(
        "pain_moderate",
        InsightSeverity::Warning,
        InsightKind::Pain,
        session.id,
        "Moderate reported pain",
        "Keep the next dose stable and observe the response.",
        session.average_pain_during(),
      ),
    )
  }
  if session.average_completion() < 0.75 {
    insights.push(
      make(
        "completion_low",
        InsightSeverity::Warning,
        InsightKind::Completion,
        session.id,
        "Completion below target",
        "The completed fraction is below the default progression target.",
        session.average_completion(),
      ),
    )
  } else {
    insights.push(
      make(
        "completion_on_target",
        InsightSeverity::Info,
        InsightKind::Completion,
        session.id,
        "Completion target met",
        "The recorded completion supports a cautious progression review.",
        session.average_completion(),
      ),
    )
  }
  if session.movements.any(movement => movement.rpe >= 9) {
    insights.push(
      make(
        "effort_very_high",
        InsightSeverity::Critical,
        InsightKind::Effort,
        session.id,
        "Very high perceived effort",
        "At least one movement reached the highest effort band.",
        9.0,
      ),
    )
  }
  if session.movements.is_empty() {
    insights.push(
      make(
        "no_movement_data",
        InsightSeverity::Notice,
        InsightKind::DataQuality,
        session.id,
        "No movement data",
        "The session cannot support load or completion analysis without movements.",
        0.0,
      ),
    )
  }
  if session.pain_delta() > 0 {
    insights.push(
      make(
        "pain_worsened",
        InsightSeverity::Warning,
        InsightKind::Pain,
        session.id,
        "Pain increased during the session",
        "The end-of-session pain is higher than the beginning-of-session value.",
        session.pain_delta().to_double(),
      ),
    )
  }
  if score >= 70 && insights.all(insight => insight.severity.rank() < 3) {
    insights.push(
      make(
        "risk_score_high",
        InsightSeverity::Warning,
        InsightKind::Progression,
        session.id,
        "Combined risk score is high",
        "The combined pain, effort, and completion signals warrant a conservative review.",
        score.to_double(),
      ),
    )
  }
  insights
}

///|
pub fn data_quality_insights(session : @core.Session) -> Array[Insight] {
  let errors = @validation.validate_session(session)
  errors.map(error => {
    make(
      "data:" + @validation.validation_error_code(error),
      InsightSeverity::Warning,
      InsightKind::DataQuality,
      session.id,
      "Data quality issue",
      @validation.validation_error_path(error),
      1.0,
    )
  })
}

///|
pub fn progression_insights(session : @core.Session) -> Array[Insight] {
  @progression.plan_session(session).map(decision => {
    make(
      "progression:" + decision.state().to_string(),
      if decision.state() == @progression.ProgressionState::Regression {
        InsightSeverity::Warning
      } else {
        InsightSeverity::Info
      },
      InsightKind::Progression,
      session.id,
      decision.movement_name(),
      decision.rationale(),
      decision.readiness().to_double(),
    )
  })
}

///|
pub fn all_session_insights(session : @core.Session) -> Array[Insight] {
  let result = session_insights(session)
  result.append(data_quality_insights(session))
  result.append(progression_insights(session))
  result
}

///|
fn sort_by_severity(insights : Array[Insight]) -> Array[Insight] {
  let sorted = insights.copy()
  sorted.sort_by((left, right) => right.severity.rank() - left.severity.rank())
  sorted
}

///|
pub fn build(sessions : Array[@core.Session]) -> InsightReport {
  let insights = []
  for session in sessions {
    insights.append(all_session_insights(session))
  }
  let sorted = sort_by_severity(insights)
  let risk = history_risk_score(sessions)
  let recommendation = if risk >= 70 {
    "Use a conservative plan and review the highest severity insight first."
  } else if risk >= 35 {
    "Keep the current dose stable and collect another comparable session."
  } else {
    "The recorded signals are relatively stable; progress gradually and monitor response."
  }
  InsightReport::{
    session_count: sessions.length(),
    risk_score: risk,
    insights: sorted,
    recommendation,
  }
}

///|
pub fn has_critical(insights : Array[Insight]) -> Bool {
  insights.any(insight => insight.severity == InsightSeverity::Critical)
}

///|
pub fn count_by_severity(insights : Array[Insight]) -> (Int, Int, Int, Int) {
  let mut info = 0
  let mut notice = 0
  let mut warning = 0
  let mut critical = 0
  for insight in insights {
    match insight.severity {
      InsightSeverity::Info => info += 1
      InsightSeverity::Notice => notice += 1
      InsightSeverity::Warning => warning += 1
      InsightSeverity::Critical => critical += 1
    }
  }
  (info, notice, warning, critical)
}

///|
pub fn filter_kind(
  insights : Array[Insight],
  kind : InsightKind,
) -> Array[Insight] {
  insights.filter(insight => insight.kind == kind)
}

///|
pub fn highest_priority(insights : Array[Insight]) -> Insight? {
  sort_by_severity(insights).get(0)
}

///|
pub fn report_text(report : InsightReport) -> String {
  let output = StringBuilder()
  output.write_string("risk score: " + report.risk_score.to_string() + "\n")
  output.write_string(report.recommendation + "\n")
  for insight in report.insights {
    output.write_string(
      "[" +
      insight.severity.label() +
      "] " +
      insight.code +
      ": " +
      insight.detail +
      "\n",
    )
  }
  output.to_string()
}
