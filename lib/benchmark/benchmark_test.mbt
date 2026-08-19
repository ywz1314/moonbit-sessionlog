///|
test "benchmark fixtures produce repeatable checksums" {
  let case = @benchmark.benchmark_case("tiny", 4, 2, 2)
  let first = @benchmark.run(case)
  let second = @benchmark.run(case)
  assert_eq(first, second)
  assert_eq(first.session_count(), 4)
  assert_eq(first.movement_count(), 2)
  assert_true(first.total_reps() > 0)
  assert_true(@benchmark.results_text([first]).contains("checksum="))
}
