///|
pub(all) enum BodyRegion {
  FullBody
  UpperLimb
  LowerLimb
  Trunk
  Balance
  Breathing
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn BodyRegion::label(self : BodyRegion) -> String {
  match self {
    FullBody => "full_body"
    UpperLimb => "upper_limb"
    LowerLimb => "lower_limb"
    Trunk => "trunk"
    Balance => "balance"
    Breathing => "breathing"
  }
}

///|
pub(all) enum MovementCategory {
  Mobility
  Strength
  Endurance
  Coordination
  Recovery
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MovementCategory::label(self : MovementCategory) -> String {
  match self {
    Mobility => "mobility"
    Strength => "strength"
    Endurance => "endurance"
    Coordination => "coordination"
    Recovery => "recovery"
  }
}

///|
pub(all) struct MovementDefinition {
  name : String
  aliases : Array[String]
  region : BodyRegion
  category : MovementCategory
  default_reps : Int
  default_sets : Int
  default_hold_time : Int
  description : String
  tags : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MovementDefinition::name(self : MovementDefinition) -> String {
  self.name
}

///|
pub fn MovementDefinition::aliases(self : MovementDefinition) -> Array[String] {
  self.aliases
}

///|
pub fn MovementDefinition::region(self : MovementDefinition) -> BodyRegion {
  self.region
}

///|
pub fn MovementDefinition::category(
  self : MovementDefinition,
) -> MovementCategory {
  self.category
}

///|
pub fn MovementDefinition::default_reps(self : MovementDefinition) -> Int {
  self.default_reps
}

///|
pub fn MovementDefinition::default_sets(self : MovementDefinition) -> Int {
  self.default_sets
}

///|
pub fn MovementDefinition::default_hold_time(self : MovementDefinition) -> Int {
  self.default_hold_time
}

///|
pub fn MovementDefinition::description(self : MovementDefinition) -> String {
  self.description
}

///|
pub fn MovementDefinition::tags(self : MovementDefinition) -> Array[String] {
  self.tags
}

///|
pub(all) struct MovementCatalog {
  mut items : Array[MovementDefinition]
  mut revision : Int
} derive(Debug, Eq)

///|
pub fn new_catalog() -> MovementCatalog {
  MovementCatalog::{ items: [], revision: 1 }
}

///|
pub fn definition(
  name : String,
  aliases : Array[String],
  region : BodyRegion,
  category : MovementCategory,
  default_reps : Int,
  default_sets : Int,
  default_hold_time : Int,
  description : String,
  tags : Array[String],
) -> MovementDefinition {
  MovementDefinition::{
    name,
    aliases,
    region,
    category,
    default_reps,
    default_sets,
    default_hold_time,
    description,
    tags,
  }
}

///|
pub fn MovementCatalog::add(
  self : MovementCatalog,
  item : MovementDefinition,
) -> Bool {
  if self.find(item.name) is Some(_) {
    false
  } else {
    self.items.push(item)
    self.revision += 1
    true
  }
}

///|
pub fn MovementCatalog::remove(self : MovementCatalog, name : String) -> Bool {
  match self.items.search_by(item => item.name == name) {
    Some(index) => {
      ignore(self.items.remove(index))
      self.revision += 1
      true
    }
    None => false
  }
}

///|
pub fn MovementCatalog::count(self : MovementCatalog) -> Int {
  self.items.length()
}

///|
pub fn MovementCatalog::revision(self : MovementCatalog) -> Int {
  self.revision
}

///|
pub fn MovementCatalog::all(
  self : MovementCatalog,
) -> Array[MovementDefinition] {
  self.items.copy()
}

///|
pub fn MovementCatalog::find(
  self : MovementCatalog,
  name : String,
) -> MovementDefinition? {
  let mut result : MovementDefinition? = None
  for item in self.items {
    if item.name == name || item.aliases.contains(name) {
      result = Some(item)
    }
  }
  result
}

///|
pub fn MovementCatalog::search(
  self : MovementCatalog,
  query : String,
) -> Array[MovementDefinition] {
  let normalized = query.to_lower()
  self.items.filter(item => {
    item.name.to_lower().contains(normalized) ||
    item.description.to_lower().contains(normalized) ||
    item.tags.any(tag => tag.to_lower().contains(normalized))
  })
}

///|
pub fn MovementCatalog::by_region(
  self : MovementCatalog,
  region : BodyRegion,
) -> Array[MovementDefinition] {
  self.items.filter(item => item.region == region)
}

///|
pub fn MovementCatalog::by_category(
  self : MovementCatalog,
  category : MovementCategory,
) -> Array[MovementDefinition] {
  self.items.filter(item => item.category == category)
}

///|
pub fn MovementCatalog::with_tag(
  self : MovementCatalog,
  tag : String,
) -> Array[MovementDefinition] {
  self.items.filter(item => item.tags.contains(tag))
}

///|
pub fn MovementCatalog::validate_movement(
  self : MovementCatalog,
  movement : @core.Movement,
) -> Array[String] {
  match self.find(movement.name) {
    None => ["unknown movement: " + movement.name]
    Some(item) => {
      let errors = []
      if movement.sets.is_empty() {
        errors.push("movement has no sets")
      }
      if item.default_reps > 0 && movement.total_reps() == 0 {
        errors.push("movement has no repetitions")
      }
      errors
    }
  }
}

///|
pub fn standard_catalog() -> MovementCatalog {
  let catalog = new_catalog()
  ignore(
    catalog.add(
      definition(
        "squat",
        ["sit_to_stand"],
        BodyRegion::LowerLimb,
        MovementCategory::Strength,
        10,
        2,
        0,
        "Supported knee and hip extension.",
        ["knee", "hip", "functional"],
      ),
    ),
  )
  ignore(
    catalog.add(
      definition(
        "leg_raise",
        ["straight_leg_raise"],
        BodyRegion::LowerLimb,
        MovementCategory::Strength,
        8,
        2,
        0,
        "Controlled hip flexion with a stable trunk.",
        ["hip", "core"],
      ),
    ),
  )
  ignore(
    catalog.add(
      definition(
        "single_leg_balance",
        ["one_leg_stand"],
        BodyRegion::Balance,
        MovementCategory::Coordination,
        3,
        2,
        30,
        "Supported single-leg balance drill.",
        ["balance", "ankle"],
      ),
    ),
  )
  ignore(
    catalog.add(
      definition(
        "breathing",
        ["diaphragmatic_breathing"],
        BodyRegion::Breathing,
        MovementCategory::Recovery,
        5,
        1,
        60,
        "Slow breathing with a comfortable posture.",
        ["recovery", "relaxation"],
      ),
    ),
  )
  catalog
}
