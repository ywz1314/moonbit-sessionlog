///|
test "history replay tracks active identities" {
  let log = new_history()
  ignore(log.append("a", "2026-02-20", HistoryEvent::SessionAdded, "add"))
  ignore(log.append("a", "2026-02-21", HistoryEvent::SessionUpdated, "update"))
  ignore(log.record_removed("a", "2026-02-22"))
  let frames = replay(log, default_replay_options()).unwrap()
  assert_eq(frames.length(), 3)
  assert_true(replay_is_monotonic(frames))
  assert_eq(frames[0].active_count(), 1)
  assert_eq(frames[2].active_count(), 0)
  assert_true(replay_has_removal(frames, "a"))
}

///|
test "replay rejects inverted ranges" {
  let log = new_history()
  let result = replay(log, replay_options(start_revision=4, end_revision=2))
  assert_true(result is Err(_))
}
