///|
/// Benchmark profiles describe workload shape separately from execution so CI
/// can select a stable fixture and compare deterministic output checksums.
pub(all) struct BenchmarkProfile {
  name : String
  case_name : String
  repetitions : Int
  warmup : Int
  expected_min_sessions : Int
  expected_min_movements : Int
  tags : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn BenchmarkProfile::name(self : BenchmarkProfile) -> String {
  self.name
}

///|
pub fn BenchmarkProfile::case_name(self : BenchmarkProfile) -> String {
  self.case_name
}

///|
pub fn BenchmarkProfile::repetitions(self : BenchmarkProfile) -> Int {
  self.repetitions
}

///|
pub fn BenchmarkProfile::warmup(self : BenchmarkProfile) -> Int {
  self.warmup
}

///|
pub fn BenchmarkProfile::expected_min_sessions(self : BenchmarkProfile) -> Int {
  self.expected_min_sessions
}

///|
pub fn BenchmarkProfile::expected_min_movements(self : BenchmarkProfile) -> Int {
  self.expected_min_movements
}

///|
pub fn BenchmarkProfile::tags(self : BenchmarkProfile) -> Array[String] {
  self.tags.copy()
}

///|
pub fn profile(
  name : String,
  case_name : String,
  repetitions : Int,
  warmup : Int,
  expected_min_sessions : Int,
  expected_min_movements : Int,
  tags : Array[String],
) -> BenchmarkProfile {
  BenchmarkProfile::{
    name,
    case_name,
    repetitions: Int::max(1, repetitions),
    warmup: Int::max(0, warmup),
    expected_min_sessions,
    expected_min_movements,
    tags,
  }
}

///|
pub fn standard_profiles() -> Array[BenchmarkProfile] {
  [
    profile("smoke", "tiny", 3, 1, 10, 20, ["ci", "fast"]),
    profile("typical", "medium", 5, 2, 100, 300, ["ci", "default"]),
    profile("scale", "large", 3, 2, 1000, 4000, ["nightly", "scale"]),
  ]
}

///|
pub fn profile_case(value : BenchmarkProfile) -> BenchmarkCase? {
  match standard_cases().search_by(item => item.name() == value.case_name) {
    Some(index) => Some(standard_cases()[index])
    None => None
  }
}

///|
pub fn validate_profile(value : BenchmarkProfile) -> Array[String] {
  let errors = []
  if value.name.trim().is_empty() {
    errors.push("name is required")
  }
  if value.expected_min_sessions < 0 {
    errors.push("expected sessions must be non-negative")
  }
  if value.expected_min_movements < 0 {
    errors.push("expected movements must be non-negative")
  }
  if profile_case(value) is None {
    errors.push("unknown benchmark case")
  }
  errors
}

///|
pub(all) struct ProfileResult {
  profile : BenchmarkProfile
  result : BenchmarkResult
  repetitions : Int
  passed : Bool
  checks : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn ProfileResult::profile(self : ProfileResult) -> BenchmarkProfile {
  self.profile
}

///|
pub fn ProfileResult::result(self : ProfileResult) -> BenchmarkResult {
  self.result
}

///|
pub fn ProfileResult::repetitions(self : ProfileResult) -> Int {
  self.repetitions
}

///|
pub fn ProfileResult::passed(self : ProfileResult) -> Bool {
  self.passed
}

///|
pub fn ProfileResult::checks(self : ProfileResult) -> Array[String] {
  self.checks.copy()
}

///|
pub fn run_profile(value : BenchmarkProfile) -> Result[ProfileResult, String] {
  let errors = validate_profile(value)
  if !errors.is_empty() {
    return Err(errors.join("; "))
  }
  let case_value = profile_case(value).unwrap()
  let result = run(case_value)
  let checks = []
  let passed = result.session_count() >= value.expected_min_sessions &&
    result.movement_count() >= value.expected_min_movements
  if result.session_count() < value.expected_min_sessions {
    checks.push("session_count below expectation")
  }
  if result.movement_count() < value.expected_min_movements {
    checks.push("movement_count below expectation")
  }
  if result.checksum() == 0 {
    checks.push("checksum is zero")
  }
  Ok(ProfileResult::{
    profile: value,
    result,
    repetitions: value.repetitions,
    passed,
    checks,
  })
}

///|
pub fn run_profiles(values : Array[BenchmarkProfile]) -> Array[ProfileResult] {
  let result = []
  for value in values {
    match run_profile(value) {
      Ok(output) => result.push(output)
      Err(_) => ()
    }
  }
  result
}

///|
pub fn passed_profiles(values : Array[ProfileResult]) -> Array[ProfileResult] {
  values.filter(value => value.passed)
}

///|
pub fn profile_report_text(values : Array[ProfileResult]) -> String {
  values
  .map(value => {
    value.profile.name +
    " passed=" +
    value.passed.to_string() +
    " sessions=" +
    value.result.session_count.to_string() +
    " checksum=" +
    value.result.checksum.to_string()
  })
  .join("\n")
}
