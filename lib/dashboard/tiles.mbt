///|
/// Tile helpers provide compact visual primitives for clients that do not
/// want to render the full dashboard model.
pub(all) struct HeatCell {
  key : String
  value : Double
  count : Int
  level : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn HeatCell::key(self : HeatCell) -> String {
  self.key
}

///|
pub fn HeatCell::value(self : HeatCell) -> Double {
  self.value
}

///|
pub fn HeatCell::count(self : HeatCell) -> Int {
  self.count
}

///|
pub fn HeatCell::level(self : HeatCell) -> String {
  self.level
}

///|
fn heat_level(value : Double) -> String {
  if value >= 8.0 {
    "critical"
  } else if value >= 6.0 {
    "high"
  } else if value >= 3.0 {
    "moderate"
  } else {
    "low"
  }
}

///|
pub fn pain_heatmap(sessions : Array[@core.Session]) -> Array[HeatCell] {
  let cells : Array[HeatCell] = []
  for session in sessions {
    let key = session.date
    match cells.search_by(cell => cell.key == key) {
      Some(index) => {
        let old = cells[index]
        let count = old.count + 1
        let value = (
            old.value * old.count.to_double() + session.average_pain_during()
          ) /
          count.to_double()
        cells[index] = HeatCell::{ key, value, count, level: heat_level(value) }
      }
      None =>
        cells.push(HeatCell::{
          key,
          value: session.average_pain_during(),
          count: 1,
          level: heat_level(session.average_pain_during()),
        })
    }
  }
  cells.sort_by((left, right) => left.key.compare(right.key))
  cells
}

///|
pub fn completion_heatmap(sessions : Array[@core.Session]) -> Array[HeatCell] {
  let cells : Array[HeatCell] = []
  for session in sessions {
    let key = session.date
    let value = session.average_completion() * 100.0
    match cells.search_by(cell => cell.key == key) {
      Some(index) => {
        let old = cells[index]
        let count = old.count + 1
        let average = (old.value * old.count.to_double() + value) /
          count.to_double()
        cells[index] = HeatCell::{
          key,
          value: average,
          count,
          level: if average >= 80.0 {
            "high"
          } else if average >= 50.0 {
            "moderate"
          } else {
            "low"
          },
        }
      }
      None =>
        cells.push(HeatCell::{
          key,
          value,
          count: 1,
          level: if value >= 80.0 {
            "high"
          } else if value >= 50.0 {
            "moderate"
          } else {
            "low"
          },
        })
    }
  }
  cells.sort_by((left, right) => left.key.compare(right.key))
  cells
}

///|
pub fn heatmap_extrema(values : Array[HeatCell]) -> (HeatCell?, HeatCell?) {
  let mut minimum : HeatCell? = None
  let mut maximum : HeatCell? = None
  for value in values {
    match minimum {
      Some(old) => if value.value < old.value { minimum = Some(value) }
      None => minimum = Some(value)
    }
    match maximum {
      Some(old) => if value.value > old.value { maximum = Some(value) }
      None => maximum = Some(value)
    }
  }
  (minimum, maximum)
}

///|
pub fn heatmap_text(values : Array[HeatCell]) -> String {
  values
  .map(value => value.key + "=" + value.value.to_string() + " " + value.level)
  .join("\n")
}
