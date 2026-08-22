///|
/// Schema compatibility is explicit so importers can distinguish safe
/// forward-compatible additions from changes that require migration.
pub(all) enum SchemaChangeKind {
  AddedField
  RemovedField
  RenamedField
  TypeChanged
  ConstraintChanged
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SchemaChangeKind::label(self : SchemaChangeKind) -> String {
  match self {
    AddedField => "added_field"
    RemovedField => "removed_field"
    RenamedField => "renamed_field"
    TypeChanged => "type_changed"
    ConstraintChanged => "constraint_changed"
  }
}

///|
pub(all) struct SchemaField {
  name : String
  type_name : String
  required : Bool
  nullable : Bool
  default_value : String?
  description : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SchemaField::name(self : SchemaField) -> String {
  self.name
}

///|
pub fn SchemaField::type_name(self : SchemaField) -> String {
  self.type_name
}

///|
pub fn SchemaField::required(self : SchemaField) -> Bool {
  self.required
}

///|
pub fn SchemaField::nullable(self : SchemaField) -> Bool {
  self.nullable
}

///|
pub fn SchemaField::default_value(self : SchemaField) -> String? {
  self.default_value
}

///|
pub fn SchemaField::description(self : SchemaField) -> String {
  self.description
}

///|
pub fn field(
  name : String,
  type_name : String,
  required : Bool,
  nullable : Bool,
  default_value : String?,
  description : String,
) -> SchemaField {
  SchemaField::{
    name,
    type_name,
    required,
    nullable,
    default_value,
    description,
  }
}

///|
pub(all) struct SchemaDescriptor {
  name : String
  version : String
  fields : Array[SchemaField]
  deprecated_fields : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SchemaDescriptor::name(self : SchemaDescriptor) -> String {
  self.name
}

///|
pub fn SchemaDescriptor::version(self : SchemaDescriptor) -> String {
  self.version
}

///|
pub fn SchemaDescriptor::fields(self : SchemaDescriptor) -> Array[SchemaField] {
  self.fields.copy()
}

///|
pub fn SchemaDescriptor::deprecated_fields(
  self : SchemaDescriptor,
) -> Array[String] {
  self.deprecated_fields.copy()
}

///|
pub fn descriptor(
  name : String,
  version : String,
  fields : Array[SchemaField],
) -> SchemaDescriptor {
  SchemaDescriptor::{ name, version, fields, deprecated_fields: [] }
}

///|
pub fn descriptor_deprecate(
  value : SchemaDescriptor,
  names : Array[String],
) -> SchemaDescriptor {
  SchemaDescriptor::{
    name: value.name,
    version: value.version,
    fields: value.fields,
    deprecated_fields: names,
  }
}

///|
pub(all) struct SchemaChange {
  kind : SchemaChangeKind
  field : String
  before_type : String?
  after_type : String?
  safe : Bool
  message : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SchemaChange::kind(self : SchemaChange) -> SchemaChangeKind {
  self.kind
}

///|
pub fn SchemaChange::field(self : SchemaChange) -> String {
  self.field
}

///|
pub fn SchemaChange::before_type(self : SchemaChange) -> String? {
  self.before_type
}

///|
pub fn SchemaChange::after_type(self : SchemaChange) -> String? {
  self.after_type
}

///|
pub fn SchemaChange::safe(self : SchemaChange) -> Bool {
  self.safe
}

///|
pub fn SchemaChange::message(self : SchemaChange) -> String {
  self.message
}

///|
fn find_field(fields : Array[SchemaField], name : String) -> SchemaField? {
  match fields.search_by(field => field.name == name) {
    Some(index) => Some(fields[index])
    None => None
  }
}

///|
pub fn compare_schema(
  left : SchemaDescriptor,
  right : SchemaDescriptor,
) -> Array[SchemaChange] {
  let changes = []
  for field in left.fields {
    match find_field(right.fields, field.name) {
      Some(next) =>
        if field.type_name != next.type_name {
          changes.push(SchemaChange::{
            kind: SchemaChangeKind::TypeChanged,
            field: field.name,
            before_type: Some(field.type_name),
            after_type: Some(next.type_name),
            safe: false,
            message: "field type changed",
          })
        } else if field.required != next.required ||
          field.nullable != next.nullable {
          changes.push(SchemaChange::{
            kind: SchemaChangeKind::ConstraintChanged,
            field: field.name,
            before_type: Some(field.type_name),
            after_type: Some(next.type_name),
            safe: !next.required,
            message: "field constraints changed",
          })
        }
      None =>
        changes.push(SchemaChange::{
          kind: SchemaChangeKind::RemovedField,
          field: field.name,
          before_type: Some(field.type_name),
          after_type: None,
          safe: !field.required,
          message: if field.required {
            "required field removed"
          } else {
            "optional field removed"
          },
        })
    }
  }
  for field in right.fields {
    if find_field(left.fields, field.name) is None {
      changes.push(SchemaChange::{
        kind: SchemaChangeKind::AddedField,
        field: field.name,
        before_type: None,
        after_type: Some(field.type_name),
        safe: !field.required || field.default_value is Some(_),
        message: if field.required {
          "required field added"
        } else {
          "optional field added"
        },
      })
    }
  }
  changes
}

///|
pub(all) struct CompatibilityReport {
  source : SchemaDescriptor
  target : SchemaDescriptor
  changes : Array[SchemaChange]
  compatible : Bool
  breaking : Array[SchemaChange]
  safe_changes : Array[SchemaChange]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CompatibilityReport::source(
  self : CompatibilityReport,
) -> SchemaDescriptor {
  self.source
}

///|
pub fn CompatibilityReport::target(
  self : CompatibilityReport,
) -> SchemaDescriptor {
  self.target
}

///|
pub fn CompatibilityReport::changes(
  self : CompatibilityReport,
) -> Array[SchemaChange] {
  self.changes.copy()
}

///|
pub fn CompatibilityReport::compatible(self : CompatibilityReport) -> Bool {
  self.compatible
}

///|
pub fn CompatibilityReport::breaking(
  self : CompatibilityReport,
) -> Array[SchemaChange] {
  self.breaking.copy()
}

///|
pub fn CompatibilityReport::safe_changes(
  self : CompatibilityReport,
) -> Array[SchemaChange] {
  self.safe_changes.copy()
}

///|
pub fn compatibility(
  source : SchemaDescriptor,
  target : SchemaDescriptor,
) -> CompatibilityReport {
  let changes = compare_schema(source, target)
  let breaking = changes.filter(change => !change.safe)
  CompatibilityReport::{
    source,
    target,
    changes,
    compatible: breaking.is_empty(),
    breaking,
    safe_changes: changes.filter(change => change.safe),
  }
}

///|
pub fn compatibility_direction(value : CompatibilityReport) -> String {
  if value.compatible {
    "backward-compatible"
  } else {
    "breaking"
  }
}

///|
pub fn change_text(value : SchemaChange) -> String {
  value.kind.label() + " " + value.field + ": " + value.message
}

///|
pub fn compatibility_text(value : CompatibilityReport) -> String {
  value.source.version +
  " -> " +
  value.target.version +
  " " +
  compatibility_direction(value) +
  " changes=" +
  value.changes.length().to_string() +
  " breaking=" +
  value.breaking.length().to_string()
}

///|
pub fn migration_required(value : CompatibilityReport) -> Bool {
  !value.compatible
}

///|
pub fn added_fields(value : CompatibilityReport) -> Array[String] {
  value.changes
  .filter(change => change.kind == SchemaChangeKind::AddedField)
  .map(change => change.field)
}

///|
pub fn removed_fields(value : CompatibilityReport) -> Array[String] {
  value.changes
  .filter(change => change.kind == SchemaChangeKind::RemovedField)
  .map(change => change.field)
}

///|
pub fn type_changes(value : CompatibilityReport) -> Array[String] {
  value.changes
  .filter(change => change.kind == SchemaChangeKind::TypeChanged)
  .map(change => change.field)
}

///|
pub fn schema_checksum(value : SchemaDescriptor) -> Int {
  value.fields.fold(init=29, (total, field) => {
    total * 31 + field.name.length() + field.type_name.length()
  })
}
