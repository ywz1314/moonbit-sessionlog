///|
test "workflow gates review until evidence exists" {
  let case_value = new_case("case-1", "subject-1", "2026-02-20").unwrap()
  let policy = default_case_policy()
  assert_true(!case_is_ready_for_review(case_value, policy))
  assert_true(
    gate_report(case_value, policy).blockers().contains("minimum_sessions"),
  )
  let activated = transition(
    case_value,
    CaseState::Active,
    "2026-02-20",
    "start",
    policy,
  ).unwrap()
  assert_eq(activated.state(), CaseState::Active)
  assert_true(case_next_actions(activated, policy).contains("record_session"))
}

///|
test "workflow records session and closes with reason" {
  let initial = new_case("case-2", "subject-2", "2026-02-20").unwrap()
  let active = transition(
    initial,
    CaseState::Active,
    "2026-02-20",
    "start",
    permissive_case_policy(),
  ).unwrap()
  let session = @core.Session::{
    id: "s-1",
    date: "2026-02-21",
    duration: 30,
    pain_before: 2,
    pain_after: 1,
    movements: [],
    notes: "ok",
  }
  let recorded = record_session(active, session, false)
  let reviewed = transition(
    recorded,
    CaseState::Review,
    "2026-02-21",
    "review",
    permissive_case_policy(),
  ).unwrap()
  let completed = transition(
    reviewed,
    CaseState::Completed,
    "2026-02-22",
    "goals met",
    permissive_case_policy(),
  ).unwrap()
  assert_eq(completed.state(), CaseState::Completed)
  assert_true(completed.session_ids().contains("s-1"))
}
