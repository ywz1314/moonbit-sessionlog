///|
/// Consistency repair suggestions identify records that should be reviewed or
/// normalized before aggregation; suggestions are not silent mutations.
pub(all) enum RepairKind {
  NormalizeName
  SplitDuplicate
  ReviewOutlier
  FillMissingSet
  VerifyPain
  Keep
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RepairKind::label(self : RepairKind) -> String {
  match self {
    NormalizeName => "normalize_name"
    SplitDuplicate => "split_duplicate"
    ReviewOutlier => "review_outlier"
    FillMissingSet => "fill_missing_set"
    VerifyPain => "verify_pain"
    Keep => "keep"
  }
}

///|
pub(all) struct RepairSuggestion {
  session_id : String
  movement_name : String
  kind : RepairKind
  priority : Int
  confidence : Double
  before : String
  after : String
  rationale : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RepairSuggestion::session_id(self : RepairSuggestion) -> String {
  self.session_id
}

///|
pub fn RepairSuggestion::movement_name(self : RepairSuggestion) -> String {
  self.movement_name
}

///|
pub fn RepairSuggestion::kind(self : RepairSuggestion) -> RepairKind {
  self.kind
}

///|
pub fn RepairSuggestion::priority(self : RepairSuggestion) -> Int {
  self.priority
}

///|
pub fn RepairSuggestion::confidence(self : RepairSuggestion) -> Double {
  self.confidence
}

///|
pub fn RepairSuggestion::before(self : RepairSuggestion) -> String {
  self.before
}

///|
pub fn RepairSuggestion::after(self : RepairSuggestion) -> String {
  self.after
}

///|
pub fn RepairSuggestion::rationale(self : RepairSuggestion) -> String {
  self.rationale
}

///|
fn suggestion(
  session : @core.Session,
  movement_name : String,
  kind : RepairKind,
  priority : Int,
  confidence : Double,
  before : String,
  after : String,
  rationale : String,
) -> RepairSuggestion {
  RepairSuggestion::{
    session_id: session.id,
    movement_name,
    kind,
    priority,
    confidence: confidence.clamp(min=0.0, max=1.0),
    before,
    after,
    rationale,
  }
}

///|
pub fn suggest_repairs(
  sessions : Array[@core.Session],
) -> Array[RepairSuggestion] {
  let result = []
  for session in sessions {
    let names = []
    for movement in session.movements {
      if movement.name.trim() != movement.name {
        result.push(
          suggestion(
            session,
            movement.name,
            RepairKind::NormalizeName,
            2,
            0.98,
            movement.name,
            movement.name.trim().to_owned(),
            "leading or trailing whitespace",
          ),
        )
      }
      if movement.name.trim().is_empty() {
        result.push(
          suggestion(
            session,
            movement.name,
            RepairKind::NormalizeName,
            1,
            1.0,
            movement.name,
            "unnamed",
            "movement name is empty",
          ),
        )
      }
      if names.contains(movement.name) {
        result.push(
          suggestion(
            session,
            movement.name,
            RepairKind::SplitDuplicate,
            3,
            0.95,
            movement.name,
            movement.name,
            "movement appears more than once in session",
          ),
        )
      }
      names.push(movement.name)
      if movement.pain >= 8 {
        result.push(
          suggestion(
            session,
            movement.name,
            RepairKind::VerifyPain,
            1,
            0.9,
            movement.pain.to_string(),
            "manual review",
            "very high movement pain",
          ),
        )
      }
      if movement.sets.is_empty() {
        result.push(
          suggestion(
            session,
            movement.name,
            RepairKind::FillMissingSet,
            3,
            0.8,
            "0 sets",
            "manual review",
            "movement has no recorded sets",
          ),
        )
      }
    }
  }
  result.sort_by((left, right) => left.priority - right.priority)
  result
}

///|
pub fn repairs_for_session(
  values : Array[RepairSuggestion],
  session_id : String,
) -> Array[RepairSuggestion] {
  values.filter(value => value.session_id == session_id)
}

///|
pub fn repairs_by_kind(
  values : Array[RepairSuggestion],
  kind : RepairKind,
) -> Array[RepairSuggestion] {
  values.filter(value => value.kind == kind)
}

///|
pub fn high_priority_repairs(
  values : Array[RepairSuggestion],
  maximum : Int,
) -> Array[RepairSuggestion] {
  values.filter(value => value.priority <= maximum)
}

///|
pub fn repair_confidence(values : Array[RepairSuggestion]) -> Double {
  if values.is_empty() {
    1.0
  } else {
    values.fold(init=0.0, (total, value) => total + value.confidence) /
    values.length().to_double()
  }
}

///|
pub fn repair_kind_counts(
  values : Array[RepairSuggestion],
) -> Array[(String, Int)] {
  let result : Array[(String, Int)] = []
  for value in values {
    let label = value.kind.label()
    match result.search_by(item => item.0 == label) {
      Some(index) => {
        let old = result[index]
        result[index] = (old.0, old.1 + 1)
      }
      None => result.push((label, 1))
    }
  }
  result
}

///|
pub fn repair_text(value : RepairSuggestion) -> String {
  value.session_id +
  " " +
  value.movement_name +
  " " +
  value.kind.label() +
  " priority=" +
  value.priority.to_string() +
  " confidence=" +
  value.confidence.to_string() +
  " " +
  value.rationale
}

///|
pub fn repair_report_text(values : Array[RepairSuggestion]) -> String {
  "suggestions=" +
  values.length().to_string() +
  ", high_priority=" +
  high_priority_repairs(values, 1).length().to_string() +
  ", confidence=" +
  repair_confidence(values).to_string()
}

///|
pub fn repair_checksum(values : Array[RepairSuggestion]) -> Int {
  values.fold(init=41, (total, value) => {
    total * 31 + value.priority + value.movement_name.length()
  })
}
