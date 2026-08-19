///|
test "calendar boundaries and weekday are stable" {
  let leap = @calendar.parse("2024-02-29").unwrap()
  assert_eq(leap.to_string(), "2024-02-29")
  assert_eq(@calendar.add_days(leap, 1).to_string(), "2024-03-01")
  assert_eq(@calendar.add_days(leap, -1).to_string(), "2024-02-28")
  assert_eq(
    @calendar.days_between(leap, @calendar.parse("2024-03-02").unwrap()),
    2,
  )
  assert_eq(
    @calendar.dates_between(leap, @calendar.parse("2024-03-01").unwrap()).length(),
    2,
  )
  assert_true(@calendar.is_weekend(@calendar.parse("2024-03-02").unwrap()))
  assert_eq(@calendar.parse("2023-02-29"), None)
  assert_eq(@calendar.month_end(leap).day(), 29)
}
