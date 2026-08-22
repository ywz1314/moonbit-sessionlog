///|
/// A named normalization pipeline makes data preparation observable and
/// repeatable.  Each stage is intentionally small so applications can report
/// which transformation changed a record.
pub(all) enum PipelineStage {
  TrimText
  CanonicalizeDates
  ClampMeasurements
  FillResistance
  MergeMovements
  SortSets
  PreserveNotes
  LimitNotes
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn PipelineStage::label(self : PipelineStage) -> String {
  match self {
    TrimText => "trim_text"
    CanonicalizeDates => "canonicalize_dates"
    ClampMeasurements => "clamp_measurements"
    FillResistance => "fill_resistance"
    MergeMovements => "merge_movements"
    SortSets => "sort_sets"
    PreserveNotes => "preserve_notes"
    LimitNotes => "limit_notes"
  }
}

///|
pub fn PipelineStage::is_lossy(self : PipelineStage) -> Bool {
  match self {
    TrimText => true
    CanonicalizeDates => false
    ClampMeasurements => true
    FillResistance => true
    MergeMovements => true
    SortSets => false
    PreserveNotes => false
    LimitNotes => true
  }
}

///|
pub fn PipelineStage::risk(self : PipelineStage) -> Int {
  match self {
    TrimText => 1
    CanonicalizeDates => 0
    ClampMeasurements => 2
    FillResistance => 1
    MergeMovements => 2
    SortSets => 0
    PreserveNotes => 0
    LimitNotes => 2
  }
}

///|
pub(all) struct PipelineOptions {
  stages : Array[PipelineStage]
  max_notes_length : Int
  reject_invalid_dates : Bool
  fail_on_warnings : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_pipeline() -> PipelineOptions {
  PipelineOptions::{
    stages: [
      PipelineStage::TrimText,
      PipelineStage::CanonicalizeDates,
      PipelineStage::ClampMeasurements,
      PipelineStage::FillResistance,
      PipelineStage::MergeMovements,
      PipelineStage::PreserveNotes,
    ],
    max_notes_length: 0,
    reject_invalid_dates: false,
    fail_on_warnings: false,
  }
}

///|
pub fn strict_pipeline() -> PipelineOptions {
  PipelineOptions::{
    stages: [
      PipelineStage::TrimText,
      PipelineStage::CanonicalizeDates,
      PipelineStage::ClampMeasurements,
      PipelineStage::FillResistance,
      PipelineStage::MergeMovements,
      PipelineStage::SortSets,
      PipelineStage::PreserveNotes,
      PipelineStage::LimitNotes,
    ],
    max_notes_length: 4096,
    reject_invalid_dates: true,
    fail_on_warnings: false,
  }
}

///|
pub fn pipeline_with_stages(
  stages : Array[PipelineStage],
  max_notes_length? : Int = 0,
  reject_invalid_dates? : Bool = false,
  fail_on_warnings? : Bool = false,
) -> PipelineOptions {
  PipelineOptions::{
    stages: stages.copy(),
    max_notes_length: Int::max(0, max_notes_length),
    reject_invalid_dates,
    fail_on_warnings,
  }
}

///|
pub fn PipelineOptions::stages(self : PipelineOptions) -> Array[PipelineStage] {
  self.stages.copy()
}

///|
pub fn PipelineOptions::has(
  self : PipelineOptions,
  stage : PipelineStage,
) -> Bool {
  self.stages.contains(stage)
}

///|
pub fn PipelineOptions::lossy(self : PipelineOptions) -> Bool {
  self.stages.any(stage => stage.is_lossy())
}

///|
pub fn PipelineOptions::risk_score(self : PipelineOptions) -> Int {
  self.stages.fold(init=0, (score, stage) => score + stage.risk())
}

///|
pub fn PipelineOptions::validate(self : PipelineOptions) -> Array[String] {
  let errors = []
  if self.stages.is_empty() {
    errors.push("at least one stage is required")
  }
  if self.max_notes_length < 0 {
    errors.push("max_notes_length must be non-negative")
  }
  if self.has(PipelineStage::LimitNotes) && self.max_notes_length == 0 {
    errors.push("limit_notes requires max_notes_length")
  }
  errors
}

///|
pub(all) struct PipelineStageReport {
  stage : PipelineStage
  changed : Bool
  warning_count : Int
  warnings : Array[String]
  before_fingerprint : String
  after_fingerprint : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn PipelineStageReport::stage(self : PipelineStageReport) -> PipelineStage {
  self.stage
}

///|
pub fn PipelineStageReport::changed(self : PipelineStageReport) -> Bool {
  self.changed
}

///|
pub fn PipelineStageReport::warning_count(self : PipelineStageReport) -> Int {
  self.warning_count
}

///|
pub fn PipelineStageReport::warnings(
  self : PipelineStageReport,
) -> Array[String] {
  self.warnings.copy()
}

///|
pub fn PipelineStageReport::before_fingerprint(
  self : PipelineStageReport,
) -> String {
  self.before_fingerprint
}

///|
pub fn PipelineStageReport::after_fingerprint(
  self : PipelineStageReport,
) -> String {
  self.after_fingerprint
}

///|
pub(all) struct PipelineResult {
  session : @core.Session
  reports : Array[PipelineStageReport]
  warnings : Array[String]
  changed : Bool
  rejected : Bool
  error : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn PipelineResult::session(self : PipelineResult) -> @core.Session {
  self.session
}

///|
pub fn PipelineResult::reports(
  self : PipelineResult,
) -> Array[PipelineStageReport] {
  self.reports.copy()
}

///|
pub fn PipelineResult::warnings(self : PipelineResult) -> Array[String] {
  self.warnings.copy()
}

///|
pub fn PipelineResult::changed(self : PipelineResult) -> Bool {
  self.changed
}

///|
pub fn PipelineResult::rejected(self : PipelineResult) -> Bool {
  self.rejected
}

///|
pub fn PipelineResult::error(self : PipelineResult) -> String? {
  self.error
}

///|
fn stage_options(
  stage : PipelineStage,
  options : PipelineOptions,
) -> NormalizationOptions {
  let defaults = default_options()
  NormalizationOptions::{
    trim_text: stage == PipelineStage::TrimText ||
    (stage != PipelineStage::PreserveNotes && defaults.trim_text),
    canonicalize_dates: stage == PipelineStage::CanonicalizeDates,
    merge_movements: stage == PipelineStage::MergeMovements,
    sort_sets: stage == PipelineStage::SortSets,
    clamp_numeric_values: stage == PipelineStage::ClampMeasurements,
    fill_blank_resistance: stage == PipelineStage::FillResistance,
    preserve_notes: stage != PipelineStage::PreserveNotes,
    reject_invalid_dates: options.reject_invalid_dates &&
    stage == PipelineStage::CanonicalizeDates,
    max_notes_length: if stage == PipelineStage::LimitNotes {
      options.max_notes_length
    } else {
      0
    },
  }
}

///|
fn warning_text(warning : NormalizationWarning) -> String {
  warning.code()
}

///|
fn run_stage(
  session : @core.Session,
  stage : PipelineStage,
  options : PipelineOptions,
) -> Result[(@core.Session, Array[String]), String] {
  let stage_options = stage_options(stage, options)
  match normalize(session, stage_options) {
    Ok(result) => {
      let warnings = result.report.warnings.map(warning_text)
      Ok((result.session, warnings))
    }
    Err(error) => Err(error)
  }
}

///|
pub fn run_pipeline(
  session : @core.Session,
  options : PipelineOptions,
) -> Result[PipelineResult, String] {
  let validation = options.validate()
  if !validation.is_empty() {
    return Err(validation.join("; "))
  }
  let mut current = session
  let reports = []
  let all_warnings = []
  for stage in options.stages {
    let before = @retention.fingerprint(current)
    match run_stage(current, stage, options) {
      Ok(pair) => {
        current = pair.0
        let after = @retention.fingerprint(current)
        let warnings = pair.1
        for warning in warnings {
          all_warnings.push(stage.label() + ":" + warning)
        }
        reports.push(PipelineStageReport::{
          stage,
          changed: before != after,
          warning_count: warnings.length(),
          warnings,
          before_fingerprint: before,
          after_fingerprint: after,
        })
      }
      Err(error) =>
        if options.reject_invalid_dates {
          return Ok(PipelineResult::{
            session: current,
            reports,
            warnings: all_warnings,
            changed: current != session,
            rejected: true,
            error: Some(error),
          })
        }
    }
  }
  if options.fail_on_warnings && !all_warnings.is_empty() {
    return Ok(PipelineResult::{
      session: current,
      reports,
      warnings: all_warnings,
      changed: current != session,
      rejected: true,
      error: Some("pipeline produced warnings"),
    })
  }
  Ok(PipelineResult::{
    session: current,
    reports,
    warnings: all_warnings,
    changed: current != session,
    rejected: false,
    error: None,
  })
}

///|
pub(all) struct PipelineBatch {
  results : Array[PipelineResult]
  accepted : Array[@core.Session]
  rejected : Array[String]
  changed_count : Int
  warning_count : Int
  stage_counts : Array[(String, Int)]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn PipelineBatch::results(self : PipelineBatch) -> Array[PipelineResult] {
  self.results.copy()
}

///|
pub fn PipelineBatch::accepted(self : PipelineBatch) -> Array[@core.Session] {
  self.accepted.copy()
}

///|
pub fn PipelineBatch::rejected(self : PipelineBatch) -> Array[String] {
  self.rejected.copy()
}

///|
pub fn PipelineBatch::changed_count(self : PipelineBatch) -> Int {
  self.changed_count
}

///|
pub fn PipelineBatch::warning_count(self : PipelineBatch) -> Int {
  self.warning_count
}

///|
pub fn PipelineBatch::stage_counts(
  self : PipelineBatch,
) -> Array[(String, Int)] {
  self.stage_counts.copy()
}

///|
pub fn run_pipeline_many(
  sessions : Array[@core.Session],
  options : PipelineOptions,
) -> Result[PipelineBatch, String] {
  let errors = options.validate()
  if !errors.is_empty() {
    return Err(errors.join("; "))
  }
  let results = []
  let accepted = []
  let rejected = []
  let stage_counts : Array[(String, Int)] = []
  let mut changed_count = 0
  let mut warning_count = 0
  for session in sessions {
    match run_pipeline(session, options) {
      Ok(result) => {
        results.push(result)
        warning_count += result.warnings.length()
        if result.changed {
          changed_count += 1
        }
        if result.rejected {
          match result.error {
            Some(error) => rejected.push(session.id + ": " + error)
            None => rejected.push(session.id)
          }
        } else {
          accepted.push(result.session)
        }
        for report in result.reports {
          match stage_counts.search_by(item => item.0 == report.stage.label()) {
            Some(index) => {
              let previous = stage_counts[index]
              stage_counts[index] = (previous.0, previous.1 + 1)
            }
            None => stage_counts.push((report.stage.label(), 1))
          }
        }
      }
      Err(error) => return Err(error)
    }
  }
  Ok(PipelineBatch::{
    results,
    accepted,
    rejected,
    changed_count,
    warning_count,
    stage_counts,
  })
}

///|
pub fn pipeline_changed_stages(result : PipelineResult) -> Array[PipelineStage] {
  result.reports.filter(report => report.changed).map(report => report.stage)
}

///|
pub fn pipeline_warning_codes(result : PipelineResult) -> Array[String] {
  let codes = []
  for warning in result.warnings {
    if !codes.contains(warning) {
      codes.push(warning)
    }
  }
  codes
}

///|
pub fn pipeline_fingerprint(result : PipelineResult) -> String {
  @retention.fingerprint(result.session)
}

///|
pub fn pipeline_summary(result : PipelineResult) -> String {
  "changed=" +
  result.changed.to_string() +
  ", rejected=" +
  result.rejected.to_string() +
  ", stages=" +
  result.reports.length().to_string() +
  ", warnings=" +
  result.warnings.length().to_string()
}

///|
pub fn pipeline_batch_summary(batch : PipelineBatch) -> String {
  "accepted=" +
  batch.accepted.length().to_string() +
  ", rejected=" +
  batch.rejected.length().to_string() +
  ", changed=" +
  batch.changed_count.to_string() +
  ", warnings=" +
  batch.warning_count.to_string()
}

///|
pub fn pipeline_stage_order(options : PipelineOptions) -> String {
  options.stages.map(stage => stage.label()).join(" -> ")
}

///|
pub fn pipeline_recommendation(options : PipelineOptions) -> String {
  if options.risk_score() >= 8 {
    "review lossy stages before import"
  } else if options.lossy() {
    "safe for routine normalization with audit logging"
  } else {
    "non-lossy inspection pipeline"
  }
}

///|
pub fn pipeline_audit_lines(result : PipelineResult) -> Array[String] {
  let lines = []
  for report in result.reports {
    lines.push(
      report.stage.label() +
      " changed=" +
      report.changed.to_string() +
      " before=" +
      report.before_fingerprint +
      " after=" +
      report.after_fingerprint,
    )
  }
  lines
}

///|
pub fn pipeline_audit_text(result : PipelineResult) -> String {
  pipeline_audit_lines(result).join("\n")
}

///|
pub fn pipeline_rejected_reason(result : PipelineResult) -> String {
  match result.error {
    Some(error) => error
    None => ""
  }
}

///|
pub fn pipeline_is_idempotent(
  session : @core.Session,
  options : PipelineOptions,
) -> Bool {
  match run_pipeline(session, options) {
    Ok(first) =>
      match run_pipeline(first.session, options) {
        Ok(second) => first.session == second.session
        Err(_) => false
      }
    Err(_) => false
  }
}
