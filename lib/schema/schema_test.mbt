///|
test "parse and migrate V1 session" {
  let v1_json =
    #|{
    #|  "id": "s-v1-001",
    #|  "date": "2026-08-01",
    #|  "duration": 30,
    #|  "pain_before": 6,
    #|  "pain_after": 4,
    #|  "movements": ["Squat", "Leg Curl"],
    #|  "notes": "Version 1 log test"
    #|}
  
  match @schema.parse_and_migrate_session(v1_json) {
    Ok(session) => {
      assert_eq(session.id, "s-v1-001")
      assert_eq(session.date, "2026-08-01")
      assert_eq(session.duration, 30)
      assert_eq(session.pain_before, 6)
      assert_eq(session.pain_after, 4)
      assert_eq(session.movements.length(), 2)
      assert_eq(session.movements[0].name, "Squat")
      assert_eq(session.movements[0].pain, 0) // Default pain migrated
      assert_eq(session.movements[0].rpe, 5) // Default rpe migrated
      assert_eq(session.movements[1].name, "Leg Curl")
      assert_eq(session.notes, "Version 1 log test")
    }
    _ => panic()
  }
}

///|
test "parse V2 session" {
  let v2_json =
    #|{
    #|  "version": 2,
    #|  "id": "s-v2-002",
    #|  "date": "2026-08-04",
    #|  "duration": 40,
    #|  "pain_before": 5,
    #|  "pain_after": 2,
    #|  "movements": [
    #|    {
    #|      "name": "Squat",
    #|      "sets": [
    #|        {
    #|          "reps": 10,
    #|          "hold_time": 5,
    #|          "resistance": "Bodyweight",
    #|          "completion": 1.0
    #|        }
    #|      ],
    #|      "pain": 2,
    #|      "rpe": 4
    #|    }
    #|  ],
    #|  "notes": "Version 2 log test"
    #|}
  
  match @schema.parse_and_migrate_session(v2_json) {
    Ok(session) => {
      assert_eq(session.id, "s-v2-002")
      assert_eq(session.date, "2026-08-04")
      assert_eq(session.duration, 40)
      assert_eq(session.pain_before, 5)
      assert_eq(session.pain_after, 2)
      assert_eq(session.movements.length(), 1)
      assert_eq(session.movements[0].name, "Squat")
      assert_eq(session.movements[0].sets.length(), 1)
      assert_eq(session.movements[0].sets[0].reps, 10)
      assert_eq(session.movements[0].sets[0].resistance, "Bodyweight")
      assert_eq(session.movements[0].pain, 2)
      assert_eq(session.movements[0].rpe, 4)
      assert_eq(session.notes, "Version 2 log test")
    }
    _ => panic()
  }
}

///|
test "serialize to V2 JSON" {
  let set1 = @core.Set::{ reps: 8, hold_time: 10, resistance: "10kg", completion: 0.8 }
  let mv1 = @core.Movement::{ name: "Deadlift", sets: [set1], pain: 4, rpe: 6 }
  let session = @core.Session::{
    id: "s-out",
    date: "2026-08-05",
    duration: 50,
    pain_before: 3,
    pain_after: 3,
    movements: [mv1],
    notes: "Export test"
  }
  
  let v2_struct = @schema.SessionV2::from_core_session(session)
  let json_str = v2_struct.to_json().stringify()
  
  // Re-parse and verify
  match @schema.parse_and_migrate_session(json_str) {
    Ok(s) => {
      assert_eq(s.id, "s-out")
      assert_eq(s.date, "2026-08-05")
      assert_eq(s.duration, 50)
      assert_eq(s.pain_before, 3)
      assert_eq(s.pain_after, 3)
      assert_eq(s.movements.length(), 1)
      assert_eq(s.movements[0].name, "Deadlift")
      assert_eq(s.movements[0].sets[0].reps, 8)
      assert_eq(s.movements[0].sets[0].resistance, "10kg")
      assert_eq(s.movements[0].sets[0].completion, 0.8)
      assert_eq(s.movements[0].pain, 4)
      assert_eq(s.movements[0].rpe, 6)
      assert_eq(s.notes, "Export test")
    }
    _ => panic()
  }
}
