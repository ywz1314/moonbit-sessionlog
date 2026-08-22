///|
test "operation queue orders and transitions work items" {
  let item = work_item(
    "w1",
    "s1",
    WorkKind::ValidateRecord,
    WorkPriority::Immediate,
    "validate",
    "check record",
    "2026-02-20",
    "2026-02-21",
  )
  let queue = new_queue().add(item)
  assert_eq(queue.count(), 1)
  assert_true(queue.pending().length() == 1)
  let done = queue.transition("w1", WorkStatus::Done)
  assert_eq(done.status_counts().3, 1)
  assert_eq(done.completion_percent(), 100.0)
}

///|
test "sla marks invalid timestamps unknown" {
  let item = work_item(
    "w2",
    "s2",
    WorkKind::ReviewRisk,
    WorkPriority::Urgent,
    "review",
    "risk",
    "",
    "",
  )
  let result = evaluate_sla(item, "2026-02-20", default_sla_policy())
  assert_eq(result.status(), SlaStatus::Unknown)
}
