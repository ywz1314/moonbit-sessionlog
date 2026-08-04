///|
test "session serialization and deserialization" {
  let set1 = Set::{
    reps: 10,
    hold_time: 5,
    resistance: "Yellow Band",
    completion: 1.0,
  }
  let mv1 = Movement::{ name: "Squat", sets: [set1], pain: 3, rpe: 4 }
  let session = Session::{
    id: "s-001",
    date: "2026-08-04",
    duration: 30,
    pain_before: 5,
    pain_after: 2,
    movements: [mv1],
    notes: "Felt good after warm up",
  }

  // Serialize
  let json = session.to_json()
  // Deserialize
  try {
    let deserialized : Session = @json.from_json(json)
    assert_eq(session.id, deserialized.id)
    assert_eq(session.date, deserialized.date)
    assert_eq(session.duration, deserialized.duration)
    assert_eq(session.pain_before, deserialized.pain_before)
    assert_eq(session.pain_after, deserialized.pain_after)
    assert_eq(session.notes, deserialized.notes)
    assert_eq(session.movements.length(), deserialized.movements.length())
    assert_eq(session.movements[0].name, deserialized.movements[0].name)
    assert_eq(session.movements[0].pain, deserialized.movements[0].pain)
    assert_eq(session.movements[0].rpe, deserialized.movements[0].rpe)
  } catch {
    _ => panic()
  }
}
