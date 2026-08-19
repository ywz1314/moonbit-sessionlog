///|
fn retention_session(
  id : String,
  date : String,
  notes : String,
) -> @core.Session {
  @core.Session::{
    id,
    date,
    duration: 30,
    pain_before: 4,
    pain_after: 2,
    movements: [
      @core.Movement::{
        name: "squat",
        pain: 2,
        rpe: 5,
        sets: [
          @core.Set::{
            reps: 10,
            hold_time: 5,
            resistance: "body",
            completion: 0.9,
          },
        ],
      },
    ],
    notes,
  }
}

///|
test "retention plans age and deduplicates deterministically" {
  let first = retention_session("a", "2026-01-01", "")
  let duplicate = retention_session("a-copy", "2026-01-01", "")
  let policy = @retention.archival_policy(30)
  let retention_plan = @retention.plan([first, duplicate], "2026-03-01", policy)
  assert_eq(retention_plan.archived_count(), 2)
  assert_eq(retention_plan.duplicate_count(), 0)
  assert_eq(
    @retention.decide(first, "2026-03-01", policy).reason(),
    @retention.RetentionReason::OlderThanWindow,
  )
}

///|
test "retention preserves painful sessions and validates dates" {
  let painful = @core.Session::{
    id: "pain",
    date: "2026-01-01",
    duration: 30,
    pain_before: 4,
    pain_after: 2,
    movements: [
      @core.Movement::{
        name: "squat",
        pain: 9,
        rpe: 5,
        sets: [
          @core.Set::{
            reps: 10,
            hold_time: 5,
            resistance: "body",
            completion: 0.9,
          },
        ],
      },
    ],
    notes: "clinical note",
  }
  let policy = @retention.archival_policy(1)
  assert_eq(
    @retention.decide(painful, "2026-03-01", policy).action(),
    @retention.RetentionAction::Keep,
  )
  assert_true(@retention.safe_plan([painful], "not-a-date", policy) is Err(_))
  assert_true(@retention.validate_policy(policy).is_empty())
}

///|
test "archive round trip and privacy redaction are loss-aware" {
  let session = retention_session("private-id", "2026-08-19", "secret")
  let policy = @retention.privacy_policy()
  let decision = @retention.decide(session, "2026-08-20", policy)
  let archive = @retention.Archive::new()
  let added = archive.add(session, "2026-08-20", decision, policy)
  assert_true(added is Ok(_))
  assert_eq(archive.count(), 1)
  assert_true(!archive.restore_all()[0].id.contains("private-id"))
  assert_eq(archive.restore_all()[0].notes, "[redacted]")
  let parsed = @retention.parse_archive(archive.json()).unwrap()
  assert_eq(parsed.count(), 1)
  assert_eq(parsed.revision(), 0)
}

///|
test "retention capacity moves only excess kept records" {
  let policy = @retention.bounded_policy(1)
  let one = retention_session("one", "2026-08-18", "")
  let two = retention_session("two", "2026-08-19", "")
  let retention_plan = @retention.plan([one, two], "2026-08-19", policy)
  assert_eq(retention_plan.kept_count(), 1)
  assert_eq(retention_plan.archived_count(), 1)
  assert_eq(
    @retention.decision_for(retention_plan, "two").unwrap().reason(),
    @retention.RetentionReason::CapacityExceeded,
  )
}
