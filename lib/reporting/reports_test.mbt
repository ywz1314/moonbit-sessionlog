///|
fn report_session() -> @core.Session {
  let set = @core.Set::{
    reps: 8,
    hold_time: 5,
    resistance: "red,band",
    completion: 0.9,
  }
  let movement = @core.Movement::{ name: "press", sets: [set], pain: 2, rpe: 4 }
  @core.Session::{
    id: "patient-001",
    date: "2026-08-01",
    duration: 25,
    pain_before: 4,
    pain_after: 2,
    movements: [movement],
    notes: "private note",
  }
}

///|
test "reports escape csv and support privacy modes" {
  let session = report_session()
  let csv = @reporting.movement_csv([session])
  assert_true(csv.contains("\"red,band\""))
  let session_csv = @reporting.session_csv([session])
  assert_true(session_csv.contains("private note"))
  let private_csv = @reporting.session_csv(
    [session],
    privacy=@reporting.PrivacyMode::Minimal,
  )
  assert_true(!private_csv.contains("private note"))
  assert_true(!private_csv.contains("red,band"))
  let text = @reporting.session_text(
    session,
    privacy=@reporting.PrivacyMode::HideNotes,
  )
  assert_true(text.contains("[redacted]"))
  assert_true(!text.contains("private note"))
  assert_true(
    @reporting.session_json(
      session,
      privacy=@reporting.PrivacyMode::HashIdentifiers,
    ).contains("id-"),
  )
}

///|
test "report builder applies filters and stable formatting" {
  let session = report_session()
  let options = @reporting.ReportOptions::{
    title: "weekly",
    format: @reporting.ReportFormat::Csv,
    privacy: @reporting.PrivacyMode::Full,
    include_invalid: true,
    include_empty_movements: false,
  }
  let document = @reporting.build([session], options~)
  assert_eq(document.title(), "weekly")
  assert_eq(document.session_count(), 1)
  assert_eq(document.valid_count(), 1)
  assert_true(document.body().contains("session_id"))
  assert_eq(@reporting.fixed_width("x", 3), "x  ")
  assert_eq(@reporting.table_row(["a", "b"], [3, 3]), "| a   | b   |")
}
