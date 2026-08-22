///|
/// Quality assessment turns validation observations into a stable score that
/// can be used for import gates and review queues.
pub(all) enum QualityDimension {
  Identity
  Date
  Completeness
  NumericRange
  ClinicalContext
  Consistency
  Freshness
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn QualityDimension::label(self : QualityDimension) -> String {
  match self {
    Identity => "identity"
    Date => "date"
    Completeness => "completeness"
    NumericRange => "numeric_range"
    ClinicalContext => "clinical_context"
    Consistency => "consistency"
    Freshness => "freshness"
  }
}

///|
pub(all) struct DimensionScore {
  dimension : QualityDimension
  score : Double
  weight : Double
  passed : Bool
  reasons : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn DimensionScore::dimension(self : DimensionScore) -> QualityDimension {
  self.dimension
}

///|
pub fn DimensionScore::score(self : DimensionScore) -> Double {
  self.score
}

///|
pub fn DimensionScore::weight(self : DimensionScore) -> Double {
  self.weight
}

///|
pub fn DimensionScore::passed(self : DimensionScore) -> Bool {
  self.passed
}

///|
pub fn DimensionScore::reasons(self : DimensionScore) -> Array[String] {
  self.reasons.copy()
}

///|
fn dimension(
  kind : QualityDimension,
  score : Double,
  weight : Double,
  reasons : Array[String],
) -> DimensionScore {
  DimensionScore::{
    dimension: kind,
    score: score.clamp(min=0.0, max=100.0),
    weight,
    passed: score >= 70.0,
    reasons,
  }
}

///|
fn identity_score(session : @core.Session) -> DimensionScore {
  let reasons = []
  let score = if session.id.trim().is_empty() {
    reasons.push("missing id")
    0.0
  } else {
    100.0
  }
  dimension(QualityDimension::Identity, score, 2.0, reasons)
}

///|
fn date_score(
  session : @core.Session,
  reference_date : String,
) -> DimensionScore {
  let reasons = []
  let mut score = 100.0
  match @calendar.parse(session.date) {
    Some(date) =>
      match @calendar.parse(reference_date) {
        Some(reference) =>
          if @calendar.days_between(date, reference).abs() > 3660 {
            score -= 20.0
            reasons.push("date is more than ten years from reference")
          }
        None => ()
      }
    None => {
      score = 0.0
      reasons.push("invalid date")
    }
  }
  dimension(QualityDimension::Date, score, 2.0, reasons)
}

///|
fn assessment_completeness_score(session : @core.Session) -> DimensionScore {
  let reasons = []
  let mut score = 100.0
  if session.movements.is_empty() {
    score -= 50.0
    reasons.push("no movements")
  }
  if session.total_sets() == 0 {
    score -= 25.0
    reasons.push("no sets")
  }
  if session.duration <= 0 {
    score -= 15.0
    reasons.push("missing duration")
  }
  if session.notes.trim().is_empty() {
    score -= 10.0
    reasons.push("missing notes")
  }
  dimension(QualityDimension::Completeness, score, 3.0, reasons)
}

///|
fn numeric_score(session : @core.Session) -> DimensionScore {
  let reasons = []
  let mut score = 100.0
  if session.pain_before < 0 || session.pain_before > 10 {
    score -= 30.0
    reasons.push("pain_before out of range")
  }
  if session.pain_after < 0 || session.pain_after > 10 {
    score -= 30.0
    reasons.push("pain_after out of range")
  }
  for movement in session.movements {
    if movement.pain < 0 || movement.pain > 10 {
      score -= 10.0
      reasons.push("movement pain out of range")
    }
    if movement.rpe < 1 || movement.rpe > 10 {
      score -= 10.0
      reasons.push("RPE out of range")
    }
    for set in movement.sets {
      if set.reps < 0 || set.hold_time < 0 {
        score -= 5.0
        reasons.push("negative set quantity")
      }
      if set.completion < 0.0 || set.completion > 1.0 {
        score -= 5.0
        reasons.push("completion out of range")
      }
    }
  }
  dimension(QualityDimension::NumericRange, score, 4.0, reasons)
}

///|
fn context_score(session : @core.Session) -> DimensionScore {
  let reasons = []
  let mut score = 100.0
  if session.movements.length() > 0 && session.notes.trim().is_empty() {
    score -= 20.0
    reasons.push("movements have no clinical context")
  }
  if session.pain_after >= 7 && session.notes.trim().is_empty() {
    score -= 40.0
    reasons.push("high pain requires a note")
  }
  dimension(QualityDimension::ClinicalContext, score, 2.0, reasons)
}

///|
fn assessment_consistency_score(session : @core.Session) -> DimensionScore {
  let reasons = []
  let mut score = 100.0
  let names = []
  for movement in session.movements {
    if names.contains(movement.name) {
      score -= 15.0
      reasons.push("duplicate movement")
    }
    names.push(movement.name)
  }
  if session.pain_after - session.pain_before > 5 {
    score -= 20.0
    reasons.push("large pain increase")
  }
  dimension(QualityDimension::Consistency, score, 2.0, reasons)
}

///|
fn assessment_freshness_score(
  session : @core.Session,
  reference_date : String,
) -> DimensionScore {
  let reasons = []
  let mut score = 100.0
  match (@calendar.parse(session.date), @calendar.parse(reference_date)) {
    (Some(date), Some(reference)) => {
      let age = @calendar.days_between(date, reference)
      if age > 730 {
        score = 50.0
        reasons.push("older than two years")
      }
      if age > 1825 {
        score = 20.0
        reasons.push("older than five years")
      }
    }
    _ => {
      score = 0.0
      reasons.push("freshness cannot be evaluated")
    }
  }
  dimension(QualityDimension::Freshness, score, 1.0, reasons)
}

///|
pub(all) struct QualityAssessment {
  session_id : String
  overall : Double
  dimensions : Array[DimensionScore]
  passed : Bool
  blocking : Bool
  recommendations : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn QualityAssessment::session_id(self : QualityAssessment) -> String {
  self.session_id
}

///|
pub fn QualityAssessment::overall(self : QualityAssessment) -> Double {
  self.overall
}

///|
pub fn QualityAssessment::dimensions(
  self : QualityAssessment,
) -> Array[DimensionScore] {
  self.dimensions.copy()
}

///|
pub fn QualityAssessment::passed(self : QualityAssessment) -> Bool {
  self.passed
}

///|
pub fn QualityAssessment::blocking(self : QualityAssessment) -> Bool {
  self.blocking
}

///|
pub fn QualityAssessment::recommendations(
  self : QualityAssessment,
) -> Array[String] {
  self.recommendations.copy()
}

///|
pub fn assess_quality(
  session : @core.Session,
  reference_date : String,
) -> QualityAssessment {
  let dimensions = [
    identity_score(session),
    date_score(session, reference_date),
    assessment_completeness_score(session),
    numeric_score(session),
    context_score(session),
    assessment_consistency_score(session),
    assessment_freshness_score(session, reference_date),
  ]
  let weight = dimensions.fold(init=0.0, (total, value) => total + value.weight)
  let weighted = dimensions.fold(init=0.0, (total, value) => {
    total + value.score * value.weight
  })
  let overall = if weight == 0.0 { 0.0 } else { weighted / weight }
  let recommendations = []
  for value in dimensions {
    for reason in value.reasons {
      recommendations.push(value.dimension.label() + ": " + reason)
    }
  }
  QualityAssessment::{
    session_id: session.id,
    overall,
    dimensions,
    passed: overall >= 70.0,
    blocking: dimensions.any(value => {
      value.dimension == QualityDimension::Identity && !value.passed
    }) ||
    overall < 40.0,
    recommendations,
  }
}

///|
pub fn assess_quality_many(
  sessions : Array[@core.Session],
  reference_date : String,
) -> Array[QualityAssessment] {
  sessions.map(session => assess_quality(session, reference_date))
}

///|
pub fn quality_passed(
  values : Array[QualityAssessment],
) -> Array[QualityAssessment] {
  values.filter(value => value.passed)
}

///|
pub fn quality_blocked(
  values : Array[QualityAssessment],
) -> Array[QualityAssessment] {
  values.filter(value => value.blocking)
}

///|
pub fn quality_average(values : Array[QualityAssessment]) -> Double {
  if values.is_empty() {
    0.0
  } else {
    values.fold(init=0.0, (total, value) => total + value.overall) /
    values.length().to_double()
  }
}

///|
pub fn quality_dimension_average(
  values : Array[QualityAssessment],
  dimension : QualityDimension,
) -> Double {
  let scores = []
  for assessment in values {
    match
      assessment.dimensions.search_by(value => value.dimension == dimension) {
      Some(index) => scores.push(assessment.dimensions[index].score)
      None => ()
    }
  }
  if scores.is_empty() {
    0.0
  } else {
    scores.fold(init=0.0, (total, value) => total + value) /
    scores.length().to_double()
  }
}

///|
pub fn assessment_text(value : QualityAssessment) -> String {
  "session=" +
  value.session_id +
  " score=" +
  value.overall.to_string() +
  " passed=" +
  value.passed.to_string() +
  " blocking=" +
  value.blocking.to_string()
}

///|
pub fn quality_report_text(values : Array[QualityAssessment]) -> String {
  "count=" +
  values.length().to_string() +
  ", average=" +
  quality_average(values).to_string() +
  ", passed=" +
  quality_passed(values).length().to_string() +
  ", blocked=" +
  quality_blocked(values).length().to_string()
}
