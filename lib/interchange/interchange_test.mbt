///|
test "tabular interchange round trips aggregate rows" {
  let set = @core.Set::{
    reps: 8,
    hold_time: 5,
    resistance: "body",
    completion: 0.9,
  }
  let session = @core.Session::{
    id: "row",
    date: "2026-08-19",
    duration: 20,
    pain_before: 3,
    pain_after: 2,
    movements: [@core.Movement::{ name: "walk", sets: [set], pain: 2, rpe: 4 }],
    notes: "",
  }
  let text = @interchange.rows_to_tsv(
    @interchange.rows_from_sessions([session]),
  )
  let (rows, errors) = @interchange.parse_tsv(text)
  assert_eq(errors, [])
  assert_eq(rows[0].id(), "row")
  assert_eq(rows[0].total_reps(), 8)
  let (sessions, line_errors) = @interchange.parse_json_lines(
    @interchange.session_json_lines([session]),
  )
  assert_eq(line_errors, [])
  assert_eq(sessions[0].id, "row")
}
