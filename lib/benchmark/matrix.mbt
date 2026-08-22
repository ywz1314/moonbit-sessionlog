///|
/// A benchmark matrix expands a profile across deterministic fixture sizes and
/// exposes pass/fail checks suitable for CI summaries.
pub(all) struct MatrixCell {
  profile : String
  scale : Int
  session_count : Int
  movement_count : Int
  reps : Int
  work_units : Int
  checksum : Int
  passed : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MatrixCell::profile(self : MatrixCell) -> String {
  self.profile
}

///|
pub fn MatrixCell::scale(self : MatrixCell) -> Int {
  self.scale
}

///|
pub fn MatrixCell::session_count(self : MatrixCell) -> Int {
  self.session_count
}

///|
pub fn MatrixCell::movement_count(self : MatrixCell) -> Int {
  self.movement_count
}

///|
pub fn MatrixCell::reps(self : MatrixCell) -> Int {
  self.reps
}

///|
pub fn MatrixCell::work_units(self : MatrixCell) -> Int {
  self.work_units
}

///|
pub fn MatrixCell::checksum(self : MatrixCell) -> Int {
  self.checksum
}

///|
pub fn MatrixCell::passed(self : MatrixCell) -> Bool {
  self.passed
}

///|
pub fn matrix_cell(
  profile_value : BenchmarkProfile,
  scale : Int,
) -> Result[MatrixCell, String] {
  let errors = validate_profile(profile_value)
  if !errors.is_empty() {
    return Err(errors.join("; "))
  }
  let value = run(profile_case(profile_value).unwrap())
  let actual_scale = Int::max(1, scale)
  let passed = value.session_count() * actual_scale >=
    profile_value.expected_min_sessions &&
    value.movement_count() * actual_scale >=
    profile_value.expected_min_movements
  Ok(MatrixCell::{
    profile: profile_value.name,
    scale: actual_scale,
    session_count: value.session_count() * actual_scale,
    movement_count: value.movement_count() * actual_scale,
    reps: value.total_reps() * actual_scale,
    work_units: value.total_work_units() * actual_scale,
    checksum: value.checksum() * actual_scale,
    passed,
  })
}

///|
pub fn run_matrix(
  profiles : Array[BenchmarkProfile],
  scales : Array[Int],
) -> Array[MatrixCell] {
  let result = []
  for profile_value in profiles {
    for scale in scales {
      match matrix_cell(profile_value, scale) {
        Ok(cell) => result.push(cell)
        Err(_) => ()
      }
    }
  }
  result
}

///|
pub fn matrix_passed(values : Array[MatrixCell]) -> Bool {
  values.all(value => value.passed)
}

///|
pub fn matrix_failed(values : Array[MatrixCell]) -> Array[MatrixCell] {
  values.filter(value => !value.passed)
}

///|
pub fn matrix_by_scale(
  values : Array[MatrixCell],
  scale : Int,
) -> Array[MatrixCell] {
  values.filter(value => value.scale == scale)
}

///|
pub fn matrix_peak_work(values : Array[MatrixCell]) -> MatrixCell? {
  let mut result : MatrixCell? = None
  for value in values {
    match result {
      Some(old) => if value.work_units > old.work_units { result = Some(value) }
      None => result = Some(value)
    }
  }
  result
}

///|
pub fn matrix_checksum(values : Array[MatrixCell]) -> Int {
  values.fold(init=53, (total, value) => {
    total * 31 + value.checksum + value.scale
  })
}

///|
pub fn matrix_text(values : Array[MatrixCell]) -> String {
  values
  .map(value => {
    value.profile +
    "x" +
    value.scale.to_string() +
    " sessions=" +
    value.session_count.to_string() +
    " work=" +
    value.work_units.to_string() +
    " passed=" +
    value.passed.to_string()
  })
  .join("\n")
}

///|
pub(all) struct BenchmarkGate {
  matrix_count : Int
  passed_count : Int
  failed_count : Int
  total_sessions : Int
  total_work_units : Int
  checksum : Int
  passed : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn BenchmarkGate::matrix_count(self : BenchmarkGate) -> Int {
  self.matrix_count
}

///|
pub fn BenchmarkGate::passed_count(self : BenchmarkGate) -> Int {
  self.passed_count
}

///|
pub fn BenchmarkGate::failed_count(self : BenchmarkGate) -> Int {
  self.failed_count
}

///|
pub fn BenchmarkGate::total_sessions(self : BenchmarkGate) -> Int {
  self.total_sessions
}

///|
pub fn BenchmarkGate::total_work_units(self : BenchmarkGate) -> Int {
  self.total_work_units
}

///|
pub fn BenchmarkGate::checksum(self : BenchmarkGate) -> Int {
  self.checksum
}

///|
pub fn BenchmarkGate::passed(self : BenchmarkGate) -> Bool {
  self.passed
}

///|
pub fn benchmark_gate(values : Array[MatrixCell]) -> BenchmarkGate {
  BenchmarkGate::{
    matrix_count: values.length(),
    passed_count: values.count_if(value => value.passed),
    failed_count: values.count_if(value => !value.passed),
    total_sessions: values.fold(init=0, (total, value) => {
      total + value.session_count
    }),
    total_work_units: values.fold(init=0, (total, value) => {
      total + value.work_units
    }),
    checksum: matrix_checksum(values),
    passed: matrix_passed(values),
  }
}

///|
pub fn benchmark_gate_text(value : BenchmarkGate) -> String {
  "cells=" +
  value.matrix_count.to_string() +
  " passed=" +
  value.passed_count.to_string() +
  " failed=" +
  value.failed_count.to_string() +
  " sessions=" +
  value.total_sessions.to_string() +
  " work=" +
  value.total_work_units.to_string() +
  " checksum=" +
  value.checksum.to_string()
}
