///|
fn episode_session(id : String, date : String) -> @core.Session {
  @core.Session::{
    id,
    date,
    duration: 30,
    pain_before: 4,
    pain_after: 2,
    movements: [
      @core.Movement::{
        name: "squat",
        sets: [
          @core.Set::{
            reps: 10,
            hold_time: 2,
            resistance: "body",
            completion: 1.0,
          },
        ],
        pain: 2,
        rpe: 4,
      },
    ],
    notes: "",
  }
}

///|
test "episode segmentation is chronological and gap aware" {
  let sessions = [
    episode_session("b", "2026-08-20"),
    episode_session("a", "2026-08-01"),
    episode_session("c", "2026-09-10"),
  ]
  let episodes = @episodes.segment(sessions)
  assert_eq(episodes.length(), 2)
  assert_eq(episodes[0].sessions().map(item => item.id), ["a", "b"])
  assert_eq(episodes[1].sessions()[0].id, "c")
  assert_true(episodes[0].gaps()[0].boundary())
  assert_eq(@episodes.total_sessions(episodes), 3)
}

///|
test "episode options clamp unsafe input and filter invalid dates" {
  let options = @episodes.with_gap_days(@episodes.default_episode_options(), 0)
  assert_eq(options.gap_days(), 1)
  assert_eq(@episodes.validate_options(options), [])
  let invalid = episode_session("bad", "not-a-date")
  let valid = episode_session("good", "2026-08-01")
  assert_eq(@episodes.segment_valid([invalid, valid]).length(), 1)
  assert_eq(@episodes.invalid_date_sessions([invalid, valid]).length(), 1)
}

///|
test "episode lookup, windowing, and boundary text are stable" {
  let episodes = @episodes.segment([
    episode_session("a", "2026-01-01"),
    episode_session("b", "2026-01-03"),
  ])
  assert_eq(
    @episodes.episode_for_session(episodes, "b").unwrap().id(),
    "episode-1",
  )
  assert_eq(@episodes.session_position(episodes[0], "a"), Some(0))
  assert_eq(
    @episodes.episode_window(episodes[0], "2026-01-02", "2026-01-03")
    .unwrap()
    .session_count(),
    1,
  )
  assert_true(@episodes.episode_text(episodes).contains("sessions=2"))
}
