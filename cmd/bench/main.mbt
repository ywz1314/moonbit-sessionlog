///|
fn main {
  println("MoonBit sessionlog deterministic benchmark")
  println("===========================================")
  for result in @benchmark.run_all() {
    println(@benchmark.result_text(result))
  }
  let fixture = @benchmark.build_fixture(
    @benchmark.benchmark_case("pipeline", 1000, 6, 4),
  )
  let normalized = @normalization.normalize_many(
    fixture,
    @normalization.default_options(),
  )
  let retention_plan = @retention.plan(
    normalized.sessions(),
    "2026-12-31",
    @retention.default_policy(),
  )
  println("pipeline.normalized=" + normalized.sessions().length().to_string())
  println("pipeline.archived=" + retention_plan.archived_count().to_string())
  println(
    "pipeline.checksum=" +
    @normalization.normalization_checksum(normalized).to_string(),
  )
}
