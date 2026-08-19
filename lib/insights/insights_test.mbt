///|
fn insight_session(pain : Int, completion : Double, rpe : Int) -> @core.Session {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion,
  }
  let movement = @core.Movement::{ name: "move", sets: [set], pain, rpe }
  @core.Session::{
    id: "i",
    date: "2026-08-19",
    duration: 20,
    pain_before: pain,
    pain_after: pain + 1,
    movements: [movement],
    notes: "",
  }
}

///|
test "insights prioritize high risk signals" {
  let session = insight_session(8, 0.5, 9)
  let report = @insights.build([session])
  assert_true(report.risk_score() >= 70)
  assert_true(@insights.has_critical(report.insights()))
  assert_true(report.recommendation().contains("conservative"))
  let top = @insights.highest_priority(report.insights()).unwrap()
  assert_eq(top.severity(), @insights.InsightSeverity::Critical)
  assert_eq(@insights.InsightSeverity::Critical.rank(), 3)
}

///|
test "insight helpers cover empty and safe records" {
  let safe = insight_session(1, 1.0, 3)
  let empty : Array[@core.Session] = []
  assert_eq(@insights.history_risk_score(empty), 0)
  let insights = @insights.all_session_insights(safe)
  assert_true(!@insights.has_critical(insights))
  let counts = @insights.count_by_severity(insights)
  assert_true(counts.0 > 0)
  assert_true(
    @insights.report_text(@insights.build([safe])).contains("risk score"),
  )
}
