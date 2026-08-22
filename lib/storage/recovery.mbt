///|
/// Recovery planning identifies what can be restored from a known snapshot
/// and what must be reviewed before applying a repair.
pub(all) enum RecoveryAction {
  Restore
  Rebuild
  Skip
  Review
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RecoveryAction::label(self : RecoveryAction) -> String {
  match self {
    Restore => "restore"
    Rebuild => "rebuild"
    Skip => "skip"
    Review => "review"
  }
}

///|
pub(all) struct RecoveryItem {
  session_id : String
  action : RecoveryAction
  reason : String
  confidence : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RecoveryItem::session_id(self : RecoveryItem) -> String {
  self.session_id
}

///|
pub fn RecoveryItem::action(self : RecoveryItem) -> RecoveryAction {
  self.action
}

///|
pub fn RecoveryItem::reason(self : RecoveryItem) -> String {
  self.reason
}

///|
pub fn RecoveryItem::confidence(self : RecoveryItem) -> Double {
  self.confidence
}

///|
pub(all) struct RecoveryPlan {
  source : StoreSnapshot
  target : StoreSnapshot
  items : Array[RecoveryItem]
  safe : Bool
  checksum_match : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RecoveryPlan::source(self : RecoveryPlan) -> StoreSnapshot {
  self.source
}

///|
pub fn RecoveryPlan::target(self : RecoveryPlan) -> StoreSnapshot {
  self.target
}

///|
pub fn RecoveryPlan::items(self : RecoveryPlan) -> Array[RecoveryItem] {
  self.items.copy()
}

///|
pub fn RecoveryPlan::safe(self : RecoveryPlan) -> Bool {
  self.safe
}

///|
pub fn RecoveryPlan::checksum_match(self : RecoveryPlan) -> Bool {
  self.checksum_match
}

///|
pub fn plan_recovery(
  source : StoreSnapshot,
  target : StoreSnapshot,
) -> RecoveryPlan {
  let items = []
  for id in target.ids() {
    if !source.ids().contains(id) {
      items.push(RecoveryItem::{
        session_id: id,
        action: RecoveryAction::Restore,
        reason: "present in target but absent from source",
        confidence: 0.95,
      })
    }
  }
  for id in source.ids() {
    if !target.ids().contains(id) {
      items.push(RecoveryItem::{
        session_id: id,
        action: RecoveryAction::Review,
        reason: "present in source but absent from target",
        confidence: 0.60,
      })
    }
  }
  let checksum_match = source.checksum() == target.checksum()
  let safe = !checksum_match ||
    items.all(item => item.action != RecoveryAction::Review)
  RecoveryPlan::{ source, target, items, safe, checksum_match }
}

///|
pub fn recovery_restore(value : RecoveryPlan) -> Array[String] {
  value.items
  .filter(item => item.action == RecoveryAction::Restore)
  .map(item => item.session_id)
}

///|
pub fn recovery_review(value : RecoveryPlan) -> Array[String] {
  value.items
  .filter(item => item.action == RecoveryAction::Review)
  .map(item => item.session_id)
}

///|
pub fn recovery_safe(value : RecoveryPlan) -> Bool {
  value.safe && recovery_review(value).is_empty()
}

///|
pub fn recovery_text(value : RecoveryPlan) -> String {
  "source=" +
  value.source.revision.to_string() +
  " target=" +
  value.target.revision.to_string() +
  " restore=" +
  recovery_restore(value).length().to_string() +
  " review=" +
  recovery_review(value).length().to_string() +
  " safe=" +
  recovery_safe(value).to_string()
}

///|
pub fn recovery_checksum(value : RecoveryPlan) -> Int {
  value.items.fold(init=47, (total, item) => {
    total * 31 + item.session_id.length() + item.confidence.to_int()
  })
}
