///|
test "summary handles empty and ordered values" {
  let empty = @statistics.describe([])
  assert_eq(empty.count(), 0)
  assert_eq(empty.mean(), 0.0)
  let summary = @statistics.describe([1.0, 2.0, 3.0, 4.0, 100.0])
  assert_eq(summary.count(), 5)
  assert_eq(summary.minimum(), 1.0)
  assert_eq(summary.maximum(), 100.0)
  assert_eq(summary.median(), 3.0)
  assert_eq(summary.first_quartile(), 2.0)
  assert_eq(summary.third_quartile(), 4.0)
}

///|
test "summary scales and ranks without mutating input" {
  let values = [4.0, 1.0, 3.0, 2.0]
  assert_eq(@statistics.sorted(values), [1.0, 2.0, 3.0, 4.0])
  assert_eq(values, [4.0, 1.0, 3.0, 2.0])
  assert_eq(@statistics.rank(values), [4, 1, 3, 2])
  assert_eq(@statistics.min_max_scale(values), [
    1.0, 0.0, 0.6666666666666666, 0.3333333333333333,
  ])
}

///|
test "robust outlier detection protects a clinical series" {
  let values = [10.0, 10.1, 9.9, 10.2, 10.0, 60.0]
  assert_true(@statistics.outlier_indices(values).contains(5))
  assert_eq(@statistics.without_outliers(values).length(), 5)
  let clipped = @statistics.winsorize(values, 10.0, 90.0)
  assert_true(clipped[5] < 60.0)
}

///|
test "linear model and correlation are deterministic" {
  let x = [0.0, 1.0, 2.0, 3.0]
  let y = [1.0, 3.0, 5.0, 7.0]
  let model = @statistics.fit_linear(x, y)
  assert_true((model.slope() - 2.0).abs() < 0.0001)
  assert_true((model.intercept() - 1.0).abs() < 0.0001)
  assert_true(model.r_squared() > 0.999)
  assert_true(@statistics.correlation(x, y) > 0.999)
  assert_eq(@statistics.residuals(model, x, y), [0.0, 0.0, 0.0, 0.0])
}

///|
test "rolling and histogram functions handle short windows" {
  assert_eq(@statistics.rolling_mean([1.0, 3.0, 5.0], 2), [1.0, 2.0, 4.0])
  assert_eq(@statistics.rolling_mean([1.0, 3.0], 0), [])
  assert_eq(@statistics.first_difference([1.0, 4.5, 3.0]), [3.5, -1.5])
  assert_eq(@statistics.cumulative_sum([1.0, 2.0, 3.0]), [1.0, 3.0, 6.0])
  assert_eq(
    @statistics.histogram([0.0, 1.0, 2.0, 3.0], 2).map(bin => bin.count()),
    [2, 2],
  )
}

///|
test "weighted statistics and smoothing clamp unsafe parameters" {
  assert_eq(@statistics.weighted_mean([10.0, 20.0], [1.0, 3.0]), 17.5)
  assert_eq(@statistics.weighted_mean([10.0], [-1.0]), 0.0)
  assert_eq(@statistics.exponential_smoothing([0.0, 10.0, 10.0], 1.0), [
    0.0, 10.0, 10.0,
  ])
  assert_eq(@statistics.exponential_smoothing([0.0, 10.0], 0.0), [0.0, 0.0])
}
