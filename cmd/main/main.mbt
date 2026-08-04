///|
fn main {
  println("==================================================")
  println("  MoonBit Rehabilitation Session Log Model Demo")
  println("==================================================")

  // 1. Define V1 Log (Legacy format: movements are just string names)
  let v1_json =
    #|{
    #|  "id": "session-20260801",
    #|  "date": "2026-08-01",
    #|  "duration": 30,
    #|  "pain_before": 6,
    #|  "pain_after": 4,
    #|  "movements": ["Squat", "Leg Raise"],
    #|  "notes": "Version 1 raw log - knee rehab first stage"
    #|}

  println("\n--- [1] Parsing and migrating Legacy V1 Log ---")
  match @schema.parse_and_migrate_session(v1_json) {
    Ok(s1) => {
      println("Successfully parsed and migrated V1 session:")
      println("  ID: " + s1.id)
      println("  Date: " + s1.date)
      println("  Duration: " + s1.duration.to_string() + " mins")
      println(
        "  Pain (before -> after): " +
        s1.pain_before.to_string() +
        " -> " +
        s1.pain_after.to_string(),
      )
      println(
        "  Migrated movements count: " + s1.movements.length().to_string(),
      )
      for m in s1.movements {
        println(
          "    - Movement: " +
          m.name +
          " (Default pain: " +
          m.pain.to_string() +
          ", RPE: " +
          m.rpe.to_string() +
          ")",
        )
      }
    }
    Err(e) => println("Error parsing V1: " + e)
  }

  // 2. Define V2 Log (Modern format with full sets, completion rates, pain, and RPE)
  let v2_json =
    #|{
    #|  "version": 2,
    #|  "id": "session-20260804",
    #|  "date": "2026-08-04",
    #|  "duration": 45,
    #|  "pain_before": 4,
    #|  "pain_after": 2,
    #|  "movements": [
    #|    {
    #|      "name": "Squat",
    #|      "sets": [
    #|        { "reps": 10, "hold_time": 5, "resistance": "Yellow Band", "completion": 1.0 },
    #|        { "reps": 10, "hold_time": 5, "resistance": "Yellow Band", "completion": 1.0 },
    #|        { "reps": 10, "hold_time": 5, "resistance": "Yellow Band", "completion": 0.9 }
    #|      ],
    #|      "pain": 2,
    #|      "rpe": 4
    #|    },
    #|    {
    #|      "name": "Single Leg Balance",
    #|      "sets": [
    #|        { "reps": 3, "hold_time": 30, "resistance": "Bodyweight", "completion": 0.6 }
    #|      ],
    #|      "pain": 5,
    #|      "rpe": 8
    #|    }
    #|  ],
    #|  "notes": "Version 2 log - progressed to yellow band squats today."
    #|}

  println("\n--- [2] Parsing Modern V2 Log ---")
  match @schema.parse_and_migrate_session(v2_json) {
    Ok(s2) => {
      println("Successfully parsed V2 session:")
      println("  ID: " + s2.id)
      println("  Date: " + s2.date)
      println("  Duration: " + s2.duration.to_string() + " mins")
      println(
        "  Pain (before -> after): " +
        s2.pain_before.to_string() +
        " -> " +
        s2.pain_after.to_string(),
      )

      // 3. Run validation
      println("\n--- [3] Validating V2 Log ---")
      let errors = @validation.validate_session(s2)
      if errors.length() == 0 {
        println("Validation check: PASS (0 errors found)")
      } else {
        println(
          "Validation check: FAILED (" +
          errors.length().to_string() +
          " errors found)",
        )
        for err in errors {
          println("  - Error: " + err.to_json().stringify())
        }
      }

      // 4. Run progression analysis
      println("\n--- [4] Generating Progression Recommendations ---")
      for m in s2.movements {
        let advice = @progression.analyze_progression(m)
        println("  Movement: " + m.name)
        println(
          "    Current load: " +
          m.sets.length().to_string() +
          " sets x " +
          (if m.sets.length() > 0 { m.sets[0].reps.to_string() } else { "0" }) +
          " reps @ " +
          (if m.sets.length() > 0 { m.sets[0].resistance } else { "None" }),
        )
        println(
          "    Pain during: " +
          m.pain.to_string() +
          ", RPE: " +
          m.rpe.to_string(),
        )
        println("    Recommendation: " + advice.state.to_json().stringify())
        println("    Reason: " + advice.reason)
        println(
          "    Suggested next: " +
          advice.suggested_sets.to_string() +
          " sets x " +
          advice.suggested_reps.to_string() +
          " reps @ " +
          advice.suggested_resistance,
        )
        println("")
      }
    }
    Err(e) => println("Error parsing V2: " + e)
  }

  // 5. Demonstrate Validation failing on incorrect data
  let invalid_json =
    #|{
    #|  "version": 2,
    #|  "id": "session-invalid",
    #|  "date": "2026/08/04",
    #|  "duration": -15,
    #|  "pain_before": 12,
    #|  "pain_after": -3,
    #|  "movements": [
    #|    {
    #|      "name": "Squat",
    #|      "sets": [
    #|        { "reps": -5, "hold_time": 5, "resistance": "Yellow Band", "completion": 1.2 }
    #|      ],
    #|      "pain": 11,
    #|      "rpe": 15
    #|    }
    #|  ],
    #|  "notes": "Invalid log entry demonstrating validators."
    #|}

  println("--- [5] Demonstrating Log Validation Failure ---")
  match @schema.parse_and_migrate_session(invalid_json) {
    Ok(s_invalid) => {
      let errors = @validation.validate_session(s_invalid)
      println("Validation result on invalid session:")
      for err in errors {
        println("  - Error: " + err.to_json().stringify())
      }
    }
    Err(e) => println("Failed to parse invalid session JSON: " + e)
  }
}
