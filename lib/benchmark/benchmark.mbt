///|
pub(all) struct BenchmarkCase {
  name : String
  session_count : Int
  movement_count : Int
  sets_per_movement : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn BenchmarkCase::name(self : BenchmarkCase) -> String {
  self.name
}

///|
pub fn BenchmarkCase::session_count(self : BenchmarkCase) -> Int {
  self.session_count
}

///|
pub fn BenchmarkCase::movement_count(self : BenchmarkCase) -> Int {
  self.movement_count
}

///|
pub fn BenchmarkCase::sets_per_movement(self : BenchmarkCase) -> Int {
  self.sets_per_movement
}

///|
pub fn benchmark_case(
  name : String,
  session_count : Int,
  movement_count : Int,
  sets_per_movement : Int,
) -> BenchmarkCase {
  BenchmarkCase::{
    name,
    session_count: Int::max(0, session_count),
    movement_count: Int::max(0, movement_count),
    sets_per_movement: Int::max(0, sets_per_movement),
  }
}

///|
pub fn standard_cases() -> Array[BenchmarkCase] {
  [
    benchmark_case("smoke", 10, 2, 2),
    benchmark_case("weekly", 100, 4, 3),
    benchmark_case("history", 1000, 6, 4),
  ]
}

///|
pub fn build_fixture(case : BenchmarkCase) -> Array[@core.Session] {
  let sessions = []
  for session_index in 0..<case.session_count {
    let movements = []
    for movement_index in 0..<case.movement_count {
      let sets = []
      for set_index in 0..<case.sets_per_movement {
        sets.push(@core.Set::{
          reps: 8 + (session_index + set_index) % 5,
          hold_time: 5 + set_index,
          resistance: if movement_index % 2 == 0 {
            "body"
          } else {
            "band"
          },
          completion: 0.75 +
          ((session_index + movement_index) % 4).to_double() / 20.0,
        })
      }
      movements.push(@core.Movement::{
        name: "movement-" + movement_index.to_string(),
        sets,
        pain: (session_index + movement_index) % 6,
        rpe: 3 + (session_index + movement_index) % 6,
      })
    }
    sessions.push(@core.Session::{
      id: "benchmark-" + session_index.to_string(),
      date: "2026-08-" + (session_index % 28 + 1).to_string(),
      duration: 30,
      pain_before: 3,
      pain_after: 2,
      movements,
      notes: "benchmark fixture",
    })
  }
  sessions
}

///|
pub(all) struct BenchmarkResult {
  name : String
  session_count : Int
  movement_count : Int
  total_reps : Int
  total_work_units : Int
  average_pain : Double
  average_completion : Double
  checksum : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn BenchmarkResult::name(self : BenchmarkResult) -> String {
  self.name
}

///|
pub fn BenchmarkResult::session_count(self : BenchmarkResult) -> Int {
  self.session_count
}

///|
pub fn BenchmarkResult::movement_count(self : BenchmarkResult) -> Int {
  self.movement_count
}

///|
pub fn BenchmarkResult::total_reps(self : BenchmarkResult) -> Int {
  self.total_reps
}

///|
pub fn BenchmarkResult::total_work_units(self : BenchmarkResult) -> Int {
  self.total_work_units
}

///|
pub fn BenchmarkResult::average_pain(self : BenchmarkResult) -> Double {
  self.average_pain
}

///|
pub fn BenchmarkResult::average_completion(self : BenchmarkResult) -> Double {
  self.average_completion
}

///|
pub fn BenchmarkResult::checksum(self : BenchmarkResult) -> Int {
  self.checksum
}

///|
pub fn checksum(sessions : Array[@core.Session]) -> Int {
  sessions.fold(init=17, (value, session) => {
    let movement_value = session.movements.fold(init=0, (
      movement_total,
      movement,
    ) => movement_total + movement.work_units() + movement.pain * 7)
    value * 31 + session.total_reps() + movement_value
  })
}

///|
pub fn run(case : BenchmarkCase) -> BenchmarkResult {
  let sessions = build_fixture(case)
  let report = @analytics.analyze(sessions)
  let aggregates = @aggregation.aggregate_all(sessions)
  BenchmarkResult::{
    name: case.name,
    session_count: report.session_count(),
    movement_count: aggregates.length(),
    total_reps: report.total_reps(),
    total_work_units: report.total_work_units(),
    average_pain: report.average_pain(),
    average_completion: report.average_completion(),
    checksum: checksum(sessions),
  }
}

///|
pub fn run_all() -> Array[BenchmarkResult] {
  standard_cases().map(case => run(case))
}

///|
pub fn result_text(result : BenchmarkResult) -> String {
  "case=" +
  result.name +
  ", sessions=" +
  result.session_count.to_string() +
  ", movements=" +
  result.movement_count.to_string() +
  ", reps=" +
  result.total_reps.to_string() +
  ", work=" +
  result.total_work_units.to_string() +
  ", avg_pain=" +
  result.average_pain.to_string() +
  ", avg_completion=" +
  result.average_completion.to_string() +
  ", checksum=" +
  result.checksum.to_string()
}

///|
pub fn results_text(results : Array[BenchmarkResult]) -> String {
  let output = StringBuilder()
  for result in results {
    output.write_string(result_text(result) + "\n")
  }
  output.to_string()
}
