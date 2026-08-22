///|
/// Migration plans are serializable descriptions of schema actions.  Execution
/// is left to an importer so a review can happen before data is rewritten.
pub(all) enum MigrationAction {
  AddDefault
  Rename
  Convert
  DropOptional
  Review
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MigrationAction::label(self : MigrationAction) -> String {
  match self {
    AddDefault => "add_default"
    Rename => "rename"
    Convert => "convert"
    DropOptional => "drop_optional"
    Review => "review"
  }
}

///|
pub(all) struct MigrationStep {
  order : Int
  field : String
  action : MigrationAction
  source_type : String?
  target_type : String?
  argument : String?
  reversible : Bool
  manual : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MigrationStep::order(self : MigrationStep) -> Int {
  self.order
}

///|
pub fn MigrationStep::field(self : MigrationStep) -> String {
  self.field
}

///|
pub fn MigrationStep::action(self : MigrationStep) -> MigrationAction {
  self.action
}

///|
pub fn MigrationStep::source_type(self : MigrationStep) -> String? {
  self.source_type
}

///|
pub fn MigrationStep::target_type(self : MigrationStep) -> String? {
  self.target_type
}

///|
pub fn MigrationStep::argument(self : MigrationStep) -> String? {
  self.argument
}

///|
pub fn MigrationStep::reversible(self : MigrationStep) -> Bool {
  self.reversible
}

///|
pub fn MigrationStep::manual(self : MigrationStep) -> Bool {
  self.manual
}

///|
pub(all) struct MigrationPlan {
  source_version : String
  target_version : String
  steps : Array[MigrationStep]
  destructive : Bool
  reversible : Bool
  checksum : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MigrationPlan::source_version(self : MigrationPlan) -> String {
  self.source_version
}

///|
pub fn MigrationPlan::target_version(self : MigrationPlan) -> String {
  self.target_version
}

///|
pub fn MigrationPlan::steps(self : MigrationPlan) -> Array[MigrationStep] {
  self.steps.copy()
}

///|
pub fn MigrationPlan::destructive(self : MigrationPlan) -> Bool {
  self.destructive
}

///|
pub fn MigrationPlan::reversible(self : MigrationPlan) -> Bool {
  self.reversible
}

///|
pub fn MigrationPlan::checksum(self : MigrationPlan) -> Int {
  self.checksum
}

///|
fn step(order : Int, change : SchemaChange) -> MigrationStep {
  let action = match change.kind {
    SchemaChangeKind::AddedField =>
      if change.safe {
        MigrationAction::AddDefault
      } else {
        MigrationAction::Review
      }
    SchemaChangeKind::RemovedField =>
      if change.safe {
        MigrationAction::DropOptional
      } else {
        MigrationAction::Review
      }
    SchemaChangeKind::TypeChanged =>
      if change.safe {
        MigrationAction::Convert
      } else {
        MigrationAction::Review
      }
    SchemaChangeKind::ConstraintChanged => MigrationAction::Review
    SchemaChangeKind::RenamedField => MigrationAction::Rename
  }
  MigrationStep::{
    order,
    field: change.field,
    action,
    source_type: change.before_type,
    target_type: change.after_type,
    argument: None,
    reversible: change.safe,
    manual: !change.safe,
  }
}

///|
pub fn migration_plan(value : CompatibilityReport) -> MigrationPlan {
  let steps = []
  for index, change in value.changes {
    steps.push(step(index + 1, change))
  }
  let destructive = steps.any(value => {
    value.action == MigrationAction::DropOptional || !value.reversible
  })
  let reversible = steps.all(value => value.reversible)
  let checksum = steps.fold(init=43, (total, value) => {
    total * 31 + value.field.length() + value.order
  })
  MigrationPlan::{
    source_version: value.source.version,
    target_version: value.target.version,
    steps,
    destructive,
    reversible,
    checksum,
  }
}

///|
pub fn migration_requires_review(value : MigrationPlan) -> Bool {
  value.steps.any(step => step.manual)
}

///|
pub fn migration_auto_steps(value : MigrationPlan) -> Array[MigrationStep] {
  value.steps.filter(step => !step.manual)
}

///|
pub fn migration_manual_steps(value : MigrationPlan) -> Array[MigrationStep] {
  value.steps.filter(step => step.manual)
}

///|
pub fn migration_text(value : MigrationPlan) -> String {
  value.source_version +
  " -> " +
  value.target_version +
  " steps=" +
  value.steps.length().to_string() +
  " auto=" +
  migration_auto_steps(value).length().to_string() +
  " manual=" +
  migration_manual_steps(value).length().to_string() +
  " destructive=" +
  value.destructive.to_string()
}

///|
pub fn migration_safe(value : MigrationPlan) -> Bool {
  !value.destructive && !migration_requires_review(value)
}
