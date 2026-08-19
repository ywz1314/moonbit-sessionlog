///|
test "forecast remains bounded and explicit about uncertainty" {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 0.8,
  }
  let movement = @core.Movement::{ name: "move", sets: [set], pain: 2, rpe: 4 }
  let session = @core.Session::{
    id: "a",
    date: "2026-08-01",
    duration: 20,
    pain_before: 2,
    pain_after: 1,
    movements: [movement],
    notes: "",
  }
  let report = @forecast.forecast([session], 3)
  assert_eq(report.points().length(), 3)
  assert_true(report.confidence() <= 1.0)
  assert_true(@forecast.expected_completion_at(report, 2) >= 0.0)
  assert_true(@forecast.expected_completion_at(report, 2) <= 1.0)
  assert_true(@forecast.report_text(report).contains("step 1"))
  assert_eq(
    @forecast.forecast([], 2).points()[0].band(),
    @forecast.ForecastBand::Uncertain,
  )
}
