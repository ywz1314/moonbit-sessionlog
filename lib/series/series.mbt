///|
pub(all) struct SeriesPoint {
  date : String
  session_id : String
  reps : Int
  work_units : Int
  average_pain : Double
  completion : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SeriesPoint::date(self : SeriesPoint) -> String {
  self.date
}

///|
pub fn SeriesPoint::session_id(self : SeriesPoint) -> String {
  self.session_id
}

///|
pub fn SeriesPoint::reps(self : SeriesPoint) -> Int {
  self.reps
}

///|
pub fn SeriesPoint::work_units(self : SeriesPoint) -> Int {
  self.work_units
}

///|
pub fn SeriesPoint::average_pain(self : SeriesPoint) -> Double {
  self.average_pain
}

///|
pub fn SeriesPoint::completion(self : SeriesPoint) -> Double {
  self.completion
}

///|
pub(all) struct SessionSeries {
  points : Array[SeriesPoint]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SessionSeries::points(self : SessionSeries) -> Array[SeriesPoint] {
  self.points
}

///|
pub fn from_sessions(sessions : Array[@core.Session]) -> SessionSeries {
  SessionSeries::{
    points: sessions.map(session => {
      let work = session.movements.fold(init=0, (total, movement) => {
        total + movement.work_units()
      })
      SeriesPoint::{
        date: session.date,
        session_id: session.id,
        reps: session.total_reps(),
        work_units: work,
        average_pain: session.average_pain_during(),
        completion: session.average_completion(),
      }
    }),
  }
}

///|
pub fn sorted(series : SessionSeries) -> SessionSeries {
  let points = series.points.copy()
  points.sort_by((left, right) => left.date.compare(right.date))
  SessionSeries::{ points, }
}

///|
pub fn select(
  series : SessionSeries,
  start : String,
  end : String,
) -> SessionSeries {
  SessionSeries::{
    points: series.points.filter(point => {
      point.date >= start && point.date <= end
    }),
  }
}

///|
pub fn count(series : SessionSeries) -> Int {
  series.points.length()
}

///|
pub fn total_reps(series : SessionSeries) -> Int {
  series.points.fold(init=0, (total, point) => total + point.reps)
}

///|
pub fn total_work_units(series : SessionSeries) -> Int {
  series.points.fold(init=0, (total, point) => total + point.work_units)
}

///|
pub fn average_pain(series : SessionSeries) -> Double {
  if series.points.is_empty() {
    0.0
  } else {
    series.points.fold(init=0.0, (total, point) => total + point.average_pain) /
    count(series).to_double()
  }
}

///|
pub fn average_completion(series : SessionSeries) -> Double {
  if series.points.is_empty() {
    0.0
  } else {
    series.points.fold(init=0.0, (total, point) => total + point.completion) /
    count(series).to_double()
  }
}

///|
pub fn first(series : SessionSeries) -> SeriesPoint? {
  series.points.get(0)
}

///|
pub fn last(series : SessionSeries) -> SeriesPoint? {
  series.points.last()
}

///|
pub fn min_pain(series : SessionSeries) -> Double {
  series.points.fold(init=10.0, (value, point) => {
    Double::min(value, point.average_pain)
  })
}

///|
pub fn max_pain(series : SessionSeries) -> Double {
  series.points.fold(init=0.0, (value, point) => {
    Double::max(value, point.average_pain)
  })
}

///|
pub fn min_completion(series : SessionSeries) -> Double {
  series.points.fold(init=1.0, (value, point) => {
    Double::min(value, point.completion)
  })
}

///|
pub fn max_completion(series : SessionSeries) -> Double {
  series.points.fold(init=0.0, (value, point) => {
    Double::max(value, point.completion)
  })
}

///|
pub fn pain_delta(series : SessionSeries) -> Double {
  match (first(series), last(series)) {
    (Some(first), Some(last)) => last.average_pain - first.average_pain
    _ => 0.0
  }
}

///|
pub fn completion_delta(series : SessionSeries) -> Double {
  match (first(series), last(series)) {
    (Some(first), Some(last)) => last.completion - first.completion
    _ => 0.0
  }
}

///|
pub fn work_delta(series : SessionSeries) -> Int {
  match (first(series), last(series)) {
    (Some(first), Some(last)) => last.work_units - first.work_units
    _ => 0
  }
}

///|
pub fn pain_values(series : SessionSeries) -> Array[Double] {
  series.points.map(point => point.average_pain)
}

///|
pub fn completion_values(series : SessionSeries) -> Array[Double] {
  series.points.map(point => point.completion)
}

///|
pub fn work_values(series : SessionSeries) -> Array[Int] {
  series.points.map(point => point.work_units)
}

///|
pub fn above_pain(
  series : SessionSeries,
  threshold : Double,
) -> Array[SeriesPoint] {
  series.points.filter(point => point.average_pain >= threshold)
}

///|
pub fn below_completion(
  series : SessionSeries,
  threshold : Double,
) -> Array[SeriesPoint] {
  series.points.filter(point => point.completion < threshold)
}

///|
pub fn best_completion(series : SessionSeries) -> SeriesPoint? {
  let mut best : SeriesPoint? = None
  let mut value = -1.0
  for point in series.points {
    if point.completion > value {
      best = Some(point)
      value = point.completion
    }
  }
  best
}

///|
pub fn highest_load(series : SessionSeries) -> SeriesPoint? {
  let mut best : SeriesPoint? = None
  let mut value = -1
  for point in series.points {
    if point.work_units > value {
      best = Some(point)
      value = point.work_units
    }
  }
  best
}

///|
pub fn text(series : SessionSeries) -> String {
  let output = StringBuilder()
  for point in sorted(series).points {
    output.write_string(
      point.date +
      " " +
      point.session_id +
      " reps=" +
      point.reps.to_string() +
      "\n",
    )
  }
  output.to_string()
}
