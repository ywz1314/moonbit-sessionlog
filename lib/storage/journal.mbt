///|
/// A serializable point-in-time description of the in-memory store.
pub(all) struct StoreSnapshot {
  revision : Int
  count : Int
  checksum : Int
  earliest_date : String
  latest_date : String
  ids : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn StoreSnapshot::revision(self : StoreSnapshot) -> Int {
  self.revision
}

///|
pub fn StoreSnapshot::count(self : StoreSnapshot) -> Int {
  self.count
}

///|
pub fn StoreSnapshot::checksum(self : StoreSnapshot) -> Int {
  self.checksum
}

///|
pub fn StoreSnapshot::earliest_date(self : StoreSnapshot) -> String {
  self.earliest_date
}

///|
pub fn StoreSnapshot::latest_date(self : StoreSnapshot) -> String {
  self.latest_date
}

///|
pub fn StoreSnapshot::ids(self : StoreSnapshot) -> Array[String] {
  self.ids
}

///|
fn stable_session_checksum(session : @core.Session) -> Int {
  let text = session.id +
    "|" +
    session.date +
    "|" +
    session.duration.to_string() +
    "|" +
    session.total_reps().to_string() +
    "|" +
    session.average_completion().to_string()
  text.fold(init=17, (hash, code) => (hash * 31 + code.to_int()) % 2147483647)
}

///|
pub fn checksum(sessions : Array[@core.Session]) -> Int {
  sessions.fold(init=0, (total, session) => {
    (total * 131 + stable_session_checksum(session)) % 2147483647
  })
}

///|
pub fn SessionStore::snapshot(self : SessionStore) -> StoreSnapshot {
  let ordered = self.sorted_by_date()
  StoreSnapshot::{
    revision: self.revision,
    count: self.count(),
    checksum: checksum(ordered),
    earliest_date: ordered.get(0).map(item => item.date).unwrap_or(""),
    latest_date: ordered.last().map(item => item.date).unwrap_or(""),
    ids: ordered.map(item => item.id),
  }
}

///|
pub fn snapshot_equal(left : StoreSnapshot, right : StoreSnapshot) -> Bool {
  left.count == right.count &&
  left.checksum == right.checksum &&
  left.ids == right.ids
}

///|
pub(all) enum StoreMutation {
  Insert(@core.Session)
  Replace(@core.Session)
  Remove(String)
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn StoreMutation::id(self : StoreMutation) -> String {
  match self {
    Insert(session) => session.id
    Replace(session) => session.id
    Remove(id) => id
  }
}

///|
pub fn StoreMutation::label(self : StoreMutation) -> String {
  match self {
    Insert(_) => "insert"
    Replace(_) => "replace"
    Remove(_) => "remove"
  }
}

///|
pub(all) struct StoreTransaction {
  base_revision : Int
  mutations : Array[StoreMutation]
  actor : String
  reason : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn transaction(
  base_revision : Int,
  actor : String,
  reason : String,
) -> StoreTransaction {
  StoreTransaction::{ base_revision, mutations: [], actor, reason }
}

///|
pub fn StoreTransaction::base_revision(self : StoreTransaction) -> Int {
  self.base_revision
}

///|
pub fn StoreTransaction::mutations(
  self : StoreTransaction,
) -> Array[StoreMutation] {
  self.mutations
}

///|
pub fn StoreTransaction::actor(self : StoreTransaction) -> String {
  self.actor
}

///|
pub fn StoreTransaction::reason(self : StoreTransaction) -> String {
  self.reason
}

///|
pub fn StoreTransaction::insert(
  self : StoreTransaction,
  session : @core.Session,
) -> StoreTransaction {
  let result = self
  result.mutations.push(StoreMutation::Insert(session))
  result
}

///|
pub fn StoreTransaction::replace(
  self : StoreTransaction,
  session : @core.Session,
) -> StoreTransaction {
  let result = self
  result.mutations.push(StoreMutation::Replace(session))
  result
}

///|
pub fn StoreTransaction::remove(
  self : StoreTransaction,
  id : String,
) -> StoreTransaction {
  let result = self
  result.mutations.push(StoreMutation::Remove(id))
  result
}

///|
pub fn StoreTransaction::is_empty(self : StoreTransaction) -> Bool {
  self.mutations.is_empty()
}

///|
pub fn StoreTransaction::count(self : StoreTransaction) -> Int {
  self.mutations.length()
}

///|
pub(all) enum CommitError {
  RevisionConflict(Int, Int)
  MutationFailed(String)
  EmptyTransaction
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CommitError::message(self : CommitError) -> String {
  match self {
    RevisionConflict(expected, actual) =>
      "revision conflict: expected " +
      expected.to_string() +
      ", actual " +
      actual.to_string()
    MutationFailed(message) => message
    EmptyTransaction => "transaction has no mutations"
  }
}

///|
pub fn SessionStore::commit(
  self : SessionStore,
  tx : StoreTransaction,
) -> Result[Int, CommitError] {
  if tx.is_empty() {
    Err(CommitError::EmptyTransaction)
  } else if tx.base_revision != self.revision {
    Err(CommitError::RevisionConflict(tx.base_revision, self.revision))
  } else {
    let mut applied = 0
    for mutation in tx.mutations {
      match mutation {
        StoreMutation::Insert(session) =>
          match self.insert(session) {
            Ok(_) => applied += 1
            Err(error) => return Err(CommitError::MutationFailed(error))
          }
        StoreMutation::Replace(session) =>
          match self.replace(session) {
            Ok(_) => applied += 1
            Err(error) => return Err(CommitError::MutationFailed(error))
          }
        StoreMutation::Remove(id) => if self.remove(id) { applied += 1 }
      }
    }
    Ok(applied)
  }
}

///|
pub fn diff(
  left : Array[@core.Session],
  right : Array[@core.Session],
) -> Array[StoreMutation] {
  let mutations = []
  for session in right {
    match left.search_by(item => item.id == session.id) {
      None => mutations.push(StoreMutation::Insert(session))
      Some(index) =>
        if stable_session_checksum(left[index]) !=
          stable_session_checksum(session) {
          mutations.push(StoreMutation::Replace(session))
        }
    }
  }
  for session in left {
    if right.all(item => item.id != session.id) {
      mutations.push(StoreMutation::Remove(session.id))
    }
  }
  mutations
}

///|
pub fn transaction_from_diff(
  base : SessionStore,
  target : Array[@core.Session],
  actor : String,
  reason : String,
) -> StoreTransaction {
  let tx = transaction(base.revision(), actor, reason)
  let mut result = tx
  for mutation in diff(base.all(), target) {
    match mutation {
      StoreMutation::Insert(value) => result = result.insert(value)
      StoreMutation::Replace(value) => result = result.replace(value)
      StoreMutation::Remove(id) => result = result.remove(id)
    }
  }
  result
}

///|
pub fn SessionStore::partition(
  self : SessionStore,
  size : Int,
) -> Array[Array[@core.Session]] {
  if size <= 0 {
    []
  } else {
    let ordered = self.sorted_by_date()
    let result = []
    let mut index = 0
    while index < ordered.length() {
      let end = Int::min(ordered.length(), index + size)
      result.push(ordered[index:end].to_owned())
      index += size
    }
    result
  }
}

///|
pub fn SessionStore::checksum(self : SessionStore) -> Int {
  checksum(self.sessions)
}

///|
pub fn SessionStore::same_content(
  self : SessionStore,
  other : SessionStore,
) -> Bool {
  self.checksum() == other.checksum() && self.ids().sort() == other.ids().sort()
}

///|
pub fn SessionStore::history_event(
  self : SessionStore,
  event : @history.HistoryEvent,
  actor : String,
) -> String {
  actor + " " + event.label() + " revision=" + self.revision.to_string()
}

///|
pub fn snapshot_text(value : StoreSnapshot) -> String {
  "revision=" +
  value.revision.to_string() +
  ", count=" +
  value.count.to_string() +
  ", checksum=" +
  value.checksum.to_string() +
  ", range=" +
  value.earliest_date +
  ".." +
  value.latest_date
}
