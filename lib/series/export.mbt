///|
/// A compact series export is useful for chart adapters and audit snapshots.
pub(all) struct SeriesExportOptions {
  include_header : Bool
  separator : String
  precision : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_series_export_options() -> SeriesExportOptions {
  SeriesExportOptions::{ include_header: true, separator: ",", precision: 4 }
}

///|
pub fn SeriesExportOptions::validate(
  self : SeriesExportOptions,
) -> Array[String] {
  let errors = []
  if self.separator.is_empty() {
    errors.push("separator must not be empty")
  }
  if self.precision < 0 || self.precision > 12 {
    errors.push("precision must be between 0 and 12")
  }
  errors
}

///|
fn export_number(value : Double, precision : Int) -> String {
  let mut factor = 1.0
  for _ in 0..<precision {
    factor *= 10.0
  }
  ((value * factor).round() / factor).to_string()
}

///|
pub fn export_header(options : SeriesExportOptions) -> String {
  ["date", "session_id", "reps", "work_units", "average_pain", "completion"].join(
    options.separator,
  )
}

///|
pub fn export_point(
  point : SeriesPoint,
  options : SeriesExportOptions,
) -> String {
  [
    point.date,
    point.session_id,
    point.reps.to_string(),
    point.work_units.to_string(),
    export_number(point.average_pain, options.precision),
    export_number(point.completion, options.precision),
  ].join(options.separator)
}

///|
pub fn export_csv(
  series : SessionSeries,
  options : SeriesExportOptions,
) -> Result[String, String] {
  let errors = options.validate()
  if !errors.is_empty() {
    return Err(errors.join("; "))
  }
  let lines = []
  if options.include_header {
    lines.push(export_header(options))
  }
  for point in sorted(series).points {
    lines.push(export_point(point, options))
  }
  Ok(lines.join("\n"))
}

///|
pub fn export_json(series : SessionSeries) -> String {
  let values = sorted(series).points
  @json.to_json(values).stringify()
}

///|
pub fn export_rows(series : SessionSeries) -> Array[Array[String]] {
  sorted(series).points.map(point => {
    [
      point.date,
      point.session_id,
      point.reps.to_string(),
      point.work_units.to_string(),
      point.average_pain.to_string(),
      point.completion.to_string(),
    ]
  })
}

///|
pub fn export_checksum(series : SessionSeries) -> Int {
  sorted(series).points.fold(init=37, (total, point) => {
    total * 31 + point.session_id.length() + point.reps + point.work_units
  })
}

///|
pub fn export_summary(series : SessionSeries) -> String {
  "points=" +
  count(series).to_string() +
  ", reps=" +
  total_reps(series).to_string() +
  ", work=" +
  total_work_units(series).to_string() +
  ", checksum=" +
  export_checksum(series).to_string()
}

///|
pub fn export_window(
  series : SessionSeries,
  start : Int,
  limit : Int,
) -> SessionSeries {
  let ordered = sorted(series).points
  let safe_start = Int::min(Int::max(0, start), ordered.length())
  let safe_end = Int::min(safe_start + Int::max(0, limit), ordered.length())
  SessionSeries::{ points: ordered[safe_start:safe_end].to_owned() }
}

///|
pub fn export_page_count(series : SessionSeries, page_size : Int) -> Int {
  let size = Int::max(1, page_size)
  (count(series) + size - 1) / size
}

///|
pub fn export_page(
  series : SessionSeries,
  page : Int,
  page_size : Int,
) -> SessionSeries {
  export_window(series, Int::max(0, page) * Int::max(1, page_size), page_size)
}
