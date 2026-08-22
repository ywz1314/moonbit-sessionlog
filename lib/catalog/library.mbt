///|
/// Matching helpers make a catalog useful at import boundaries where names
/// come from different clinics, languages, or historical templates.
pub(all) struct CatalogMatch {
  query : String
  name : String
  score : Int
  exact : Bool
  alias_match : Bool
  region : BodyRegion
  category : MovementCategory
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CatalogMatch::query(self : CatalogMatch) -> String {
  self.query
}

///|
pub fn CatalogMatch::name(self : CatalogMatch) -> String {
  self.name
}

///|
pub fn CatalogMatch::score(self : CatalogMatch) -> Int {
  self.score
}

///|
pub fn CatalogMatch::exact(self : CatalogMatch) -> Bool {
  self.exact
}

///|
pub fn CatalogMatch::alias_match(self : CatalogMatch) -> Bool {
  self.alias_match
}

///|
pub fn CatalogMatch::region(self : CatalogMatch) -> BodyRegion {
  self.region
}

///|
pub fn CatalogMatch::category(self : CatalogMatch) -> MovementCategory {
  self.category
}

///|
fn normalized_name(value : String) -> String {
  value
  .trim()
  .to_owned()
  .to_lower()
  .replace(old="_", new=" ")
  .replace(old="-", new=" ")
}

///|
fn word_score(query : String, candidate : String) -> Int {
  let q = normalized_name(query)
  let c = normalized_name(candidate)
  if q == c {
    100
  } else if c.contains(q) || q.contains(c) {
    70
  } else {
    let qwords = q.split(" ").to_array().map(value => value.to_owned())
    let mut matches = 0
    for word in qwords {
      if word.length() > 1 && c.contains(word) {
        matches += 1
      }
    }
    Int::min(60, matches * 20)
  }
}

///|
fn match_definition(query : String, item : MovementDefinition) -> CatalogMatch? {
  let exact_score = word_score(query, item.name())
  let mut best = exact_score
  let mut alias_match = false
  for value in item.aliases() {
    let score = word_score(query, value)
    if score > best {
      best = score
      alias_match = true
    }
  }
  if best == 0 {
    None
  } else {
    Some(CatalogMatch::{
      query,
      name: item.name(),
      score: best,
      exact: best == 100 && !alias_match,
      alias_match,
      region: item.region(),
      category: item.category(),
    })
  }
}

///|
pub fn match_catalog(
  catalog : MovementCatalog,
  query : String,
) -> Array[CatalogMatch] {
  let matches = []
  for item in catalog.all() {
    match match_definition(query, item) {
      Some(value) => matches.push(value)
      None => ()
    }
  }
  matches.sort_by((left, right) => right.score - left.score)
  matches
}

///|
pub fn best_catalog_match(
  catalog : MovementCatalog,
  query : String,
) -> CatalogMatch? {
  match match_catalog(catalog, query) {
    values => values.last()
  }
}

///|
pub fn catalog_match(
  catalog : MovementCatalog,
  query : String,
) -> MovementDefinition? {
  match match_catalog(catalog, query).last() {
    Some(value) => catalog.find(value.name)
    None => None
  }
}

///|
pub fn unmatched_names(
  catalog : MovementCatalog,
  names : Array[String],
) -> Array[String] {
  names.filter(name => catalog_match(catalog, name) is None)
}

///|
pub fn ambiguous_names(
  catalog : MovementCatalog,
  names : Array[String],
  margin : Int,
) -> Array[String] {
  let result = []
  for name in names {
    let matches = match_catalog(catalog, name)
    if matches.length() >= 2 && matches[0].score - matches[1].score < margin {
      result.push(name)
    }
  }
  result
}

///|
pub(all) struct CatalogImportPlan {
  input_count : Int
  matched_count : Int
  unmatched : Array[String]
  ambiguous : Array[String]
  mappings : Array[(String, String, Int)]
  confidence : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CatalogImportPlan::input_count(self : CatalogImportPlan) -> Int {
  self.input_count
}

///|
pub fn CatalogImportPlan::matched_count(self : CatalogImportPlan) -> Int {
  self.matched_count
}

///|
pub fn CatalogImportPlan::unmatched(self : CatalogImportPlan) -> Array[String] {
  self.unmatched.copy()
}

///|
pub fn CatalogImportPlan::ambiguous(self : CatalogImportPlan) -> Array[String] {
  self.ambiguous.copy()
}

///|
pub fn CatalogImportPlan::mappings(
  self : CatalogImportPlan,
) -> Array[(String, String, Int)] {
  self.mappings.copy()
}

///|
pub fn CatalogImportPlan::confidence(self : CatalogImportPlan) -> Double {
  self.confidence
}

///|
pub fn plan_catalog_import(
  catalog : MovementCatalog,
  names : Array[String],
  ambiguity_margin : Int,
) -> CatalogImportPlan {
  let unmatched = []
  let mappings : Array[(String, String, Int)] = []
  let ambiguous = ambiguous_names(catalog, names, Int::max(0, ambiguity_margin))
  for name in names {
    match match_catalog(catalog, name).last() {
      Some(value) => mappings.push((name, value.name, value.score))
      None => unmatched.push(name)
    }
  }
  let confidence = if names.is_empty() {
    1.0
  } else {
    mappings.fold(init=0, (total, value) => total + value.2).to_double() /
    (names.length() * 100).to_double()
  }
  CatalogImportPlan::{
    input_count: names.length(),
    matched_count: mappings.length(),
    unmatched,
    ambiguous,
    mappings,
    confidence,
  }
}

///|
pub fn import_plan_safe(
  value : CatalogImportPlan,
  minimum_confidence : Double,
) -> Bool {
  value.unmatched.is_empty() &&
  value.ambiguous.is_empty() &&
  value.confidence >= minimum_confidence
}

///|
pub fn import_plan_text(value : CatalogImportPlan) -> String {
  "input=" +
  value.input_count.to_string() +
  ", matched=" +
  value.matched_count.to_string() +
  ", unmatched=" +
  value.unmatched.length().to_string() +
  ", ambiguous=" +
  value.ambiguous.length().to_string() +
  ", confidence=" +
  value.confidence.to_string()
}

///|
pub(all) struct CatalogCoverage {
  catalog_size : Int
  used_names : Int
  covered_names : Int
  unused_definitions : Array[String]
  coverage_percent : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn CatalogCoverage::catalog_size(self : CatalogCoverage) -> Int {
  self.catalog_size
}

///|
pub fn CatalogCoverage::used_names(self : CatalogCoverage) -> Int {
  self.used_names
}

///|
pub fn CatalogCoverage::covered_names(self : CatalogCoverage) -> Int {
  self.covered_names
}

///|
pub fn CatalogCoverage::unused_definitions(
  self : CatalogCoverage,
) -> Array[String] {
  self.unused_definitions.copy()
}

///|
pub fn CatalogCoverage::coverage_percent(self : CatalogCoverage) -> Double {
  self.coverage_percent
}

///|
pub fn catalog_coverage(
  catalog : MovementCatalog,
  names : Array[String],
) -> CatalogCoverage {
  let covered = []
  for name in names {
    match catalog_match(catalog, name) {
      Some(value) =>
        if !covered.contains(value.name()) {
          covered.push(value.name())
        }
      None => ()
    }
  }
  let unused = catalog
    .all()
    .filter(item => !covered.contains(item.name()))
    .map(item => item.name())
  CatalogCoverage::{
    catalog_size: catalog.count(),
    used_names: names.length(),
    covered_names: covered.length(),
    unused_definitions: unused,
    coverage_percent: if names.is_empty() {
      0.0
    } else {
      covered.length().to_double() * 100.0 / names.length().to_double()
    },
  }
}

///|
pub fn coverage_text(value : CatalogCoverage) -> String {
  "catalog=" +
  value.catalog_size.to_string() +
  ", covered=" +
  value.covered_names.to_string() +
  ", used=" +
  value.used_names.to_string() +
  ", coverage=" +
  value.coverage_percent.to_string() +
  "%"
}

///|
pub fn catalog_tag_index(
  catalog : MovementCatalog,
) -> Array[(String, Array[String])] {
  let result : Array[(String, Array[String])] = []
  for item in catalog.all() {
    for tag in item.tags() {
      match result.search_by(value => value.0 == tag) {
        Some(index) =>
          if !result[index].1.contains(item.name()) {
            result[index].1.push(item.name())
          }
        None => result.push((tag, [item.name()]))
      }
    }
  }
  result.sort_by((left, right) => left.0.compare(right.0))
  result
}

///|
pub fn catalog_region_counts(catalog : MovementCatalog) -> Array[(String, Int)] {
  let result : Array[(String, Int)] = []
  for item in catalog.all() {
    let label = item.region().label()
    match result.search_by(value => value.0 == label) {
      Some(index) => {
        let old = result[index]
        result[index] = (old.0, old.1 + 1)
      }
      None => result.push((label, 1))
    }
  }
  result
}
