///|
/// Rolling views are index-based and therefore deterministic even when a
/// dataset contains sparse dates.  Callers can choose a window size that
/// matches a reporting cadence without inventing missing sessions.
pub(all) enum SeriesMetric {
  Reps
  Work
  Pain
  Completion
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SeriesMetric::label(self : SeriesMetric) -> String {
  match self {
    Reps => "reps"
    Work => "work"
    Pain => "pain"
    Completion => "completion"
  }
}

///|
pub fn SeriesMetric::value(self : SeriesMetric, point : SeriesPoint) -> Double {
  match self {
    Reps => point.reps.to_double()
    Work => point.work_units.to_double()
    Pain => point.average_pain
    Completion => point.completion
  }
}

///|
pub(all) struct RollingPoint {
  index : Int
  date : String
  session_id : String
  metric : SeriesMetric
  value : Double
  window_size : Int
  window_mean : Double
  window_median : Double
  window_min : Double
  window_max : Double
  window_stddev : Double
  delta : Double
  z_score : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RollingPoint::index(self : RollingPoint) -> Int {
  self.index
}

///|
pub fn RollingPoint::date(self : RollingPoint) -> String {
  self.date
}

///|
pub fn RollingPoint::session_id(self : RollingPoint) -> String {
  self.session_id
}

///|
pub fn RollingPoint::metric(self : RollingPoint) -> SeriesMetric {
  self.metric
}

///|
pub fn RollingPoint::value(self : RollingPoint) -> Double {
  self.value
}

///|
pub fn RollingPoint::window_size(self : RollingPoint) -> Int {
  self.window_size
}

///|
pub fn RollingPoint::window_mean(self : RollingPoint) -> Double {
  self.window_mean
}

///|
pub fn RollingPoint::window_median(self : RollingPoint) -> Double {
  self.window_median
}

///|
pub fn RollingPoint::window_min(self : RollingPoint) -> Double {
  self.window_min
}

///|
pub fn RollingPoint::window_max(self : RollingPoint) -> Double {
  self.window_max
}

///|
pub fn RollingPoint::window_stddev(self : RollingPoint) -> Double {
  self.window_stddev
}

///|
pub fn RollingPoint::delta(self : RollingPoint) -> Double {
  self.delta
}

///|
pub fn RollingPoint::z_score(self : RollingPoint) -> Double {
  self.z_score
}

///|
pub(all) struct RollingSeries {
  metric : SeriesMetric
  window : Int
  points : Array[RollingPoint]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RollingSeries::metric(self : RollingSeries) -> SeriesMetric {
  self.metric
}

///|
pub fn RollingSeries::window(self : RollingSeries) -> Int {
  self.window
}

///|
pub fn RollingSeries::points(self : RollingSeries) -> Array[RollingPoint] {
  self.points.copy()
}

///|
fn values_in_window(
  series : SessionSeries,
  metric : SeriesMetric,
  index : Int,
  window : Int,
) -> Array[Double] {
  let start = Int::max(0, index - window + 1)
  let values : Array[Double] = []
  let mut cursor = start
  while cursor <= index {
    values.push(metric.value(series.points[cursor]))
    cursor += 1
  }
  values
}

///|
fn safe_stddev(values : Array[Double]) -> Double {
  @statistics.standard_deviation(values)
}

///|
pub fn rolling(
  series : SessionSeries,
  metric : SeriesMetric,
  window : Int,
) -> Result[RollingSeries, String] {
  if window <= 0 {
    return Err("window must be positive")
  }
  let source = sorted(series)
  let points = []
  for index, point in source.points {
    let values = values_in_window(source, metric, index, window)
    let summary = @statistics.describe(values)
    let previous = if index == 0 {
      let point_value = metric.value(point)
      point_value
    } else {
      metric.value(source.points[index - 1])
    }
    let mean = @statistics.mean(values)
    let deviation = safe_stddev(values)
    let z = if deviation == 0.0 {
      0.0
    } else {
      (metric.value(point) - mean) / deviation
    }
    points.push(RollingPoint::{
      index,
      date: point.date,
      session_id: point.session_id,
      metric,
      value: metric.value(point),
      window_size: values.length(),
      window_mean: mean,
      window_median: @statistics.median(values),
      window_min: summary.minimum,
      window_max: summary.maximum,
      window_stddev: deviation,
      delta: metric.value(point) - previous,
      z_score: z,
    })
  }
  Ok(RollingSeries::{ metric, window, points })
}

///|
pub fn rolling_or_empty(
  series : SessionSeries,
  metric : SeriesMetric,
  window : Int,
) -> RollingSeries {
  match rolling(series, metric, window) {
    Ok(value) => value
    Err(_) => RollingSeries::{ metric, window: Int::max(1, window), points: [] }
  }
}

///|
pub fn rolling_values(value : RollingSeries) -> Array[Double] {
  value.points.map(point => point.window_mean)
}

///|
pub fn rolling_deltas(value : RollingSeries) -> Array[Double] {
  value.points.map(point => point.delta)
}

///|
pub fn rolling_anomalies(
  value : RollingSeries,
  threshold : Double,
) -> Array[RollingPoint] {
  value.points.filter(point => point.z_score.abs() >= threshold)
}

///|
pub fn rolling_improvements(value : RollingSeries) -> Array[RollingPoint] {
  match value.metric {
    SeriesMetric::Pain => value.points.filter(point => point.delta < 0.0)
    _ => value.points.filter(point => point.delta > 0.0)
  }
}

///|
pub fn rolling_declines(value : RollingSeries) -> Array[RollingPoint] {
  match value.metric {
    SeriesMetric::Pain => value.points.filter(point => point.delta > 0.0)
    _ => value.points.filter(point => point.delta < 0.0)
  }
}

///|
pub fn rolling_slope(value : RollingSeries) -> Double {
  let xs = value.points.map(point => point.index.to_double())
  let ys = value.points.map(point => point.value)
  @statistics.fit_linear(xs, ys).slope
}

///|
pub fn rolling_stability(value : RollingSeries) -> Double {
  let values = value.points.map(point => point.value)
  let deviation = @statistics.standard_deviation(values)
  1.0 / (1.0 + deviation)
}

///|
pub fn rolling_text(value : RollingSeries) -> String {
  let output = StringBuilder()
  output.write_string(
    value.metric.label() + " window=" + value.window.to_string() + "\n",
  )
  for point in value.points {
    output.write_string(
      point.date +
      " " +
      point.session_id +
      " value=" +
      point.value.to_string() +
      " mean=" +
      point.window_mean.to_string() +
      " z=" +
      point.z_score.to_string() +
      "\n",
    )
  }
  output.to_string()
}

///|
pub(all) struct ExponentialPoint {
  index : Int
  date : String
  session_id : String
  metric : SeriesMetric
  value : Double
  smoothed : Double
  residual : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ExponentialPoint::index(self : ExponentialPoint) -> Int {
  self.index
}

///|
pub fn ExponentialPoint::date(self : ExponentialPoint) -> String {
  self.date
}

///|
pub fn ExponentialPoint::session_id(self : ExponentialPoint) -> String {
  self.session_id
}

///|
pub fn ExponentialPoint::metric(self : ExponentialPoint) -> SeriesMetric {
  self.metric
}

///|
pub fn ExponentialPoint::value(self : ExponentialPoint) -> Double {
  self.value
}

///|
pub fn ExponentialPoint::smoothed(self : ExponentialPoint) -> Double {
  self.smoothed
}

///|
pub fn ExponentialPoint::residual(self : ExponentialPoint) -> Double {
  self.residual
}

///|
pub fn exponential(
  series : SessionSeries,
  metric : SeriesMetric,
  alpha : Double,
) -> Result[Array[ExponentialPoint], String] {
  if alpha <= 0.0 || alpha > 1.0 {
    return Err("alpha must be in (0, 1]")
  }
  let source = sorted(series)
  let points = []
  let mut previous = 0.0
  for index, point in source.points {
    let value = metric.value(point)
    let smoothed = if index == 0 {
      value
    } else {
      alpha * value + (1.0 - alpha) * previous
    }
    points.push(ExponentialPoint::{
      index,
      date: point.date,
      session_id: point.session_id,
      metric,
      value,
      smoothed,
      residual: value - smoothed,
    })
    previous = smoothed
  }
  Ok(points)
}

///|
pub fn exponential_values(points : Array[ExponentialPoint]) -> Array[Double] {
  points.map(point => point.smoothed)
}

///|
pub fn exponential_error(points : Array[ExponentialPoint]) -> Double {
  if points.is_empty() {
    0.0
  } else {
    points.fold(init=0.0, (total, point) => total + point.residual.abs()) /
    points.length().to_double()
  }
}

///|
pub(all) struct ChangePoint {
  index : Int
  date : String
  session_id : String
  before_mean : Double
  after_mean : Double
  change : Double
  direction : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ChangePoint::index(self : ChangePoint) -> Int {
  self.index
}

///|
pub fn ChangePoint::date(self : ChangePoint) -> String {
  self.date
}

///|
pub fn ChangePoint::session_id(self : ChangePoint) -> String {
  self.session_id
}

///|
pub fn ChangePoint::before_mean(self : ChangePoint) -> Double {
  self.before_mean
}

///|
pub fn ChangePoint::after_mean(self : ChangePoint) -> Double {
  self.after_mean
}

///|
pub fn ChangePoint::change(self : ChangePoint) -> Double {
  self.change
}

///|
pub fn ChangePoint::direction(self : ChangePoint) -> String {
  self.direction
}

///|
pub fn change_points(
  series : SessionSeries,
  metric : SeriesMetric,
  half_window : Int,
  minimum_change : Double,
) -> Result[Array[ChangePoint], String] {
  if half_window <= 0 {
    return Err("half_window must be positive")
  }
  let source = sorted(series)
  let result = []
  if source.points.length() <= half_window * 2 {
    return Ok(result)
  }
  let mut index = half_window
  while index < source.points.length() - half_window {
    let before = []
    let after = []
    let mut cursor = index - half_window
    while cursor < index {
      before.push(metric.value(source.points[cursor]))
      cursor += 1
    }
    cursor = index
    while cursor < index + half_window {
      after.push(metric.value(source.points[cursor]))
      cursor += 1
    }
    let before_mean = @statistics.mean(before)
    let after_mean = @statistics.mean(after)
    let change = after_mean - before_mean
    if change.abs() >= minimum_change {
      result.push(ChangePoint::{
        index,
        date: source.points[index].date,
        session_id: source.points[index].session_id,
        before_mean,
        after_mean,
        change,
        direction: if change > 0.0 {
          "up"
        } else {
          "down"
        },
      })
    }
    index += 1
  }
  Ok(result)
}

///|
pub fn change_point_count(points : Array[ChangePoint]) -> Int {
  points.length()
}

///|
pub fn change_point_text(points : Array[ChangePoint]) -> String {
  points
  .map(point => {
    point.date + " " + point.direction + " " + point.change.to_string()
  })
  .join("\n")
}

///|
pub(all) struct SeriesWindow {
  start_index : Int
  end_index : Int
  start_date : String
  end_date : String
  count : Int
  mean : Double
  median : Double
  minimum : Double
  maximum : Double
  total : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SeriesWindow::start_index(self : SeriesWindow) -> Int {
  self.start_index
}

///|
pub fn SeriesWindow::end_index(self : SeriesWindow) -> Int {
  self.end_index
}

///|
pub fn SeriesWindow::start_date(self : SeriesWindow) -> String {
  self.start_date
}

///|
pub fn SeriesWindow::end_date(self : SeriesWindow) -> String {
  self.end_date
}

///|
pub fn SeriesWindow::count(self : SeriesWindow) -> Int {
  self.count
}

///|
pub fn SeriesWindow::mean(self : SeriesWindow) -> Double {
  self.mean
}

///|
pub fn SeriesWindow::median(self : SeriesWindow) -> Double {
  self.median
}

///|
pub fn SeriesWindow::minimum(self : SeriesWindow) -> Double {
  self.minimum
}

///|
pub fn SeriesWindow::maximum(self : SeriesWindow) -> Double {
  self.maximum
}

///|
pub fn SeriesWindow::total(self : SeriesWindow) -> Double {
  self.total
}

///|
pub fn windows(
  series : SessionSeries,
  metric : SeriesMetric,
  size : Int,
) -> Result[Array[SeriesWindow], String] {
  if size <= 0 {
    return Err("size must be positive")
  }
  let source = sorted(series)
  let result = []
  let mut start = 0
  while start < source.points.length() {
    let end = Int::min(start + size, source.points.length())
    let values = []
    for index in start..<end {
      values.push(metric.value(source.points[index]))
    }
    let summary = @statistics.describe(values)
    result.push(SeriesWindow::{
      start_index: start,
      end_index: end - 1,
      start_date: source.points[start].date,
      end_date: source.points[end - 1].date,
      count: values.length(),
      mean: summary.mean,
      median: @statistics.median(values),
      minimum: summary.minimum,
      maximum: summary.maximum,
      total: @statistics.sum(values),
    })
    start = end
  }
  Ok(result)
}

///|
pub fn window_means(value : Array[SeriesWindow]) -> Array[Double] {
  value.map(window => window.mean)
}

///|
pub fn window_text(value : Array[SeriesWindow]) -> String {
  value
  .map(window => {
    window.start_date +
    ".." +
    window.end_date +
    " mean=" +
    window.mean.to_string()
  })
  .join("\n")
}

///|
pub fn resample_mean(
  series : SessionSeries,
  metric : SeriesMetric,
  bucket_size : Int,
) -> Result[Array[SeriesWindow], String] {
  windows(series, metric, bucket_size)
}

///|
pub fn resample_total(
  series : SessionSeries,
  metric : SeriesMetric,
  bucket_size : Int,
) -> Result[Array[Double], String] {
  match windows(series, metric, bucket_size) {
    Ok(values) => Ok(values.map(window => window.total))
    Err(error) => Err(error)
  }
}

///|
pub fn metric_values(
  series : SessionSeries,
  metric : SeriesMetric,
) -> Array[Double] {
  sorted(series).points.map(point => metric.value(point))
}

///|
pub fn metric_summary(
  series : SessionSeries,
  metric : SeriesMetric,
) -> @statistics.Summary {
  @statistics.describe(metric_values(series, metric))
}

///|
pub fn compare_windows(left : SeriesWindow, right : SeriesWindow) -> Double {
  right.mean - left.mean
}

///|
pub fn rolling_report(series : SessionSeries, window : Int) -> String {
  let lines = []
  for
    metric in [
      SeriesMetric::Reps,
      SeriesMetric::Work,
      SeriesMetric::Pain,
      SeriesMetric::Completion,
    ] {
    match rolling(series, metric, window) {
      Ok(value) =>
        lines.push(
          metric.label() + " slope=" + rolling_slope(value).to_string(),
        )
      Err(error) => lines.push(metric.label() + " error=" + error)
    }
  }
  lines.join("\n")
}
