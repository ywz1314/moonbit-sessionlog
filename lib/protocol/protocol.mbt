///|
/// A lightweight, deterministic protocol layer for turning measurements into
/// reviewable milestones. It does not prescribe medical treatment; it makes
/// the operational assumptions explicit and auditable.
pub(all) enum ProtocolPhase {
  Assessment
  Activation
  Capacity
  Function
  Maintenance
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ProtocolPhase::label(self : ProtocolPhase) -> String {
  match self {
    Assessment => "assessment"
    Activation => "activation"
    Capacity => "capacity"
    Function => "function"
    Maintenance => "maintenance"
  }
}

///|
pub fn ProtocolPhase::rank(self : ProtocolPhase) -> Int {
  match self {
    Assessment => 0
    Activation => 1
    Capacity => 2
    Function => 3
    Maintenance => 4
  }
}

///|
pub fn next_phase(phase : ProtocolPhase) -> ProtocolPhase {
  match phase {
    Assessment => Activation
    Activation => Capacity
    Capacity => Function
    Function => Maintenance
    Maintenance => Maintenance
  }
}

///|
pub fn previous_phase(phase : ProtocolPhase) -> ProtocolPhase {
  match phase {
    Assessment => Assessment
    Activation => Assessment
    Capacity => Activation
    Function => Capacity
    Maintenance => Function
  }
}

///|
pub(all) enum GoalMetric {
  PainAfter
  PainDelta
  Completion
  Repetitions
  WorkUnits
  Duration
  Readiness
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn GoalMetric::label(self : GoalMetric) -> String {
  match self {
    PainAfter => "pain_after"
    PainDelta => "pain_delta"
    Completion => "completion"
    Repetitions => "repetitions"
    WorkUnits => "work_units"
    Duration => "duration"
    Readiness => "readiness"
  }
}

///|
pub fn GoalMetric::lower_is_better(self : GoalMetric) -> Bool {
  self == GoalMetric::PainAfter || self == GoalMetric::PainDelta
}

///|
pub(all) struct Goal {
  id : String
  title : String
  metric : GoalMetric
  target : Double
  tolerance : Double
  deadline : String
  phase : ProtocolPhase
  required_observations : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Goal::id(self : Goal) -> String {
  self.id
}

///|
pub fn Goal::title(self : Goal) -> String {
  self.title
}

///|
pub fn Goal::metric(self : Goal) -> GoalMetric {
  self.metric
}

///|
pub fn Goal::target(self : Goal) -> Double {
  self.target
}

///|
pub fn Goal::tolerance(self : Goal) -> Double {
  self.tolerance
}

///|
pub fn Goal::deadline(self : Goal) -> String {
  self.deadline
}

///|
pub fn Goal::phase(self : Goal) -> ProtocolPhase {
  self.phase
}

///|
pub fn Goal::required_observations(self : Goal) -> Int {
  self.required_observations
}

///|
pub fn goal(
  id : String,
  title : String,
  metric : GoalMetric,
  target : Double,
  tolerance : Double,
  deadline : String,
  phase : ProtocolPhase,
  required_observations : Int,
) -> Goal {
  Goal::{
    id,
    title,
    metric,
    target,
    tolerance: tolerance.abs(),
    deadline,
    phase,
    required_observations: Int::max(1, required_observations),
  }
}

///|
pub(all) struct Protocol {
  name : String
  phase : ProtocolPhase
  goals : Array[Goal]
  risk_limit : @risk.RiskLevel
  minimum_sessions : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Protocol::name(self : Protocol) -> String {
  self.name
}

///|
pub fn Protocol::phase(self : Protocol) -> ProtocolPhase {
  self.phase
}

///|
pub fn Protocol::goals(self : Protocol) -> Array[Goal] {
  self.goals
}

///|
pub fn Protocol::risk_limit(self : Protocol) -> @risk.RiskLevel {
  self.risk_limit
}

///|
pub fn Protocol::minimum_sessions(self : Protocol) -> Int {
  self.minimum_sessions
}

///|
pub fn new_protocol(name : String, phase : ProtocolPhase) -> Protocol {
  Protocol::{
    name,
    phase,
    goals: [],
    risk_limit: @risk.RiskLevel::High,
    minimum_sessions: 3,
  }
}

///|
pub fn Protocol::add_goal(self : Protocol, value : Goal) -> Protocol {
  let result = self
  result.goals.push(value)
  result
}

///|
pub fn Protocol::remove_goal(self : Protocol, id : String) -> Protocol {
  let result = self
  result.goals.retain(goal => goal.id != id)
  result
}

///|
pub fn Protocol::goals_for_phase(
  self : Protocol,
  phase : ProtocolPhase,
) -> Array[Goal] {
  self.goals.filter(goal => goal.phase == phase)
}

///|
pub fn Protocol::goal(self : Protocol, id : String) -> Goal? {
  for item in self.goals {
    if item.id == id {
      return Some(item)
    }
  }
  None
}

///|
pub fn Protocol::validate(self : Protocol) -> Array[String] {
  let errors = []
  if self.name.trim().is_empty() {
    errors.push("protocol name must not be empty")
  }
  if self.goals.is_empty() {
    errors.push("protocol must define at least one goal")
  }
  let ids = []
  for item in self.goals {
    if item.id.trim().is_empty() {
      errors.push("goal id must not be empty")
    }
    if ids.contains(item.id) {
      errors.push("duplicate goal id: " + item.id)
    } else {
      ids.push(item.id)
    }
    if item.title.trim().is_empty() {
      errors.push("goal title must not be empty: " + item.id)
    }
    if item.deadline.trim().is_empty() {
      errors.push("goal deadline must not be empty: " + item.id)
    }
    if item.tolerance < 0.0 {
      errors.push("goal tolerance must not be negative: " + item.id)
    }
  }
  errors
}

///|
pub fn Protocol::with_risk_limit(
  self : Protocol,
  limit : @risk.RiskLevel,
) -> Protocol {
  Protocol::{
    name: self.name,
    phase: self.phase,
    goals: self.goals,
    risk_limit: limit,
    minimum_sessions: self.minimum_sessions,
  }
}

///|
pub fn Protocol::with_minimum_sessions(
  self : Protocol,
  count : Int,
) -> Protocol {
  Protocol::{
    name: self.name,
    phase: self.phase,
    goals: self.goals,
    risk_limit: self.risk_limit,
    minimum_sessions: Int::max(1, count),
  }
}

///|
pub fn value_for(metric : GoalMetric, session : @core.Session) -> Double {
  match metric {
    GoalMetric::PainAfter => session.pain_after.to_double()
    GoalMetric::PainDelta => session.pain_delta().to_double()
    GoalMetric::Completion => session.average_completion()
    GoalMetric::Repetitions => session.total_reps().to_double()
    GoalMetric::WorkUnits =>
      session.movements
      .fold(init=0, (total, movement) => total + movement.work_units())
      .to_double()
    GoalMetric::Duration => session.duration.to_double()
    GoalMetric::Readiness => {
      let completion = session.average_completion() * 50.0
      let pain = (10 - session.pain_after).to_double() * 5.0
      Int::max(0, Int::min(100, (completion + pain).round().to_int())).to_double()
    }
  }
}

///|
pub fn target_distance(goal : Goal, value : Double) -> Double {
  (value - goal.target).abs()
}

///|
pub fn goal_met(goal : Goal, value : Double) -> Bool {
  target_distance(goal, value) <= goal.tolerance
}

///|
pub fn goal_progress(goal : Goal, baseline : Double, value : Double) -> Double {
  if goal_met(goal, value) {
    100.0
  } else if baseline == goal.target {
    0.0
  } else {
    let total = (goal.target - baseline).abs()
    if total == 0.0 {
      0.0
    } else {
      Double::max(
        0.0,
        Double::min(100.0, (value - baseline).abs() / total * 100.0),
      )
    }
  }
}

///|
pub(all) struct GoalProgress {
  goal : Goal
  observations : Int
  baseline : Double
  current : Double
  average : Double
  progress : Double
  met : Bool
  stable : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn GoalProgress::goal(self : GoalProgress) -> Goal {
  self.goal
}

///|
pub fn GoalProgress::observations(self : GoalProgress) -> Int {
  self.observations
}

///|
pub fn GoalProgress::baseline(self : GoalProgress) -> Double {
  self.baseline
}

///|
pub fn GoalProgress::current(self : GoalProgress) -> Double {
  self.current
}

///|
pub fn GoalProgress::average(self : GoalProgress) -> Double {
  self.average
}

///|
pub fn GoalProgress::progress(self : GoalProgress) -> Double {
  self.progress
}

///|
pub fn GoalProgress::met(self : GoalProgress) -> Bool {
  self.met
}

///|
pub fn GoalProgress::stable(self : GoalProgress) -> Bool {
  self.stable
}

///|
fn evaluate_goal(goal : Goal, sessions : Array[@core.Session]) -> GoalProgress {
  let values = sessions.map(session => value_for(goal.metric, session))
  let baseline = values.get(0).unwrap_or(0.0)
  let current = values.get(values.length() - 1).unwrap_or(0.0)
  let average = @statistics.mean(values)
  let stable = values.length() >= goal.required_observations &&
    @statistics.stable(values, goal.tolerance)
  GoalProgress::{
    goal,
    observations: values.length(),
    baseline,
    current,
    average,
    progress: goal_progress(goal, baseline, current),
    met: goal_met(goal, current) && stable,
    stable,
  }
}

///|
pub fn evaluate_goals(
  protocol : Protocol,
  sessions : Array[@core.Session],
) -> Array[GoalProgress] {
  protocol.goals.map(goal => evaluate_goal(goal, sessions))
}

///|
pub(all) enum ProtocolDecision {
  Hold
  Advance
  Regress
  Review
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ProtocolDecision::label(self : ProtocolDecision) -> String {
  match self {
    Hold => "hold"
    Advance => "advance"
    Regress => "regress"
    Review => "review"
  }
}

///|
pub(all) struct ProtocolReview {
  protocol_name : String
  phase : ProtocolPhase
  decision : ProtocolDecision
  risk : @risk.RiskScore
  goals : Array[GoalProgress]
  readiness : Double
  rationale : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ProtocolReview::protocol_name(self : ProtocolReview) -> String {
  self.protocol_name
}

///|
pub fn ProtocolReview::phase(self : ProtocolReview) -> ProtocolPhase {
  self.phase
}

///|
pub fn ProtocolReview::decision(self : ProtocolReview) -> ProtocolDecision {
  self.decision
}

///|
pub fn ProtocolReview::risk(self : ProtocolReview) -> @risk.RiskScore {
  self.risk
}

///|
pub fn ProtocolReview::goals(self : ProtocolReview) -> Array[GoalProgress] {
  self.goals
}

///|
pub fn ProtocolReview::readiness(self : ProtocolReview) -> Double {
  self.readiness
}

///|
pub fn ProtocolReview::rationale(self : ProtocolReview) -> String {
  self.rationale
}

///|
fn decision_for(
  protocol : Protocol,
  risk : @risk.RiskScore,
  goals : Array[GoalProgress],
) -> ProtocolDecision {
  if risk.level().rank() >= protocol.risk_limit.rank() {
    ProtocolDecision::Review
  } else if goals.is_empty() {
    ProtocolDecision::Hold
  } else if goals.all(item => item.met()) && goals.all(item => item.stable()) {
    ProtocolDecision::Advance
  } else if goals.any(item => item.progress() < 0.0) {
    ProtocolDecision::Regress
  } else {
    ProtocolDecision::Hold
  }
}

///|
pub fn review(
  protocol : Protocol,
  sessions : Array[@core.Session],
) -> ProtocolReview {
  let latest = sessions
    .get(sessions.length() - 1)
    .unwrap_or(@core.Session::{
      id: "",
      date: "",
      duration: 0,
      pain_before: 0,
      pain_after: 0,
      movements: [],
      notes: "",
    })
  let risk = @risk.evaluate(latest)
  let goals = evaluate_goals(protocol, sessions)
  let readiness = if goals.is_empty() {
    0.0
  } else {
    goals.fold(init=0.0, (total, item) => total + item.progress()) /
    goals.length().to_double()
  }
  let decision = decision_for(protocol, risk, goals)
  let rationale = match decision {
    ProtocolDecision::Advance => "All active goals are met and stable."
    ProtocolDecision::Regress =>
      "At least one goal is moving away from its target."
    ProtocolDecision::Review => "Risk exceeded the protocol review limit."
    ProtocolDecision::Hold =>
      "Collect another comparable observation before changing phase."
  }
  ProtocolReview::{
    protocol_name: protocol.name,
    phase: protocol.phase,
    decision,
    risk,
    goals,
    readiness,
    rationale,
  }
}

///|
pub fn suggested_phase(review : ProtocolReview) -> ProtocolPhase {
  match review.decision {
    ProtocolDecision::Advance => next_phase(review.phase)
    ProtocolDecision::Regress => previous_phase(review.phase)
    _ => review.phase
  }
}

///|
pub fn unmet_goals(review : ProtocolReview) -> Array[GoalProgress] {
  review.goals.filter(item => !item.met())
}

///|
pub fn met_goals(review : ProtocolReview) -> Array[GoalProgress] {
  review.goals.filter(item => item.met())
}

///|
pub fn overdue_goals(
  review : ProtocolReview,
  today : String,
) -> Array[GoalProgress] {
  review.goals.filter(item => item.goal.deadline < today && !item.met())
}

///|
pub fn progress_summary(review : ProtocolReview) -> String {
  review.protocol_name +
  " phase=" +
  review.phase.label() +
  " decision=" +
  review.decision.label() +
  " readiness=" +
  review.readiness.to_string()
}

///|
pub fn review_text(review : ProtocolReview) -> String {
  let output = StringBuilder()
  output.write_string(progress_summary(review) + "\n")
  output.write_string(
    "risk=" +
    review.risk.level().label() +
    " (" +
    review.risk.score().to_string() +
    ")\n",
  )
  for item in review.goals {
    output.write_string(
      item.goal.id +
      ": " +
      item.progress.to_string() +
      "% met=" +
      item.met.to_string() +
      "\n",
    )
  }
  output.write_string(review.rationale + "\n")
  output.to_string()
}
