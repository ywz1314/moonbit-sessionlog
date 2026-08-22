///|
test "rolling series supports short and invalid windows" {
  let session = @core.Session::{
    id: "s",
    date: "2026-02-20",
    duration: 30,
    pain_before: 2,
    pain_after: 1,
    movements: [],
    notes: "",
  }
  let series = from_sessions([session])
  assert_true(rolling(series, SeriesMetric::Pain, 1) is Ok(_))
  assert_true(rolling(series, SeriesMetric::Pain, 0) is Err(_))
  let value = rolling_or_empty(series, SeriesMetric::Completion, 2)
  assert_eq(value.points().length(), 1)
}

///|
test "exponential smoothing rejects unsafe alpha" {
  let series = from_sessions([])
  assert_true(exponential(series, SeriesMetric::Work, 0.0) is Err(_))
  assert_eq(exponential(series, SeriesMetric::Work, 0.5).unwrap().length(), 0)
}
