///|
pub(all) enum ValidationError {
  InvalidPain(String, Int) // (field_name, value)
  InvalidRPE(String, Int) // (field_name, value)
  InvalidReps(String, Int) // (field_name, value)
  InvalidDuration(Int) // value
  InvalidCompletion(String, Double) // (field_name, value)
  InvalidDate(String) // date value
  InvalidId(String)
  InvalidMovementName(String)
  InvalidResistance(String)
  InvalidNotes(String)
  PainWorsened(Int)
  TooManySets(String, Int)
  TooManyReps(String, Int)
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn validate_session(session : @core.Session) -> Array[ValidationError] {
  let errors = []

  // 1. Pain VAS checks
  if session.pain_before < 0 || session.pain_before > 10 {
    errors.push(
      ValidationError::InvalidPain("pain_before", session.pain_before),
    )
  }
  if session.pain_after < 0 || session.pain_after > 10 {
    errors.push(ValidationError::InvalidPain("pain_after", session.pain_after))
  }

  // 2. Duration check
  if session.duration < 0 {
    errors.push(ValidationError::InvalidDuration(session.duration))
  }

  // 3. Date check (YYYY-MM-DD basic verification)
  if !is_calendar_date(session.date) {
    errors.push(ValidationError::InvalidDate(session.date))
  }

  // 4. Movements check
  for movement in session.movements {
    if movement.pain < 0 || movement.pain > 10 {
      errors.push(
        ValidationError::InvalidPain(
          "movement:" + movement.name + ":pain",
          movement.pain,
        ),
      )
    }
    if movement.rpe < 1 || movement.rpe > 10 {
      errors.push(
        ValidationError::InvalidRPE(
          "movement:" + movement.name + ":rpe",
          movement.rpe,
        ),
      )
    }

    // Sets check
    for i, set in movement.sets {
      let suffix = ":" + i.to_string()
      if set.reps < 0 {
        errors.push(
          ValidationError::InvalidReps(
            "movement:" + movement.name + ":set" + suffix + ":reps",
            set.reps,
          ),
        )
      }
      if set.hold_time < 0 {
        errors.push(
          ValidationError::InvalidReps(
            "movement:" + movement.name + ":set" + suffix + ":hold_time",
            set.hold_time,
          ),
        ) // using InvalidReps for negative hold_time
      }
      if set.completion < 0.0 || set.completion > 1.0 {
        errors.push(
          ValidationError::InvalidCompletion(
            "movement:" + movement.name + ":set" + suffix + ":completion",
            set.completion,
          ),
        )
      }
    }
  }

  errors
}

///|
pub(all) struct ValidationOptions {
  require_id : Bool
  require_movement_name : Bool
  require_resistance : Bool
  reject_empty_notes : Bool
  reject_pain_worsening : Bool
  max_duration : Int
  max_sets_per_movement : Int
  max_reps_per_set : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_validation_options() -> ValidationOptions {
  ValidationOptions::{
    require_id: false,
    require_movement_name: false,
    require_resistance: false,
    reject_empty_notes: false,
    reject_pain_worsening: false,
    max_duration: 0,
    max_sets_per_movement: 0,
    max_reps_per_set: 0,
  }
}

///|
pub fn strict_validation_options() -> ValidationOptions {
  ValidationOptions::{
    require_id: true,
    require_movement_name: true,
    require_resistance: true,
    reject_empty_notes: false,
    reject_pain_worsening: false,
    max_duration: 240,
    max_sets_per_movement: 30,
    max_reps_per_set: 500,
  }
}

///|
fn is_digit(code : UInt16) -> Bool {
  code >= 48 && code <= 57
}

///|
fn digit_at(value : String, index : Int) -> Int? {
  match value.get(index) {
    Some(code) => if is_digit(code) { Some(code.to_int() - 48) } else { None }
    None => None
  }
}

///|
fn two_digits(value : String, index : Int) -> Int? {
  match (digit_at(value, index), digit_at(value, index + 1)) {
    (Some(first), Some(second)) => Some(first * 10 + second)
    _ => None
  }
}

///|
fn four_digits(value : String) -> Int? {
  match
    (
      digit_at(value, 0),
      digit_at(value, 1),
      digit_at(value, 2),
      digit_at(value, 3),
    ) {
    (Some(a), Some(b), Some(c), Some(d)) =>
      Some(a * 1000 + b * 100 + c * 10 + d)
    _ => None
  }
}

///|
pub fn is_leap_year(year : Int) -> Bool {
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
}

///|
pub fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
}

///|
pub fn is_calendar_date(value : String) -> Bool {
  if value.length() != 10 || value[4] != '-' || value[7] != '-' {
    false
  } else {
    let year = four_digits(value)
    let month = two_digits(value, 5)
    let day = two_digits(value, 8)
    match (year, month, day) {
      (Some(y), Some(m), Some(d)) =>
        m >= 1 && m <= 12 && d >= 1 && d <= days_in_month(y, m)
      _ => false
    }
  }
}

///|
pub fn validation_error_code(error : ValidationError) -> String {
  match error {
    InvalidPain(_, _) => "invalid_pain"
    InvalidRPE(_, _) => "invalid_rpe"
    InvalidReps(_, _) => "invalid_reps"
    InvalidDuration(_) => "invalid_duration"
    InvalidCompletion(_, _) => "invalid_completion"
    InvalidDate(_) => "invalid_date"
    InvalidId(_) => "invalid_id"
    InvalidMovementName(_) => "invalid_movement_name"
    InvalidResistance(_) => "invalid_resistance"
    InvalidNotes(_) => "invalid_notes"
    PainWorsened(_) => "pain_worsened"
    TooManySets(_, _) => "too_many_sets"
    TooManyReps(_, _) => "too_many_reps"
  }
}

///|
pub fn validation_error_path(error : ValidationError) -> String {
  match error {
    InvalidPain(field, _) => field
    InvalidRPE(field, _) => field
    InvalidReps(field, _) => field
    InvalidDuration(_) => "duration"
    InvalidCompletion(field, _) => field
    InvalidDate(_) => "date"
    InvalidId(_) => "id"
    InvalidMovementName(name) => "movement:" + name + ":name"
    InvalidResistance(name) => "movement:" + name + ":resistance"
    InvalidNotes(_) => "notes"
    PainWorsened(_) => "pain_after"
    TooManySets(name, _) => "movement:" + name + ":sets"
    TooManyReps(name, _) => "movement:" + name + ":reps"
  }
}

///|
pub fn validate_session_with_options(
  session : @core.Session,
  options : ValidationOptions,
) -> Array[ValidationError] {
  let errors = validate_session(session)
  if options.require_id && session.id.trim().is_empty() {
    errors.push(ValidationError::InvalidId(session.id))
  }
  if options.reject_empty_notes && session.notes.trim().is_empty() {
    errors.push(ValidationError::InvalidNotes(session.notes))
  }
  if options.reject_pain_worsening && session.pain_after > session.pain_before {
    errors.push(
      ValidationError::PainWorsened(session.pain_after - session.pain_before),
    )
  }
  if options.max_duration > 0 && session.duration > options.max_duration {
    errors.push(ValidationError::InvalidDuration(session.duration))
  }
  for movement in session.movements {
    if options.require_movement_name && movement.name.trim().is_empty() {
      errors.push(ValidationError::InvalidMovementName(movement.name))
    }
    if options.require_resistance &&
      movement.sets.any(set => set.resistance.trim().is_empty()) {
      errors.push(ValidationError::InvalidResistance(movement.name))
    }
    if options.max_sets_per_movement > 0 &&
      movement.sets.length() > options.max_sets_per_movement {
      errors.push(
        ValidationError::TooManySets(movement.name, movement.sets.length()),
      )
    }
    if options.max_reps_per_set > 0 {
      for set in movement.sets {
        if set.reps > options.max_reps_per_set {
          errors.push(ValidationError::TooManyReps(movement.name, set.reps))
        }
      }
    }
  }
  errors
}

///|
pub fn is_valid(session : @core.Session) -> Bool {
  validate_session(session).is_empty()
}

///|
pub fn is_strictly_valid(session : @core.Session) -> Bool {
  validate_session_with_options(session, strict_validation_options()).is_empty()
}

///|
pub(all) struct ValidationSummary {
  session_id : String
  valid : Bool
  error_count : Int
  codes : Array[String]
  paths : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ValidationSummary::session_id(self : ValidationSummary) -> String {
  self.session_id
}

///|
pub fn ValidationSummary::valid(self : ValidationSummary) -> Bool {
  self.valid
}

///|
pub fn ValidationSummary::error_count(self : ValidationSummary) -> Int {
  self.error_count
}

///|
pub fn ValidationSummary::codes(self : ValidationSummary) -> Array[String] {
  self.codes
}

///|
pub fn ValidationSummary::paths(self : ValidationSummary) -> Array[String] {
  self.paths
}

///|
pub fn summarize(
  session : @core.Session,
  options? : ValidationOptions = default_validation_options(),
) -> ValidationSummary {
  let errors = validate_session_with_options(session, options)
  let codes = errors.map(error => validation_error_code(error))
  codes.dedup()
  let paths = errors.map(error => validation_error_path(error))
  ValidationSummary::{
    session_id: session.id,
    valid: errors.is_empty(),
    error_count: errors.length(),
    codes,
    paths,
  }
}

///|
pub fn summarize_many(
  sessions : Array[@core.Session],
  options? : ValidationOptions = default_validation_options(),
) -> Array[ValidationSummary] {
  sessions.map(session => summarize(session, options~))
}

///|
pub fn count_errors(
  sessions : Array[@core.Session],
  options? : ValidationOptions = default_validation_options(),
) -> Int {
  summarize_many(sessions, options~).fold(init=0, (total, summary) => {
    total + summary.error_count
  })
}

///|
pub fn first_error(session : @core.Session) -> ValidationError? {
  validate_session(session).get(0)
}

///|
pub fn errors_by_code(
  errors : Array[ValidationError],
  code : String,
) -> Array[ValidationError] {
  errors.filter(error => validation_error_code(error) == code)
}

///|
pub fn error_code_counts(
  errors : Array[ValidationError],
) -> Array[(String, Int)] {
  let counts : Map[String, Int] = Map([])
  for error in errors {
    let code = validation_error_code(error)
    counts.update_or_default(code, 1, value => value + 1)
  }
  counts.to_array()
}

///|
pub fn validate_many(
  sessions : Array[@core.Session],
  options? : ValidationOptions = default_validation_options(),
) -> Array[(String, Array[ValidationError])] {
  sessions.map(session => {
    (session.id, validate_session_with_options(session, options))
  })
}

///|
pub fn all_valid(
  sessions : Array[@core.Session],
  options? : ValidationOptions = default_validation_options(),
) -> Bool {
  sessions.all(session => {
    validate_session_with_options(session, options).is_empty()
  })
}
