///|
/// Stable sorting fields for API pagination and exported tables.
pub(all) enum SortField {
  Date
  Id
  Pain
  Completion
  Duration
  WorkUnits
  Repetitions
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SortField::label(self : SortField) -> String {
  match self {
    Date => "date"
    Id => "id"
    Pain => "pain"
    Completion => "completion"
    Duration => "duration"
    WorkUnits => "work_units"
    Repetitions => "repetitions"
  }
}

///|
pub(all) struct SortSpec {
  field : SortField
  descending : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn sort_spec(field : SortField, descending : Bool) -> SortSpec {
  SortSpec::{ field, descending }
}

///|
pub fn SortSpec::field(self : SortSpec) -> SortField {
  self.field
}

///|
pub fn SortSpec::descending(self : SortSpec) -> Bool {
  self.descending
}

///|
fn compare_field(
  left : @core.Session,
  right : @core.Session,
  field : SortField,
) -> Int {
  match field {
    SortField::Date => left.date.compare(right.date)
    SortField::Id => left.id.compare(right.id)
    SortField::Pain =>
      left.average_pain_during().compare(right.average_pain_during())
    SortField::Completion =>
      left.average_completion().compare(right.average_completion())
    SortField::Duration => left.duration - right.duration
    SortField::WorkUnits => left.total_work_units() - right.total_work_units()
    SortField::Repetitions => left.total_reps() - right.total_reps()
  }
}

///|
pub fn sort(
  sessions : Array[@core.Session],
  spec : SortSpec,
) -> Array[@core.Session] {
  let result = sessions.copy()
  result.sort_by((left, right) => {
    let value = compare_field(left, right, spec.field)
    if spec.descending {
      0 - value
    } else {
      value
    }
  })
  result
}

///|
pub(all) struct Page {
  items : Array[@core.Session]
  offset : Int
  limit : Int
  total : Int
  has_next : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Page::items(self : Page) -> Array[@core.Session] {
  self.items
}

///|
pub fn Page::offset(self : Page) -> Int {
  self.offset
}

///|
pub fn Page::limit(self : Page) -> Int {
  self.limit
}

///|
pub fn Page::total(self : Page) -> Int {
  self.total
}

///|
pub fn Page::has_next(self : Page) -> Bool {
  self.has_next
}

///|
pub fn Page::next_offset(self : Page) -> Int {
  self.offset + self.items.length()
}

///|
pub fn paginate(
  sessions : Array[@core.Session],
  offset : Int,
  limit : Int,
) -> Page {
  let safe_offset = Int::max(0, offset)
  let safe_limit = Int::max(1, limit)
  let start = Int::min(safe_offset, sessions.length())
  let end = Int::min(sessions.length(), start + safe_limit)
  Page::{
    items: sessions[start:end].to_owned(),
    offset: start,
    limit: safe_limit,
    total: sessions.length(),
    has_next: end < sessions.length(),
  }
}

///|
pub fn paginate_sorted(
  sessions : Array[@core.Session],
  offset : Int,
  limit : Int,
  spec : SortSpec,
) -> Page {
  paginate(sort(sessions, spec), offset, limit)
}

///|
pub(all) struct CursorPage {
  items : Array[@core.Session]
  next_cursor : String
  has_next : Bool
  total : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CursorPage::items(self : CursorPage) -> Array[@core.Session] {
  self.items
}

///|
pub fn CursorPage::next_cursor(self : CursorPage) -> String {
  self.next_cursor
}

///|
pub fn CursorPage::has_next(self : CursorPage) -> Bool {
  self.has_next
}

///|
pub fn CursorPage::total(self : CursorPage) -> Int {
  self.total
}

///|
pub fn cursor_page(
  sessions : Array[@core.Session],
  cursor : String,
  limit : Int,
) -> CursorPage {
  let start = if cursor.is_empty() {
    0
  } else {
    let mut result = 0
    for index, session in sessions {
      if session.id == cursor {
        result = index + 1
      }
    }
    result
  }
  let page = paginate(sessions, start, limit)
  let next = page.items
    .get(page.items.length() - 1)
    .map(item => item.id)
    .unwrap_or("")
  CursorPage::{
    items: page.items,
    next_cursor: next,
    has_next: page.has_next,
    total: page.total,
  }
}

///|
pub(all) struct QueryStats {
  count : Int
  total_reps : Int
  total_work_units : Int
  mean_pain : Double
  median_pain : Double
  mean_completion : Double
  valid_count : Int
  invalid_count : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn QueryStats::count(self : QueryStats) -> Int {
  self.count
}

///|
pub fn QueryStats::total_reps(self : QueryStats) -> Int {
  self.total_reps
}

///|
pub fn QueryStats::total_work_units(self : QueryStats) -> Int {
  self.total_work_units
}

///|
pub fn QueryStats::mean_pain(self : QueryStats) -> Double {
  self.mean_pain
}

///|
pub fn QueryStats::median_pain(self : QueryStats) -> Double {
  self.median_pain
}

///|
pub fn QueryStats::mean_completion(self : QueryStats) -> Double {
  self.mean_completion
}

///|
pub fn QueryStats::valid_count(self : QueryStats) -> Int {
  self.valid_count
}

///|
pub fn QueryStats::invalid_count(self : QueryStats) -> Int {
  self.invalid_count
}

///|
pub fn stats(sessions : Array[@core.Session]) -> QueryStats {
  let pains = sessions.map(session => session.average_pain_during())
  QueryStats::{
    count: sessions.length(),
    total_reps: sessions.fold(init=0, (total, session) => {
      total + session.total_reps()
    }),
    total_work_units: sessions.fold(init=0, (total, session) => {
      total + session.total_work_units()
    }),
    mean_pain: @statistics.mean(pains),
    median_pain: @statistics.median(pains),
    mean_completion: @statistics.mean(
      sessions.map(session => session.average_completion()),
    ),
    valid_count: sessions.count_if(session => @validation.is_valid(session)),
    invalid_count: sessions.count_if(session => !@validation.is_valid(session)),
  }
}

///|
pub fn search_text(
  sessions : Array[@core.Session],
  text : String,
) -> Array[@core.Session] {
  let needle = text.trim()
  if needle.is_empty() {
    sessions
  } else {
    sessions.filter(session => {
      session.id.contains(needle) ||
      session.notes.contains(needle) ||
      session.movement_names().any(name => name.contains(needle))
    })
  }
}

///|
pub fn search_tag(
  sessions : Array[@core.Session],
  tag : String,
) -> Array[@core.Session] {
  sessions.filter(session => {
    session.notes.contains("#" + tag) || session.notes.contains("[" + tag + "]")
  })
}

///|
pub fn deduplicate_by_id(
  sessions : Array[@core.Session],
) -> Array[@core.Session] {
  let seen = []
  let result = []
  for session in sessions {
    if !seen.contains(session.id) {
      seen.push(session.id)
      result.push(session)
    }
  }
  result
}

///|
pub fn latest_by_id(sessions : Array[@core.Session]) -> Array[@core.Session] {
  let result = deduplicate_by_id(
    sort(sessions, sort_spec(SortField::Date, true)),
  )
  result.sort_by((left, right) => left.id.compare(right.id))
  result
}

///|
pub fn top_by(
  sessions : Array[@core.Session],
  limit : Int,
  field : SortField,
) -> Array[@core.Session] {
  paginate(sort(sessions, sort_spec(field, true)), 0, limit).items
}

///|
pub fn bottom_by(
  sessions : Array[@core.Session],
  limit : Int,
  field : SortField,
) -> Array[@core.Session] {
  paginate(sort(sessions, sort_spec(field, false)), 0, limit).items
}

///|
pub fn date_histogram(sessions : Array[@core.Session]) -> Array[(String, Int)] {
  let counts : Map[String, Int] = Map([])
  for session in sessions {
    counts.update_or_default(session.date, 1, value => value + 1)
  }
  let result = counts.to_array()
  result.sort_by((left, right) => left.0.compare(right.0))
  result
}

///|
pub fn movement_histogram(
  sessions : Array[@core.Session],
) -> Array[(String, Int)] {
  let counts : Map[String, Int] = Map([])
  for session in sessions {
    for name in session.movement_names() {
      counts.update_or_default(name, 1, value => value + 1)
    }
  }
  counts.to_array()
}

///|
pub fn pain_histogram(sessions : Array[@core.Session]) -> Array[(Int, Int)] {
  let counts : Map[Int, Int] = Map([])
  for session in sessions {
    let score = session.pain_after
    counts.update_or_default(score, 1, value => value + 1)
  }
  counts.to_array()
}

///|
pub fn stable_cursor(_sessions : Array[@core.Session], page : Page) -> String {
  page.items.get(page.items.length() - 1).map(item => item.id).unwrap_or("")
}

///|
pub fn query_text(
  query : SessionQuery,
  sessions : Array[@core.Session],
) -> String {
  let selected = filter(sessions, query)
  describe(query) + ": " + selected.length().to_string() + " matches"
}
