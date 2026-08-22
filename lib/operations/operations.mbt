///|
/// Status of an operational review item, separate from clinical risk level.
pub(all) enum WorkStatus {
  Queued
  InProgress
  Waiting
  Done
  Cancelled
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn WorkStatus::label(self : WorkStatus) -> String {
  match self {
    Queued => "queued"
    InProgress => "in_progress"
    Waiting => "waiting"
    Done => "done"
    Cancelled => "cancelled"
  }
}

///|
pub fn WorkStatus::terminal(self : WorkStatus) -> Bool {
  self == WorkStatus::Done || self == WorkStatus::Cancelled
}

///|
pub(all) enum WorkPriority {
  Routine
  Soon
  Urgent
  Immediate
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn WorkPriority::label(self : WorkPriority) -> String {
  match self {
    Routine => "routine"
    Soon => "soon"
    Urgent => "urgent"
    Immediate => "immediate"
  }
}

///|
pub fn WorkPriority::rank(self : WorkPriority) -> Int {
  match self {
    Routine => 0
    Soon => 1
    Urgent => 2
    Immediate => 3
  }
}

///|
pub(all) enum WorkKind {
  ValidateRecord
  ReviewRisk
  ContactParticipant
  UpdatePlan
  VerifyOutcome
  ResolveDuplicate
  ExportReport
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn WorkKind::label(self : WorkKind) -> String {
  match self {
    ValidateRecord => "validate_record"
    ReviewRisk => "review_risk"
    ContactParticipant => "contact_participant"
    UpdatePlan => "update_plan"
    VerifyOutcome => "verify_outcome"
    ResolveDuplicate => "resolve_duplicate"
    ExportReport => "export_report"
  }
}

///|
pub(all) struct WorkItem {
  id : String
  session_id : String
  kind : WorkKind
  priority : WorkPriority
  status : WorkStatus
  title : String
  detail : String
  created_at : String
  due_at : String
  owner : String
  tags : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn WorkItem::id(self : WorkItem) -> String {
  self.id
}

///|
pub fn WorkItem::session_id(self : WorkItem) -> String {
  self.session_id
}

///|
pub fn WorkItem::kind(self : WorkItem) -> WorkKind {
  self.kind
}

///|
pub fn WorkItem::priority(self : WorkItem) -> WorkPriority {
  self.priority
}

///|
pub fn WorkItem::status(self : WorkItem) -> WorkStatus {
  self.status
}

///|
pub fn WorkItem::title(self : WorkItem) -> String {
  self.title
}

///|
pub fn WorkItem::detail(self : WorkItem) -> String {
  self.detail
}

///|
pub fn WorkItem::created_at(self : WorkItem) -> String {
  self.created_at
}

///|
pub fn WorkItem::due_at(self : WorkItem) -> String {
  self.due_at
}

///|
pub fn WorkItem::owner(self : WorkItem) -> String {
  self.owner
}

///|
pub fn WorkItem::tags(self : WorkItem) -> Array[String] {
  self.tags
}

///|
pub fn WorkItem::overdue(self : WorkItem, now : String) -> Bool {
  !self.status.terminal() && !self.due_at.is_empty() && self.due_at < now
}

///|
pub fn WorkItem::with_status(self : WorkItem, status : WorkStatus) -> WorkItem {
  WorkItem::{
    id: self.id,
    session_id: self.session_id,
    kind: self.kind,
    priority: self.priority,
    status,
    title: self.title,
    detail: self.detail,
    created_at: self.created_at,
    due_at: self.due_at,
    owner: self.owner,
    tags: self.tags,
  }
}

///|
pub fn WorkItem::assign(self : WorkItem, owner : String) -> WorkItem {
  WorkItem::{
    id: self.id,
    session_id: self.session_id,
    kind: self.kind,
    priority: self.priority,
    status: self.status,
    title: self.title,
    detail: self.detail,
    created_at: self.created_at,
    due_at: self.due_at,
    owner,
    tags: self.tags,
  }
}

///|
pub fn work_item(
  id : String,
  session_id : String,
  kind : WorkKind,
  priority : WorkPriority,
  title : String,
  detail : String,
  created_at : String,
  due_at : String,
) -> WorkItem {
  WorkItem::{
    id,
    session_id,
    kind,
    priority,
    status: WorkStatus::Queued,
    title,
    detail,
    created_at,
    due_at,
    owner: "",
    tags: [],
  }
}

///|
pub fn with_tags(item : WorkItem, tags : Array[String]) -> WorkItem {
  WorkItem::{
    id: item.id,
    session_id: item.session_id,
    kind: item.kind,
    priority: item.priority,
    status: item.status,
    title: item.title,
    detail: item.detail,
    created_at: item.created_at,
    due_at: item.due_at,
    owner: item.owner,
    tags,
  }
}

///|
pub(all) struct WorkQueue {
  items : Array[WorkItem]
  mut revision : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn new_queue() -> WorkQueue {
  WorkQueue::{ items: [], revision: 0 }
}

///|
pub fn WorkQueue::items(self : WorkQueue) -> Array[WorkItem] {
  self.items
}

///|
pub fn WorkQueue::revision(self : WorkQueue) -> Int {
  self.revision
}

///|
pub fn WorkQueue::count(self : WorkQueue) -> Int {
  self.items.length()
}

///|
pub fn WorkQueue::add(self : WorkQueue, item : WorkItem) -> WorkQueue {
  let result = self
  if result.items.all(existing => existing.id != item.id) {
    result.items.push(item)
  }
  result.revision += 1
  result
}

///|
pub fn WorkQueue::add_many(
  self : WorkQueue,
  items : Array[WorkItem],
) -> WorkQueue {
  let mut result = self
  for item in items {
    result = result.add(item)
  }
  result
}

///|
pub fn WorkQueue::remove(self : WorkQueue, id : String) -> WorkQueue {
  let result = self
  let before = result.items.length()
  result.items.retain(item => item.id != id)
  if result.items.length() != before {
    result.revision += 1
  }
  result
}

///|
pub fn WorkQueue::get(self : WorkQueue, id : String) -> WorkItem? {
  for item in self.items {
    if item.id == id {
      return Some(item)
    }
  }
  None
}

///|
pub fn WorkQueue::update(self : WorkQueue, item : WorkItem) -> WorkQueue {
  let result = self
  for index, existing in result.items {
    if existing.id == item.id {
      result.items[index] = item
      result.revision += 1
      return result
    }
  }
  result
}

///|
pub fn WorkQueue::transition(
  self : WorkQueue,
  id : String,
  status : WorkStatus,
) -> WorkQueue {
  match self.get(id) {
    Some(item) => self.update(item.with_status(status))
    None => self
  }
}

///|
pub fn WorkQueue::pending(self : WorkQueue) -> Array[WorkItem] {
  self.items.filter(item => !item.status.terminal())
}

///|
pub fn WorkQueue::overdue(self : WorkQueue, now : String) -> Array[WorkItem] {
  self.items.filter(item => item.overdue(now))
}

///|
pub fn WorkQueue::for_owner(
  self : WorkQueue,
  owner : String,
) -> Array[WorkItem] {
  self.items.filter(item => item.owner == owner)
}

///|
pub fn WorkQueue::for_session(
  self : WorkQueue,
  session_id : String,
) -> Array[WorkItem] {
  self.items.filter(item => item.session_id == session_id)
}

///|
pub fn WorkQueue::by_priority(self : WorkQueue) -> Array[WorkItem] {
  let result = self.pending()
  result.sort_by((left, right) => right.priority.rank() - left.priority.rank())
  result
}

///|
pub fn WorkQueue::by_due_date(self : WorkQueue) -> Array[WorkItem] {
  let result = self.pending()
  result.sort_by((left, right) => left.due_at.compare(right.due_at))
  result
}

///|
pub fn WorkQueue::status_counts(self : WorkQueue) -> (Int, Int, Int, Int, Int) {
  (
    self.items.count_if(item => item.status == WorkStatus::Queued),
    self.items.count_if(item => item.status == WorkStatus::InProgress),
    self.items.count_if(item => item.status == WorkStatus::Waiting),
    self.items.count_if(item => item.status == WorkStatus::Done),
    self.items.count_if(item => item.status == WorkStatus::Cancelled),
  )
}

///|
pub fn WorkQueue::priority_counts(self : WorkQueue) -> (Int, Int, Int, Int) {
  (
    self.items.count_if(item => item.priority == WorkPriority::Routine),
    self.items.count_if(item => item.priority == WorkPriority::Soon),
    self.items.count_if(item => item.priority == WorkPriority::Urgent),
    self.items.count_if(item => item.priority == WorkPriority::Immediate),
  )
}

///|
pub fn WorkQueue::tagged(self : WorkQueue, tag : String) -> Array[WorkItem] {
  self.items.filter(item => item.tags.contains(tag))
}

///|
pub fn WorkQueue::completion_percent(self : WorkQueue) -> Double {
  if self.items.is_empty() {
    0.0
  } else {
    self.items.count_if(item => item.status == WorkStatus::Done).to_double() *
    100.0 /
    self.items.length().to_double()
  }
}

///|
pub fn WorkQueue::summary(self : WorkQueue) -> String {
  let counts = self.status_counts()
  "queue=" +
  counts.0.to_string() +
  ", active=" +
  counts.1.to_string() +
  ", waiting=" +
  counts.2.to_string() +
  ", done=" +
  counts.3.to_string() +
  ", cancelled=" +
  counts.4.to_string()
}

///|
pub(all) enum OperationEventKind {
  Created
  StatusChanged
  Assigned
  Escalated
  Commented
  Linked
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct OperationEvent {
  item_id : String
  timestamp : String
  kind : OperationEventKind
  actor : String
  detail : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn OperationEvent::item_id(self : OperationEvent) -> String {
  self.item_id
}

///|
pub fn OperationEvent::timestamp(self : OperationEvent) -> String {
  self.timestamp
}

///|
pub fn OperationEvent::kind(self : OperationEvent) -> OperationEventKind {
  self.kind
}

///|
pub fn OperationEvent::actor(self : OperationEvent) -> String {
  self.actor
}

///|
pub fn OperationEvent::detail(self : OperationEvent) -> String {
  self.detail
}

///|
pub(all) struct OperationLog {
  events : Array[OperationEvent]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn new_log() -> OperationLog {
  OperationLog::{ events: [] }
}

///|
pub fn OperationLog::events(self : OperationLog) -> Array[OperationEvent] {
  self.events
}

///|
pub fn OperationLog::append(
  self : OperationLog,
  event : OperationEvent,
) -> OperationLog {
  let result = self
  result.events.push(event)
  result
}

///|
pub fn OperationLog::for_item(
  self : OperationLog,
  item_id : String,
) -> Array[OperationEvent] {
  self.events.filter(event => event.item_id == item_id)
}

///|
pub fn OperationLog::latest(
  self : OperationLog,
  item_id : String,
) -> OperationEvent? {
  self.for_item(item_id).get(self.for_item(item_id).length() - 1)
}

///|
pub fn OperationLog::count(self : OperationLog) -> Int {
  self.events.length()
}

///|
pub fn event(
  item_id : String,
  timestamp : String,
  kind : OperationEventKind,
  actor : String,
  detail : String,
) -> OperationEvent {
  OperationEvent::{ item_id, timestamp, kind, actor, detail }
}

///|
pub fn create_items_for_sessions(
  sessions : Array[@core.Session],
  now : String,
) -> Array[WorkItem] {
  let items = []
  for session in sessions {
    let quality = @quality.score(session)
    if quality.score() < 75 {
      items.push(
        work_item(
          "quality-" + session.id,
          session.id,
          WorkKind::ValidateRecord,
          WorkPriority::Soon,
          "Validate session record",
          "Quality score is " + quality.score().to_string(),
          now,
          session.date,
        ),
      )
    }
    let risk = @risk.evaluate(session)
    if risk.level().rank() >= @risk.RiskLevel::High.rank() {
      items.push(
        work_item(
          "risk-" + session.id,
          session.id,
          WorkKind::ReviewRisk,
          WorkPriority::Urgent,
          "Review elevated risk",
          risk.action(),
          now,
          session.date,
        ),
      )
    }
  }
  items
}

///|
pub fn refresh_for_sessions(
  queue : WorkQueue,
  sessions : Array[@core.Session],
  now : String,
) -> WorkQueue {
  queue.add_many(create_items_for_sessions(sessions, now))
}

///|
pub fn queue_text(queue : WorkQueue) -> String {
  let output = StringBuilder()
  output.write_string(queue.summary() + "\n")
  for item in queue.by_priority() {
    output.write_string(
      item.priority.label() + " " + item.id + " " + item.title + "\n",
    )
  }
  output.to_string()
}
