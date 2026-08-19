///|
pub(all) enum HistoryEvent {
  SessionAdded
  SessionUpdated
  SessionRemoved
  Imported
  Exported
  PlanApplied
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn HistoryEvent::label(self : HistoryEvent) -> String {
  match self {
    SessionAdded => "session_added"
    SessionUpdated => "session_updated"
    SessionRemoved => "session_removed"
    Imported => "imported"
    Exported => "exported"
    PlanApplied => "plan_applied"
  }
}

///|
pub(all) struct HistoryEntry {
  revision : Int
  session_id : String
  date : String
  event : HistoryEvent
  summary : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn HistoryEntry::revision(self : HistoryEntry) -> Int {
  self.revision
}

///|
pub fn HistoryEntry::session_id(self : HistoryEntry) -> String {
  self.session_id
}

///|
pub fn HistoryEntry::date(self : HistoryEntry) -> String {
  self.date
}

///|
pub fn HistoryEntry::event(self : HistoryEntry) -> HistoryEvent {
  self.event
}

///|
pub fn HistoryEntry::summary(self : HistoryEntry) -> String {
  self.summary
}

///|
pub(all) struct HistoryLog {
  mut entries : Array[HistoryEntry]
  mut next_revision : Int
} derive(Debug, Eq)

///|
pub fn new_history() -> HistoryLog {
  HistoryLog::{ entries: [], next_revision: 1 }
}

///|
pub fn HistoryLog::count(self : HistoryLog) -> Int {
  self.entries.length()
}

///|
pub fn HistoryLog::entries(self : HistoryLog) -> Array[HistoryEntry] {
  self.entries.copy()
}

///|
pub fn HistoryLog::append(
  self : HistoryLog,
  session_id : String,
  date : String,
  event : HistoryEvent,
  summary : String,
) -> HistoryEntry {
  let entry = HistoryEntry::{
    revision: self.next_revision,
    session_id,
    date,
    event,
    summary,
  }
  self.entries.push(entry)
  self.next_revision += 1
  entry
}

///|
pub fn HistoryLog::record_added(
  self : HistoryLog,
  session : @core.Session,
) -> HistoryEntry {
  self.append(
    session.id,
    session.date,
    HistoryEvent::SessionAdded,
    "session stored",
  )
}

///|
pub fn HistoryLog::record_updated(
  self : HistoryLog,
  session : @core.Session,
) -> HistoryEntry {
  self.append(
    session.id,
    session.date,
    HistoryEvent::SessionUpdated,
    "session replaced",
  )
}

///|
pub fn HistoryLog::record_removed(
  self : HistoryLog,
  session_id : String,
  date : String,
) -> HistoryEntry {
  self.append(session_id, date, HistoryEvent::SessionRemoved, "session removed")
}

///|
pub fn HistoryLog::record_imported(
  self : HistoryLog,
  session : @core.Session,
) -> HistoryEntry {
  self.append(
    session.id,
    session.date,
    HistoryEvent::Imported,
    "session imported",
  )
}

///|
pub fn HistoryLog::record_exported(
  self : HistoryLog,
  session_id : String,
  date : String,
) -> HistoryEntry {
  self.append(session_id, date, HistoryEvent::Exported, "session exported")
}

///|
pub fn HistoryLog::for_session(
  self : HistoryLog,
  session_id : String,
) -> Array[HistoryEntry] {
  self.entries.filter(entry => entry.session_id == session_id)
}

///|
pub fn HistoryLog::since(
  self : HistoryLog,
  revision : Int,
) -> Array[HistoryEntry] {
  self.entries.filter(entry => entry.revision >= revision)
}

///|
pub fn HistoryLog::by_event(
  self : HistoryLog,
  event : HistoryEvent,
) -> Array[HistoryEntry] {
  self.entries.filter(entry => entry.event == event)
}

///|
pub fn HistoryLog::latest(self : HistoryLog) -> HistoryEntry? {
  self.entries.last()
}

///|
pub fn HistoryLog::session_ids(self : HistoryLog) -> Array[String] {
  let ids = []
  for entry in self.entries {
    if !ids.contains(entry.session_id) {
      ids.push(entry.session_id)
    }
  }
  ids
}

///|
pub fn HistoryLog::event_counts(
  self : HistoryLog,
) -> (Int, Int, Int, Int, Int, Int) {
  let mut added = 0
  let mut updated = 0
  let mut removed = 0
  let mut imported = 0
  let mut exported = 0
  let mut planned = 0
  for entry in self.entries {
    match entry.event {
      HistoryEvent::SessionAdded => added += 1
      HistoryEvent::SessionUpdated => updated += 1
      HistoryEvent::SessionRemoved => removed += 1
      HistoryEvent::Imported => imported += 1
      HistoryEvent::Exported => exported += 1
      HistoryEvent::PlanApplied => planned += 1
    }
  }
  (added, updated, removed, imported, exported, planned)
}

///|
pub fn HistoryLog::to_json_string(self : HistoryLog) -> String {
  @json.to_json(self.entries).stringify()
}

///|
pub fn HistoryLog::to_text(self : HistoryLog) -> String {
  let output = StringBuilder()
  for entry in self.entries {
    output.write_string(
      "#" +
      entry.revision.to_string() +
      " " +
      entry.date +
      " " +
      entry.event.label() +
      " " +
      entry.session_id +
      " - " +
      entry.summary +
      "\n",
    )
  }
  output.to_string()
}

///|
pub fn HistoryLog::clear(self : HistoryLog) -> Unit {
  self.entries.clear()
  self.next_revision = 1
}

///|
pub fn HistoryLog::merge(self : HistoryLog, other : HistoryLog) -> Unit {
  for entry in other.entries {
    ignore(
      self.append(entry.session_id, entry.date, entry.event, entry.summary),
    )
  }
}
