///|
pub(all) enum ReportFormat {
  Text
  Csv
  Json
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) enum PrivacyMode {
  Full
  HideNotes
  HashIdentifiers
  Minimal
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ReportOptions {
  title : String
  format : ReportFormat
  privacy : PrivacyMode
  include_invalid : Bool
  include_empty_movements : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_report_options() -> ReportOptions {
  ReportOptions::{
    title: "Rehabilitation session report",
    format: ReportFormat::Text,
    privacy: PrivacyMode::Full,
    include_invalid: true,
    include_empty_movements: false,
  }
}

///|
pub(all) struct ReportDocument {
  title : String
  format : ReportFormat
  privacy : PrivacyMode
  session_count : Int
  valid_count : Int
  invalid_count : Int
  body : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ReportDocument::title(self : ReportDocument) -> String {
  self.title
}

///|
pub fn ReportDocument::format(self : ReportDocument) -> ReportFormat {
  self.format
}

///|
pub fn ReportDocument::privacy(self : ReportDocument) -> PrivacyMode {
  self.privacy
}

///|
pub fn ReportDocument::session_count(self : ReportDocument) -> Int {
  self.session_count
}

///|
pub fn ReportDocument::valid_count(self : ReportDocument) -> Int {
  self.valid_count
}

///|
pub fn ReportDocument::invalid_count(self : ReportDocument) -> Int {
  self.invalid_count
}

///|
pub fn ReportDocument::body(self : ReportDocument) -> String {
  self.body
}

///|
pub fn format_name(format : ReportFormat) -> String {
  match format {
    ReportFormat::Text => "text"
    ReportFormat::Csv => "csv"
    ReportFormat::Json => "json"
  }
}

///|
pub fn privacy_name(privacy : PrivacyMode) -> String {
  match privacy {
    PrivacyMode::Full => "full"
    PrivacyMode::HideNotes => "hide_notes"
    PrivacyMode::HashIdentifiers => "hash_identifiers"
    PrivacyMode::Minimal => "minimal"
  }
}

///|
fn stable_hash(value : String) -> String {
  let mut hash = 216613626
  for code in value.code_units() {
    hash = (hash ^ code.to_int()) * 16777619
  }
  let positive = if hash < 0 { -hash } else { hash }
  "id-" + positive.to_string()
}

///|
pub fn redact_id(id : String, privacy : PrivacyMode) -> String {
  match privacy {
    PrivacyMode::Full | PrivacyMode::HideNotes => id
    PrivacyMode::HashIdentifiers | PrivacyMode::Minimal => stable_hash(id)
  }
}

///|
pub fn redact_notes(notes : String, privacy : PrivacyMode) -> String {
  match privacy {
    PrivacyMode::Full | PrivacyMode::HashIdentifiers => notes
    PrivacyMode::HideNotes | PrivacyMode::Minimal => "[redacted]"
  }
}

///|
pub fn redact_resistance(resistance : String, privacy : PrivacyMode) -> String {
  match privacy {
    PrivacyMode::Full | PrivacyMode::HideNotes => resistance
    PrivacyMode::HashIdentifiers => "resistance"
    PrivacyMode::Minimal => ""
  }
}

///|
fn csv_cell(value : String) -> String {
  if value.contains(",") || value.contains("\"") || value.contains("\n") {
    "\"" + value.replace_all(old="\"", new="\"\"") + "\""
  } else {
    value
  }
}

///|
fn append_csv_row(builder : StringBuilder, values : Array[String]) -> Unit {
  builder.write_string(values.map(value => csv_cell(value)).join(","))
  builder.write_string("\n")
}

///|
pub fn session_csv(
  sessions : Array[@core.Session],
  privacy? : PrivacyMode = PrivacyMode::Full,
) -> String {
  let output = StringBuilder()
  append_csv_row(output, [
    "session_id", "date", "duration", "pain_before", "pain_after", "total_reps",
    "sets", "average_pain", "completion", "notes",
  ])
  for session in sessions {
    let notes = redact_notes(session.notes, privacy)
    append_csv_row(output, [
      redact_id(session.id, privacy),
      session.date,
      session.duration.to_string(),
      session.pain_before.to_string(),
      session.pain_after.to_string(),
      session.total_reps().to_string(),
      session.total_sets().to_string(),
      session.average_pain_during().to_string(),
      session.average_completion().to_string(),
      notes,
    ])
  }
  output.to_string()
}

///|
pub fn movement_csv(
  sessions : Array[@core.Session],
  privacy? : PrivacyMode = PrivacyMode::Full,
) -> String {
  let output = StringBuilder()
  append_csv_row(output, [
    "session_id", "date", "movement", "sets", "reps", "effective_reps", "work_units",
    "pain", "rpe", "resistance",
  ])
  for session in sessions {
    for movement in session.movements {
      append_csv_row(output, [
        redact_id(session.id, privacy),
        session.date,
        movement.name,
        movement.sets.length().to_string(),
        movement.total_reps().to_string(),
        movement.effective_reps().to_string(),
        movement.work_units().to_string(),
        movement.pain.to_string(),
        movement.rpe.to_string(),
        redact_resistance(movement.dominant_resistance(), privacy),
      ])
    }
  }
  output.to_string()
}

///|
pub fn trend_csv(report : @analytics.TrendReport) -> String {
  let output = StringBuilder()
  append_csv_row(output, [
    "date", "session_id", "reps", "sets", "work_units", "average_pain", "completion",
    "pain_delta", "readiness", "recovery", "flags",
  ])
  for item in report.snapshots() {
    append_csv_row(output, [
      item.date(),
      item.session_id(),
      item.total_reps().to_string(),
      item.total_sets().to_string(),
      item.work_units().to_string(),
      item.average_pain().to_string(),
      item.average_completion().to_string(),
      item.pain_delta().to_string(),
      item.readiness_score().to_string(),
      item.recovery().label(),
      item.flags().join("|"),
    ])
  }
  output.to_string()
}

///|
pub fn validation_text(sessions : Array[@core.Session]) -> String {
  let output = StringBuilder()
  for session in sessions {
    let errors = @validation.validate_session(session)
    if errors.is_empty() {
      output.write_string("[OK] " + session.id + "\n")
    } else {
      output.write_string(
        "[ERROR] " + session.id + " (" + errors.length().to_string() + ")\n",
      )
      for error in errors {
        output.write_string("  - " + error.to_json().stringify() + "\n")
      }
    }
  }
  output.to_string()
}

///|
pub fn trend_text(report : @analytics.TrendReport, title : String) -> String {
  let output = StringBuilder()
  output.write_string(title + "\n")
  output.write_string("sessions: " + report.session_count().to_string() + "\n")
  output.write_string("total reps: " + report.total_reps().to_string() + "\n")
  output.write_string(
    "total work units: " + report.total_work_units().to_string() + "\n",
  )
  output.write_string(
    "average pain: " + report.average_pain().to_string() + "\n",
  )
  output.write_string(
    "average completion: " + report.average_completion().to_string() + "\n",
  )
  output.write_string("pain trend: " + report.pain_direction().label() + "\n")
  output.write_string(
    "completion trend: " + report.completion_direction().label() + "\n",
  )
  output.write_string("load trend: " + report.load_direction().label() + "\n")
  output.write_string(
    "adherence: " + report.adherence_percent().to_string() + "%\n",
  )
  output.to_string()
}

///|
pub fn session_text(
  session : @core.Session,
  privacy? : PrivacyMode = PrivacyMode::Full,
) -> String {
  let output = StringBuilder()
  output.write_string(
    "Session " + redact_id(session.id, privacy) + " (" + session.date + ")\n",
  )
  output.write_string("duration: " + session.duration.to_string() + " min\n")
  output.write_string(
    "pain: " +
    session.pain_before.to_string() +
    " -> " +
    session.pain_after.to_string() +
    "\n",
  )
  output.write_string(
    "reps: " +
    session.total_reps().to_string() +
    ", sets: " +
    session.total_sets().to_string() +
    "\n",
  )
  output.write_string(
    "completion: " + session.average_completion().to_string() + "\n",
  )
  output.write_string("notes: " + redact_notes(session.notes, privacy) + "\n")
  for movement in session.movements {
    output.write_string(
      "  * " +
      movement.name +
      ": " +
      movement.total_reps().to_string() +
      " reps, pain=" +
      movement.pain.to_string() +
      ", rpe=" +
      movement.rpe.to_string() +
      "\n",
    )
  }
  output.to_string()
}

///|
pub fn session_json(
  session : @core.Session,
  privacy? : PrivacyMode = PrivacyMode::Full,
) -> String {
  let json = session.to_json()
  let object = match json {
    Object(value) => value
    _ => {}
  }
  object["id"] = Json::string(redact_id(session.id, privacy))
  object["notes"] = Json::string(redact_notes(session.notes, privacy))
  Json::object(object).stringify()
}

///|
pub fn trend_json(report : @analytics.TrendReport) -> String {
  report.to_json().stringify()
}

///|
fn should_include(session : @core.Session, options : ReportOptions) -> Bool {
  if options.include_empty_movements || !session.movements.is_empty() {
    options.include_invalid || @validation.validate_session(session).is_empty()
  } else {
    false
  }
}

///|
pub fn build(
  sessions : Array[@core.Session],
  options? : ReportOptions = default_report_options(),
) -> ReportDocument {
  let selected = sessions.filter(session => should_include(session, options))
  let valid_count = selected.count_if(session => {
    @validation.validate_session(session).is_empty()
  })
  let invalid_count = selected.length() - valid_count
  let body = match options.format {
    ReportFormat::Text => {
      let report = @analytics.analyze(selected)
      trend_text(report, options.title)
    }
    ReportFormat::Csv => session_csv(selected, privacy=options.privacy)
    ReportFormat::Json => @json.to_json(selected).stringify()
  }
  ReportDocument::{
    title: options.title,
    format: options.format,
    privacy: options.privacy,
    session_count: selected.length(),
    valid_count,
    invalid_count,
    body,
  }
}

///|
pub fn combine_text(
  parts : Array[String],
  separator? : String = "\n",
) -> String {
  parts.join(separator)
}

///|
pub fn fixed_width(value : String, width : Int) -> String {
  if width <= 0 {
    ""
  } else if value.length() >= width {
    value[:width].to_owned()
  } else {
    value.pad_end(width, ' ')
  }
}

///|
pub fn table_row(values : Array[String], widths : Array[Int]) -> String {
  let cells = []
  for i, value in values {
    let width = match widths.get(i) {
      Some(item) => item
      None => value.length()
    }
    cells.push(fixed_width(value, width))
  }
  "| " + cells.join(" | ") + " |"
}

///|
pub fn table_separator(widths : Array[Int]) -> String {
  let cells = widths.map(width => "-".repeat(Int::max(3, width)))
  "|-" + cells.join("-|-") + "-|"
}
