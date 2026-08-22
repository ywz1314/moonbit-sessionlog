///|
/// Lightweight digest and row helpers for logs, cache keys, and export
/// adapters.  They intentionally avoid depending on a storage backend.
pub(all) struct SerializationDigest {
  id : String
  date : String
  movement_count : Int
  set_count : Int
  reps : Int
  hold_time : Int
  completion : Double
  pain_before : Int
  pain_after : Int
  checksum : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SerializationDigest::id(self : SerializationDigest) -> String {
  self.id
}

///|
pub fn SerializationDigest::date(self : SerializationDigest) -> String {
  self.date
}

///|
pub fn SerializationDigest::movement_count(self : SerializationDigest) -> Int {
  self.movement_count
}

///|
pub fn SerializationDigest::set_count(self : SerializationDigest) -> Int {
  self.set_count
}

///|
pub fn SerializationDigest::reps(self : SerializationDigest) -> Int {
  self.reps
}

///|
pub fn SerializationDigest::hold_time(self : SerializationDigest) -> Int {
  self.hold_time
}

///|
pub fn SerializationDigest::completion(self : SerializationDigest) -> Double {
  self.completion
}

///|
pub fn SerializationDigest::pain_before(self : SerializationDigest) -> Int {
  self.pain_before
}

///|
pub fn SerializationDigest::pain_after(self : SerializationDigest) -> Int {
  self.pain_after
}

///|
pub fn SerializationDigest::checksum(self : SerializationDigest) -> Int {
  self.checksum
}

///|
fn digest_checksum(session : Session) -> Int {
  let base = session.id.length() * 31 + session.date.length() + session.duration
  session.movements.fold(init=base, (total, movement) => {
    let movement_value = movement.name.length() * 17 +
      movement.pain +
      movement.rpe
    movement.sets.fold(init=total + movement_value, (sum, set) => {
      sum * 31 +
      set.reps +
      set.hold_time +
      (set.completion * 100.0).round().to_int()
    })
  })
}

///|
pub fn Session::serialization_digest(self : Session) -> SerializationDigest {
  SerializationDigest::{
    id: self.id,
    date: self.date,
    movement_count: self.movements.length(),
    set_count: self.total_sets(),
    reps: self.total_reps(),
    hold_time: self.total_hold_time(),
    completion: self.average_completion(),
    pain_before: self.pain_before,
    pain_after: self.pain_after,
    checksum: digest_checksum(self),
  }
}

///|
pub fn SerializationDigest::stable_key(self : SerializationDigest) -> String {
  self.id + "@" + self.date + "#" + self.checksum.to_string()
}

///|
pub fn SerializationDigest::text(self : SerializationDigest) -> String {
  self.id +
  " " +
  self.date +
  " movements=" +
  self.movement_count.to_string() +
  " sets=" +
  self.set_count.to_string() +
  " reps=" +
  self.reps.to_string() +
  " completion=" +
  self.completion.to_string() +
  " checksum=" +
  self.checksum.to_string()
}

///|
pub fn serialization_digests(
  sessions : Array[Session],
) -> Array[SerializationDigest] {
  sessions.map(session => session.serialization_digest())
}

///|
pub fn digest_checksum_all(values : Array[SerializationDigest]) -> Int {
  values.fold(init=59, (total, value) => total * 31 + value.checksum)
}

///|
pub fn digest_find(
  values : Array[SerializationDigest],
  key : String,
) -> SerializationDigest? {
  match values.search_by(value => value.stable_key() == key) {
    Some(index) => Some(values[index])
    None => None
  }
}

///|
pub fn digest_duplicates(
  values : Array[SerializationDigest],
) -> Array[SerializationDigest] {
  let seen = []
  let duplicates = []
  for value in values {
    if seen.contains(value.stable_key()) {
      duplicates.push(value)
    } else {
      seen.push(value.stable_key())
    }
  }
  duplicates
}

///|
pub fn digest_changed(
  left : SerializationDigest,
  right : SerializationDigest,
) -> Array[String] {
  let changes = []
  if left.date != right.date {
    changes.push("date")
  }
  if left.movement_count != right.movement_count {
    changes.push("movement_count")
  }
  if left.set_count != right.set_count {
    changes.push("set_count")
  }
  if left.reps != right.reps {
    changes.push("reps")
  }
  if left.completion != right.completion {
    changes.push("completion")
  }
  if left.pain_before != right.pain_before {
    changes.push("pain_before")
  }
  if left.pain_after != right.pain_after {
    changes.push("pain_after")
  }
  changes
}

///|
pub fn digest_map_by_id(
  values : Array[SerializationDigest],
) -> Array[(String, Int)] {
  let result : Array[(String, Int)] = []
  for value in values {
    match result.search_by(item => item.0 == value.id) {
      Some(index) => {
        let old = result[index]
        result[index] = (old.0, old.1 + 1)
      }
      None => result.push((value.id, 1))
    }
  }
  result
}

///|
pub(all) struct SessionExportRow {
  id : String
  date : String
  duration : Int
  movements : Int
  sets : Int
  reps : Int
  hold_time : Int
  pain_before : Int
  pain_after : Int
  completion : Double
  notes_length : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SessionExportRow::id(self : SessionExportRow) -> String {
  self.id
}

///|
pub fn SessionExportRow::date(self : SessionExportRow) -> String {
  self.date
}

///|
pub fn SessionExportRow::duration(self : SessionExportRow) -> Int {
  self.duration
}

///|
pub fn SessionExportRow::movements(self : SessionExportRow) -> Int {
  self.movements
}

///|
pub fn SessionExportRow::sets(self : SessionExportRow) -> Int {
  self.sets
}

///|
pub fn SessionExportRow::reps(self : SessionExportRow) -> Int {
  self.reps
}

///|
pub fn SessionExportRow::hold_time(self : SessionExportRow) -> Int {
  self.hold_time
}

///|
pub fn SessionExportRow::pain_before(self : SessionExportRow) -> Int {
  self.pain_before
}

///|
pub fn SessionExportRow::pain_after(self : SessionExportRow) -> Int {
  self.pain_after
}

///|
pub fn SessionExportRow::completion(self : SessionExportRow) -> Double {
  self.completion
}

///|
pub fn SessionExportRow::notes_length(self : SessionExportRow) -> Int {
  self.notes_length
}

///|
pub fn Session::export_row(self : Session) -> SessionExportRow {
  SessionExportRow::{
    id: self.id,
    date: self.date,
    duration: self.duration,
    movements: self.movements.length(),
    sets: self.total_sets(),
    reps: self.total_reps(),
    hold_time: self.total_hold_time(),
    pain_before: self.pain_before,
    pain_after: self.pain_after,
    completion: self.average_completion(),
    notes_length: self.notes.length(),
  }
}

///|
pub fn export_rows(sessions : Array[Session]) -> Array[SessionExportRow] {
  sessions.map(session => session.export_row())
}

///|
pub fn export_row_values(value : SessionExportRow) -> Array[String] {
  [
    value.id,
    value.date,
    value.duration.to_string(),
    value.movements.to_string(),
    value.sets.to_string(),
    value.reps.to_string(),
    value.hold_time.to_string(),
    value.pain_before.to_string(),
    value.pain_after.to_string(),
    value.completion.to_string(),
    value.notes_length.to_string(),
  ]
}

///|
pub fn export_row_header() -> Array[String] {
  [
    "id", "date", "duration", "movements", "sets", "reps", "hold_time", "pain_before",
    "pain_after", "completion", "notes_length",
  ]
}

///|
pub fn export_rows_tsv(sessions : Array[Session]) -> String {
  let lines = [export_row_header().join("\t")]
  for row in export_rows(sessions) {
    lines.push(export_row_values(row).join("\t"))
  }
  lines.join("\n")
}

///|
pub fn export_rows_by_date(sessions : Array[Session]) -> Array[(String, Int)] {
  let counts : Array[(String, Int)] = []
  for session in sessions {
    match counts.search_by(item => item.0 == session.date) {
      Some(index) => {
        let old = counts[index]
        counts[index] = (old.0, old.1 + 1)
      }
      None => counts.push((session.date, 1))
    }
  }
  counts.sort_by((left, right) => left.0.compare(right.0))
  counts
}

///|
pub fn export_row_checksum(value : SessionExportRow) -> Int {
  value.id.length() * 31 +
  value.date.length() +
  value.reps +
  value.sets +
  value.hold_time +
  value.pain_before +
  value.pain_after
}

///|
pub fn export_rows_checksum(values : Array[SessionExportRow]) -> Int {
  values.fold(init=61, (total, value) => total * 31 + export_row_checksum(value))
}

///|
pub fn export_rows_select_date(
  values : Array[SessionExportRow],
  start : String,
  end : String,
) -> Array[SessionExportRow] {
  values.filter(value => {
    (start.is_empty() || value.date >= start) &&
    (end.is_empty() || value.date <= end)
  })
}

///|
pub fn export_rows_select_pain(
  values : Array[SessionExportRow],
  threshold : Int,
) -> Array[SessionExportRow] {
  values.filter(value => {
    value.pain_before >= threshold || value.pain_after >= threshold
  })
}

///|
pub fn export_rows_select_completion(
  values : Array[SessionExportRow],
  threshold : Double,
) -> Array[SessionExportRow] {
  values.filter(value => value.completion >= threshold)
}

///|
pub fn export_rows_sort_by_reps(
  values : Array[SessionExportRow],
) -> Array[SessionExportRow] {
  let result = values.copy()
  result.sort_by((left, right) => right.reps - left.reps)
  result
}

///|
pub fn export_rows_sort_by_pain(
  values : Array[SessionExportRow],
) -> Array[SessionExportRow] {
  let result = values.copy()
  result.sort_by((left, right) => {
    right.pain_before + right.pain_after - (left.pain_before + left.pain_after)
  })
  result
}

///|
pub fn export_rows_sort_by_completion(
  values : Array[SessionExportRow],
) -> Array[SessionExportRow] {
  let result = values.copy()
  result.sort_by((left, right) => right.completion.compare(left.completion))
  result
}

///|
pub fn export_rows_top_reps(
  values : Array[SessionExportRow],
  limit : Int,
) -> Array[SessionExportRow] {
  export_rows_sort_by_reps(values)[:Int::min(
    Int::max(0, limit),
    values.length(),
  )].to_owned()
}

///|
pub fn export_rows_top_pain(
  values : Array[SessionExportRow],
  limit : Int,
) -> Array[SessionExportRow] {
  export_rows_sort_by_pain(values)[:Int::min(
    Int::max(0, limit),
    values.length(),
  )].to_owned()
}

///|
pub(all) struct ExportRowSummary {
  count : Int
  duration : Int
  movements : Int
  sets : Int
  reps : Int
  hold_time : Int
  average_completion : Double
  average_pain : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ExportRowSummary::count(self : ExportRowSummary) -> Int {
  self.count
}

///|
pub fn ExportRowSummary::duration(self : ExportRowSummary) -> Int {
  self.duration
}

///|
pub fn ExportRowSummary::movements(self : ExportRowSummary) -> Int {
  self.movements
}

///|
pub fn ExportRowSummary::sets(self : ExportRowSummary) -> Int {
  self.sets
}

///|
pub fn ExportRowSummary::reps(self : ExportRowSummary) -> Int {
  self.reps
}

///|
pub fn ExportRowSummary::hold_time(self : ExportRowSummary) -> Int {
  self.hold_time
}

///|
pub fn ExportRowSummary::average_completion(self : ExportRowSummary) -> Double {
  self.average_completion
}

///|
pub fn ExportRowSummary::average_pain(self : ExportRowSummary) -> Double {
  self.average_pain
}

///|
pub fn summarize_export_rows(
  values : Array[SessionExportRow],
) -> ExportRowSummary {
  let count = values.length()
  let divisor = if count == 0 { 1.0 } else { count.to_double() }
  ExportRowSummary::{
    count,
    duration: values.fold(init=0, (total, value) => total + value.duration),
    movements: values.fold(init=0, (total, value) => total + value.movements),
    sets: values.fold(init=0, (total, value) => total + value.sets),
    reps: values.fold(init=0, (total, value) => total + value.reps),
    hold_time: values.fold(init=0, (total, value) => total + value.hold_time),
    average_completion: values.fold(init=0.0, (total, value) => {
      total + value.completion
    }) /
    divisor,
    average_pain: values.fold(init=0.0, (total, value) => {
      total + (value.pain_before + value.pain_after).to_double() / 2.0
    }) /
    divisor,
  }
}

///|
pub fn export_summary_text(value : ExportRowSummary) -> String {
  "count=" +
  value.count.to_string() +
  ", duration=" +
  value.duration.to_string() +
  ", movements=" +
  value.movements.to_string() +
  ", sets=" +
  value.sets.to_string() +
  ", reps=" +
  value.reps.to_string() +
  ", completion=" +
  value.average_completion.to_string() +
  ", pain=" +
  value.average_pain.to_string()
}

///|
pub(all) enum ExportMetric {
  Duration
  Movements
  Sets
  Reps
  HoldTime
  Completion
  Pain
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ExportMetric::label(self : ExportMetric) -> String {
  match self {
    Duration => "duration"
    Movements => "movements"
    Sets => "sets"
    Reps => "reps"
    HoldTime => "hold_time"
    Completion => "completion"
    Pain => "pain"
  }
}

///|
pub fn ExportMetric::value(
  self : ExportMetric,
  row : SessionExportRow,
) -> Double {
  match self {
    Duration => row.duration.to_double()
    Movements => row.movements.to_double()
    Sets => row.sets.to_double()
    Reps => row.reps.to_double()
    HoldTime => row.hold_time.to_double()
    Completion => row.completion
    Pain => (row.pain_before + row.pain_after).to_double() / 2.0
  }
}

///|
pub fn export_metric_values(
  values : Array[SessionExportRow],
  metric : ExportMetric,
) -> Array[Double] {
  values.map(row => metric.value(row))
}

///|
pub fn export_metric_total(
  values : Array[SessionExportRow],
  metric : ExportMetric,
) -> Double {
  export_metric_values(values, metric).fold(init=0.0, (total, value) => {
    total + value
  })
}

///|
pub fn export_metric_average(
  values : Array[SessionExportRow],
  metric : ExportMetric,
) -> Double {
  if values.is_empty() {
    0.0
  } else {
    export_metric_total(values, metric) / values.length().to_double()
  }
}

///|
pub fn export_metric_minimum(
  values : Array[SessionExportRow],
  metric : ExportMetric,
) -> Double {
  let numbers = export_metric_values(values, metric)
  if numbers.is_empty() {
    0.0
  } else {
    numbers.fold(init=numbers[0], (value, item) => Double::min(value, item))
  }
}

///|
pub fn export_metric_maximum(
  values : Array[SessionExportRow],
  metric : ExportMetric,
) -> Double {
  let numbers = export_metric_values(values, metric)
  if numbers.is_empty() {
    0.0
  } else {
    numbers.fold(init=numbers[0], (value, item) => Double::max(value, item))
  }
}

///|
pub fn export_metric_range(
  values : Array[SessionExportRow],
  metric : ExportMetric,
) -> Double {
  export_metric_maximum(values, metric) - export_metric_minimum(values, metric)
}

///|
pub fn export_metric_report(
  values : Array[SessionExportRow],
  metric : ExportMetric,
) -> String {
  metric.label() +
  " count=" +
  values.length().to_string() +
  " total=" +
  export_metric_total(values, metric).to_string() +
  " average=" +
  export_metric_average(values, metric).to_string() +
  " range=" +
  export_metric_range(values, metric).to_string()
}

///|
pub fn export_metric_above(
  values : Array[SessionExportRow],
  metric : ExportMetric,
  threshold : Double,
) -> Array[SessionExportRow] {
  values.filter(row => metric.value(row) >= threshold)
}

///|
pub fn export_metric_below(
  values : Array[SessionExportRow],
  metric : ExportMetric,
  threshold : Double,
) -> Array[SessionExportRow] {
  values.filter(row => metric.value(row) < threshold)
}

///|
pub fn export_metric_rank(
  values : Array[SessionExportRow],
  metric : ExportMetric,
) -> Array[(String, Double)] {
  let result = values.map(row => (row.id, metric.value(row)))
  result.sort_by((left, right) => right.1.compare(left.1))
  result
}

///|
pub fn export_metric_top(
  values : Array[SessionExportRow],
  metric : ExportMetric,
  limit : Int,
) -> Array[(String, Double)] {
  let ranked = export_metric_rank(values, metric)
  ranked[:Int::min(Int::max(0, limit), ranked.length())].to_owned()
}

///|
pub fn export_metric_bottom(
  values : Array[SessionExportRow],
  metric : ExportMetric,
  limit : Int,
) -> Array[(String, Double)] {
  let ranked = export_metric_rank(values, metric)
  ranked.sort_by((left, right) => left.1.compare(right.1))
  ranked[:Int::min(Int::max(0, limit), ranked.length())].to_owned()
}

///|
pub fn export_row_is_complete(value : SessionExportRow) -> Bool {
  value.id != "" &&
  value.date != "" &&
  value.movements > 0 &&
  value.sets > 0 &&
  value.reps >= 0
}

///|
pub fn export_complete_rows(
  values : Array[SessionExportRow],
) -> Array[SessionExportRow] {
  values.filter(export_row_is_complete)
}

///|
pub fn export_incomplete_rows(
  values : Array[SessionExportRow],
) -> Array[SessionExportRow] {
  values.filter(row => !export_row_is_complete(row))
}

///|
pub fn export_rows_with_notes(
  values : Array[SessionExportRow],
) -> Array[SessionExportRow] {
  values.filter(row => row.notes_length > 0)
}

///|
pub fn export_rows_without_notes(
  values : Array[SessionExportRow],
) -> Array[SessionExportRow] {
  values.filter(row => row.notes_length == 0)
}

///|
pub fn export_duration_total(values : Array[SessionExportRow]) -> Int {
  values.fold(init=0, (total, row) => total + row.duration)
}

///|
pub fn export_reps_total(values : Array[SessionExportRow]) -> Int {
  values.fold(init=0, (total, row) => total + row.reps)
}

///|
pub fn export_sets_total(values : Array[SessionExportRow]) -> Int {
  values.fold(init=0, (total, row) => total + row.sets)
}

///|
pub fn export_pain_total(values : Array[SessionExportRow]) -> Int {
  values.fold(init=0, (total, row) => total + row.pain_before + row.pain_after)
}

///|
pub fn export_row_quality_score(value : SessionExportRow) -> Int {
  let mut score = 100
  if value.id.is_empty() {
    score -= 30
  }
  if value.date.is_empty() {
    score -= 20
  }
  if value.movements == 0 {
    score -= 15
  }
  if value.sets == 0 {
    score -= 15
  }
  if value.notes_length == 0 {
    score -= 5
  }
  score.clamp(min=0, max=100)
}

///|
pub fn export_quality_average(values : Array[SessionExportRow]) -> Double {
  if values.is_empty() {
    0.0
  } else {
    values
    .fold(init=0, (total, row) => total + export_row_quality_score(row))
    .to_double() /
    values.length().to_double()
  }
}

///|
pub fn export_quality_pass(
  values : Array[SessionExportRow],
  threshold : Int,
) -> Array[SessionExportRow] {
  values.filter(row => export_row_quality_score(row) >= threshold)
}

///|
pub fn export_quality_fail(
  values : Array[SessionExportRow],
  threshold : Int,
) -> Array[SessionExportRow] {
  values.filter(row => export_row_quality_score(row) < threshold)
}

///|
pub fn export_quality_report(
  values : Array[SessionExportRow],
  threshold : Int,
) -> String {
  "rows=" +
  values.length().to_string() +
  ", average=" +
  export_quality_average(values).to_string() +
  ", pass=" +
  export_quality_pass(values, threshold).length().to_string() +
  ", fail=" +
  export_quality_fail(values, threshold).length().to_string()
}

///|
pub fn export_rows_sorted_by_date(
  values : Array[SessionExportRow],
) -> Array[SessionExportRow] {
  let result = values.copy()
  result.sort_by((left, right) => left.date.compare(right.date))
  result
}

///|
pub fn export_rows_latest(
  values : Array[SessionExportRow],
) -> SessionExportRow? {
  export_rows_sorted_by_date(values).last()
}

///|
pub fn export_rows_earliest(
  values : Array[SessionExportRow],
) -> SessionExportRow? {
  export_rows_sorted_by_date(values).get(0)
}

///|
pub fn export_rows_date_span(
  values : Array[SessionExportRow],
) -> (String, String) {
  match (export_rows_earliest(values), export_rows_latest(values)) {
    (Some(first), Some(last)) => (first.date, last.date)
    _ => ("", "")
  }
}

///|
pub fn export_rows_unique_ids(
  values : Array[SessionExportRow],
) -> Array[String] {
  let ids = []
  for value in values {
    if !ids.contains(value.id) {
      ids.push(value.id)
    }
  }
  ids
}

///|
pub fn export_rows_id_counts(
  values : Array[SessionExportRow],
) -> Array[(String, Int)] {
  let counts : Array[(String, Int)] = []
  for value in values {
    match counts.search_by(item => item.0 == value.id) {
      Some(index) => {
        let old = counts[index]
        counts[index] = (old.0, old.1 + 1)
      }
      None => counts.push((value.id, 1))
    }
  }
  counts
}

///|
pub fn export_duplicate_ids(values : Array[SessionExportRow]) -> Array[String] {
  export_rows_id_counts(values).filter(item => item.1 > 1).map(item => item.0)
}

///|
pub fn export_rows_has_duplicate_ids(values : Array[SessionExportRow]) -> Bool {
  !export_duplicate_ids(values).is_empty()
}

///|
pub fn export_rows_ready_for_import(values : Array[SessionExportRow]) -> Bool {
  export_incomplete_rows(values).is_empty() &&
  !export_rows_has_duplicate_ids(values)
}

///|
pub fn export_import_gate_text(values : Array[SessionExportRow]) -> String {
  "rows=" +
  values.length().to_string() +
  ", incomplete=" +
  export_incomplete_rows(values).length().to_string() +
  ", duplicate_ids=" +
  export_duplicate_ids(values).length().to_string() +
  ", ready=" +
  export_rows_ready_for_import(values).to_string()
}

///|
pub fn export_rows_limit(
  values : Array[SessionExportRow],
  limit : Int,
) -> Array[SessionExportRow] {
  values[:Int::min(Int::max(0, limit), values.length())].to_owned()
}

///|
pub fn export_rows_after(
  values : Array[SessionExportRow],
  start : Int,
) -> Array[SessionExportRow] {
  let index = Int::min(Int::max(0, start), values.length())
  values[index:].to_owned()
}

///|
pub fn export_rows_page(
  values : Array[SessionExportRow],
  page : Int,
  size : Int,
) -> Array[SessionExportRow] {
  let safe_size = Int::max(1, size)
  export_rows_limit(
    export_rows_after(values, Int::max(0, page) * safe_size),
    safe_size,
  )
}

///|
pub fn export_rows_page_count(
  values : Array[SessionExportRow],
  size : Int,
) -> Int {
  let safe_size = Int::max(1, size)
  (values.length() + safe_size - 1) / safe_size
}

///|
pub fn export_rows_page_valid(
  values : Array[SessionExportRow],
  page : Int,
  size : Int,
) -> Bool {
  page >= 0 && page < export_rows_page_count(values, size)
}

///|
pub fn export_rows_empty(values : Array[SessionExportRow]) -> Bool {
  values.is_empty()
}

///|
pub fn export_rows_nonempty(values : Array[SessionExportRow]) -> Bool {
  !values.is_empty()
}

///|
pub fn export_rows_ids_text(values : Array[SessionExportRow]) -> String {
  export_rows_unique_ids(values).join(",")
}

///|
pub fn export_rows_date_text(values : Array[SessionExportRow]) -> String {
  let span = export_rows_date_span(values)
  span.0 + ".." + span.1
}

///|
pub fn export_rows_integrity_text(values : Array[SessionExportRow]) -> String {
  "checksum=" +
  export_rows_checksum(values).to_string() +
  ", quality=" +
  export_quality_average(values).to_string() +
  ", ready=" +
  export_rows_ready_for_import(values).to_string()
}

///|
pub fn export_rows_revision_key(values : Array[SessionExportRow]) -> String {
  export_rows_checksum(values).to_string() + ":" + values.length().to_string()
}

///|
pub fn export_rows_same_revision(
  left : Array[SessionExportRow],
  right : Array[SessionExportRow],
) -> Bool {
  export_rows_revision_key(left) == export_rows_revision_key(right)
}

///|
pub fn export_rows_changed(
  left : Array[SessionExportRow],
  right : Array[SessionExportRow],
) -> Bool {
  !export_rows_same_revision(left, right)
}

///|
pub fn export_rows_count_delta(
  left : Array[SessionExportRow],
  right : Array[SessionExportRow],
) -> Int {
  right.length() - left.length()
}

///|
pub fn export_rows_reps_delta(
  left : Array[SessionExportRow],
  right : Array[SessionExportRow],
) -> Int {
  export_reps_total(right) - export_reps_total(left)
}

///|
pub fn export_rows_sets_delta(
  left : Array[SessionExportRow],
  right : Array[SessionExportRow],
) -> Int {
  export_sets_total(right) - export_sets_total(left)
}

///|
pub fn export_rows_pain_delta(
  left : Array[SessionExportRow],
  right : Array[SessionExportRow],
) -> Int {
  export_pain_total(right) - export_pain_total(left)
}

///|
pub fn export_rows_duration_delta(
  left : Array[SessionExportRow],
  right : Array[SessionExportRow],
) -> Int {
  export_duration_total(right) - export_duration_total(left)
}

///|
pub fn export_rows_quality_delta(
  left : Array[SessionExportRow],
  right : Array[SessionExportRow],
) -> Double {
  export_quality_average(right) - export_quality_average(left)
}

///|
pub fn export_rows_summary_delta(
  left : Array[SessionExportRow],
  right : Array[SessionExportRow],
) -> String {
  "count=" +
  export_rows_count_delta(left, right).to_string() +
  ", reps=" +
  export_rows_reps_delta(left, right).to_string() +
  ", sets=" +
  export_rows_sets_delta(left, right).to_string() +
  ", pain=" +
  export_rows_pain_delta(left, right).to_string() +
  ", quality=" +
  export_rows_quality_delta(left, right).to_string()
}

///|
pub fn export_rows_version(values : Array[SessionExportRow]) -> String {
  "rows-v1-" + export_rows_revision_key(values)
}
