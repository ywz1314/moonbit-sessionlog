///|
/// Interval aggregation groups sessions into stable reporting buckets while
/// preserving raw session counts and extrema for drill-down views.
pub(all) enum IntervalKind {
  Day
  Week
  Month
  Quarter
  Year
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn IntervalKind::label(self : IntervalKind) -> String {
  match self {
    Day => "day"
    Week => "week"
    Month => "month"
    Quarter => "quarter"
    Year => "year"
  }
}

///|
fn interval_key(date : String, kind : IntervalKind) -> String {
  match kind {
    IntervalKind::Day => date
    IntervalKind::Week => date[:Int::min(date.length(), 7)].to_owned()
    IntervalKind::Month => date[:Int::min(date.length(), 7)].to_owned()
    IntervalKind::Quarter => {
      let month = if date.length() >= 7 { date[5:7].to_owned() } else { "01" }
      let quarter = match month {
        "01" | "02" | "03" => "Q1"
        "04" | "05" | "06" => "Q2"
        "07" | "08" | "09" => "Q3"
        _ => "Q4"
      }
      date[:Int::min(date.length(), 4)].to_owned() + "-" + quarter
    }
    IntervalKind::Year => date[:Int::min(date.length(), 4)].to_owned()
  }
}

///|
pub(all) struct IntervalAggregate {
  key : String
  kind : IntervalKind
  session_count : Int
  total_duration : Int
  total_reps : Int
  total_sets : Int
  total_work : Int
  average_pain : Double
  average_completion : Double
  minimum_pain : Int
  maximum_pain : Int
  first_date : String
  last_date : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn IntervalAggregate::key(self : IntervalAggregate) -> String {
  self.key
}

///|
pub fn IntervalAggregate::kind(self : IntervalAggregate) -> IntervalKind {
  self.kind
}

///|
pub fn IntervalAggregate::session_count(self : IntervalAggregate) -> Int {
  self.session_count
}

///|
pub fn IntervalAggregate::total_duration(self : IntervalAggregate) -> Int {
  self.total_duration
}

///|
pub fn IntervalAggregate::total_reps(self : IntervalAggregate) -> Int {
  self.total_reps
}

///|
pub fn IntervalAggregate::total_sets(self : IntervalAggregate) -> Int {
  self.total_sets
}

///|
pub fn IntervalAggregate::total_work(self : IntervalAggregate) -> Int {
  self.total_work
}

///|
pub fn IntervalAggregate::average_pain(self : IntervalAggregate) -> Double {
  self.average_pain
}

///|
pub fn IntervalAggregate::average_completion(
  self : IntervalAggregate,
) -> Double {
  self.average_completion
}

///|
pub fn IntervalAggregate::minimum_pain(self : IntervalAggregate) -> Int {
  self.minimum_pain
}

///|
pub fn IntervalAggregate::maximum_pain(self : IntervalAggregate) -> Int {
  self.maximum_pain
}

///|
pub fn IntervalAggregate::first_date(self : IntervalAggregate) -> String {
  self.first_date
}

///|
pub fn IntervalAggregate::last_date(self : IntervalAggregate) -> String {
  self.last_date
}

///|
fn aggregate_session(
  value : @core.Session,
  kind : IntervalKind,
) -> IntervalAggregate {
  IntervalAggregate::{
    key: interval_key(value.date, kind),
    kind,
    session_count: 1,
    total_duration: value.duration,
    total_reps: value.total_reps(),
    total_sets: value.total_sets(),
    total_work: value.movements.fold(init=0, (total, movement) => {
      total + movement.work_units()
    }),
    average_pain: value.average_pain_during(),
    average_completion: value.average_completion(),
    minimum_pain: Int::min(value.pain_before, value.pain_after),
    maximum_pain: Int::max(value.pain_before, value.pain_after),
    first_date: value.date,
    last_date: value.date,
  }
}

///|
fn merge_aggregate(
  left : IntervalAggregate,
  right : IntervalAggregate,
) -> IntervalAggregate {
  let count = left.session_count + right.session_count
  IntervalAggregate::{
    key: left.key,
    kind: left.kind,
    session_count: count,
    total_duration: left.total_duration + right.total_duration,
    total_reps: left.total_reps + right.total_reps,
    total_sets: left.total_sets + right.total_sets,
    total_work: left.total_work + right.total_work,
    average_pain: (
      left.average_pain * left.session_count.to_double() +
      right.average_pain * right.session_count.to_double()
    ) /
    count.to_double(),
    average_completion: (
      left.average_completion * left.session_count.to_double() +
      right.average_completion * right.session_count.to_double()
    ) /
    count.to_double(),
    minimum_pain: Int::min(left.minimum_pain, right.minimum_pain),
    maximum_pain: Int::max(left.maximum_pain, right.maximum_pain),
    first_date: if left.first_date < right.first_date {
      left.first_date
    } else {
      right.first_date
    },
    last_date: if left.last_date > right.last_date {
      left.last_date
    } else {
      right.last_date
    },
  }
}

///|
pub fn aggregate_intervals(
  sessions : Array[@core.Session],
  kind : IntervalKind,
) -> Array[IntervalAggregate] {
  let result : Array[IntervalAggregate] = []
  for session in sessions {
    let current = aggregate_session(session, kind)
    match result.search_by(value => value.key == current.key) {
      Some(index) => result[index] = merge_aggregate(result[index], current)
      None => result.push(current)
    }
  }
  result.sort_by((left, right) => left.key.compare(right.key))
  result
}

///|
pub fn aggregate_interval(
  value : Array[IntervalAggregate],
  key : String,
) -> IntervalAggregate? {
  match value.search_by(item => item.key == key) {
    Some(index) => Some(value[index])
    None => None
  }
}

///|
pub fn aggregate_completion(values : Array[IntervalAggregate]) -> Double {
  if values.is_empty() {
    0.0
  } else {
    let total = values.fold(init=0.0, (sum, value) => {
      sum + value.average_completion * value.session_count.to_double()
    })
    total /
    values.fold(init=0, (sum, value) => sum + value.session_count).to_double()
  }
}

///|
pub fn aggregate_pain_delta(value : IntervalAggregate) -> Int {
  value.maximum_pain - value.minimum_pain
}

///|
pub fn aggregate_peak_work(
  values : Array[IntervalAggregate],
) -> IntervalAggregate? {
  let mut best : IntervalAggregate? = None
  for value in values {
    match best {
      Some(current) =>
        if value.total_work > current.total_work {
          best = Some(value)
        }
      None => best = Some(value)
    }
  }
  best
}

///|
pub fn aggregate_sparse(
  values : Array[IntervalAggregate],
  minimum_sessions : Int,
) -> Array[IntervalAggregate] {
  values.filter(value => value.session_count < minimum_sessions)
}

///|
pub fn interval_aggregate_text(values : Array[IntervalAggregate]) -> String {
  let output = StringBuilder()
  for value in values {
    output.write_string(
      value.key +
      " sessions=" +
      value.session_count.to_string() +
      " reps=" +
      value.total_reps.to_string() +
      " pain=" +
      value.average_pain.to_string() +
      "\n",
    )
  }
  output.to_string()
}

///|
pub fn aggregate_checksum(values : Array[IntervalAggregate]) -> Int {
  values.fold(init=31, (total, value) => {
    total * 31 + value.key.length() + value.total_reps + value.total_work
  })
}
