///|
/// A small deterministic in-memory store for applications and tests.
pub(all) struct SessionStore {
  mut sessions : Array[@core.Session]
  mut revision : Int
  capacity : Int
} derive(Debug, Eq)

///|
pub(all) struct StoreStats {
  revision : Int
  count : Int
  total_reps : Int
  total_sets : Int
  valid_count : Int
  invalid_count : Int
  earliest_date : String
  latest_date : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SessionStore::new(capacity? : Int = 1024) -> SessionStore {
  SessionStore::{ sessions: [], revision: 0, capacity: Int::max(1, capacity) }
}

///|
pub fn SessionStore::revision(self : SessionStore) -> Int {
  self.revision
}

///|
pub fn SessionStore::capacity(self : SessionStore) -> Int {
  self.capacity
}

///|
pub fn SessionStore::count(self : SessionStore) -> Int {
  self.sessions.length()
}

///|
pub fn SessionStore::is_empty(self : SessionStore) -> Bool {
  self.sessions.is_empty()
}

///|
pub fn SessionStore::all(self : SessionStore) -> Array[@core.Session] {
  self.sessions.copy()
}

///|
fn SessionStore::index_of(self : SessionStore, id : String) -> Int? {
  self.sessions.search_by(session => session.id == id)
}

///|
pub fn SessionStore::contains(self : SessionStore, id : String) -> Bool {
  self.index_of(id) is Some(_)
}

///|
pub fn SessionStore::get(self : SessionStore, id : String) -> @core.Session? {
  match self.index_of(id) {
    Some(index) => Some(self.sessions[index])
    None => None
  }
}

///|
pub fn SessionStore::insert(
  self : SessionStore,
  session : @core.Session,
) -> Result[Unit, String] {
  if self.contains(session.id) {
    Err("session id already exists: " + session.id)
  } else if self.count() >= self.capacity {
    Err("session store capacity exceeded")
  } else {
    self.sessions.push(session)
    self.revision += 1
    Ok(())
  }
}

///|
pub fn SessionStore::replace(
  self : SessionStore,
  session : @core.Session,
) -> Result[Unit, String] {
  match self.index_of(session.id) {
    Some(index) => {
      self.sessions[index] = session
      self.revision += 1
      Ok(())
    }
    None => Err("session id not found: " + session.id)
  }
}

///|
pub fn SessionStore::upsert(
  self : SessionStore,
  session : @core.Session,
) -> Result[Unit, String] {
  if self.contains(session.id) {
    self.replace(session)
  } else {
    self.insert(session)
  }
}

///|
pub fn SessionStore::remove(self : SessionStore, id : String) -> Bool {
  match self.index_of(id) {
    Some(index) => {
      ignore(self.sessions.remove(index))
      self.revision += 1
      true
    }
    None => false
  }
}

///|
pub fn SessionStore::clear(self : SessionStore) -> Unit {
  if !self.sessions.is_empty() {
    self.sessions.clear()
    self.revision += 1
  }
}

///|
pub fn SessionStore::by_date(
  self : SessionStore,
  date : String,
) -> Array[@core.Session] {
  self.sessions.filter(session => session.date == date)
}

///|
pub fn SessionStore::between_dates(
  self : SessionStore,
  start_date : String,
  end_date : String,
) -> Array[@core.Session] {
  self.sessions.filter(session => {
    session.date >= start_date && session.date <= end_date
  })
}

///|
pub fn SessionStore::with_movement(
  self : SessionStore,
  name : String,
) -> Array[@core.Session] {
  self.sessions.filter(session => session.movement(name) is Some(_))
}

///|
pub fn SessionStore::with_pain_at_least(
  self : SessionStore,
  threshold : Int,
) -> Array[@core.Session] {
  self.sessions.filter(session => {
    session.average_pain_during() >= threshold.to_double()
  })
}

///|
pub fn SessionStore::with_completion_below(
  self : SessionStore,
  threshold : Double,
) -> Array[@core.Session] {
  self.sessions.filter(session => session.average_completion() < threshold)
}

///|
pub fn SessionStore::valid(self : SessionStore) -> Array[@core.Session] {
  self.sessions.filter(session => {
    @validation.validate_session(session).is_empty()
  })
}

///|
pub fn SessionStore::invalid(self : SessionStore) -> Array[@core.Session] {
  self.sessions.filter(session => {
    !@validation.validate_session(session).is_empty()
  })
}

///|
pub fn SessionStore::sorted_by_date(
  self : SessionStore,
) -> Array[@core.Session] {
  let result = self.all()
  result.sort_by((left, right) => {
    let date_order = left.date.compare(right.date)
    if date_order == 0 {
      left.id.compare(right.id)
    } else {
      date_order
    }
  })
  result
}

///|
pub fn SessionStore::latest(self : SessionStore) -> @core.Session? {
  self.sorted_by_date().last()
}

///|
pub fn SessionStore::earliest(self : SessionStore) -> @core.Session? {
  self.sorted_by_date().get(0)
}

///|
pub fn SessionStore::page(
  self : SessionStore,
  offset : Int,
  limit : Int,
) -> Array[@core.Session] {
  if offset < 0 || limit <= 0 || offset >= self.count() {
    []
  } else {
    let end = Int::min(self.count(), offset + limit)
    self.sessions[offset:end].to_owned()
  }
}

///|
pub fn SessionStore::duplicate_ids(self : SessionStore) -> Array[String] {
  let ids = []
  let duplicates = []
  for session in self.sessions {
    if ids.contains(session.id) {
      if !duplicates.contains(session.id) {
        duplicates.push(session.id)
      }
    } else {
      ids.push(session.id)
    }
  }
  duplicates
}

///|
pub fn SessionStore::stats(self : SessionStore) -> StoreStats {
  let ordered = self.sorted_by_date()
  let total_reps = ordered.fold(init=0, (total, session) => {
    total + session.total_reps()
  })
  let total_sets = ordered.fold(init=0, (total, session) => {
    total + session.total_sets()
  })
  let earliest = match ordered.get(0) {
    Some(session) => session.date
    None => ""
  }
  let latest = match ordered.last() {
    Some(session) => session.date
    None => ""
  }
  StoreStats::{
    revision: self.revision,
    count: self.count(),
    total_reps,
    total_sets,
    valid_count: self.valid().length(),
    invalid_count: self.invalid().length(),
    earliest_date: earliest,
    latest_date: latest,
  }
}

///|
pub fn SessionStore::export_json(self : SessionStore) -> String {
  @json.to_json(self.sessions).stringify()
}

///|
pub fn SessionStore::import_json(
  self : SessionStore,
  json_text : String,
) -> Result[Int, String] {
  try {
    let json = @json.parse(json_text)
    let sessions : Array[@core.Session] = @json.from_json(json)
    let mut imported = 0
    for session in sessions {
      match self.upsert(session) {
        Ok(_) => imported += 1
        Err(error) => return Err(error)
      }
    }
    Ok(imported)
  } catch {
    error => Err("invalid session JSON: " + error.to_string())
  }
}

///|
pub fn SessionStore::import_versioned_json(
  self : SessionStore,
  records : Array[String],
) -> Result[Int, String] {
  let mut imported = 0
  for record in records {
    let session = match @schema.parse_and_migrate_session(record) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    match self.upsert(session) {
      Ok(_) => imported += 1
      Err(error) => return Err(error)
    }
  }
  Ok(imported)
}

///|
pub fn SessionStore::merge(
  self : SessionStore,
  other : SessionStore,
) -> Result[Int, String] {
  let mut merged = 0
  for session in other.sessions {
    match self.upsert(session) {
      Ok(_) => merged += 1
      Err(error) => return Err(error)
    }
  }
  Ok(merged)
}

///|
pub fn SessionStore::ids(self : SessionStore) -> Array[String] {
  self.sessions.map(session => session.id)
}

///|
pub fn SessionStore::movement_names(self : SessionStore) -> Array[String] {
  let names = []
  for session in self.sessions {
    for name in session.movement_names() {
      if !names.contains(name) {
        names.push(name)
      }
    }
  }
  names
}

///|
pub fn SessionStore::total_duration(self : SessionStore) -> Int {
  self.sessions.fold(init=0, (total, session) => total + session.duration)
}

///|
pub fn SessionStore::average_duration(self : SessionStore) -> Double {
  if self.is_empty() {
    0.0
  } else {
    self.total_duration().to_double() / self.count().to_double()
  }
}

///|
pub fn SessionStore::pain_improved_count(self : SessionStore) -> Int {
  self.sessions.count_if(session => session.pain_delta() < 0)
}

///|
pub fn SessionStore::completion_target_count(
  self : SessionStore,
  target : Double,
) -> Int {
  self.sessions.count_if(session => session.average_completion() >= target)
}

///|
pub fn SessionStore::take_latest(
  self : SessionStore,
  count : Int,
) -> Array[@core.Session] {
  let ordered = self.sorted_by_date()
  if count <= 0 {
    []
  } else if count >= ordered.length() {
    ordered
  } else {
    ordered[ordered.length() - count:].to_owned()
  }
}

///|
pub fn StoreStats::summary(self : StoreStats) -> String {
  "sessions=" +
  self.count.to_string() +
  ", reps=" +
  self.total_reps.to_string() +
  ", sets=" +
  self.total_sets.to_string() +
  ", valid=" +
  self.valid_count.to_string() +
  ", invalid=" +
  self.invalid_count.to_string()
}
