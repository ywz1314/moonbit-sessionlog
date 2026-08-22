///|
test "pipeline reports stage fingerprints and idempotence" {
  let session = @core.Session::{
    id: " s ",
    date: "2026-02-20",
    duration: 30,
    pain_before: 2,
    pain_after: 1,
    movements: [@core.Movement::{ name: " step ", pain: 2, rpe: 5, sets: [] }],
    notes: "",
  }
  let result = run_pipeline(session, default_pipeline()).unwrap()
  assert_true(result.changed())
  assert_true(result.reports().length() > 0)
  assert_true(pipeline_is_idempotent(result.session(), default_pipeline()))
}

///|
test "pipeline validates incompatible options" {
  let options = pipeline_with_stages([PipelineStage::LimitNotes])
  assert_true(run_pipeline_many([], options) is Err(_))
}
