///|
test "schema inspection and canonical encoding" {
  let text = "{\"id\":\"s\",\"date\":\"2026-08-19\",\"duration\":1,\"pain_before\":0,\"pain_after\":0,\"movements\":[],\"notes\":\"\"}"
  assert_eq(@schema.schema_version(text), Ok(1))
  assert_true(@schema.is_json_object(text))
  assert_true(!@schema.is_json_array(text))
  assert_eq(@schema.schema_name(1), "legacy")
  assert_eq(@schema.schema_name(2), "current")
  assert_true(@schema.canonical_json(text).unwrap().contains("\n"))
  match @schema.migrate_with_report(text) {
    Ok((session, report)) => {
      assert_eq(session.id, "s")
      assert_eq(report.source_version(), 1)
      assert_eq(report.target_version(), 2)
      assert_true(
        report
        .warnings()
        .contains(@schema.MigrationWarning::LegacyVersionAssumed),
      )
    }
    Err(_) => panic()
  }
}

///|
test "schema batch parsing isolates failures" {
  let valid = "{\"version\":2,\"id\":\"s\",\"date\":\"2026-08-19\",\"duration\":1,\"pain_before\":0,\"pain_after\":0,\"movements\":[],\"notes\":\"\"}"
  let (sessions, errors) = @schema.parse_many([valid, "not-json"])
  assert_eq(sessions.length(), 1)
  assert_eq(errors.length(), 1)
  assert_eq(@schema.parse_many_strict([valid]).unwrap().length(), 1)
  assert_true(@schema.parse_many_strict(["not-json"]) is Err(_))
}
