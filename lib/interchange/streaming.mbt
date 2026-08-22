///|
/// Chunk-oriented JSON-lines ingestion keeps import code bounded by the
/// caller's batch size and preserves malformed-line diagnostics.
pub(all) struct StreamOptions {
  chunk_size : Int
  reject_empty_id : Bool
  deduplicate : Bool
  maximum_errors : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_stream_options() -> StreamOptions {
  StreamOptions::{
    chunk_size: 256,
    reject_empty_id: true,
    deduplicate: true,
    maximum_errors: 1000,
  }
}

///|
pub fn stream_options(
  chunk_size? : Int = 256,
  reject_empty_id? : Bool = true,
  deduplicate? : Bool = true,
  maximum_errors? : Int = 1000,
) -> StreamOptions {
  StreamOptions::{
    chunk_size: Int::max(1, chunk_size),
    reject_empty_id,
    deduplicate,
    maximum_errors: Int::max(1, maximum_errors),
  }
}

///|
pub fn StreamOptions::validate(self : StreamOptions) -> Array[String] {
  let errors = []
  if self.chunk_size <= 0 {
    errors.push("chunk_size must be positive")
  }
  if self.maximum_errors <= 0 {
    errors.push("maximum_errors must be positive")
  }
  errors
}

///|
pub(all) struct StreamChunk {
  index : Int
  line_count : Int
  accepted : Array[@core.Session]
  errors : Array[String]
  complete : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn StreamChunk::index(self : StreamChunk) -> Int {
  self.index
}

///|
pub fn StreamChunk::line_count(self : StreamChunk) -> Int {
  self.line_count
}

///|
pub fn StreamChunk::accepted(self : StreamChunk) -> Array[@core.Session] {
  self.accepted.copy()
}

///|
pub fn StreamChunk::errors(self : StreamChunk) -> Array[String] {
  self.errors.copy()
}

///|
pub fn StreamChunk::complete(self : StreamChunk) -> Bool {
  self.complete
}

///|
fn accept_chunk(
  index : Int,
  lines : Array[String],
  options : StreamOptions,
  seen : Array[String],
) -> StreamChunk {
  let accepted = []
  let errors = []
  for line in lines {
    if line.trim().is_empty() {
      continue
    }
    let (sessions, parse_errors) = parse_json_lines(line)
    for error in parse_errors {
      errors.push(error)
    }
    for session in sessions {
      if options.reject_empty_id && session.id.trim().is_empty() {
        errors.push("line rejected: empty session id")
      } else {
        let key = @retention.fingerprint(session)
        if options.deduplicate && seen.contains(key) {
          errors.push(session.id + ": duplicate fingerprint")
        } else {
          seen.push(key)
          accepted.push(session)
        }
      }
    }
  }
  StreamChunk::{
    index,
    line_count: lines.length(),
    accepted,
    errors,
    complete: errors.length() < options.maximum_errors,
  }
}

///|
pub fn stream_chunks(
  text : String,
  options : StreamOptions,
) -> Result[Array[StreamChunk], String] {
  let errors = options.validate()
  if !errors.is_empty() {
    return Err(errors.join("; "))
  }
  let lines = text.split("\n").to_array().map(line => line.to_owned())
  let chunks = []
  let seen = []
  let mut start = 0
  let mut index = 0
  while start < lines.length() {
    let end = Int::min(start + options.chunk_size, lines.length())
    let current : Array[String] = lines[start:end].to_owned()
    let chunk = accept_chunk(index, current, options, seen)
    chunks.push(chunk)
    start = end
    index += 1
  }
  Ok(chunks)
}

///|
pub(all) struct StreamReport {
  chunks : Int
  lines : Int
  accepted : Array[@core.Session]
  errors : Array[String]
  complete : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn StreamReport::chunks(self : StreamReport) -> Int {
  self.chunks
}

///|
pub fn StreamReport::lines(self : StreamReport) -> Int {
  self.lines
}

///|
pub fn StreamReport::accepted(self : StreamReport) -> Array[@core.Session] {
  self.accepted.copy()
}

///|
pub fn StreamReport::errors(self : StreamReport) -> Array[String] {
  self.errors.copy()
}

///|
pub fn StreamReport::complete(self : StreamReport) -> Bool {
  self.complete
}

///|
pub fn ingest_stream(
  text : String,
  options : StreamOptions,
) -> Result[StreamReport, String] {
  match stream_chunks(text, options) {
    Err(error) => Err(error)
    Ok(chunks) => {
      let accepted = []
      let errors = []
      let mut lines = 0
      let mut complete = true
      for chunk in chunks {
        lines += chunk.line_count
        accepted.append(chunk.accepted)
        errors.append(chunk.errors)
        if !chunk.complete {
          complete = false
        }
      }
      Ok(StreamReport::{
        chunks: chunks.length(),
        lines,
        accepted,
        errors,
        complete,
      })
    }
  }
}

///|
pub fn stream_report_text(value : StreamReport) -> String {
  "chunks=" +
  value.chunks.to_string() +
  ", lines=" +
  value.lines.to_string() +
  ", accepted=" +
  value.accepted.length().to_string() +
  ", errors=" +
  value.errors.length().to_string() +
  ", complete=" +
  value.complete.to_string()
}

///|
pub fn stream_error_codes(value : StreamReport) -> Array[String] {
  let codes = []
  for error in value.errors {
    let code = if error.contains("duplicate") {
      "duplicate"
    } else if error.contains("empty") {
      "identity"
    } else {
      "parse"
    }
    if !codes.contains(code) {
      codes.push(code)
    }
  }
  codes
}

///|
pub fn stream_success_rate(value : StreamReport) -> Double {
  if value.lines == 0 {
    0.0
  } else {
    value.accepted.length().to_double() * 100.0 / value.lines.to_double()
  }
}

///|
pub fn stream_to_json_lines(value : StreamReport) -> String {
  session_json_lines(value.accepted)
}

///|
pub fn stream_partition(value : StreamReport) -> (@core.Session, Array[String]) {
  let first = match value.accepted.get(0) {
    Some(session) => session
    None =>
      @core.Session::{
        id: "",
        date: "",
        duration: 0,
        pain_before: 0,
        pain_after: 0,
        movements: [],
        notes: "",
      }
  }
  (first, value.errors.copy())
}
