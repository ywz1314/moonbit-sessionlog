///|
fn messy_session() -> @core.Session {
  @core.Session::{
    id: "  session-1  ",
    date: "2026-8-1",
    duration: -4,
    pain_before: 12,
    pain_after: -2,
    movements: [
      @core.Movement::{
        name: " squat ",
        pain: -1,
        rpe: 20,
        sets: [
          @core.Set::{
            reps: -3,
            hold_time: -1,
            resistance: " ",
            completion: 2.0,
          },
        ],
      },
      @core.Movement::{ name: "squat", pain: 3, rpe: 5, sets: [] },
    ],
    notes: "  notes  ",
  }
}

///|
test "normalization clamps numeric boundaries and merges names" {
  let result = @normalization.normalize(
    messy_session(),
    @normalization.default_options(),
  ).unwrap()
  let session = result.session()
  assert_eq(session.id, "session-1")
  assert_eq(session.duration, 0)
  assert_eq(session.pain_before, 10)
  assert_eq(session.pain_after, 0)
  assert_eq(session.movements.length(), 1)
  assert_eq(session.movements[0].sets[0].reps, 0)
  assert_eq(session.movements[0].sets[0].resistance, "unspecified")
  assert_eq(session.notes, "notes")
  assert_true(result.report().changed())
  assert_true(result.report().warning_count() >= 5)
}

///|
test "strict normalization rejects invalid dates and truncates notes" {
  let options = @normalization.strict_options()
  let invalid = @core.Session::{
    id: "invalid",
    date: "2026-02-30",
    duration: 1,
    pain_before: 1,
    pain_after: 1,
    movements: [],
    notes: "hello",
  }
  assert_true(@normalization.normalize(invalid, options) is Err(_))
  let valid = @core.Session::{
    id: "valid",
    date: "2026-08-01",
    duration: 1,
    pain_before: 1,
    pain_after: 1,
    movements: [],
    notes: "123456789",
  }
  let short = @normalization.with_max_notes_length(options, 4)
  assert_eq(
    @normalization.normalize(valid, short).unwrap().session().notes,
    "1234",
  )
}

///|
test "batch normalization reports rejection and duplicate counts" {
  let first = @core.Session::{
    id: "a",
    date: "2026-08-01",
    duration: 10,
    pain_before: 1,
    pain_after: 1,
    movements: [],
    notes: "",
  }
  let duplicate = @core.Session::{
    id: "a",
    date: "2026-08-01",
    duration: 10,
    pain_before: 1,
    pain_after: 1,
    movements: [],
    notes: "",
  }
  let invalid = @core.Session::{
    id: "bad",
    date: "2026-02-30",
    duration: 1,
    pain_before: 1,
    pain_after: 1,
    movements: [],
    notes: "",
  }
  let batch = @normalization.normalize_many(
    [first, duplicate, invalid],
    @normalization.strict_options(),
  )
  assert_eq(batch.sessions().length(), 2)
  assert_eq(batch.rejected().length(), 1)
  assert_eq(@normalization.duplicate_count(batch.sessions()), 1)
  assert_true(@normalization.report_text(batch).contains("rejected: 1"))
}
