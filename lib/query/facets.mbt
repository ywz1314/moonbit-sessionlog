///|
/// Facets are compact distributions used by search UIs and data-quality
/// reports.  They preserve counts while keeping the query layer read-only.
pub(all) struct FacetBucket {
  key : String
  count : Int
  percentage : Double
  first_date : String
  last_date : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn FacetBucket::key(self : FacetBucket) -> String {
  self.key
}

///|
pub fn FacetBucket::count(self : FacetBucket) -> Int {
  self.count
}

///|
pub fn FacetBucket::percentage(self : FacetBucket) -> Double {
  self.percentage
}

///|
pub fn FacetBucket::first_date(self : FacetBucket) -> String {
  self.first_date
}

///|
pub fn FacetBucket::last_date(self : FacetBucket) -> String {
  self.last_date
}

///|
pub(all) struct FacetSet {
  total : Int
  buckets : Array[FacetBucket]
  selected : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn FacetSet::total(self : FacetSet) -> Int {
  self.total
}

///|
pub fn FacetSet::buckets(self : FacetSet) -> Array[FacetBucket] {
  self.buckets.copy()
}

///|
pub fn FacetSet::selected(self : FacetSet) -> String? {
  self.selected
}

///|
fn facet_from_pairs(pairs : Array[(String, String)]) -> FacetSet {
  let buckets : Array[FacetBucket] = []
  for pair in pairs {
    match buckets.search_by(bucket => bucket.key == pair.1) {
      Some(index) => {
        let old = buckets[index]
        buckets[index] = FacetBucket::{
          key: old.key,
          count: old.count + 1,
          percentage: 0.0,
          first_date: if pair.0 < old.first_date {
            pair.0
          } else {
            old.first_date
          },
          last_date: if pair.0 > old.last_date {
            pair.0
          } else {
            old.last_date
          },
        }
      }
      None =>
        buckets.push(FacetBucket::{
          key: pair.1,
          count: 1,
          percentage: 0.0,
          first_date: pair.0,
          last_date: pair.0,
        })
    }
  }
  let total = pairs.length()
  for index, bucket in buckets {
    buckets[index] = FacetBucket::{
      key: bucket.key,
      count: bucket.count,
      percentage: if total == 0 {
        0.0
      } else {
        bucket.count.to_double() * 100.0 / total.to_double()
      },
      first_date: bucket.first_date,
      last_date: bucket.last_date,
    }
  }
  buckets.sort_by((left, right) => right.count - left.count)
  FacetSet::{ total, buckets, selected: None }
}

///|
pub fn facet_with_selection(value : FacetSet, selected : String) -> FacetSet {
  FacetSet::{
    total: value.total,
    buckets: value.buckets,
    selected: Some(selected),
  }
}

///|
pub fn date_facet(sessions : Array[@core.Session]) -> FacetSet {
  facet_from_pairs(sessions.map(session => (session.date, session.date)))
}

///|
pub fn pain_band_facet(
  sessions : Array[@core.Session],
  width : Int,
) -> FacetSet {
  let safe_width = Int::max(1, width)
  facet_from_pairs(
    sessions.map(session => {
      let pain = session.average_pain_during().floor().to_int()
      let lower = pain / safe_width * safe_width
      (
        session.date,
        lower.to_string() + "-" + (lower + safe_width - 1).to_string(),
      )
    }),
  )
}

///|
pub fn duration_band_facet(
  sessions : Array[@core.Session],
  width : Int,
) -> FacetSet {
  let safe_width = Int::max(1, width)
  facet_from_pairs(
    sessions.map(session => {
      let lower = session.duration / safe_width * safe_width
      (
        session.date,
        lower.to_string() + "-" + (lower + safe_width - 1).to_string() + " min",
      )
    }),
  )
}

///|
pub fn completion_band_facet(sessions : Array[@core.Session]) -> FacetSet {
  facet_from_pairs(
    sessions.map(session => {
      let completion = session.average_completion()
      let label = if completion < 0.25 {
        "0-25%"
      } else if completion < 0.5 {
        "25-50%"
      } else if completion < 0.75 {
        "50-75%"
      } else {
        "75-100%"
      }
      (session.date, label)
    }),
  )
}

///|
pub fn movement_facet(sessions : Array[@core.Session]) -> FacetSet {
  let pairs : Array[(String, String)] = []
  for session in sessions {
    for movement in session.movements {
      pairs.push((session.date, movement.name))
    }
  }
  facet_from_pairs(pairs)
}

///|
pub fn tag_facet(sessions : Array[@core.Session]) -> FacetSet {
  let pairs : Array[(String, String)] = []
  for session in sessions {
    for word in session.notes.split(" ") {
      let tag = word.to_owned().trim().to_owned()
      if tag.has_prefix("#") && tag.length() > 1 {
        pairs.push((session.date, tag))
      }
    }
  }
  facet_from_pairs(pairs)
}

///|
pub fn facet_keys(value : FacetSet) -> Array[String] {
  value.buckets.map(bucket => bucket.key)
}

///|
pub fn facet_count(value : FacetSet, key : String) -> Int {
  match value.buckets.search_by(bucket => bucket.key == key) {
    Some(index) => value.buckets[index].count
    None => 0
  }
}

///|
pub fn facet_top(value : FacetSet, limit : Int) -> Array[FacetBucket] {
  value.buckets[:Int::min(Int::max(0, limit), value.buckets.length())].to_owned()
}

///|
pub fn facet_filter(value : FacetSet, minimum_count : Int) -> FacetSet {
  FacetSet::{
    total: value.total,
    buckets: value.buckets.filter(bucket => bucket.count >= minimum_count),
    selected: value.selected,
  }
}

///|
pub fn facet_text(value : FacetSet) -> String {
  let output = StringBuilder()
  for bucket in value.buckets {
    output.write_string(
      bucket.key +
      "=" +
      bucket.count.to_string() +
      " (" +
      bucket.percentage.to_string() +
      "%)\n",
    )
  }
  output.to_string()
}

///|
pub(all) struct QueryFacetReport {
  date : FacetSet
  pain : FacetSet
  duration : FacetSet
  completion : FacetSet
  movement : FacetSet
  tags : FacetSet
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn build_facets(sessions : Array[@core.Session]) -> QueryFacetReport {
  QueryFacetReport::{
    date: date_facet(sessions),
    pain: pain_band_facet(sessions, 2),
    duration: duration_band_facet(sessions, 15),
    completion: completion_band_facet(sessions),
    movement: movement_facet(sessions),
    tags: tag_facet(sessions),
  }
}

///|
pub fn QueryFacetReport::date(self : QueryFacetReport) -> FacetSet {
  self.date
}

///|
pub fn QueryFacetReport::pain(self : QueryFacetReport) -> FacetSet {
  self.pain
}

///|
pub fn QueryFacetReport::duration(self : QueryFacetReport) -> FacetSet {
  self.duration
}

///|
pub fn QueryFacetReport::completion(self : QueryFacetReport) -> FacetSet {
  self.completion
}

///|
pub fn QueryFacetReport::movement(self : QueryFacetReport) -> FacetSet {
  self.movement
}

///|
pub fn QueryFacetReport::tags(self : QueryFacetReport) -> FacetSet {
  self.tags
}

///|
pub fn facet_report_text(value : QueryFacetReport) -> String {
  "dates=" +
  value.date.buckets.length().to_string() +
  ", pain=" +
  value.pain.buckets.length().to_string() +
  ", duration=" +
  value.duration.buckets.length().to_string() +
  ", completion=" +
  value.completion.buckets.length().to_string() +
  ", movements=" +
  value.movement.buckets.length().to_string() +
  ", tags=" +
  value.tags.buckets.length().to_string()
}
