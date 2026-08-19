///|
fn plan_session() -> @core.Session {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 1.0,
  }
  let movement = @core.Movement::{ name: "squat", sets: [set], pain: 2, rpe: 4 }
  @core.Session::{
    id: "session",
    date: "2026-08-19",
    duration: 30,
    pain_before: 3,
    pain_after: 2,
    movements: [movement],
    notes: "",
  }
}

///|
test "plan targets calculate workload and execution status" {
  let plan = @planning.new_plan("starter")
  let squat = @planning.target("squat", 1, 10, 5, "body", 0.75, 3, 6)
  let stretch = @planning.target("stretch", 2, 20, 30, "none", 0.75, 3, 6)
  plan.add(@planning.PlanDay::Monday, squat)
  plan.add(@planning.PlanDay::Monday, stretch)
  assert_eq(plan.item_count(), 2)
  assert_eq(plan.day_count(), 1)
  assert_eq(plan.weekly_target_reps(), 50)
  assert_eq(plan.weekly_target_hold_time(), 65)
  assert_eq(plan.estimate_work_units(), 1300)
  assert_eq(plan.validate(), [])
  let statuses = @planning.execute_day(
    plan,
    @planning.PlanDay::Monday,
    plan_session(),
  )
  assert_eq(statuses, [
    @planning.PlanItemStatus::Completed,
    @planning.PlanItemStatus::Skipped,
  ])
  assert_eq(
    @planning.adherence_for(plan, @planning.PlanDay::Monday, plan_session()),
    50.0,
  )
}

///|
test "plan boundary validation and day rotation" {
  let bad = @planning.target("", 0, -1, -2, "", 2.0, 11, 0)
  let plan = @planning.new_plan("")
  plan.add(@planning.PlanDay::Sunday, bad)
  assert_true(plan.validate().length() >= 7)
  assert_eq(
    @planning.next_day(plan, @planning.PlanDay::Sunday),
    @planning.PlanDay::Monday,
  )
  assert_eq(@planning.plan_day_from_number(7), Some(@planning.PlanDay::Sunday))
  assert_eq(@planning.plan_day_from_number(0), None)
  assert_true(@planning.plan_text(plan).contains("Sunday"))
}
