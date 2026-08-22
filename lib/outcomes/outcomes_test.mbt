///|
test "outcome normalization and change bands are bounded" {
  let instrument = pain_instrument()
  assert_eq(normalize(instrument, -1.0), 0.0)
  assert_eq(normalize(instrument, 11.0), 100.0)
  let change = change(instrument, 8.0, 3.0)
  assert_true(change.delta() < 0.0)
  assert_eq(change.band(), ResponseBand::MeaningfulImprovement)
}

///|
test "outcome series ignores invalid observations in summaries" {
  let instrument = function_instrument()
  let series = new_series(instrument)
    .append(
      observation(
        "o1",
        instrument,
        "2026-02-01",
        10.0,
        10,
        OutcomeSource::Clinician,
        "",
      ),
    )
    .append(
      observation(
        "o2",
        instrument,
        "2026-02-02",
        20.0,
        0,
        OutcomeSource::Participant,
        "",
      ),
    )
  assert_eq(series.count(), 2)
  assert_eq(series.valid().length(), 1)
  assert_eq(series.invalid().length(), 1)
}
