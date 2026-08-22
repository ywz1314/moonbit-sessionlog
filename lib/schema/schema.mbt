///|
pub(all) struct SessionV1 {
  id : String
  date : String
  duration : Int
  pain_before : Int
  pain_after : Int
  movements : Array[String]
  notes : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct SessionV2 {
  version : Int
  id : String
  date : String
  duration : Int
  pain_before : Int
  pain_after : Int
  movements : Array[@core.Movement]
  notes : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SessionV2::to_core_session(self : SessionV2) -> @core.Session {
  @core.Session::{
    id: self.id,
    date: self.date,
    duration: self.duration,
    pain_before: self.pain_before,
    pain_after: self.pain_after,
    movements: self.movements,
    notes: self.notes,
  }
}

///|
pub fn SessionV2::from_core_session(session : @core.Session) -> SessionV2 {
  SessionV2::{
    version: 2,
    id: session.id,
    date: session.date,
    duration: session.duration,
    pain_before: session.pain_before,
    pain_after: session.pain_after,
    movements: session.movements,
    notes: session.notes,
  }
}

///|
pub fn SessionV1::migrate_to_v2(self : SessionV1) -> @core.Session {
  let movements = []
  for mv_name in self.movements {
    let m = @core.Movement::{ name: mv_name, sets: [], pain: 0, rpe: 5 }
    movements.push(m)
  }
  @core.Session::{
    id: self.id,
    date: self.date,
    duration: self.duration,
    pain_before: self.pain_before,
    pain_after: self.pain_after,
    movements,
    notes: self.notes,
  }
}

///|
pub fn parse_and_migrate_session(
  json_str : String,
) -> Result[@core.Session, String] {
  try {
    let json = @json.parse(json_str)
    let mut version = 1
    match json {
      Object(obj) =>
        match obj.get("version") {
          Some(Number(v, ..)) => version = v.to_int()
          _ => ()
        }
      _ => return Err("Invalid JSON: expected a JSON object")
    }
    if version == 2 {
      let v2 : SessionV2 = @json.from_json(json)
      Ok(v2.to_core_session())
    } else if version == 1 {
      let v1 : SessionV1 = @json.from_json(json)
      Ok(v1.migrate_to_v2())
    } else {
      Err("Unsupported schema version: " + version.to_string())
    }
  } catch {
    err => Err("Failed to parse or migrate session: " + err.to_string())
  }
}

///|
pub(all) enum MigrationWarning {
  LegacyVersionAssumed
  EmptyMovementSet
  MissingNotes
  MissingPainValue
  UnsupportedField(String)
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MigrationWarning::code(self : MigrationWarning) -> String {
  match self {
    LegacyVersionAssumed => "legacy_version_assumed"
    EmptyMovementSet => "empty_movement_set"
    MissingNotes => "missing_notes"
    MissingPainValue => "missing_pain_value"
    UnsupportedField(name) => "unsupported_field:" + name
  }
}

///|
pub(all) struct MigrationReport {
  source_version : Int
  target_version : Int
  session_id : String
  movement_count : Int
  warnings : Array[MigrationWarning]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MigrationReport::source_version(self : MigrationReport) -> Int {
  self.source_version
}

///|
pub fn MigrationReport::target_version(self : MigrationReport) -> Int {
  self.target_version
}

///|
pub fn MigrationReport::session_id(self : MigrationReport) -> String {
  self.session_id
}

///|
pub fn MigrationReport::movement_count(self : MigrationReport) -> Int {
  self.movement_count
}

///|
pub fn MigrationReport::warnings(
  self : MigrationReport,
) -> Array[MigrationWarning] {
  self.warnings
}

///|
pub fn schema_version(json_str : String) -> Result[Int, String] {
  try {
    let json = @json.parse(json_str)
    match json {
      Object(object) =>
        match object.get("version") {
          Some(Number(value, ..)) => Ok(value.to_int())
          _ => Ok(1)
        }
      _ => Err("Invalid JSON: expected a JSON object")
    }
  } catch {
    error => Err("Failed to inspect schema version: " + error.to_string())
  }
}

///|
pub fn supported_version(version : Int) -> Bool {
  version == 1 || version == 2
}

///|
pub fn schema_name(version : Int) -> String {
  match version {
    1 => "legacy"
    2 => "current"
    _ => "unknown"
  }
}

///|
pub fn encode_session(session : @core.Session) -> String {
  ToJson::to_json(SessionV2::from_core_session(session)).stringify()
}

///|
pub fn encode_session_pretty(session : @core.Session) -> String {
  ToJson::to_json(SessionV2::from_core_session(session)).stringify(indent=2)
}

///|
pub fn encode_sessions(sessions : Array[@core.Session]) -> String {
  @json.to_json(sessions.map(session => SessionV2::from_core_session(session))).stringify()
}

///|
pub fn encode_sessions_pretty(sessions : Array[@core.Session]) -> String {
  @json.to_json(sessions.map(session => SessionV2::from_core_session(session))).stringify(
    indent=2,
  )
}

///|
pub fn canonical_json(json_str : String) -> Result[String, String] {
  Ok(@json.parse(json_str).stringify(indent=2)) catch {
    error => Err("Invalid JSON: " + error.to_string())
  }
}

///|
fn migration_warnings_v1(value : SessionV1) -> Array[MigrationWarning] {
  let warnings = [MigrationWarning::LegacyVersionAssumed]
  if value.movements.is_empty() {
    warnings.push(MigrationWarning::EmptyMovementSet)
  }
  if value.notes.is_empty() {
    warnings.push(MigrationWarning::MissingNotes)
  }
  if value.pain_before == 0 && value.pain_after == 0 {
    warnings.push(MigrationWarning::MissingPainValue)
  }
  warnings
}

///|
pub fn migrate_with_report(
  json_str : String,
) -> Result[(@core.Session, MigrationReport), String] {
  let version = schema_version(json_str)
  let source_version = match version {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if source_version == 1 {
    try {
      let json = @json.parse(json_str)
      let legacy : SessionV1 = @json.from_json(json)
      let session = legacy.migrate_to_v2()
      Ok(
        (
          session,
          MigrationReport::{
            source_version,
            target_version: 2,
            session_id: legacy.id,
            movement_count: legacy.movements.length(),
            warnings: migration_warnings_v1(legacy),
          },
        ),
      )
    } catch {
      error => Err("Failed to migrate legacy session: " + error.to_string())
    }
  } else if source_version == 2 {
    match parse_and_migrate_session(json_str) {
      Ok(session) =>
        Ok(
          (
            session,
            MigrationReport::{
              source_version: 2,
              target_version: 2,
              session_id: session.id,
              movement_count: session.movements.length(),
              warnings: [],
            },
          ),
        )
      Err(error) => Err(error)
    }
  } else {
    Err("Unsupported schema version: " + source_version.to_string())
  }
}

///|
pub fn parse_many(
  records : Array[String],
) -> (Array[@core.Session], Array[String]) {
  let sessions = []
  let errors = []
  for record in records {
    match parse_and_migrate_session(record) {
      Ok(session) => sessions.push(session)
      Err(error) => errors.push(error)
    }
  }
  (sessions, errors)
}

///|
pub fn parse_many_strict(
  records : Array[String],
) -> Result[Array[@core.Session], String] {
  let (sessions, errors) = parse_many(records)
  if errors.is_empty() {
    Ok(sessions)
  } else {
    Err(errors.join("; "))
  }
}

///|
pub fn parse_json_array(
  json_str : String,
) -> Result[Array[@core.Session], String] {
  try {
    let json = @json.parse(json_str)
    let values : Array[Json] = match json {
      Array(items) => items
      _ => return Err("Invalid JSON: expected an array")
    }
    let sessions = []
    for value in values {
      let versioned = value.stringify()
      match parse_and_migrate_session(versioned) {
        Ok(session) => sessions.push(session)
        Err(error) => return Err(error)
      }
    }
    Ok(sessions)
  } catch {
    error => Err("Failed to parse session array: " + error.to_string())
  }
}

///|
pub fn round_trip(json_str : String) -> Result[String, String] {
  match parse_and_migrate_session(json_str) {
    Ok(session) => Ok(encode_session(session))
    Err(error) => Err(error)
  }
}

///|
pub fn is_json_object(json_str : String) -> Bool {
  try (@json.parse(json_str) is Object(_)) catch {
    _ => false
  }
}

///|
pub fn is_json_array(json_str : String) -> Bool {
  try (@json.parse(json_str) is Array(_)) catch {
    _ => false
  }
}

///|
pub fn migration_warning_codes(report : MigrationReport) -> Array[String] {
  report.warnings.map(warning => warning.code())
}

///|
pub fn has_warnings(report : MigrationReport) -> Bool {
  !report.warnings.is_empty()
}

///|
pub fn migration_summary(report : MigrationReport) -> String {
  "v" +
  report.source_version.to_string() +
  " -> v" +
  report.target_version.to_string() +
  ": " +
  report.session_id +
  ", movements=" +
  report.movement_count.to_string() +
  ", warnings=" +
  report.warnings.length().to_string()
}
