///|
test "quality assessment scores missing evidence" {
  let session = @core.Session::{
    id: "",
    date: "2026-02-20",
    duration: 0,
    pain_before: 2,
    pain_after: 8,
    movements: [],
    notes: "",
  }
  let value = assess_quality(session, "2026-02-20")
  assert_true(value.overall() < 70.0)
  assert_true(value.recommendations().length() > 0)
  assert_true(value.blocking())
}
