///|
pub(all) enum PlanDay {
  Monday
  Tuesday
  Wednesday
  Thursday
  Friday
  Saturday
  Sunday
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn PlanDay::number(self : PlanDay) -> Int {
  match self {
    Monday => 1
    Tuesday => 2
    Wednesday => 3
    Thursday => 4
    Friday => 5
    Saturday => 6
    Sunday => 7
  }
}

///|
pub fn PlanDay::label(self : PlanDay) -> String {
  match self {
    Monday => "Monday"
    Tuesday => "Tuesday"
    Wednesday => "Wednesday"
    Thursday => "Thursday"
    Friday => "Friday"
    Saturday => "Saturday"
    Sunday => "Sunday"
  }
}

///|
pub fn plan_day_from_number(number : Int) -> PlanDay? {
  match number {
    1 => Some(PlanDay::Monday)
    2 => Some(PlanDay::Tuesday)
    3 => Some(PlanDay::Wednesday)
    4 => Some(PlanDay::Thursday)
    5 => Some(PlanDay::Friday)
    6 => Some(PlanDay::Saturday)
    7 => Some(PlanDay::Sunday)
    _ => None
  }
}

///|
pub(all) enum PlanItemStatus {
  Planned
  Completed
  PartiallyCompleted
  Skipped
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ExerciseTarget {
  movement_name : String
  target_sets : Int
  target_reps : Int
  target_hold_time : Int
  resistance : String
  minimum_completion : Double
  maximum_pain : Int
  maximum_rpe : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ExerciseTarget::movement_name(self : ExerciseTarget) -> String {
  self.movement_name
}

///|
pub fn ExerciseTarget::target_sets(self : ExerciseTarget) -> Int {
  self.target_sets
}

///|
pub fn ExerciseTarget::target_reps(self : ExerciseTarget) -> Int {
  self.target_reps
}

///|
pub fn ExerciseTarget::target_hold_time(self : ExerciseTarget) -> Int {
  self.target_hold_time
}

///|
pub fn ExerciseTarget::resistance(self : ExerciseTarget) -> String {
  self.resistance
}

///|
pub fn ExerciseTarget::minimum_completion(self : ExerciseTarget) -> Double {
  self.minimum_completion
}

///|
pub fn ExerciseTarget::maximum_pain(self : ExerciseTarget) -> Int {
  self.maximum_pain
}

///|
pub fn ExerciseTarget::maximum_rpe(self : ExerciseTarget) -> Int {
  self.maximum_rpe
}

///|
pub(all) struct PlanItem {
  day : PlanDay
  order : Int
  target : ExerciseTarget
  status : PlanItemStatus
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn PlanItem::day(self : PlanItem) -> PlanDay {
  self.day
}

///|
pub fn PlanItem::order(self : PlanItem) -> Int {
  self.order
}

///|
pub fn PlanItem::target(self : PlanItem) -> ExerciseTarget {
  self.target
}

///|
pub fn PlanItem::status(self : PlanItem) -> PlanItemStatus {
  self.status
}

///|
pub fn PlanItem::movement_name(self : PlanItem) -> String {
  self.target.movement_name
}

///|
pub(all) struct TrainingPlan {
  name : String
  mut version : Int
  mut active : Bool
  items : Array[PlanItem]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn TrainingPlan::name(self : TrainingPlan) -> String {
  self.name
}

///|
pub fn TrainingPlan::version(self : TrainingPlan) -> Int {
  self.version
}

///|
pub fn TrainingPlan::active(self : TrainingPlan) -> Bool {
  self.active
}

///|
pub fn TrainingPlan::items(self : TrainingPlan) -> Array[PlanItem] {
  self.items
}

///|
pub fn new_plan(name : String) -> TrainingPlan {
  TrainingPlan::{ name, version: 1, active: true, items: [] }
}

///|
pub fn target(
  movement_name : String,
  target_sets : Int,
  target_reps : Int,
  target_hold_time : Int,
  resistance : String,
  minimum_completion : Double,
  maximum_pain : Int,
  maximum_rpe : Int,
) -> ExerciseTarget {
  ExerciseTarget::{
    movement_name,
    target_sets,
    target_reps,
    target_hold_time,
    resistance,
    minimum_completion,
    maximum_pain,
    maximum_rpe,
  }
}

///|
pub fn TrainingPlan::add(
  self : TrainingPlan,
  day : PlanDay,
  exercise : ExerciseTarget,
) -> Unit {
  let order = self.items.count_if(item => item.day == day)
  self.items.push(PlanItem::{
    day,
    order,
    target: exercise,
    status: PlanItemStatus::Planned,
  })
  self.version += 1
}

///|
pub fn TrainingPlan::remove_movement(
  self : TrainingPlan,
  movement_name : String,
) -> Int {
  let before = self.items.length()
  self.items.retain(item => item.target.movement_name != movement_name)
  let removed = before - self.items.length()
  if removed > 0 {
    self.version += 1
  }
  removed
}

///|
pub fn TrainingPlan::set_active(self : TrainingPlan, active : Bool) -> Unit {
  self.active = active
  self.version += 1
}

///|
pub fn TrainingPlan::for_day(
  self : TrainingPlan,
  day : PlanDay,
) -> Array[PlanItem] {
  self.items.filter(item => item.day == day)
}

///|
pub fn TrainingPlan::for_movement(
  self : TrainingPlan,
  movement_name : String,
) -> Array[PlanItem] {
  self.items.filter(item => item.target.movement_name == movement_name)
}

///|
pub fn TrainingPlan::movement_names(self : TrainingPlan) -> Array[String] {
  let names = []
  for item in self.items {
    if !names.contains(item.target.movement_name) {
      names.push(item.target.movement_name)
    }
  }
  names
}

///|
pub fn TrainingPlan::day_count(self : TrainingPlan) -> Int {
  let days = self.items.map(item => item.day.number())
  days.dedup()
  days.length()
}

///|
pub fn TrainingPlan::item_count(self : TrainingPlan) -> Int {
  self.items.length()
}

///|
pub fn TrainingPlan::weekly_target_reps(self : TrainingPlan) -> Int {
  self.items.fold(init=0, (total, item) => {
    total + item.target.target_sets * item.target.target_reps
  })
}

///|
pub fn TrainingPlan::weekly_target_hold_time(self : TrainingPlan) -> Int {
  self.items.fold(init=0, (total, item) => {
    total + item.target.target_sets * item.target.target_hold_time
  })
}

///|
pub fn TrainingPlan::estimate_work_units(self : TrainingPlan) -> Int {
  self.items.fold(init=0, (total, item) => {
    total +
    item.target.target_sets *
    item.target.target_reps *
    (item.target.target_hold_time + 1)
  })
}

///|
pub fn TrainingPlan::validate(self : TrainingPlan) -> Array[String] {
  let errors = []
  if self.name.trim().is_empty() {
    errors.push("plan name must not be empty")
  }
  for item in self.items {
    let exercise = item.target
    if exercise.movement_name.trim().is_empty() {
      errors.push("movement name must not be empty")
    }
    if exercise.target_sets <= 0 {
      errors.push("target sets must be positive: " + exercise.movement_name)
    }
    if exercise.target_reps <= 0 {
      errors.push("target reps must be positive: " + exercise.movement_name)
    }
    if exercise.target_hold_time < 0 {
      errors.push(
        "target hold time must not be negative: " + exercise.movement_name,
      )
    }
    if exercise.minimum_completion < 0.0 || exercise.minimum_completion > 1.0 {
      errors.push("minimum completion out of range: " + exercise.movement_name)
    }
    if exercise.maximum_pain < 0 || exercise.maximum_pain > 10 {
      errors.push("maximum pain out of range: " + exercise.movement_name)
    }
    if exercise.maximum_rpe < 1 || exercise.maximum_rpe > 10 {
      errors.push("maximum RPE out of range: " + exercise.movement_name)
    }
  }
  errors
}

///|
pub fn execute(item : PlanItem, movement : @core.Movement) -> PlanItemStatus {
  let target = item.target
  if movement.sets.is_empty() {
    PlanItemStatus::Skipped
  } else {
    let sets_ratio = movement.sets.length().to_double() /
      target.target_sets.to_double()
    let reps_ratio = movement.total_reps().to_double() /
      (target.target_sets * target.target_reps).to_double()
    let completion = movement.average_completion()
    if sets_ratio >= 1.0 &&
      reps_ratio >= 1.0 &&
      completion >= target.minimum_completion &&
      movement.pain <= target.maximum_pain &&
      movement.rpe <= target.maximum_rpe {
      PlanItemStatus::Completed
    } else if sets_ratio > 0.0 || reps_ratio > 0.0 {
      PlanItemStatus::PartiallyCompleted
    } else {
      PlanItemStatus::Skipped
    }
  }
}

///|
pub fn execute_day(
  plan : TrainingPlan,
  day : PlanDay,
  session : @core.Session,
) -> Array[PlanItemStatus] {
  plan
  .for_day(day)
  .map(item => {
    match session.movement(item.target.movement_name) {
      Some(movement) => execute(item, movement)
      None => PlanItemStatus::Skipped
    }
  })
}

///|
pub fn adherence_for(
  plan : TrainingPlan,
  day : PlanDay,
  session : @core.Session,
) -> Double {
  let items = plan.for_day(day)
  if items.is_empty() {
    0.0
  } else {
    let completed = execute_day(plan, day, session).count_if(status => {
      status == PlanItemStatus::Completed
    })
    completed.to_double() * 100.0 / items.length().to_double()
  }
}

///|
pub fn completed_target_count(
  plan : TrainingPlan,
  day : PlanDay,
  session : @core.Session,
) -> Int {
  execute_day(plan, day, session).count_if(status => {
    status == PlanItemStatus::Completed
  })
}

///|
pub fn next_day(_plan : TrainingPlan, day : PlanDay) -> PlanDay {
  match day {
    Monday => Tuesday
    Tuesday => Wednesday
    Wednesday => Thursday
    Thursday => Friday
    Friday => Saturday
    Saturday => Sunday
    Sunday => Monday
  }
}

///|
pub fn active_days(plan : TrainingPlan) -> Array[PlanDay] {
  let days = []
  for item in plan.items {
    if !days.contains(item.day) {
      days.push(item.day)
    }
  }
  days.sort_by((left, right) => left.number() - right.number())
  days
}

///|
pub fn plan_text(plan : TrainingPlan) -> String {
  let output = StringBuilder()
  output.write_string(plan.name + " v" + plan.version.to_string() + "\n")
  output.write_string("active: " + plan.active.to_string() + "\n")
  for day in active_days(plan) {
    output.write_string(day.label() + ":\n")
    for item in plan.for_day(day) {
      let target = item.target
      output.write_string(
        "  - " +
        target.movement_name +
        ": " +
        target.target_sets.to_string() +
        " x " +
        target.target_reps.to_string() +
        " @ " +
        target.resistance +
        "\n",
      )
    }
  }
  output.to_string()
}
