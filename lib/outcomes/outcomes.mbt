///|
/// A configurable patient-reported outcome instrument.
pub(all) struct OutcomeInstrument {
  code : String
  name : String
  minimum : Double
  maximum : Double
  lower_is_better : Bool
  meaningful_change : Double
  item_count : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn OutcomeInstrument::code(self : OutcomeInstrument) -> String {
  self.code
}

///|
pub fn OutcomeInstrument::name(self : OutcomeInstrument) -> String {
  self.name
}

///|
pub fn OutcomeInstrument::minimum(self : OutcomeInstrument) -> Double {
  self.minimum
}

///|
pub fn OutcomeInstrument::maximum(self : OutcomeInstrument) -> Double {
  self.maximum
}

///|
pub fn OutcomeInstrument::lower_is_better(self : OutcomeInstrument) -> Bool {
  self.lower_is_better
}

///|
pub fn OutcomeInstrument::meaningful_change(self : OutcomeInstrument) -> Double {
  self.meaningful_change
}

///|
pub fn OutcomeInstrument::item_count(self : OutcomeInstrument) -> Int {
  self.item_count
}

///|
pub fn instrument(
  code : String,
  name : String,
  minimum : Double,
  maximum : Double,
  lower_is_better : Bool,
  meaningful_change : Double,
  item_count : Int,
) -> OutcomeInstrument {
  OutcomeInstrument::{
    code,
    name,
    minimum,
    maximum: Double::max(minimum, maximum),
    lower_is_better,
    meaningful_change: meaningful_change.abs(),
    item_count: Int::max(1, item_count),
  }
}

///|
pub fn pain_instrument() -> OutcomeInstrument {
  instrument("pain-v0", "Pain score", 0.0, 10.0, true, 2.0, 1)
}

///|
pub fn function_instrument() -> OutcomeInstrument {
  instrument("function-v0", "Function score", 0.0, 100.0, false, 10.0, 1)
}

///|
pub fn normalize(instrument : OutcomeInstrument, value : Double) -> Double {
  let bounded = Double::max(
    instrument.minimum,
    Double::min(instrument.maximum, value),
  )
  let width = instrument.maximum - instrument.minimum
  if width == 0.0 {
    0.0
  } else {
    (bounded - instrument.minimum) / width * 100.0
  }
}

///|
pub fn denormalize(instrument : OutcomeInstrument, percent : Double) -> Double {
  let bounded = Double::max(0.0, Double::min(100.0, percent))
  instrument.minimum +
  (instrument.maximum - instrument.minimum) * bounded / 100.0
}

///|
pub fn in_range(instrument : OutcomeInstrument, value : Double) -> Bool {
  value >= instrument.minimum && value <= instrument.maximum
}

///|
pub(all) enum OutcomeSource {
  Clinician
  Participant
  Device
  Imported
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn OutcomeSource::label(self : OutcomeSource) -> String {
  match self {
    Clinician => "clinician"
    Participant => "participant"
    Device => "device"
    Imported => "imported"
  }
}

///|
pub(all) struct OutcomeObservation {
  id : String
  instrument : OutcomeInstrument
  date : String
  score : Double
  answered_items : Int
  source : OutcomeSource
  note : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn OutcomeObservation::id(self : OutcomeObservation) -> String {
  self.id
}

///|
pub fn OutcomeObservation::instrument(
  self : OutcomeObservation,
) -> OutcomeInstrument {
  self.instrument
}

///|
pub fn OutcomeObservation::date(self : OutcomeObservation) -> String {
  self.date
}

///|
pub fn OutcomeObservation::score(self : OutcomeObservation) -> Double {
  self.score
}

///|
pub fn OutcomeObservation::answered_items(self : OutcomeObservation) -> Int {
  self.answered_items
}

///|
pub fn OutcomeObservation::source(self : OutcomeObservation) -> OutcomeSource {
  self.source
}

///|
pub fn OutcomeObservation::note(self : OutcomeObservation) -> String {
  self.note
}

///|
pub fn OutcomeObservation::completeness(self : OutcomeObservation) -> Double {
  Double::max(
    0.0,
    Double::min(
      100.0,
      self.answered_items.to_double() *
      100.0 /
      self.instrument.item_count.to_double(),
    ),
  )
}

///|
pub fn OutcomeObservation::valid(self : OutcomeObservation) -> Bool {
  self.instrument.code != "" &&
  self.date != "" &&
  in_range(self.instrument, self.score) &&
  self.answered_items >= 0 &&
  self.answered_items <= self.instrument.item_count
}

///|
pub fn OutcomeObservation::normalized(self : OutcomeObservation) -> Double {
  normalize(self.instrument, self.score)
}

///|
pub fn observation(
  id : String,
  instrument : OutcomeInstrument,
  date : String,
  score : Double,
  answered_items : Int,
  source : OutcomeSource,
  note : String,
) -> OutcomeObservation {
  OutcomeObservation::{
    id,
    instrument,
    date,
    score,
    answered_items: Int::max(0, answered_items),
    source,
    note,
  }
}

///|
pub fn OutcomeObservation::with_note(
  self : OutcomeObservation,
  note : String,
) -> OutcomeObservation {
  OutcomeObservation::{
    id: self.id,
    instrument: self.instrument,
    date: self.date,
    score: self.score,
    answered_items: self.answered_items,
    source: self.source,
    note,
  }
}

///|
pub(all) enum ResponseBand {
  Deteriorated
  Unchanged
  Improved
  MeaningfulImprovement
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ResponseBand::label(self : ResponseBand) -> String {
  match self {
    Deteriorated => "deteriorated"
    Unchanged => "unchanged"
    Improved => "improved"
    MeaningfulImprovement => "meaningful_improvement"
  }
}

///|
pub(all) struct OutcomeChange {
  instrument : OutcomeInstrument
  baseline : Double
  current : Double
  delta : Double
  percent_change : Double
  band : ResponseBand
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn OutcomeChange::instrument(self : OutcomeChange) -> OutcomeInstrument {
  self.instrument
}

///|
pub fn OutcomeChange::baseline(self : OutcomeChange) -> Double {
  self.baseline
}

///|
pub fn OutcomeChange::current(self : OutcomeChange) -> Double {
  self.current
}

///|
pub fn OutcomeChange::delta(self : OutcomeChange) -> Double {
  self.delta
}

///|
pub fn OutcomeChange::percent_change(self : OutcomeChange) -> Double {
  self.percent_change
}

///|
pub fn OutcomeChange::band(self : OutcomeChange) -> ResponseBand {
  self.band
}

///|
fn response(instrument : OutcomeInstrument, delta : Double) -> ResponseBand {
  let improvement = if instrument.lower_is_better { -delta } else { delta }
  if improvement <= -instrument.meaningful_change {
    ResponseBand::Deteriorated
  } else if improvement < instrument.meaningful_change {
    if improvement > 0.0 {
      ResponseBand::Improved
    } else {
      ResponseBand::Unchanged
    }
  } else {
    ResponseBand::MeaningfulImprovement
  }
}

///|
pub fn change(
  instrument : OutcomeInstrument,
  baseline : Double,
  current : Double,
) -> OutcomeChange {
  let delta = current - baseline
  let percent = if baseline == 0.0 { 0.0 } else { delta / baseline * 100.0 }
  OutcomeChange::{
    instrument,
    baseline,
    current,
    delta,
    percent_change: percent,
    band: response(instrument, delta),
  }
}

///|
pub(all) struct OutcomeSeries {
  instrument : OutcomeInstrument
  observations : Array[OutcomeObservation]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn new_series(instrument : OutcomeInstrument) -> OutcomeSeries {
  OutcomeSeries::{ instrument, observations: [] }
}

///|
pub fn OutcomeSeries::instrument(self : OutcomeSeries) -> OutcomeInstrument {
  self.instrument
}

///|
pub fn OutcomeSeries::observations(
  self : OutcomeSeries,
) -> Array[OutcomeObservation] {
  self.observations
}

///|
pub fn OutcomeSeries::count(self : OutcomeSeries) -> Int {
  self.observations.length()
}

///|
pub fn OutcomeSeries::append(
  self : OutcomeSeries,
  item : OutcomeObservation,
) -> OutcomeSeries {
  let result = self
  if item.instrument.code == result.instrument.code &&
    result.observations.all(existing => existing.id != item.id) {
    result.observations.push(item)
  }
  result
}

///|
pub fn OutcomeSeries::append_many(
  self : OutcomeSeries,
  items : Array[OutcomeObservation],
) -> OutcomeSeries {
  let mut result = self
  for item in items {
    result = result.append(item)
  }
  result
}

///|
pub fn OutcomeSeries::valid(self : OutcomeSeries) -> Array[OutcomeObservation] {
  self.observations.filter(item => item.valid())
}

///|
pub fn OutcomeSeries::invalid(
  self : OutcomeSeries,
) -> Array[OutcomeObservation] {
  self.observations.filter(item => !item.valid())
}

///|
pub fn OutcomeSeries::chronological(
  self : OutcomeSeries,
) -> Array[OutcomeObservation] {
  let result = self.valid()
  result.sort_by((left, right) => left.date.compare(right.date))
  result
}

///|
pub fn OutcomeSeries::latest(self : OutcomeSeries) -> OutcomeObservation? {
  let items = self.chronological()
  items.get(items.length() - 1)
}

///|
pub fn OutcomeSeries::baseline(self : OutcomeSeries) -> OutcomeObservation? {
  self.chronological().get(0)
}

///|
pub fn OutcomeSeries::values(self : OutcomeSeries) -> Array[Double] {
  self.chronological().map(item => item.score)
}

///|
pub fn OutcomeSeries::summary(self : OutcomeSeries) -> @statistics.Summary {
  @statistics.describe(self.values())
}

///|
pub fn OutcomeSeries::change(self : OutcomeSeries) -> OutcomeChange? {
  match (self.baseline(), self.latest()) {
    (Some(first), Some(last)) =>
      Some(change(self.instrument, first.score, last.score))
    _ => None
  }
}

///|
pub fn OutcomeSeries::trend(self : OutcomeSeries) -> Double {
  @statistics.slope(self.values())
}

///|
pub fn OutcomeSeries::completion(self : OutcomeSeries) -> Double {
  if self.observations.is_empty() {
    0.0
  } else {
    self.valid().length().to_double() *
    100.0 /
    self.observations.length().to_double()
  }
}

///|
pub fn OutcomeSeries::reliable(
  self : OutcomeSeries,
  minimum? : Double = 80.0,
) -> Bool {
  self.completion() >= minimum && self.count() >= 2
}

///|
pub fn OutcomeSeries::response(self : OutcomeSeries) -> ResponseBand {
  match self.change() {
    Some(value) => value.band
    None => ResponseBand::Unchanged
  }
}

///|
pub fn OutcomeSeries::remove(
  self : OutcomeSeries,
  id : String,
) -> OutcomeSeries {
  let result = self
  result.observations.retain(item => item.id != id)
  result
}

///|
pub fn OutcomeSeries::between(
  self : OutcomeSeries,
  start : String,
  end : String,
) -> OutcomeSeries {
  OutcomeSeries::{
    instrument: self.instrument,
    observations: self.observations.filter(item => {
      item.date >= start && item.date <= end
    }),
  }
}

///|
pub(all) struct OutcomeReport {
  series : Array[OutcomeSeries]
  reliable_count : Int
  improved_count : Int
  deteriorated_count : Int
  mean_normalized : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn OutcomeReport::series(self : OutcomeReport) -> Array[OutcomeSeries] {
  self.series
}

///|
pub fn OutcomeReport::reliable_count(self : OutcomeReport) -> Int {
  self.reliable_count
}

///|
pub fn OutcomeReport::improved_count(self : OutcomeReport) -> Int {
  self.improved_count
}

///|
pub fn OutcomeReport::deteriorated_count(self : OutcomeReport) -> Int {
  self.deteriorated_count
}

///|
pub fn OutcomeReport::mean_normalized(self : OutcomeReport) -> Double {
  self.mean_normalized
}

///|
pub fn report(series : Array[OutcomeSeries]) -> OutcomeReport {
  let reliable = series.count_if(item => item.reliable())
  let improved = series.count_if(item => {
    item.response() == ResponseBand::Improved ||
    item.response() == ResponseBand::MeaningfulImprovement
  })
  let deteriorated = series.count_if(item => {
    item.response() == ResponseBand::Deteriorated
  })
  let normalized = []
  for item in series {
    normalized.append(
      item.values().map(value => normalize(item.instrument, value)),
    )
  }
  OutcomeReport::{
    series,
    reliable_count: reliable,
    improved_count: improved,
    deteriorated_count: deteriorated,
    mean_normalized: @statistics.mean(normalized),
  }
}

///|
pub fn response_rate(report : OutcomeReport) -> Double {
  if report.series.is_empty() {
    0.0
  } else {
    report.improved_count.to_double() *
    100.0 /
    report.series.length().to_double()
  }
}

///|
pub fn outcome_text(series : OutcomeSeries) -> String {
  let output = StringBuilder()
  output.write_string(
    series.instrument.code +
    " " +
    series.instrument.name +
    " n=" +
    series.count().to_string() +
    "\n",
  )
  match series.change() {
    Some(value) =>
      output.write_string(
        "change=" + value.delta.to_string() + " (" + value.band.label() + ")\n",
      )
    None => output.write_string("change=insufficient_observations\n")
  }
  output.write_string(
    "completion=" +
    series.completion().to_string() +
    "% trend=" +
    series.trend().to_string() +
    "\n",
  )
  output.to_string()
}
