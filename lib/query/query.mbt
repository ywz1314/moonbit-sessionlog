///|
pub(all) struct SessionQuery {
  mut id_contains : String
  mut date_from : String
  mut date_to : String
  mut movement_name : String
  mut minimum_pain : Int
  mut maximum_pain : Int
  mut minimum_completion : Double
  mut maximum_completion : Double
  mut minimum_duration : Int
  mut valid_only : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn empty_query() -> SessionQuery {
  SessionQuery::{
    id_contains: "",
    date_from: "",
    date_to: "",
    movement_name: "",
    minimum_pain: -1,
    maximum_pain: -1,
    minimum_completion: -1.0,
    maximum_completion: -1.0,
    minimum_duration: -1,
    valid_only: false,
  }
}

///|
pub fn by_movement(query : SessionQuery, name : String) -> SessionQuery {
  query.movement_name = name
  query
}

///|
pub fn by_date_range(
  query : SessionQuery,
  start : String,
  end : String,
) -> SessionQuery {
  query.date_from = start
  query.date_to = end
  query
}

///|
pub fn by_pain(
  query : SessionQuery,
  minimum : Int,
  maximum : Int,
) -> SessionQuery {
  query.minimum_pain = minimum
  query.maximum_pain = maximum
  query
}

///|
pub fn by_completion(
  query : SessionQuery,
  minimum : Double,
  maximum : Double,
) -> SessionQuery {
  query.minimum_completion = minimum
  query.maximum_completion = maximum
  query
}

///|
pub fn valid_only(query : SessionQuery) -> SessionQuery {
  query.valid_only = true
  query
}

///|
pub fn matches(query : SessionQuery, session : @core.Session) -> Bool {
  let pain = session.average_pain_during()
  let has_id = query.id_contains.is_empty() ||
    session.id.contains(query.id_contains)
  let after_start = query.date_from.is_empty() ||
    session.date >= query.date_from
  let before_end = query.date_to.is_empty() || session.date <= query.date_to
  let movement = query.movement_name.is_empty() ||
    session.movement(query.movement_name) is Some(_)
  let pain_min = query.minimum_pain < 0 ||
    pain >= query.minimum_pain.to_double()
  let pain_max = query.maximum_pain < 0 ||
    pain <= query.maximum_pain.to_double()
  let completion_min = query.minimum_completion < 0.0 ||
    session.average_completion() >= query.minimum_completion
  let completion_max = query.maximum_completion < 0.0 ||
    session.average_completion() <= query.maximum_completion
  let duration = query.minimum_duration < 0 ||
    session.duration >= query.minimum_duration
  let valid = !query.valid_only || @validation.is_valid(session)
  has_id &&
  after_start &&
  before_end &&
  movement &&
  pain_min &&
  pain_max &&
  completion_min &&
  completion_max &&
  duration &&
  valid
}

///|
pub fn filter(
  sessions : Array[@core.Session],
  query : SessionQuery,
) -> Array[@core.Session] {
  sessions.filter(session => matches(query, session))
}

///|
pub fn count(sessions : Array[@core.Session], query : SessionQuery) -> Int {
  sessions.count_if(session => matches(query, session))
}

///|
pub fn first(
  sessions : Array[@core.Session],
  query : SessionQuery,
) -> @core.Session? {
  filter(sessions, query).get(0)
}

///|
pub fn ids(
  sessions : Array[@core.Session],
  query : SessionQuery,
) -> Array[String] {
  filter(sessions, query).map(session => session.id)
}

///|
pub fn total_reps(sessions : Array[@core.Session], query : SessionQuery) -> Int {
  filter(sessions, query).fold(init=0, (total, session) => {
    total + session.total_reps()
  })
}

///|
pub fn average_pain(
  sessions : Array[@core.Session],
  query : SessionQuery,
) -> Double {
  let selected = filter(sessions, query)
  if selected.is_empty() {
    0.0
  } else {
    selected.fold(init=0.0, (total, session) => {
      total + session.average_pain_during()
    }) /
    selected.length().to_double()
  }
}

///|
pub fn group_by_movement(
  sessions : Array[@core.Session],
  query : SessionQuery,
) -> Array[(String, Int)] {
  let counts : Map[String, Int] = Map([])
  for session in filter(sessions, query) {
    for movement in session.movements {
      counts.update_or_default(movement.name, 1, value => value + 1)
    }
  }
  counts.to_array()
}

///|
pub fn describe(query : SessionQuery) -> String {
  let parts = []
  if !query.id_contains.is_empty() {
    parts.push("id contains '" + query.id_contains + "'")
  }
  if !query.movement_name.is_empty() {
    parts.push("movement='" + query.movement_name + "'")
  }
  if !query.date_from.is_empty() || !query.date_to.is_empty() {
    parts.push("date range")
  }
  if query.minimum_pain >= 0 || query.maximum_pain >= 0 {
    parts.push("pain range")
  }
  if query.minimum_completion >= 0.0 || query.maximum_completion >= 0.0 {
    parts.push("completion range")
  }
  if query.valid_only {
    parts.push("valid only")
  }
  if parts.is_empty() {
    "all sessions"
  } else {
    parts.join(", ")
  }
}

///|
pub fn sort_by_date(sessions : Array[@core.Session]) -> Array[@core.Session] {
  let output = sessions.copy()
  output.sort_by((left, right) => left.date.compare(right.date))
  output
}

///|
pub fn sort_by_pain(sessions : Array[@core.Session]) -> Array[@core.Session] {
  let output = sessions.copy()
  output.sort_by((left, right) => {
    left.average_pain_during().compare(right.average_pain_during())
  })
  output
}

///|
pub fn sort_by_completion(
  sessions : Array[@core.Session],
) -> Array[@core.Session] {
  let output = sessions.copy()
  output.sort_by((left, right) => {
    right.average_completion().compare(left.average_completion())
  })
  output
}
