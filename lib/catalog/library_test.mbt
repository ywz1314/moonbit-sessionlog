///|
test "catalog matching handles aliases and unknown names" {
  let catalog = standard_catalog()
  let matches = match_catalog(catalog, "squat")
  assert_true(matches.length() > 0)
  let plan = plan_catalog_import(catalog, ["squat", "not-a-real-movement"], 5)
  assert_eq(plan.input_count(), 2)
  assert_true(plan.unmatched().contains("not-a-real-movement"))
}
