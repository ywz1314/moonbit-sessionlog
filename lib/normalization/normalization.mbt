///|
/// Normalization is deliberately explicit: callers can choose which lossy
/// transformations are allowed before a session enters storage or analytics.
pub(all) struct NormalizationOptions {
  trim_text : Bool
  canonicalize_dates : Bool
  merge_movements : Bool
  sort_sets : Bool
  clamp_numeric_values : Bool
  fill_blank_resistance : Bool
  preserve_notes : Bool
  reject_invalid_dates : Bool
  max_notes_length : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_options() -> NormalizationOptions {
  NormalizationOptions::{
    trim_text: true,
    canonicalize_dates: true,
    merge_movements: true,
    sort_sets: false,
    clamp_numeric_values: true,
    fill_blank_resistance: true,
    preserve_notes: true,
    reject_invalid_dates: false,
    max_notes_length: 0,
  }
}

///|
pub fn strict_options() -> NormalizationOptions {
  NormalizationOptions::{
    trim_text: true,
    canonicalize_dates: true,
    merge_movements: true,
    sort_sets: true,
    clamp_numeric_values: true,
    fill_blank_resistance: true,
    preserve_notes: true,
    reject_invalid_dates: true,
    max_notes_length: 4096,
  }
}

///|
pub fn with_max_notes_length(
  options : NormalizationOptions,
  max_notes_length : Int,
) -> NormalizationOptions {
  NormalizationOptions::{
    trim_text: options.trim_text,
    canonicalize_dates: options.canonicalize_dates,
    merge_movements: options.merge_movements,
    sort_sets: options.sort_sets,
    clamp_numeric_values: options.clamp_numeric_values,
    fill_blank_resistance: options.fill_blank_resistance,
    preserve_notes: options.preserve_notes,
    reject_invalid_dates: options.reject_invalid_dates,
    max_notes_length: Int::max(0, max_notes_length),
  }
}

///|
pub(all) enum NormalizationWarning {
  TrimmedIdentifier
  TrimmedMovementName(String)
  CanonicalizedDate
  InvalidDate(String)
  MergedMovement(String)
  ClampedPain(String, Int)
  ClampedRpe(String, Int)
  ClampedReps(String, Int)
  ClampedHoldTime(String, Int)
  ClampedCompletion(String, Double)
  FilledResistance(String)
  TruncatedNotes(Int)
  DroppedEmptyMovement
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn NormalizationWarning::code(self : NormalizationWarning) -> String {
  match self {
    TrimmedIdentifier => "trimmed_identifier"
    TrimmedMovementName(name) => "trimmed_movement_name:" + name
    CanonicalizedDate => "canonicalized_date"
    InvalidDate(value) => "invalid_date:" + value
    MergedMovement(name) => "merged_movement:" + name
    ClampedPain(name, value) => "clamped_pain:" + name + ":" + value.to_string()
    ClampedRpe(name, value) => "clamped_rpe:" + name + ":" + value.to_string()
    ClampedReps(name, value) => "clamped_reps:" + name + ":" + value.to_string()
    ClampedHoldTime(name, value) =>
      "clamped_hold_time:" + name + ":" + value.to_string()
    ClampedCompletion(name, value) =>
      "clamped_completion:" + name + ":" + value.to_string()
    FilledResistance(name) => "filled_resistance:" + name
    TruncatedNotes(length) => "truncated_notes:" + length.to_string()
    DroppedEmptyMovement => "dropped_empty_movement"
  }
}

///|
pub(all) struct NormalizationReport {
  session_id : String
  changed : Bool
  warning_count : Int
  warnings : Array[NormalizationWarning]
  original_movement_count : Int
  normalized_movement_count : Int
  original_set_count : Int
  normalized_set_count : Int
  original_fingerprint : String
  normalized_fingerprint : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn NormalizationReport::session_id(self : NormalizationReport) -> String {
  self.session_id
}

///|
pub fn NormalizationReport::changed(self : NormalizationReport) -> Bool {
  self.changed
}

///|
pub fn NormalizationReport::warning_count(self : NormalizationReport) -> Int {
  self.warning_count
}

///|
pub fn NormalizationReport::warnings(
  self : NormalizationReport,
) -> Array[NormalizationWarning] {
  self.warnings.copy()
}

///|
pub fn NormalizationReport::original_movement_count(
  self : NormalizationReport,
) -> Int {
  self.original_movement_count
}

///|
pub fn NormalizationReport::normalized_movement_count(
  self : NormalizationReport,
) -> Int {
  self.normalized_movement_count
}

///|
pub fn NormalizationReport::original_set_count(
  self : NormalizationReport,
) -> Int {
  self.original_set_count
}

///|
pub fn NormalizationReport::normalized_set_count(
  self : NormalizationReport,
) -> Int {
  self.normalized_set_count
}

///|
pub fn NormalizationReport::original_fingerprint(
  self : NormalizationReport,
) -> String {
  self.original_fingerprint
}

///|
pub fn NormalizationReport::normalized_fingerprint(
  self : NormalizationReport,
) -> String {
  self.normalized_fingerprint
}

///|
pub(all) struct NormalizationResult {
  session : @core.Session
  report : NormalizationReport
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn NormalizationResult::session(
  self : NormalizationResult,
) -> @core.Session {
  self.session
}

///|
pub fn NormalizationResult::report(
  self : NormalizationResult,
) -> NormalizationReport {
  self.report
}

///|
fn trim_or_keep(value : String, options : NormalizationOptions) -> String {
  if options.trim_text {
    value.trim().to_owned()
  } else {
    value
  }
}

///|
fn canonical_date(value : String) -> (String, Bool) {
  match @calendar.parse(value) {
    Some(date) => (date.to_string(), date.to_string() != value)
    None => (value, false)
  }
}

///|
fn normalized_completion(
  value : Double,
  name : String,
  options : NormalizationOptions,
  warnings : Array[NormalizationWarning],
) -> Double {
  if !options.clamp_numeric_values {
    value
  } else {
    let result = value.clamp(min=0.0, max=1.0)
    if result != value {
      warnings.push(NormalizationWarning::ClampedCompletion(name, value))
    }
    result
  }
}

///|
fn normalized_int(
  value : Int,
  minimum : Int,
  maximum : Int,
  name : String,
  warnings : Array[NormalizationWarning],
  warning : (String, Int) -> NormalizationWarning,
  options : NormalizationOptions,
) -> Int {
  if !options.clamp_numeric_values {
    value
  } else {
    let result = value.clamp(min=minimum, max=maximum)
    if result != value {
      warnings.push(warning(name, value))
    }
    result
  }
}

///|
fn normalize_set(
  movement_name : String,
  set : @core.Set,
  options : NormalizationOptions,
  warnings : Array[NormalizationWarning],
) -> @core.Set {
  let reps = normalized_int(
    set.reps,
    0,
    1000000,
    movement_name,
    warnings,
    (name, value) => NormalizationWarning::ClampedReps(name, value),
    options,
  )
  let hold = normalized_int(
    set.hold_time,
    0,
    86400,
    movement_name,
    warnings,
    (name, value) => NormalizationWarning::ClampedHoldTime(name, value),
    options,
  )
  let resistance = trim_or_keep(set.resistance, options)
  let final_resistance = if options.fill_blank_resistance &&
    resistance.is_empty() {
    warnings.push(NormalizationWarning::FilledResistance(movement_name))
    "unspecified"
  } else {
    resistance
  }
  @core.Set::{
    reps,
    hold_time: hold,
    resistance: final_resistance,
    completion: normalized_completion(
      set.completion,
      movement_name,
      options,
      warnings,
    ),
  }
}

///|
fn normalize_movement(
  movement : @core.Movement,
  options : NormalizationOptions,
  warnings : Array[NormalizationWarning],
) -> @core.Movement? {
  let name = trim_or_keep(movement.name, options)
  if name.is_empty() {
    warnings.push(NormalizationWarning::DroppedEmptyMovement)
    return None
  }
  if name != movement.name {
    warnings.push(NormalizationWarning::TrimmedMovementName(name))
  }
  let pain = normalized_int(
    movement.pain,
    0,
    10,
    name,
    warnings,
    (value, original) => NormalizationWarning::ClampedPain(value, original),
    options,
  )
  let rpe = normalized_int(
    movement.rpe,
    1,
    10,
    name,
    warnings,
    (value, original) => NormalizationWarning::ClampedRpe(value, original),
    options,
  )
  let sets = movement.sets.map(set => {
    normalize_set(name, set, options, warnings)
  })
  if options.sort_sets {
    sets.sort_by((left, right) => right.reps - left.reps)
  }
  Some(@core.Movement::{ name, sets, pain, rpe })
}

///|
fn append_movement(
  movements : Array[@core.Movement],
  movement : @core.Movement,
  merge : Bool,
  warnings : Array[NormalizationWarning],
) -> Unit {
  if !merge {
    movements.push(movement)
    return
  }
  match movements.search_by(item => item.name == movement.name) {
    Some(index) => {
      let previous = movements[index]
      let sets = previous.sets.copy()
      sets.append(movement.sets)
      let merged_pain = Int::max(previous.pain, movement.pain)
      let merged_rpe = Int::max(previous.rpe, movement.rpe)
      movements[index] = @core.Movement::{
        name: previous.name,
        sets,
        pain: merged_pain,
        rpe: merged_rpe,
      }
      warnings.push(NormalizationWarning::MergedMovement(movement.name))
    }
    None => movements.push(movement)
  }
}

///|
fn note_value(
  notes : String,
  options : NormalizationOptions,
  warnings : Array[NormalizationWarning],
) -> String {
  let trimmed = trim_or_keep(notes, options)
  let preserved = if options.preserve_notes { trimmed } else { "" }
  if options.max_notes_length > 0 &&
    preserved.length() > options.max_notes_length {
    warnings.push(NormalizationWarning::TruncatedNotes(preserved.length()))
    preserved[:options.max_notes_length].to_owned()
  } else {
    preserved
  }
}

///|
pub fn normalize(
  session : @core.Session,
  options : NormalizationOptions,
) -> Result[NormalizationResult, String] {
  let warnings = []
  let id = trim_or_keep(session.id, options)
  if id != session.id {
    warnings.push(NormalizationWarning::TrimmedIdentifier)
  }
  let (date, changed_date) = if options.canonicalize_dates {
    canonical_date(session.date)
  } else {
    (session.date, false)
  }
  if changed_date {
    warnings.push(NormalizationWarning::CanonicalizedDate)
  }
  if options.reject_invalid_dates && @calendar.parse(date) is None {
    return Err("invalid session date: " + date)
  }
  if @calendar.parse(date) is None {
    warnings.push(NormalizationWarning::InvalidDate(date))
  }
  let movements = []
  for movement in session.movements {
    match normalize_movement(movement, options, warnings) {
      Some(value) =>
        append_movement(movements, value, options.merge_movements, warnings)
      None => ()
    }
  }
  let normalized = @core.Session::{
    id,
    date,
    duration: if options.clamp_numeric_values {
      session.duration.clamp(min=0, max=10080)
    } else {
      session.duration
    },
    pain_before: if options.clamp_numeric_values {
      session.pain_before.clamp(min=0, max=10)
    } else {
      session.pain_before
    },
    pain_after: if options.clamp_numeric_values {
      session.pain_after.clamp(min=0, max=10)
    } else {
      session.pain_after
    },
    movements,
    notes: note_value(session.notes, options, warnings),
  }
  let report = NormalizationReport::{
    session_id: normalized.id,
    changed: normalized != session,
    warning_count: warnings.length(),
    warnings,
    original_movement_count: session.movements.length(),
    normalized_movement_count: normalized.movements.length(),
    original_set_count: session.total_sets(),
    normalized_set_count: normalized.total_sets(),
    original_fingerprint: @retention.fingerprint(session),
    normalized_fingerprint: @retention.fingerprint(normalized),
  }
  Ok(NormalizationResult::{ session: normalized, report })
}

///|
pub fn normalize_or_keep(
  session : @core.Session,
  options : NormalizationOptions,
) -> NormalizationResult {
  match normalize(session, options) {
    Ok(result) => result
    Err(_) => {
      let report = NormalizationReport::{
        session_id: session.id,
        changed: false,
        warning_count: 0,
        warnings: [],
        original_movement_count: session.movements.length(),
        normalized_movement_count: session.movements.length(),
        original_set_count: session.total_sets(),
        normalized_set_count: session.total_sets(),
        original_fingerprint: @retention.fingerprint(session),
        normalized_fingerprint: @retention.fingerprint(session),
      }
      NormalizationResult::{ session, report }
    }
  }
}

///|
pub(all) struct BatchNormalization {
  sessions : Array[@core.Session]
  reports : Array[NormalizationReport]
  rejected : Array[String]
  changed_count : Int
  warning_count : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn BatchNormalization::sessions(
  self : BatchNormalization,
) -> Array[@core.Session] {
  self.sessions.copy()
}

///|
pub fn BatchNormalization::reports(
  self : BatchNormalization,
) -> Array[NormalizationReport] {
  self.reports.copy()
}

///|
pub fn BatchNormalization::rejected(self : BatchNormalization) -> Array[String] {
  self.rejected.copy()
}

///|
pub fn BatchNormalization::changed_count(self : BatchNormalization) -> Int {
  self.changed_count
}

///|
pub fn BatchNormalization::warning_count(self : BatchNormalization) -> Int {
  self.warning_count
}

///|
pub fn normalize_many(
  sessions : Array[@core.Session],
  options : NormalizationOptions,
) -> BatchNormalization {
  let normalized = []
  let reports = []
  let rejected = []
  let mut changed_count = 0
  let mut warning_count = 0
  for session in sessions {
    match normalize(session, options) {
      Ok(result) => {
        normalized.push(result.session)
        reports.push(result.report)
        if result.report.changed {
          changed_count += 1
        }
        warning_count += result.report.warning_count
      }
      Err(error) => rejected.push(session.id + ": " + error)
    }
  }
  BatchNormalization::{
    sessions: normalized,
    reports,
    rejected,
    changed_count,
    warning_count,
  }
}

///|
pub fn deduplicate(sessions : Array[@core.Session]) -> Array[@core.Session] {
  let result = []
  let fingerprints = []
  for session in sessions {
    let value = @retention.fingerprint(session)
    if !fingerprints.contains(value) {
      fingerprints.push(value)
      result.push(session)
    }
  }
  result
}

///|
pub fn duplicate_count(sessions : Array[@core.Session]) -> Int {
  sessions.length() - deduplicate(sessions).length()
}

///|
pub fn sorted_by_date(sessions : Array[@core.Session]) -> Array[@core.Session] {
  let result = sessions.copy()
  result.sort_by((left, right) => left.date.compare(right.date))
  result
}

///|
pub fn sorted_by_id(sessions : Array[@core.Session]) -> Array[@core.Session] {
  let result = sessions.copy()
  result.sort_by((left, right) => left.id.compare(right.id))
  result
}

///|
pub fn group_by_date(
  sessions : Array[@core.Session],
) -> Array[(String, Array[@core.Session])] {
  let groups : Array[(String, Array[@core.Session])] = []
  for session in sorted_by_date(sessions) {
    match groups.search_by(item => item.0 == session.date) {
      Some(index) => groups[index].1.push(session)
      None => groups.push((session.date, [session]))
    }
  }
  groups
}

///|
pub fn date_counts(sessions : Array[@core.Session]) -> Array[(String, Int)] {
  group_by_date(sessions).map(item => (item.0, item.1.length()))
}

///|
pub fn movement_counts(sessions : Array[@core.Session]) -> Array[(String, Int)] {
  let counts : Array[(String, Int)] = []
  for session in sessions {
    for movement in session.movements {
      match counts.search_by(item => item.0 == movement.name) {
        Some(index) => {
          let previous = counts[index]
          counts[index] = (previous.0, previous.1 + 1)
        }
        None => counts.push((movement.name, 1))
      }
    }
  }
  counts.sort_by((left, right) => right.1 - left.1)
  counts
}

///|
pub fn warning_codes(reports : Array[NormalizationReport]) -> Array[String] {
  let codes = []
  for report in reports {
    for warning in report.warnings {
      let code = warning.code()
      if !codes.contains(code) {
        codes.push(code)
      }
    }
  }
  codes
}

///|
pub fn normalization_checksum(batch : BatchNormalization) -> Int {
  batch.reports.fold(init=23, (value, report) => {
    value * 31 +
    report.warning_count +
    report.normalized_set_count +
    report.normalized_movement_count
  })
}

///|
pub fn report_text(batch : BatchNormalization) -> String {
  let output = StringBuilder()
  output.write_string("normalized: ")
  output.write_string(batch.sessions.length().to_string())
  output.write_string("\nchanged: ")
  output.write_string(batch.changed_count.to_string())
  output.write_string("\nwarnings: ")
  output.write_string(batch.warning_count.to_string())
  output.write_string("\nrejected: ")
  output.write_string(batch.rejected.length().to_string())
  output.write_string("\nchecksum: ")
  output.write_string(normalization_checksum(batch).to_string())
  output.write_string("\n")
  for report in batch.reports {
    output.write_string(report.session_id)
    output.write_string(" changed=")
    output.write_string(report.changed.to_string())
    output.write_string(" warnings=")
    output.write_string(report.warning_count.to_string())
    output.write_string("\n")
  }
  output.to_string()
}

///|
pub fn normalize_and_deduplicate(
  sessions : Array[@core.Session],
  options : NormalizationOptions,
) -> BatchNormalization {
  let batch = normalize_many(sessions, options)
  let unique = deduplicate(batch.sessions)
  BatchNormalization::{
    sessions: unique,
    reports: batch.reports,
    rejected: batch.rejected,
    changed_count: batch.changed_count,
    warning_count: batch.warning_count,
  }
}

///|
pub fn validate_options(options : NormalizationOptions) -> Array[String] {
  let errors = []
  if options.max_notes_length < 0 {
    errors.push("max_notes_length must be non-negative")
  }
  errors
}

///|
pub fn safe_normalize(
  session : @core.Session,
  options : NormalizationOptions,
) -> Result[NormalizationResult, String] {
  let errors = validate_options(options)
  if !errors.is_empty() {
    Err(errors.join("; "))
  } else {
    normalize(session, options)
  }
}
