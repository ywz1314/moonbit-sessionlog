///|
pub(all) enum QualityGrade {
  Excellent
  Good
  Review
  Poor
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn QualityGrade::label(self : QualityGrade) -> String {
  match self {
    Excellent => "excellent"
    Good => "good"
    Review => "review"
    Poor => "poor"
  }
}

///|
pub(all) struct QualityScore {
  session_id : String
  score : Int
  grade : QualityGrade
  completeness : Int
  consistency : Int
  validity : Int
  warnings : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn QualityScore::session_id(self : QualityScore) -> String {
  self.session_id
}

///|
pub fn QualityScore::score(self : QualityScore) -> Int {
  self.score
}

///|
pub fn QualityScore::grade(self : QualityScore) -> QualityGrade {
  self.grade
}

///|
pub fn QualityScore::completeness(self : QualityScore) -> Int {
  self.completeness
}

///|
pub fn QualityScore::consistency(self : QualityScore) -> Int {
  self.consistency
}

///|
pub fn QualityScore::validity(self : QualityScore) -> Int {
  self.validity
}

///|
pub fn QualityScore::warnings(self : QualityScore) -> Array[String] {
  self.warnings
}

///|
fn grade(score : Int) -> QualityGrade {
  if score >= 90 {
    QualityGrade::Excellent
  } else if score >= 75 {
    QualityGrade::Good
  } else if score >= 50 {
    QualityGrade::Review
  } else {
    QualityGrade::Poor
  }
}

///|
fn completeness_score(session : @core.Session) -> (Int, Array[String]) {
  let checks = [
    ("id", !session.id.trim().is_empty()),
    ("date", !session.date.trim().is_empty()),
    ("duration", session.duration > 0),
    ("movements", !session.movements.is_empty()),
    ("notes", !session.notes.trim().is_empty()),
  ]
  let missing = checks.filter(item => !item.1).map(item => item.0)
  let score = checks.count_if(item => item.1) * 100 / checks.length()
  (score, missing.map(value => "missing:" + value))
}

///|
fn consistency_score(session : @core.Session) -> (Int, Array[String]) {
  let warnings = []
  let mut checks = 0
  let mut passed = 0
  for movement in session.movements {
    if movement.sets.length() > 0 {
      checks += 1
      let first = movement.sets[0]
      if movement.sets.all(set => set.resistance == first.resistance) {
        passed += 1
      } else {
        warnings.push("mixed_resistance:" + movement.name)
      }
      checks += 1
      if movement.sets.all(set => set.reps > 0) {
        passed += 1
      } else {
        warnings.push("zero_reps:" + movement.name)
      }
    }
  }
  if checks == 0 {
    (0, ["no_sets"])
  } else {
    (passed * 100 / checks, warnings)
  }
}

///|
pub fn score(session : @core.Session) -> QualityScore {
  let (completeness, completeness_warnings) = completeness_score(session)
  let (consistency, consistency_warnings) = consistency_score(session)
  let validity = if @validation.is_valid(session) { 100 } else { 0 }
  let warnings = []
  warnings.append(completeness_warnings)
  warnings.append(consistency_warnings)
  if validity == 0 {
    warnings.push("validation_failed")
  }
  let total = (completeness + consistency + validity) / 3
  QualityScore::{
    session_id: session.id,
    score: total,
    grade: grade(total),
    completeness,
    consistency,
    validity,
    warnings,
  }
}

///|
pub fn score_many(sessions : Array[@core.Session]) -> Array[QualityScore] {
  sessions.map(session => score(session))
}

///|
pub fn average_score(sessions : Array[@core.Session]) -> Double {
  if sessions.is_empty() {
    0.0
  } else {
    score_many(sessions)
    .fold(init=0, (total, item) => total + item.score)
    .to_double() /
    sessions.length().to_double()
  }
}

///|
pub fn quality_failures(
  sessions : Array[@core.Session],
) -> Array[@core.Session] {
  sessions.filter(session => score(session).grade == QualityGrade::Poor)
}

///|
pub fn quality_warnings(sessions : Array[@core.Session]) -> Array[String] {
  let warnings = []
  for item in score_many(sessions) {
    for warning in item.warnings {
      if !warnings.contains(warning) {
        warnings.push(warning)
      }
    }
  }
  warnings
}

///|
pub fn duplicate_movement_names(session : @core.Session) -> Array[String] {
  let seen = []
  let duplicates = []
  for movement in session.movements {
    if seen.contains(movement.name) && !duplicates.contains(movement.name) {
      duplicates.push(movement.name)
    } else {
      seen.push(movement.name)
    }
  }
  duplicates
}

///|
pub fn empty_resistance_count(session : @core.Session) -> Int {
  session.movements.fold(init=0, (total, movement) => {
    total + movement.sets.count_if(set => set.resistance.trim().is_empty())
  })
}

///|
pub fn invalid_completion_count(session : @core.Session) -> Int {
  session.movements.fold(init=0, (total, movement) => {
    total +
    movement.sets.count_if(set => set.completion < 0.0 || set.completion > 1.0)
  })
}

///|
pub fn zero_duration_count(sessions : Array[@core.Session]) -> Int {
  sessions.count_if(session => session.duration <= 0)
}

///|
pub fn valid_ratio(sessions : Array[@core.Session]) -> Double {
  if sessions.is_empty() {
    0.0
  } else {
    sessions.count_if(session => @validation.is_valid(session)).to_double() *
    100.0 /
    sessions.length().to_double()
  }
}

///|
pub fn grade_counts(sessions : Array[@core.Session]) -> (Int, Int, Int, Int) {
  let mut excellent = 0
  let mut good = 0
  let mut review = 0
  let mut poor = 0
  for item in score_many(sessions) {
    match item.grade {
      QualityGrade::Excellent => excellent += 1
      QualityGrade::Good => good += 1
      QualityGrade::Review => review += 1
      QualityGrade::Poor => poor += 1
    }
  }
  (excellent, good, review, poor)
}

///|
pub fn quality_text(item : QualityScore) -> String {
  let output = StringBuilder()
  output.write_string(
    item.session_id +
    ": " +
    item.grade.label() +
    " (" +
    item.score.to_string() +
    ")\n",
  )
  output.write_string("completeness=" + item.completeness.to_string() + "%\n")
  output.write_string("consistency=" + item.consistency.to_string() + "%\n")
  output.write_string("validity=" + item.validity.to_string() + "%\n")
  for warning in item.warnings {
    output.write_string("- " + warning + "\n")
  }
  output.to_string()
}
