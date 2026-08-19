///|
pub(all) struct SessionRow {
  id : String
  date : String
  duration : Int
  pain_before : Int
  pain_after : Int
  total_reps : Int
  total_sets : Int
  average_pain : Double
  average_completion : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SessionRow::id(self : SessionRow) -> String {
  self.id
}

///|
pub fn SessionRow::date(self : SessionRow) -> String {
  self.date
}

///|
pub fn SessionRow::duration(self : SessionRow) -> Int {
  self.duration
}

///|
pub fn SessionRow::pain_before(self : SessionRow) -> Int {
  self.pain_before
}

///|
pub fn SessionRow::pain_after(self : SessionRow) -> Int {
  self.pain_after
}

///|
pub fn SessionRow::total_reps(self : SessionRow) -> Int {
  self.total_reps
}

///|
pub fn SessionRow::total_sets(self : SessionRow) -> Int {
  self.total_sets
}

///|
pub fn SessionRow::average_pain(self : SessionRow) -> Double {
  self.average_pain
}

///|
pub fn SessionRow::average_completion(self : SessionRow) -> Double {
  self.average_completion
}

///|
pub fn row_from_session(session : @core.Session) -> SessionRow {
  SessionRow::{
    id: session.id,
    date: session.date,
    duration: session.duration,
    pain_before: session.pain_before,
    pain_after: session.pain_after,
    total_reps: session.total_reps(),
    total_sets: session.total_sets(),
    average_pain: session.average_pain_during(),
    average_completion: session.average_completion(),
  }
}

///|
pub fn rows_from_sessions(sessions : Array[@core.Session]) -> Array[SessionRow] {
  sessions.map(session => row_from_session(session))
}

///|
fn cell(value : String) -> String {
  if value.contains("\t") || value.contains("\n") {
    value.replace_all(old="\t", new=" ").replace_all(old="\n", new=" ")
  } else {
    value
  }
}

///|
pub fn row_to_tsv(row : SessionRow) -> String {
  [
    cell(row.id),
    cell(row.date),
    row.duration.to_string(),
    row.pain_before.to_string(),
    row.pain_after.to_string(),
    row.total_reps.to_string(),
    row.total_sets.to_string(),
    row.average_pain.to_string(),
    row.average_completion.to_string(),
  ].join("\t")
}

///|
pub fn rows_to_tsv(rows : Array[SessionRow]) -> String {
  let output = StringBuilder()
  output.write_string(
    "id\tdate\tduration\tpain_before\tpain_after\ttotal_reps\ttotal_sets\taverage_pain\taverage_completion\n",
  )
  for row in rows {
    output.write_string(row_to_tsv(row) + "\n")
  }
  output.to_string()
}

///|
fn parse_int(value : StringView) -> Result[Int, String] {
  Ok(@strconv.from_str(value)) catch {
    error => Err(error.to_string())
  }
}

///|
fn parse_double(value : StringView) -> Result[Double, String] {
  Ok(@strconv.from_str(value)) catch {
    error => Err(error.to_string())
  }
}

///|
pub fn parse_row(line : String) -> Result[SessionRow, String] {
  let fields = line.split("\t").map(item => item.to_owned()).to_array()
  if fields.length() != 9 {
    Err("expected 9 tab-separated fields")
  } else {
    let duration = parse_int(fields[2])
    let pain_before = parse_int(fields[3])
    let pain_after = parse_int(fields[4])
    let total_reps = parse_int(fields[5])
    let total_sets = parse_int(fields[6])
    let average_pain = parse_double(fields[7])
    let average_completion = parse_double(fields[8])
    match
      (
        duration, pain_before, pain_after, total_reps, total_sets, average_pain,
        average_completion,
      ) {
      (Ok(a), Ok(b), Ok(c), Ok(d), Ok(e), Ok(f), Ok(g)) =>
        Ok(SessionRow::{
          id: fields[0],
          date: fields[1],
          duration: a,
          pain_before: b,
          pain_after: c,
          total_reps: d,
          total_sets: e,
          average_pain: f,
          average_completion: g,
        })
      _ => Err("invalid numeric field")
    }
  }
}

///|
pub fn parse_tsv(text : String) -> (Array[SessionRow], Array[String]) {
  let rows = []
  let errors = []
  let lines = text.split("\n").map(line => line.to_owned()).to_array()
  for i, line in lines {
    if i == 0 || line.trim().is_empty() {
      continue
    }
    match parse_row(line) {
      Ok(row) => rows.push(row)
      Err(error) => errors.push("line " + (i + 1).to_string() + ": " + error)
    }
  }
  (rows, errors)
}

///|
pub fn rows_to_json(rows : Array[SessionRow]) -> String {
  @json.to_json(rows).stringify()
}

///|
pub fn session_json_lines(sessions : Array[@core.Session]) -> String {
  let output = StringBuilder()
  for session in sessions {
    output.write_string(@schema.encode_session(session) + "\n")
  }
  output.to_string()
}

///|
pub fn parse_json_lines(text : String) -> (Array[@core.Session], Array[String]) {
  let sessions = []
  let errors = []
  for i, line in text.split("\n").map(item => item.to_owned()) {
    if line.trim().is_empty() {
      continue
    }
    match @schema.parse_and_migrate_session(line) {
      Ok(session) => sessions.push(session)
      Err(error) => errors.push("line " + (i + 1).to_string() + ": " + error)
    }
  }
  (sessions, errors)
}
