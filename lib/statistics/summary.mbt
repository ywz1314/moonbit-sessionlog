///|
/// Descriptive statistics for deterministic rehabilitation analytics.
///
/// The package deliberately returns zero-valued summaries for empty inputs so
/// dashboards can render incomplete data without special-case exceptions.
pub(all) struct Summary {
  count : Int
  sum : Double
  mean : Double
  minimum : Double
  maximum : Double
  median : Double
  first_quartile : Double
  third_quartile : Double
  variance : Double
  standard_deviation : Double
  median_absolute_deviation : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Summary::count(self : Summary) -> Int {
  self.count
}

///|
pub fn Summary::sum(self : Summary) -> Double {
  self.sum
}

///|
pub fn Summary::mean(self : Summary) -> Double {
  self.mean
}

///|
pub fn Summary::minimum(self : Summary) -> Double {
  self.minimum
}

///|
pub fn Summary::maximum(self : Summary) -> Double {
  self.maximum
}

///|
pub fn Summary::median(self : Summary) -> Double {
  self.median
}

///|
pub fn Summary::first_quartile(self : Summary) -> Double {
  self.first_quartile
}

///|
pub fn Summary::third_quartile(self : Summary) -> Double {
  self.third_quartile
}

///|
pub fn Summary::variance(self : Summary) -> Double {
  self.variance
}

///|
pub fn Summary::standard_deviation(self : Summary) -> Double {
  self.standard_deviation
}

///|
pub fn Summary::median_absolute_deviation(self : Summary) -> Double {
  self.median_absolute_deviation
}

///|
pub fn Summary::is_empty(self : Summary) -> Bool {
  self.count == 0
}

///|
pub fn Summary::range(self : Summary) -> Double {
  self.maximum - self.minimum
}

///|
pub fn Summary::interquartile_range(self : Summary) -> Double {
  self.third_quartile - self.first_quartile
}

///|
pub fn Summary::coefficient_of_variation(self : Summary) -> Double {
  if self.mean == 0.0 {
    0.0
  } else {
    self.standard_deviation / self.mean
  }
}

///|
pub fn Summary::relative_range(self : Summary) -> Double {
  if self.minimum == 0.0 {
    self.range()
  } else {
    self.range() / self.minimum.abs()
  }
}

///|
fn zero_summary() -> Summary {
  Summary::{
    count: 0,
    sum: 0.0,
    mean: 0.0,
    minimum: 0.0,
    maximum: 0.0,
    median: 0.0,
    first_quartile: 0.0,
    third_quartile: 0.0,
    variance: 0.0,
    standard_deviation: 0.0,
    median_absolute_deviation: 0.0,
  }
}

///|
/// Return a sorted copy without changing the caller's time series.
pub fn sorted(values : Array[Double]) -> Array[Double] {
  let result = values.copy()
  result.sort_by((left, right) => left.compare(right))
  result
}

///|
pub fn sum(values : Array[Double]) -> Double {
  values.fold(init=0.0, (total, value) => total + value)
}

///|
pub fn mean(values : Array[Double]) -> Double {
  if values.is_empty() {
    0.0
  } else {
    sum(values) / values.length().to_double()
  }
}

///|
pub fn minimum(values : Array[Double]) -> Double {
  match values.get(0) {
    None => 0.0
    Some(first) =>
      values.fold(init=first, (current, value) => Double::min(current, value))
  }
}

///|
pub fn maximum(values : Array[Double]) -> Double {
  match values.get(0) {
    None => 0.0
    Some(first) =>
      values.fold(init=first, (current, value) => Double::max(current, value))
  }
}

///|
/// Linear interpolation percentile in the inclusive range 0..100.
pub fn percentile(values : Array[Double], percent : Double) -> Double {
  if values.is_empty() {
    0.0
  } else {
    let ordered = sorted(values)
    let p = Double::max(0.0, Double::min(100.0, percent)) / 100.0
    let position = p * (ordered.length() - 1).to_double()
    let lower = position.floor().to_int()
    let upper = position.ceil().to_int()
    if lower == upper {
      ordered[lower]
    } else {
      let fraction = position - lower.to_double()
      ordered[lower] + (ordered[upper] - ordered[lower]) * fraction
    }
  }
}

///|
pub fn median(values : Array[Double]) -> Double {
  percentile(values, 50.0)
}

///|
pub fn variance(values : Array[Double]) -> Double {
  if values.length() < 2 {
    0.0
  } else {
    let center = mean(values)
    values.fold(init=0.0, (total, value) => {
      let delta = value - center
      total + delta * delta
    }) /
    (values.length() - 1).to_double()
  }
}

///|
pub fn standard_deviation(values : Array[Double]) -> Double {
  variance(values).sqrt()
}

///|
pub fn median_absolute_deviation(values : Array[Double]) -> Double {
  let center = median(values)
  median(values.map(value => (value - center).abs()))
}

///|
pub fn describe(values : Array[Double]) -> Summary {
  if values.is_empty() {
    zero_summary()
  } else {
    Summary::{
      count: values.length(),
      sum: sum(values),
      mean: mean(values),
      minimum: minimum(values),
      maximum: maximum(values),
      median: median(values),
      first_quartile: percentile(values, 25.0),
      third_quartile: percentile(values, 75.0),
      variance: variance(values),
      standard_deviation: standard_deviation(values),
      median_absolute_deviation: median_absolute_deviation(values),
    }
  }
}

///|
pub fn trimmed_mean(values : Array[Double], trim_percent : Double) -> Double {
  if values.is_empty() {
    0.0
  } else {
    let ordered = sorted(values)
    let bounded = Double::max(0.0, Double::min(49.0, trim_percent))
    let trim = (ordered.length().to_double() * bounded / 100.0).floor().to_int()
    let end = ordered.length() - trim
    if trim * 2 >= ordered.length() {
      mean(ordered)
    } else {
      mean(ordered[trim:end].to_owned())
    }
  }
}

///|
pub fn z_score(value : Double, values : Array[Double]) -> Double {
  let spread = standard_deviation(values)
  if spread == 0.0 {
    0.0
  } else {
    (value - mean(values)) / spread
  }
}

///|
pub fn z_scores(values : Array[Double]) -> Array[Double] {
  let center = mean(values)
  let spread = standard_deviation(values)
  if spread == 0.0 {
    values.map(_ => 0.0)
  } else {
    values.map(value => (value - center) / spread)
  }
}

///|
pub fn robust_z_score(value : Double, values : Array[Double]) -> Double {
  let center = median(values)
  let mad = median_absolute_deviation(values)
  if mad == 0.0 {
    0.0
  } else {
    0.6745 * (value - center) / mad
  }
}

///|
pub fn robust_z_scores(values : Array[Double]) -> Array[Double] {
  values.map(value => robust_z_score(value, values))
}

///|
pub fn outlier_indices(
  values : Array[Double],
  threshold? : Double = 3.0,
) -> Array[Int] {
  let limit = threshold.abs()
  let scores = robust_z_scores(values)
  let result = []
  for index, score in scores {
    if score.abs() > limit {
      result.push(index)
    }
  }
  result
}

///|
pub fn without_outliers(
  values : Array[Double],
  threshold? : Double = 3.0,
) -> Array[Double] {
  let indices = outlier_indices(values, threshold~)
  let result = []
  for index, value in values {
    if !indices.contains(index) {
      result.push(value)
    }
  }
  result
}

///|
pub fn winsorize(
  values : Array[Double],
  lower_percent : Double,
  upper_percent : Double,
) -> Array[Double] {
  if values.is_empty() {
    []
  } else {
    let lower = percentile(values, lower_percent)
    let upper = percentile(values, upper_percent)
    values.map(value => Double::max(lower, Double::min(upper, value)))
  }
}

///|
pub fn covariance(left : Array[Double], right : Array[Double]) -> Double {
  let size = Int::min(left.length(), right.length())
  if size < 2 {
    0.0
  } else {
    let left_mean = mean(left[:size].to_owned())
    let right_mean = mean(right[:size].to_owned())
    let mut total = 0.0
    for index in 0..<size {
      total += (left[index] - left_mean) * (right[index] - right_mean)
    }
    total / (size - 1).to_double()
  }
}

///|
pub fn correlation(left : Array[Double], right : Array[Double]) -> Double {
  let denominator = standard_deviation(left) * standard_deviation(right)
  if denominator == 0.0 {
    0.0
  } else {
    covariance(left, right) / denominator
  }
}

///|
pub(all) struct LinearModel {
  slope : Double
  intercept : Double
  r_squared : Double
  observations : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn LinearModel::slope(self : LinearModel) -> Double {
  self.slope
}

///|
pub fn LinearModel::intercept(self : LinearModel) -> Double {
  self.intercept
}

///|
pub fn LinearModel::r_squared(self : LinearModel) -> Double {
  self.r_squared
}

///|
pub fn LinearModel::observations(self : LinearModel) -> Int {
  self.observations
}

///|
pub fn LinearModel::predict(self : LinearModel, x : Double) -> Double {
  self.intercept + self.slope * x
}

///|
pub fn fit_linear(x : Array[Double], y : Array[Double]) -> LinearModel {
  let size = Int::min(x.length(), y.length())
  if size == 0 {
    LinearModel::{ slope: 0.0, intercept: 0.0, r_squared: 0.0, observations: 0 }
  } else {
    let xs = x[:size].to_owned()
    let ys = y[:size].to_owned()
    let x_mean = mean(xs)
    let y_mean = mean(ys)
    let mut numerator = 0.0
    let mut denominator = 0.0
    for index in 0..<size {
      let dx = xs[index] - x_mean
      numerator += dx * (ys[index] - y_mean)
      denominator += dx * dx
    }
    let slope = if denominator == 0.0 { 0.0 } else { numerator / denominator }
    let intercept = y_mean - slope * x_mean
    let predicted = xs.map(value => intercept + slope * value)
    let total = ys.fold(init=0.0, (total, value) => {
      let delta = value - y_mean
      total + delta * delta
    })
    let mut residual_sum = 0.0
    for index in 0..<size {
      let delta = ys[index] - predicted[index]
      residual_sum += delta * delta
    }
    let r_squared = if total == 0.0 { 1.0 } else { 1.0 - residual_sum / total }
    LinearModel::{ slope, intercept, r_squared, observations: size }
  }
}

///|
pub fn predictions(model : LinearModel, x : Array[Double]) -> Array[Double] {
  x.map(value => model.predict(value))
}

///|
pub fn residuals(
  model : LinearModel,
  x : Array[Double],
  y : Array[Double],
) -> Array[Double] {
  let size = Int::min(x.length(), y.length())
  let result = []
  for index in 0..<size {
    result.push(y[index] - model.predict(x[index]))
  }
  result
}

///|
pub(all) struct HistogramBin {
  lower : Double
  upper : Double
  count : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn HistogramBin::lower(self : HistogramBin) -> Double {
  self.lower
}

///|
pub fn HistogramBin::upper(self : HistogramBin) -> Double {
  self.upper
}

///|
pub fn HistogramBin::count(self : HistogramBin) -> Int {
  self.count
}

///|
pub fn histogram(
  values : Array[Double],
  bin_count : Int,
) -> Array[HistogramBin] {
  if values.is_empty() || bin_count <= 0 {
    []
  } else {
    let lower = minimum(values)
    let upper = maximum(values)
    let width = if upper == lower {
      1.0
    } else {
      (upper - lower) / bin_count.to_double()
    }
    let counts = Array::make(bin_count, 0)
    for value in values {
      let raw = if width == 0.0 {
        0
      } else {
        ((value - lower) / width).floor().to_int()
      }
      let index = Int::max(0, Int::min(bin_count - 1, raw))
      counts[index] += 1
    }
    let result = []
    for index in 0..<bin_count {
      result.push(HistogramBin::{
        lower: lower + width * index.to_double(),
        upper: if index == bin_count - 1 {
          upper
        } else {
          lower + width * (index + 1).to_double()
        },
        count: counts[index],
      })
    }
    result
  }
}

///|
pub fn histogram_text(values : Array[Double], bin_count : Int) -> String {
  let output = StringBuilder()
  for bin in histogram(values, bin_count) {
    output.write_string(
      "[" +
      bin.lower.to_string() +
      ", " +
      bin.upper.to_string() +
      "] " +
      bin.count.to_string() +
      "\n",
    )
  }
  output.to_string()
}

///|
pub fn rolling_mean(values : Array[Double], window : Int) -> Array[Double] {
  if window <= 0 || values.is_empty() {
    []
  } else {
    let result = []
    for index in 0..<values.length() {
      let start = Int::max(0, index + 1 - window)
      result.push(mean(values[start:index + 1].to_owned()))
    }
    result
  }
}

///|
pub fn rolling_summary(values : Array[Double], window : Int) -> Array[Summary] {
  if window <= 0 || values.is_empty() {
    []
  } else {
    let result = []
    for index in 0..<values.length() {
      let start = Int::max(0, index + 1 - window)
      result.push(describe(values[start:index + 1].to_owned()))
    }
    result
  }
}

///|
pub fn exponential_smoothing(
  values : Array[Double],
  alpha : Double,
) -> Array[Double] {
  if values.is_empty() {
    []
  } else {
    let weight = Double::max(0.0, Double::min(1.0, alpha))
    let result = [values[0]]
    for value in values[1:] {
      result.push(weight * value + (1.0 - weight) * result[result.length() - 1])
    }
    result
  }
}

///|
pub fn cumulative_sum(values : Array[Double]) -> Array[Double] {
  let result = []
  let mut total = 0.0
  for value in values {
    total += value
    result.push(total)
  }
  result
}

///|
pub fn first_difference(values : Array[Double]) -> Array[Double] {
  if values.length() < 2 {
    []
  } else {
    let result = []
    for index in 1..<values.length() {
      result.push(values[index] - values[index - 1])
    }
    result
  }
}

///|
pub fn min_max_scale(values : Array[Double]) -> Array[Double] {
  if values.is_empty() {
    []
  } else {
    let lower = minimum(values)
    let width = maximum(values) - lower
    if width == 0.0 {
      values.map(_ => 0.0)
    } else {
      values.map(value => (value - lower) / width)
    }
  }
}

///|
pub fn standard_scale(values : Array[Double]) -> Array[Double] {
  z_scores(values)
}

///|
pub fn weighted_mean(values : Array[Double], weights : Array[Double]) -> Double {
  let size = Int::min(values.length(), weights.length())
  let mut total = 0.0
  let mut weight_total = 0.0
  for index in 0..<size {
    let weight = Double::max(0.0, weights[index])
    total += values[index] * weight
    weight_total += weight
  }
  if weight_total == 0.0 {
    0.0
  } else {
    total / weight_total
  }
}

///|
pub fn weighted_variance(
  values : Array[Double],
  weights : Array[Double],
) -> Double {
  let center = weighted_mean(values, weights)
  let size = Int::min(values.length(), weights.length())
  let mut total = 0.0
  let mut weight_total = 0.0
  for index in 0..<size {
    let weight = Double::max(0.0, weights[index])
    let delta = values[index] - center
    total += weight * delta * delta
    weight_total += weight
  }
  if weight_total == 0.0 {
    0.0
  } else {
    total / weight_total
  }
}

///|
pub fn rank(values : Array[Double]) -> Array[Int] {
  let ordered = sorted(values)
  values.map(value => {
    let mut position = 0
    for candidate in ordered {
      if candidate < value {
        position += 1
      }
    }
    position + 1
  })
}

///|
pub fn percentile_ranks(values : Array[Double]) -> Array[Double] {
  let n = values.length()
  if n == 0 {
    []
  } else {
    rank(values).map(item => {
      (item - 1).to_double() * 100.0 / (n - 1).to_double()
    })
  }
}

///|
pub fn autocorrelation(values : Array[Double], lag : Int) -> Double {
  if lag <= 0 || lag >= values.length() {
    0.0
  } else {
    correlation(
      values[lag:].to_owned(),
      values[:values.length() - lag].to_owned(),
    )
  }
}

///|
pub fn lagged(values : Array[Double], lag : Int) -> Array[(Double, Double)] {
  if lag < 0 || lag >= values.length() {
    []
  } else {
    let result = []
    for index in lag..<values.length() {
      result.push((values[index - lag], values[index]))
    }
    result
  }
}

///|
pub fn slope(values : Array[Double]) -> Double {
  if values.length() < 2 {
    0.0
  } else {
    let x = Array::make(values.length(), 0.0)
    for index in 0..<x.length() {
      x[index] = index.to_double()
    }
    fit_linear(x, values).slope()
  }
}

///|
pub fn slope_change(values : Array[Double], split : Int) -> Double {
  if split <= 0 || split >= values.length() {
    0.0
  } else {
    slope(values[split:].to_owned()) - slope(values[:split].to_owned())
  }
}

///|
pub fn stable(values : Array[Double], tolerance : Double) -> Bool {
  if values.length() < 2 {
    true
  } else {
    slope(values).abs() <= tolerance.abs()
  }
}

///|
pub fn summary_text(summary : Summary) -> String {
  "n=" +
  summary.count.to_string() +
  ", mean=" +
  summary.mean.to_string() +
  ", median=" +
  summary.median.to_string() +
  ", sd=" +
  summary.standard_deviation.to_string() +
  ", range=" +
  summary.minimum.to_string() +
  ".." +
  summary.maximum.to_string()
}
