///|
pub(all) enum SafetyLevel {
  Green
  Amber
  Red
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SafetyLevel::label(self : SafetyLevel) -> String {
  match self {
    Green => "green"
    Amber => "amber"
    Red => "red"
  }
}

///|
pub(all) enum SafetyRule {
  PainRange
  PainIncrease
  EffortRange
  CompletionRange
  DurationRange
  DataValidity
  MovementPresence
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SafetyRule::label(self : SafetyRule) -> String {
  match self {
    PainRange => "pain_range"
    PainIncrease => "pain_increase"
    EffortRange => "effort_range"
    CompletionRange => "completion_range"
    DurationRange => "duration_range"
    DataValidity => "data_validity"
    MovementPresence => "movement_presence"
  }
}

///|
pub(all) struct SafetyFinding {
  rule : SafetyRule
  level : SafetyLevel
  message : String
  metric : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SafetyFinding::rule(self : SafetyFinding) -> SafetyRule {
  self.rule
}

///|
pub fn SafetyFinding::level(self : SafetyFinding) -> SafetyLevel {
  self.level
}

///|
pub fn SafetyFinding::message(self : SafetyFinding) -> String {
  self.message
}

///|
pub fn SafetyFinding::metric(self : SafetyFinding) -> Double {
  self.metric
}

///|
pub(all) struct SafetyReport {
  session_id : String
  level : SafetyLevel
  score : Int
  findings : Array[SafetyFinding]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SafetyReport::session_id(self : SafetyReport) -> String {
  self.session_id
}

///|
pub fn SafetyReport::level(self : SafetyReport) -> SafetyLevel {
  self.level
}

///|
pub fn SafetyReport::score(self : SafetyReport) -> Int {
  self.score
}

///|
pub fn SafetyReport::findings(self : SafetyReport) -> Array[SafetyFinding] {
  self.findings
}

///|
fn finding(
  rule : SafetyRule,
  level : SafetyLevel,
  message : String,
  metric : Double,
) -> SafetyFinding {
  SafetyFinding::{ rule, level, message, metric }
}

///|
pub fn evaluate(session : @core.Session) -> SafetyReport {
  let findings = []
  let pain = session.average_pain_during()
  if pain > 10.0 || pain < 0.0 {
    findings.push(
      finding(
        SafetyRule::PainRange,
        SafetyLevel::Red,
        "pain is outside VAS range",
        pain,
      ),
    )
  } else if pain >= 7.0 {
    findings.push(
      finding(SafetyRule::PainRange, SafetyLevel::Amber, "pain is severe", pain),
    )
  }
  if session.pain_delta() > 0 {
    findings.push(
      finding(
        SafetyRule::PainIncrease,
        SafetyLevel::Amber,
        "pain increased",
        session.pain_delta().to_double(),
      ),
    )
  }
  if session.movements.any(movement => movement.rpe > 10 || movement.rpe < 1) {
    findings.push(
      finding(
        SafetyRule::EffortRange,
        SafetyLevel::Red,
        "effort is outside RPE range",
        0.0,
      ),
    )
  } else if session.movements.any(movement => movement.rpe >= 9) {
    findings.push(
      finding(
        SafetyRule::EffortRange,
        SafetyLevel::Amber,
        "effort is very high",
        9.0,
      ),
    )
  }
  if session.movements.any(movement => {
      movement.sets.any(set => set.completion < 0.0 || set.completion > 1.0)
    }) {
    findings.push(
      finding(
        SafetyRule::CompletionRange,
        SafetyLevel::Red,
        "completion is outside range",
        session.average_completion(),
      ),
    )
  }
  if session.duration < 0 {
    findings.push(
      finding(
        SafetyRule::DurationRange,
        SafetyLevel::Red,
        "duration is negative",
        session.duration.to_double(),
      ),
    )
  }
  if !@validation.is_valid(session) {
    findings.push(
      finding(
        SafetyRule::DataValidity,
        SafetyLevel::Amber,
        "session failed validation",
        @validation.validate_session(session).length().to_double(),
      ),
    )
  }
  if session.movements.is_empty() {
    findings.push(
      finding(
        SafetyRule::MovementPresence,
        SafetyLevel::Amber,
        "no movement observations",
        0.0,
      ),
    )
  }
  let red = findings.count_if(item => item.level == SafetyLevel::Red)
  let amber = findings.count_if(item => item.level == SafetyLevel::Amber)
  let level = if red > 0 {
    SafetyLevel::Red
  } else if amber > 0 {
    SafetyLevel::Amber
  } else {
    SafetyLevel::Green
  }
  let score = Int::max(0, 100 - red * 35 - amber * 15)
  SafetyReport::{ session_id: session.id, level, score, findings }
}

///|
pub fn evaluate_many(sessions : Array[@core.Session]) -> Array[SafetyReport] {
  sessions.map(session => evaluate(session))
}

///|
pub fn safe(session : @core.Session) -> Bool {
  evaluate(session).level == SafetyLevel::Green
}

///|
pub fn red_reports(reports : Array[SafetyReport]) -> Array[SafetyReport] {
  reports.filter(report => report.level == SafetyLevel::Red)
}

///|
pub fn amber_reports(reports : Array[SafetyReport]) -> Array[SafetyReport] {
  reports.filter(report => report.level == SafetyLevel::Amber)
}

///|
pub fn text(report : SafetyReport) -> String {
  let output = StringBuilder()
  output.write_string(
    report.session_id +
    ": " +
    report.level.label() +
    " score=" +
    report.score.to_string() +
    "\n",
  )
  for item in report.findings {
    output.write_string("- " + item.rule.label() + ": " + item.message + "\n")
  }
  output.to_string()
}
