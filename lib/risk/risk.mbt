///|
/// Explainable risk factors used to prioritize a clinician's review queue.
pub(all) enum RiskLevel {
  Low
  Guarded
  Elevated
  High
  Critical
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RiskLevel::label(self : RiskLevel) -> String {
  match self {
    Low => "low"
    Guarded => "guarded"
    Elevated => "elevated"
    High => "high"
    Critical => "critical"
  }
}

///|
pub fn RiskLevel::rank(self : RiskLevel) -> Int {
  match self {
    Low => 0
    Guarded => 1
    Elevated => 2
    High => 3
    Critical => 4
  }
}

///|
pub(all) enum RiskFactorKind {
  HighPain
  WorseningPain
  LowCompletion
  HighEffort
  WorkloadSpike
  DataInvalid
  MissingObservation
  RepeatedMiss
  UnstableTrend
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RiskFactorKind::label(self : RiskFactorKind) -> String {
  match self {
    HighPain => "high_pain"
    WorseningPain => "worsening_pain"
    LowCompletion => "low_completion"
    HighEffort => "high_effort"
    WorkloadSpike => "workload_spike"
    DataInvalid => "data_invalid"
    MissingObservation => "missing_observation"
    RepeatedMiss => "repeated_miss"
    UnstableTrend => "unstable_trend"
  }
}

///|
pub(all) struct RiskFactor {
  kind : RiskFactorKind
  score : Int
  weight : Int
  metric : Double
  threshold : Double
  message : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RiskFactor::kind(self : RiskFactor) -> RiskFactorKind {
  self.kind
}

///|
pub fn RiskFactor::score(self : RiskFactor) -> Int {
  self.score
}

///|
pub fn RiskFactor::weight(self : RiskFactor) -> Int {
  self.weight
}

///|
pub fn RiskFactor::metric(self : RiskFactor) -> Double {
  self.metric
}

///|
pub fn RiskFactor::threshold(self : RiskFactor) -> Double {
  self.threshold
}

///|
pub fn RiskFactor::message(self : RiskFactor) -> String {
  self.message
}

///|
pub fn RiskFactor::weighted_score(self : RiskFactor) -> Int {
  self.score * self.weight
}

///|
pub(all) struct RiskOptions {
  pain_threshold : Int
  worsening_delta : Int
  completion_threshold : Double
  effort_threshold : Int
  workload_spike_ratio : Double
  invalid_penalty : Int
  missing_penalty : Int
  unstable_penalty : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_risk_options() -> RiskOptions {
  RiskOptions::{
    pain_threshold: 7,
    worsening_delta: 2,
    completion_threshold: 0.6,
    effort_threshold: 9,
    workload_spike_ratio: 1.5,
    invalid_penalty: 25,
    missing_penalty: 10,
    unstable_penalty: 10,
  }
}

///|
pub fn conservative_risk_options() -> RiskOptions {
  RiskOptions::{
    pain_threshold: 5,
    worsening_delta: 1,
    completion_threshold: 0.75,
    effort_threshold: 8,
    workload_spike_ratio: 1.25,
    invalid_penalty: 35,
    missing_penalty: 15,
    unstable_penalty: 15,
  }
}

///|
pub fn validate_options(options : RiskOptions) -> Array[String] {
  let errors = []
  if options.pain_threshold < 0 || options.pain_threshold > 10 {
    errors.push("pain_threshold must be 0..10")
  }
  if options.worsening_delta < 0 {
    errors.push("worsening_delta must not be negative")
  }
  if options.completion_threshold < 0.0 || options.completion_threshold > 1.0 {
    errors.push("completion_threshold must be 0..1")
  }
  if options.effort_threshold < 1 || options.effort_threshold > 10 {
    errors.push("effort_threshold must be 1..10")
  }
  if options.workload_spike_ratio < 1.0 {
    errors.push("workload_spike_ratio must be at least 1")
  }
  errors
}

///|
pub(all) struct RiskScore {
  session_id : String
  date : String
  score : Int
  level : RiskLevel
  factors : Array[RiskFactor]
  action : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RiskScore::session_id(self : RiskScore) -> String {
  self.session_id
}

///|
pub fn RiskScore::date(self : RiskScore) -> String {
  self.date
}

///|
pub fn RiskScore::score(self : RiskScore) -> Int {
  self.score
}

///|
pub fn RiskScore::level(self : RiskScore) -> RiskLevel {
  self.level
}

///|
pub fn RiskScore::factors(self : RiskScore) -> Array[RiskFactor] {
  self.factors
}

///|
pub fn RiskScore::action(self : RiskScore) -> String {
  self.action
}

///|
pub fn RiskScore::has_factor(self : RiskScore, kind : RiskFactorKind) -> Bool {
  self.factors.any(factor => factor.kind == kind)
}

///|
pub fn RiskScore::critical(self : RiskScore) -> Bool {
  self.level == RiskLevel::Critical
}

///|
fn level_for(score : Int) -> RiskLevel {
  if score >= 80 {
    RiskLevel::Critical
  } else if score >= 60 {
    RiskLevel::High
  } else if score >= 35 {
    RiskLevel::Elevated
  } else if score >= 15 {
    RiskLevel::Guarded
  } else {
    RiskLevel::Low
  }
}

///|
fn factor(
  kind : RiskFactorKind,
  score : Int,
  weight : Int,
  metric : Double,
  threshold : Double,
  message : String,
) -> RiskFactor {
  RiskFactor::{
    kind,
    score: Int::max(0, Int::min(100, score)),
    weight,
    metric,
    threshold,
    message,
  }
}

///|
fn pain_factor(session : @core.Session, options : RiskOptions) -> RiskFactor? {
  let value = session.average_pain_during()
  if value >= options.pain_threshold.to_double() {
    Some(
      factor(
        RiskFactorKind::HighPain,
        (value * 10.0).round().to_int(),
        3,
        value,
        options.pain_threshold.to_double(),
        "Pain is above the review threshold.",
      ),
    )
  } else {
    None
  }
}

///|
fn worsening_factor(
  session : @core.Session,
  options : RiskOptions,
) -> RiskFactor? {
  let delta = session.pain_delta()
  if delta >= options.worsening_delta {
    Some(
      factor(
        RiskFactorKind::WorseningPain,
        Int::min(100, delta * 20),
        3,
        delta.to_double(),
        options.worsening_delta.to_double(),
        "Pain increased during the session.",
      ),
    )
  } else {
    None
  }
}

///|
fn completion_factor(
  session : @core.Session,
  options : RiskOptions,
) -> RiskFactor? {
  let value = session.average_completion()
  if value < options.completion_threshold {
    Some(
      factor(
        RiskFactorKind::LowCompletion,
        ((options.completion_threshold - value) * 100.0).round().to_int(),
        2,
        value,
        options.completion_threshold,
        "Completion is below the prescribed tolerance.",
      ),
    )
  } else {
    None
  }
}

///|
fn effort_factor(session : @core.Session, options : RiskOptions) -> RiskFactor? {
  let mut highest = 0
  for movement in session.movements {
    highest = Int::max(highest, movement.rpe)
  }
  if highest >= options.effort_threshold {
    Some(
      factor(
        RiskFactorKind::HighEffort,
        highest * 10,
        2,
        highest.to_double(),
        options.effort_threshold.to_double(),
        "Perceived effort is high; review load or recovery.",
      ),
    )
  } else {
    None
  }
}

///|
fn validity_factor(
  session : @core.Session,
  options : RiskOptions,
) -> RiskFactor? {
  if @validation.is_valid(session) {
    None
  } else {
    Some(
      factor(
        RiskFactorKind::DataInvalid,
        options.invalid_penalty,
        1,
        0.0,
        1.0,
        "The record failed validation and should not drive progression.",
      ),
    )
  }
}

///|
fn missing_factor(
  session : @core.Session,
  options : RiskOptions,
) -> RiskFactor? {
  if session.notes.trim().is_empty() || session.movements.is_empty() {
    Some(
      factor(
        RiskFactorKind::MissingObservation,
        options.missing_penalty,
        1,
        0.0,
        1.0,
        "The observation is incomplete for safe interpretation.",
      ),
    )
  } else {
    None
  }
}

///|
fn action_for(level : RiskLevel, factors : Array[RiskFactor]) -> String {
  match level {
    RiskLevel::Critical =>
      "Pause progression and request clinical review immediately."
    RiskLevel::High => "Review symptoms and dose before the next session."
    RiskLevel::Elevated =>
      "Keep the next dose conservative and collect a complete observation."
    RiskLevel::Guarded =>
      "Monitor the next session and compare the same movement metrics."
    RiskLevel::Low =>
      if factors.is_empty() {
        "No additional action is required."
      } else {
        "Continue current monitoring."
      }
  }
}

///|
pub fn evaluate(
  session : @core.Session,
  options? : RiskOptions = default_risk_options(),
) -> RiskScore {
  let factors = []
  match pain_factor(session, options) {
    Some(value) => factors.push(value)
    None => ()
  }
  match worsening_factor(session, options) {
    Some(value) => factors.push(value)
    None => ()
  }
  match completion_factor(session, options) {
    Some(value) => factors.push(value)
    None => ()
  }
  match effort_factor(session, options) {
    Some(value) => factors.push(value)
    None => ()
  }
  match validity_factor(session, options) {
    Some(value) => factors.push(value)
    None => ()
  }
  match missing_factor(session, options) {
    Some(value) => factors.push(value)
    None => ()
  }
  let score = Int::min(
    100,
    factors.fold(init=0, (total, item) => total + item.weighted_score()),
  )
  let level = level_for(score)
  RiskScore::{
    session_id: session.id,
    date: session.date,
    score,
    level,
    factors,
    action: action_for(level, factors),
  }
}

///|
pub fn evaluate_many(
  sessions : Array[@core.Session],
  options? : RiskOptions = default_risk_options(),
) -> Array[RiskScore] {
  sessions.map(session => evaluate(session, options~))
}

///|
pub(all) struct RiskReport {
  scores : Array[RiskScore]
  average_score : Double
  maximum_score : Int
  high_count : Int
  critical_count : Int
  trend : Double
  recommendation : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RiskReport::scores(self : RiskReport) -> Array[RiskScore] {
  self.scores
}

///|
pub fn RiskReport::average_score(self : RiskReport) -> Double {
  self.average_score
}

///|
pub fn RiskReport::maximum_score(self : RiskReport) -> Int {
  self.maximum_score
}

///|
pub fn RiskReport::high_count(self : RiskReport) -> Int {
  self.high_count
}

///|
pub fn RiskReport::critical_count(self : RiskReport) -> Int {
  self.critical_count
}

///|
pub fn RiskReport::trend(self : RiskReport) -> Double {
  self.trend
}

///|
pub fn RiskReport::recommendation(self : RiskReport) -> String {
  self.recommendation
}

///|
fn report_recommendation(high : Int, critical : Int, trend : Double) -> String {
  if critical > 0 {
    "Escalate critical observations before increasing dose."
  } else if high > 0 {
    "Prioritize high-risk observations for review."
  } else if trend > 5.0 {
    "Risk is rising; shorten the feedback loop."
  } else {
    "Risk profile is within the expected monitoring range."
  }
}

///|
pub fn report(
  sessions : Array[@core.Session],
  options? : RiskOptions = default_risk_options(),
) -> RiskReport {
  let scores = evaluate_many(sessions, options~)
  let values = scores.map(item => item.score.to_double())
  let average = @statistics.mean(values)
  let maximum = values.fold(init=0, (current, value) => {
    Int::max(current, value.round().to_int())
  })
  let high = scores.count_if(item => item.level.rank() >= RiskLevel::High.rank())
  let critical = scores.count_if(item => item.level == RiskLevel::Critical)
  RiskReport::{
    scores,
    average_score: average,
    maximum_score: maximum,
    high_count: high,
    critical_count: critical,
    trend: @statistics.slope(values),
    recommendation: report_recommendation(
      high,
      critical,
      @statistics.slope(values),
    ),
  }
}

///|
pub fn high_risk(scores : Array[RiskScore]) -> Array[RiskScore] {
  scores.filter(item => item.level.rank() >= RiskLevel::High.rank())
}

///|
pub fn critical(scores : Array[RiskScore]) -> Array[RiskScore] {
  scores.filter(item => item.level == RiskLevel::Critical)
}

///|
pub fn factors(
  scores : Array[RiskScore],
  kind : RiskFactorKind,
) -> Array[RiskFactor] {
  let result = []
  for score in scores {
    for factor in score.factors {
      if factor.kind == kind {
        result.push(factor)
      }
    }
  }
  result
}

///|
pub fn factor_counts(scores : Array[RiskScore]) -> Array[(String, Int)] {
  let counts : Map[String, Int] = Map([])
  for score in scores {
    for factor in score.factors {
      counts.update_or_default(factor.kind.label(), 1, value => value + 1)
    }
  }
  counts.to_array()
}

///|
pub fn score_percentile(score : RiskScore, scores : Array[RiskScore]) -> Double {
  @statistics.percentile(
    scores.map(item => item.score.to_double()),
    score.score.to_double(),
  )
}

///|
pub fn next_action(score : RiskScore) -> String {
  score.action
}

///|
pub fn explain(score : RiskScore) -> String {
  let output = StringBuilder()
  output.write_string(
    score.session_id +
    " risk=" +
    score.level.label() +
    " (" +
    score.score.to_string() +
    ")\n",
  )
  for factor in score.factors {
    output.write_string(
      "- " + factor.kind.label() + ": " + factor.message + "\n",
    )
  }
  output.write_string("action: " + score.action + "\n")
  output.to_string()
}

///|
pub fn report_text(value : RiskReport) -> String {
  "average=" +
  value.average_score.to_string() +
  ", maximum=" +
  value.maximum_score.to_string() +
  ", high=" +
  value.high_count.to_string() +
  ", critical=" +
  value.critical_count.to_string() +
  ", trend=" +
  value.trend.to_string() +
  "\n" +
  value.recommendation
}
