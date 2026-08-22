///|
fn adherence_session(id : String, date : String, reps : Int) -> @core.Session {
  @core.Session::{
    id,
    date,
    duration: 25,
    pain_before: 2,
    pain_after: 1,
    movements: [
      @core.Movement::{
        name: "squat",
        sets: [
          @core.Set::{ reps, hold_time: 0, resistance: "body", completion: 1.0 },
        ],
        pain: 1,
        rpe: 3,
      },
    ],
    notes: "",
  }
}

///|
fn adherence_plan() -> @planning.TrainingPlan {
  let plan = @planning.new_plan("baseline")
  plan.add(
    @planning.PlanDay::Monday,
    @planning.target("squat", 1, 10, 0, "body", 0.8, 4, 6),
  )
  plan.add(
    @planning.PlanDay::Wednesday,
    @planning.target("squat", 1, 10, 0, "body", 0.8, 4, 6),
  )
  plan
}

///|
test "adherence distinguishes completed partial and missed work" {
  let plan = adherence_plan()
  let sessions = [
    adherence_session("mon", "2026-08-17", 10),
    adherence_session("wed", "2026-08-19", 5),
  ]
  let report = @adherence.evaluate(plan, sessions, "2026-08-17", "2026-08-19")
  assert_eq(report.scheduled_count(), 2)
  assert_eq(report.completed_count(), 1)
  assert_eq(report.partial_count(), 1)
  assert_eq(report.missed_count(), 0)
  assert_eq(report.adherence(), 50.0)
  assert_true(@adherence.needs_follow_up(report))
}

///|
test "adherence handles empty windows and invalid dates" {
  let plan = adherence_plan()
  let empty = @adherence.evaluate(plan, [], "bad", "also-bad")
  assert_eq(empty.days(), [])
  assert_eq(empty.scheduled_count(), 0)
  let day = @adherence.evaluate_day(plan, "2026-08-17", [])
  assert_eq(day.unwrap().status(), @adherence.AdherenceStatus::Missed)
}

///|
test "adherence range and streak calculations are deterministic" {
  let plan = adherence_plan()
  let sessions = [adherence_session("mon", "2026-08-17", 10)]
  let report = @adherence.weekly(plan, sessions, "2026-08-23")
  assert_eq(report.start_date(), "2026-08-17")
  assert_eq(report.end_date(), "2026-08-23")
  assert_eq(report.successful_days(), 1)
  assert_eq(report.longest_streak(), 1)
  assert_eq(@adherence.plan_day("2026-08-17"), Some(@planning.PlanDay::Monday))
  assert_eq(@adherence.scheduled_on(plan, "2026-08-17"), 1)
}
