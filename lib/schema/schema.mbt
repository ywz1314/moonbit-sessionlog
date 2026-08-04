///|
pub(all) struct SessionV1 {
  id : String
  date : String
  duration : Int
  pain_before : Int
  pain_after : Int
  movements : Array[String]
  notes : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct SessionV2 {
  version : Int
  id : String
  date : String
  duration : Int
  pain_before : Int
  pain_after : Int
  movements : Array[@core.Movement]
  notes : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SessionV2::to_core_session(self : SessionV2) -> @core.Session {
  @core.Session::{
    id: self.id,
    date: self.date,
    duration: self.duration,
    pain_before: self.pain_before,
    pain_after: self.pain_after,
    movements: self.movements,
    notes: self.notes,
  }
}

///|
pub fn SessionV2::from_core_session(session : @core.Session) -> SessionV2 {
  SessionV2::{
    version: 2,
    id: session.id,
    date: session.date,
    duration: session.duration,
    pain_before: session.pain_before,
    pain_after: session.pain_after,
    movements: session.movements,
    notes: session.notes,
  }
}

///|
pub fn SessionV1::migrate_to_v2(self : SessionV1) -> @core.Session {
  let movements = []
  for mv_name in self.movements {
    let m = @core.Movement::{ name: mv_name, sets: [], pain: 0, rpe: 5 }
    movements.push(m)
  }
  @core.Session::{
    id: self.id,
    date: self.date,
    duration: self.duration,
    pain_before: self.pain_before,
    pain_after: self.pain_after,
    movements,
    notes: self.notes,
  }
}

///|
pub fn parse_and_migrate_session(
  json_str : String,
) -> Result[@core.Session, String] {
  try {
    let json = @json.parse(json_str)
    let mut version = 1
    match json {
      Object(obj) =>
        match obj.get("version") {
          Some(Number(v, ..)) => version = v.to_int()
          _ => ()
        }
      _ => return Err("Invalid JSON: expected a JSON object")
    }
    if version == 2 {
      let v2 : SessionV2 = @json.from_json(json)
      Ok(v2.to_core_session())
    } else if version == 1 {
      let v1 : SessionV1 = @json.from_json(json)
      Ok(v1.migrate_to_v2())
    } else {
      Err("Unsupported schema version: " + version.to_string())
    }
  } catch {
    err => Err("Failed to parse or migrate session: " + err.to_string())
  }
}
