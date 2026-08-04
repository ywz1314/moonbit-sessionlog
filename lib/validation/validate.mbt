///|
pub enum ValidationError {
  InvalidPain(String, Int) // (field_name, value)
  InvalidRPE(String, Int) // (field_name, value)
  InvalidReps(String, Int) // (field_name, value)
  InvalidDuration(Int) // value
  InvalidCompletion(String, Double) // (field_name, value)
  InvalidDate(String) // date value
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn validate_session(session : @core.Session) -> Array[ValidationError] {
  let errors = []
  
  // 1. Pain VAS checks
  if session.pain_before < 0 || session.pain_before > 10 {
    errors.push(ValidationError::InvalidPain("pain_before", session.pain_before))
  }
  if session.pain_after < 0 || session.pain_after > 10 {
    errors.push(ValidationError::InvalidPain("pain_after", session.pain_after))
  }
  
  // 2. Duration check
  if session.duration < 0 {
    errors.push(ValidationError::InvalidDuration(session.duration))
  }
  
  // 3. Date check (YYYY-MM-DD basic verification)
  if session.date.length() != 10 {
    errors.push(ValidationError::InvalidDate(session.date))
  } else {
    // Check if characters at index 4 and 7 are dashes
    if session.date[4] != '-' || session.date[7] != '-' {
      errors.push(ValidationError::InvalidDate(session.date))
    }
  }
  
  // 4. Movements check
  for movement in session.movements {
    if movement.pain < 0 || movement.pain > 10 {
      errors.push(ValidationError::InvalidPain("movement:" + movement.name + ":pain", movement.pain))
    }
    if movement.rpe < 1 || movement.rpe > 10 {
      errors.push(ValidationError::InvalidRPE("movement:" + movement.name + ":rpe", movement.rpe))
    }
    
    // Sets check
    for i, set in movement.sets {
      let suffix = ":" + i.to_string()
      if set.reps < 0 {
        errors.push(ValidationError::InvalidReps("movement:" + movement.name + ":set" + suffix + ":reps", set.reps))
      }
      if set.hold_time < 0 {
        errors.push(ValidationError::InvalidReps("movement:" + movement.name + ":set" + suffix + ":hold_time", set.hold_time)) // using InvalidReps for negative hold_time
      }
      if set.completion < 0.0 || set.completion > 1.0 {
        errors.push(ValidationError::InvalidCompletion("movement:" + movement.name + ":set" + suffix + ":completion", set.completion))
      }
    }
  }
  
  errors
}
