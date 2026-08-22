///|
test "guardrails reject high pain without notes" {
  let session = @core.Session::{
    id: "guard",
    date: "2026-02-20",
    duration: 30,
    pain_before: 2,
    pain_after: 9,
    movements: [],
    notes: "",
  }
  let result = apply_guardrails(session, default_guardrail_policy())
  assert_eq(result.decision(), GuardrailDecision::Reject)
  assert_true(result.blockers().contains("high pain requires notes"))
}
