///|
/// Replay turns an append-only history log into deterministic audit frames.
/// The original session payload remains owned by the storage layer.
pub(all) enum ReplayAction {
  Add
  Update
  Remove
  Import
  Export
  Plan
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ReplayAction::label(self : ReplayAction) -> String {
  match self {
    Add => "add"
    Update => "update"
    Remove => "remove"
    Import => "import"
    Export => "export"
    Plan => "plan"
  }
}

///|
fn action_of(event : HistoryEvent) -> ReplayAction {
  match event {
    HistoryEvent::SessionAdded => ReplayAction::Add
    HistoryEvent::SessionUpdated => ReplayAction::Update
    HistoryEvent::SessionRemoved => ReplayAction::Remove
    HistoryEvent::Imported => ReplayAction::Import
    HistoryEvent::Exported => ReplayAction::Export
    HistoryEvent::PlanApplied => ReplayAction::Plan
  }
}

///|
pub(all) struct ReplayFrame {
  revision : Int
  session_id : String
  date : String
  action : ReplayAction
  summary : String
  active_ids : Array[String]
  active_count : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ReplayFrame::revision(self : ReplayFrame) -> Int {
  self.revision
}

///|
pub fn ReplayFrame::session_id(self : ReplayFrame) -> String {
  self.session_id
}

///|
pub fn ReplayFrame::date(self : ReplayFrame) -> String {
  self.date
}

///|
pub fn ReplayFrame::action(self : ReplayFrame) -> ReplayAction {
  self.action
}

///|
pub fn ReplayFrame::summary(self : ReplayFrame) -> String {
  self.summary
}

///|
pub fn ReplayFrame::active_ids(self : ReplayFrame) -> Array[String] {
  self.active_ids.copy()
}

///|
pub fn ReplayFrame::active_count(self : ReplayFrame) -> Int {
  self.active_count
}

///|
pub(all) struct ReplayOptions {
  include_exports : Bool
  include_plans : Bool
  start_revision : Int
  end_revision : Int
  include_empty : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_replay_options() -> ReplayOptions {
  ReplayOptions::{
    include_exports: true,
    include_plans: true,
    start_revision: 0,
    end_revision: 0,
    include_empty: false,
  }
}

///|
pub fn replay_options(
  start_revision? : Int = 0,
  end_revision? : Int = 0,
  include_exports? : Bool = true,
  include_plans? : Bool = true,
  include_empty? : Bool = false,
) -> ReplayOptions {
  ReplayOptions::{
    include_exports,
    include_plans,
    start_revision: Int::max(0, start_revision),
    end_revision: Int::max(0, end_revision),
    include_empty,
  }
}

///|
pub fn ReplayOptions::validate(self : ReplayOptions) -> Array[String] {
  let errors = []
  if self.end_revision > 0 && self.end_revision < self.start_revision {
    errors.push("end_revision must not be before start_revision")
  }
  errors
}

///|
fn accepted_event(event : HistoryEvent, options : ReplayOptions) -> Bool {
  match event {
    HistoryEvent::Exported => options.include_exports
    HistoryEvent::PlanApplied => options.include_plans
    _ => true
  }
}

///|
fn apply_action(
  active : Array[String],
  id : String,
  action : ReplayAction,
) -> Unit {
  match action {
    ReplayAction::Add | ReplayAction::Import =>
      if !active.contains(id) {
        active.push(id)
      }
    ReplayAction::Update | ReplayAction::Plan | ReplayAction::Export =>
      if !active.contains(id) && id != "" {
        active.push(id)
      }
    ReplayAction::Remove =>
      match active.search_by(value => value == id) {
        Some(index) => ignore(active.remove(index))
        None => ()
      }
  }
}

///|
pub fn replay(
  log : HistoryLog,
  options : ReplayOptions,
) -> Result[Array[ReplayFrame], String] {
  let errors = options.validate()
  if !errors.is_empty() {
    return Err(errors.join("; "))
  }
  let active = []
  let frames = []
  for entry in log.entries() {
    if entry.revision() < options.start_revision {
      continue
    }
    if options.end_revision > 0 && entry.revision() > options.end_revision {
      continue
    }
    if !accepted_event(entry.event(), options) {
      continue
    }
    let action = action_of(entry.event())
    apply_action(active, entry.session_id(), action)
    if options.include_empty ||
      !active.is_empty() ||
      action == ReplayAction::Remove {
      frames.push(ReplayFrame::{
        revision: entry.revision(),
        session_id: entry.session_id(),
        date: entry.date(),
        action,
        summary: entry.summary(),
        active_ids: active.copy(),
        active_count: active.length(),
      })
    }
  }
  Ok(frames)
}

///|
pub fn replay_latest(log : HistoryLog, options : ReplayOptions) -> ReplayFrame? {
  match replay(log, options) {
    Ok(frames) => frames.last()
    Err(_) => None
  }
}

///|
pub fn active_at(
  log : HistoryLog,
  revision : Int,
) -> Result[Array[String], String] {
  match replay(log, replay_options(end_revision=revision)) {
    Ok(frames) =>
      match frames.last() {
        Some(frame) => Ok(frame.active_ids())
        None => Ok([])
      }
    Err(error) => Err(error)
  }
}

///|
pub(all) struct ReplaySummary {
  revisions : Int
  frames : Int
  first_revision : Int
  last_revision : Int
  peak_active : Int
  final_active : Int
  additions : Int
  updates : Int
  removals : Int
  imports : Int
  exports : Int
  plans : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ReplaySummary::revisions(self : ReplaySummary) -> Int {
  self.revisions
}

///|
pub fn ReplaySummary::frames(self : ReplaySummary) -> Int {
  self.frames
}

///|
pub fn ReplaySummary::first_revision(self : ReplaySummary) -> Int {
  self.first_revision
}

///|
pub fn ReplaySummary::last_revision(self : ReplaySummary) -> Int {
  self.last_revision
}

///|
pub fn ReplaySummary::peak_active(self : ReplaySummary) -> Int {
  self.peak_active
}

///|
pub fn ReplaySummary::final_active(self : ReplaySummary) -> Int {
  self.final_active
}

///|
pub fn ReplaySummary::additions(self : ReplaySummary) -> Int {
  self.additions
}

///|
pub fn ReplaySummary::updates(self : ReplaySummary) -> Int {
  self.updates
}

///|
pub fn ReplaySummary::removals(self : ReplaySummary) -> Int {
  self.removals
}

///|
pub fn ReplaySummary::imports(self : ReplaySummary) -> Int {
  self.imports
}

///|
pub fn ReplaySummary::exports(self : ReplaySummary) -> Int {
  self.exports
}

///|
pub fn ReplaySummary::plans(self : ReplaySummary) -> Int {
  self.plans
}

///|
pub fn summarize_replay(frames : Array[ReplayFrame]) -> ReplaySummary {
  let mut additions = 0
  let mut updates = 0
  let mut removals = 0
  let mut imports = 0
  let mut exports = 0
  let mut plans = 0
  let mut peak_active = 0
  for frame in frames {
    peak_active = Int::max(peak_active, frame.active_count)
    match frame.action {
      ReplayAction::Add => additions += 1
      ReplayAction::Update => updates += 1
      ReplayAction::Remove => removals += 1
      ReplayAction::Import => imports += 1
      ReplayAction::Export => exports += 1
      ReplayAction::Plan => plans += 1
    }
  }
  ReplaySummary::{
    revisions: frames.length(),
    frames: frames.length(),
    first_revision: if frames.is_empty() {
      0
    } else {
      frames[0].revision
    },
    last_revision: match frames.last() {
      Some(value) => value.revision
      None => 0
    },
    peak_active,
    final_active: match frames.last() {
      Some(value) => value.active_count
      None => 0
    },
    additions,
    updates,
    removals,
    imports,
    exports,
    plans,
  }
}

///|
pub fn replay_summary(
  log : HistoryLog,
  options : ReplayOptions,
) -> Result[ReplaySummary, String] {
  match replay(log, options) {
    Ok(frames) => Ok(summarize_replay(frames))
    Err(error) => Err(error)
  }
}

///|
pub fn replay_session(
  log : HistoryLog,
  session_id : String,
  options : ReplayOptions,
) -> Result[Array[ReplayFrame], String] {
  match replay(log, options) {
    Ok(frames) => Ok(frames.filter(frame => frame.session_id == session_id))
    Err(error) => Err(error)
  }
}

///|
pub fn replay_revisions(
  log : HistoryLog,
  revisions : Array[Int],
) -> Result[Array[ReplayFrame], String] {
  let wanted = revisions.copy()
  wanted.sort()
  match replay(log, default_replay_options()) {
    Ok(frames) => Ok(frames.filter(frame => wanted.contains(frame.revision)))
    Err(error) => Err(error)
  }
}

///|
pub fn replay_diff(
  left : Array[ReplayFrame],
  right : Array[ReplayFrame],
) -> Array[String] {
  let differences = []
  let left_summary = summarize_replay(left)
  let right_summary = summarize_replay(right)
  if left_summary.final_active != right_summary.final_active {
    differences.push(
      "final_active:" +
      left_summary.final_active.to_string() +
      "->" +
      right_summary.final_active.to_string(),
    )
  }
  if left_summary.peak_active != right_summary.peak_active {
    differences.push(
      "peak_active:" +
      left_summary.peak_active.to_string() +
      "->" +
      right_summary.peak_active.to_string(),
    )
  }
  let max_length = Int::max(left.length(), right.length())
  for index in 0..<max_length {
    let left_value = if index < left.length() {
      left[index].summary
    } else {
      ""
    }
    let right_value = if index < right.length() {
      right[index].summary
    } else {
      ""
    }
    if left_value != right_value {
      differences.push(
        "frame[" + index.to_string() + "]:" + left_value + "->" + right_value,
      )
    }
  }
  differences
}

///|
pub fn replay_text(frames : Array[ReplayFrame]) -> String {
  let output = StringBuilder()
  for frame in frames {
    output.write_string(
      "#" +
      frame.revision.to_string() +
      " " +
      frame.action.label() +
      " " +
      frame.session_id +
      " active=" +
      frame.active_count.to_string() +
      " " +
      frame.summary +
      "\n",
    )
  }
  output.to_string()
}

///|
pub fn replay_summary_text(summary : ReplaySummary) -> String {
  "revisions=" +
  summary.revisions.to_string() +
  ", active=" +
  summary.final_active.to_string() +
  ", peak=" +
  summary.peak_active.to_string() +
  ", add=" +
  summary.additions.to_string() +
  ", update=" +
  summary.updates.to_string() +
  ", remove=" +
  summary.removals.to_string()
}

///|
pub fn replay_is_monotonic(frames : Array[ReplayFrame]) -> Bool {
  let mut previous = 0
  for frame in frames {
    if frame.revision <= previous {
      return false
    }
    previous = frame.revision
  }
  true
}

///|
pub fn replay_active_contains(
  frames : Array[ReplayFrame],
  revision : Int,
  session_id : String,
) -> Bool {
  match frames.search_by(frame => frame.revision == revision) {
    Some(index) => frames[index].active_ids.contains(session_id)
    None => false
  }
}

///|
pub fn replay_event_counts(frames : Array[ReplayFrame]) -> Array[(String, Int)] {
  let counts : Array[(String, Int)] = []
  for frame in frames {
    let label = frame.action.label()
    match counts.search_by(item => item.0 == label) {
      Some(index) => {
        let previous = counts[index]
        counts[index] = (previous.0, previous.1 + 1)
      }
      None => counts.push((label, 1))
    }
  }
  counts
}

///|
pub fn replay_sessions(frames : Array[ReplayFrame]) -> Array[String] {
  let ids = []
  for frame in frames {
    if !ids.contains(frame.session_id) {
      ids.push(frame.session_id)
    }
  }
  ids
}

///|
pub fn replay_changes_for(
  frames : Array[ReplayFrame],
  session_id : String,
) -> Int {
  frames.count_if(frame => frame.session_id == session_id)
}

///|
pub fn replay_has_removal(
  frames : Array[ReplayFrame],
  session_id : String,
) -> Bool {
  frames.any(frame => {
    frame.session_id == session_id && frame.action == ReplayAction::Remove
  })
}

///|
pub fn replay_last_change(
  frames : Array[ReplayFrame],
  session_id : String,
) -> ReplayFrame? {
  let matches = frames.filter(frame => frame.session_id == session_id)
  matches.last()
}

///|
pub(all) struct Checkpoint {
  revision : Int
  active_ids : Array[String]
  checksum : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Checkpoint::revision(self : Checkpoint) -> Int {
  self.revision
}

///|
pub fn Checkpoint::active_ids(self : Checkpoint) -> Array[String] {
  self.active_ids.copy()
}

///|
pub fn Checkpoint::checksum(self : Checkpoint) -> Int {
  self.checksum
}

///|
fn active_checksum(ids : Array[String]) -> Int {
  ids.fold(init=17, (value, id) => value * 31 + id.length())
}

///|
pub fn checkpoint(frames : Array[ReplayFrame]) -> Checkpoint {
  match frames.last() {
    Some(frame) =>
      Checkpoint::{
        revision: frame.revision,
        active_ids: frame.active_ids,
        checksum: active_checksum(frame.active_ids),
      }
    None =>
      Checkpoint::{ revision: 0, active_ids: [], checksum: active_checksum([]) }
  }
}

///|
pub fn checkpoint_valid(value : Checkpoint) -> Bool {
  value.checksum == active_checksum(value.active_ids)
}

///|
pub fn checkpoint_diff(left : Checkpoint, right : Checkpoint) -> Array[String] {
  let changes = []
  for id in left.active_ids {
    if !right.active_ids.contains(id) {
      changes.push("removed:" + id)
    }
  }
  for id in right.active_ids {
    if !left.active_ids.contains(id) {
      changes.push("added:" + id)
    }
  }
  changes
}
