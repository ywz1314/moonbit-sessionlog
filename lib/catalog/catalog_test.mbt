///|
test "movement catalog supports aliases and safety lookup" {
  let catalog = @catalog.standard_catalog()
  assert_eq(catalog.count(), 4)
  assert_eq(catalog.find("sit_to_stand").unwrap().name(), "squat")
  assert_eq(catalog.by_region(@catalog.BodyRegion::LowerLimb).length(), 2)
  assert_eq(catalog.with_tag("balance").length(), 1)
  assert_eq(catalog.search("breath").length(), 1)
  let unknown = @core.Movement::{ name: "unknown", sets: [], pain: 0, rpe: 1 }
  assert_true(catalog.validate_movement(unknown)[0].contains("unknown"))
}
