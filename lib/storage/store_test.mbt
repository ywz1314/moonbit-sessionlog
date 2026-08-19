///|
fn stored_session(id : String, date : String, pain : Int) -> @core.Session {
  let set = @core.Set::{
    reps: 10,
    hold_time: 5,
    resistance: "body",
    completion: 1.0,
  }
  let movement = @core.Movement::{ name: "walk", sets: [set], pain, rpe: 4 }
  @core.Session::{
    id,
    date,
    duration: 20,
    pain_before: pain,
    pain_after: pain - 1,
    movements: [movement],
    notes: "",
  }
}

///|
test "store lifecycle and indexes" {
  let store = @storage.SessionStore::new(capacity=2)
  assert_eq(store.insert(stored_session("b", "2026-08-02", 4)), Ok(()))
  assert_eq(store.insert(stored_session("a", "2026-08-01", 2)), Ok(()))
  assert_true(store.contains("a"))
  assert_eq(store.count(), 2)
  assert_eq(
    store.insert(stored_session("c", "2026-08-03", 1)),
    Err("session store capacity exceeded"),
  )
  assert_eq(store.sorted_by_date().map(session => session.id), ["a", "b"])
  assert_eq(store.latest().unwrap().id, "b")
  assert_eq(store.earliest().unwrap().id, "a")
  assert_eq(store.with_movement("walk").length(), 2)
  assert_eq(store.with_pain_at_least(4).length(), 1)
  assert_eq(store.pain_improved_count(), 2)
  assert_eq(store.page(1, 1)[0].id, "a")
  assert_eq(store.remove("a"), true)
  assert_eq(store.remove("missing"), false)
}

///|
test "store import export and statistics" {
  let source = @storage.SessionStore::new()
  ignore(source.insert(stored_session("a", "2026-08-01", 2)))
  let exported = source.export_json()
  let target = @storage.SessionStore::new()
  assert_eq(target.import_json(exported), Ok(1))
  assert_eq(target.get("a").unwrap().id, "a")
  assert_eq(
    target.stats().summary(),
    "sessions=1, reps=10, sets=1, valid=1, invalid=0",
  )
  assert_eq(target.movement_names(), ["walk"])
  assert_eq(target.average_duration(), 20.0)
}
