///|
test "facets count and select buckets" {
  let session = @core.Session::{
    id: "q",
    date: "2026-02-20",
    duration: 30,
    pain_before: 2,
    pain_after: 4,
    movements: [],
    notes: "#home",
  }
  let facets = build_facets([session])
  assert_eq(facets.date().total(), 1)
  assert_eq(facets.date().buckets().length(), 1)
  assert_eq(facets.tags().total(), 1)
  assert_eq(facet_count(facets.tags(), "#home"), 1)
}
