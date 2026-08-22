///|
/// Structured Markdown output for review notes, dashboards and issue trackers.
pub(all) struct MarkdownSection {
  title : String
  level : Int
  body : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MarkdownSection::title(self : MarkdownSection) -> String {
  self.title
}

///|
pub fn MarkdownSection::level(self : MarkdownSection) -> Int {
  self.level
}

///|
pub fn MarkdownSection::body(self : MarkdownSection) -> String {
  self.body
}

///|
pub fn section(title : String, level : Int, body : String) -> MarkdownSection {
  MarkdownSection::{ title, level: Int::max(1, Int::min(6, level)), body }
}

///|
pub fn heading(title : String, level : Int) -> String {
  "#".repeat(Int::max(1, Int::min(6, level))) + " " + title + "\n\n"
}

///|
pub fn escape(value : String) -> String {
  value
  .replace(old="\\", new="\\\\")
  .replace(old="|", new="\\|")
  .replace(old="\n", new="<br>")
}

///|
pub fn bullet(items : Array[String]) -> String {
  let output = StringBuilder()
  for item in items {
    output.write_string("- " + item + "\n")
  }
  output.to_string() + "\n"
}

///|
pub fn numbered(items : Array[String]) -> String {
  let output = StringBuilder()
  for index, item in items {
    output.write_string((index + 1).to_string() + ". " + item + "\n")
  }
  output.to_string() + "\n"
}

///|
pub fn table(headers : Array[String], rows : Array[Array[String]]) -> String {
  if headers.is_empty() {
    ""
  } else {
    let output = StringBuilder()
    output.write_string("| " + headers.map(escape).join(" | ") + " |\n")
    output.write_string("| " + headers.map(_ => "---").join(" | ") + " |\n")
    for row in rows {
      output.write_string("| " + row.map(escape).join(" | ") + " |\n")
    }
    output.to_string() + "\n"
  }
}

///|
pub fn code_block(language : String, body : String) -> String {
  "```" + language + "\n" + body + "\n```\n\n"
}

///|
pub(all) struct MarkdownDocument {
  title : String
  sections : Array[MarkdownSection]
  footer : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn new_document(title : String) -> MarkdownDocument {
  MarkdownDocument::{ title, sections: [], footer: "" }
}

///|
pub fn MarkdownDocument::title(self : MarkdownDocument) -> String {
  self.title
}

///|
pub fn MarkdownDocument::sections(
  self : MarkdownDocument,
) -> Array[MarkdownSection] {
  self.sections
}

///|
pub fn MarkdownDocument::footer(self : MarkdownDocument) -> String {
  self.footer
}

///|
pub fn MarkdownDocument::add(
  self : MarkdownDocument,
  value : MarkdownSection,
) -> MarkdownDocument {
  let result = self
  result.sections.push(value)
  result
}

///|
pub fn MarkdownDocument::with_footer(
  self : MarkdownDocument,
  footer : String,
) -> MarkdownDocument {
  MarkdownDocument::{ title: self.title, sections: self.sections, footer }
}

///|
pub fn MarkdownDocument::render(self : MarkdownDocument) -> String {
  let output = StringBuilder()
  output.write_string(heading(self.title, 1))
  for item in self.sections {
    output.write_string(heading(item.title, item.level))
    output.write_string(item.body + "\n\n")
  }
  if !self.footer.is_empty() {
    output.write_string("---\n\n" + self.footer + "\n")
  }
  output.to_string()
}

///|
pub fn metric_line(
  name : String,
  value : String,
  note? : String = "",
) -> String {
  if note.is_empty() {
    "**" + name + ":** " + value + "\n\n"
  } else {
    "**" + name + ":** " + value + " — " + note + "\n\n"
  }
}

///|
pub fn status_badge(label : String) -> String {
  "`" + label + "`"
}

///|
pub fn session_document(
  session : @core.Session,
  privacy? : PrivacyMode = PrivacyMode::Full,
) -> MarkdownDocument {
  let visible_id = redact_id(session.id, privacy)
  let document = new_document("Session " + visible_id)
  let metrics = table(["Metric", "Value"], [
    ["Date", session.date],
    ["Duration", session.duration.to_string() + " min"],
    ["Pain before", session.pain_before.to_string()],
    ["Pain after", session.pain_after.to_string()],
    ["Pain delta", session.pain_delta().to_string()],
    ["Repetitions", session.total_reps().to_string()],
    ["Completion", session.average_completion().to_string()],
  ])
  let movement_rows = session.movements.map(movement => {
    [
      movement.name,
      movement.sets.length().to_string(),
      movement.pain.to_string(),
      movement.rpe.to_string(),
      movement.average_completion().to_string(),
    ]
  })
  document
  .add(section("Overview", 2, metrics))
  .add(
    section(
      "Movements",
      2,
      table(["Name", "Sets", "Pain", "RPE", "Completion"], movement_rows),
    ),
  )
  .add(
    section(
      "Notes",
      2,
      if session.notes.is_empty() {
        "_No notes recorded._"
      } else {
        escape(redact_notes(session.notes, privacy))
      },
    ),
  )
}

///|
pub fn trend_document(
  report : @analytics.TrendReport,
  title : String,
) -> MarkdownDocument {
  let document = new_document(title)
  let summary = table(["Metric", "Value"], [
    ["Sessions", report.session_count().to_string()],
    ["Repetitions", report.total_reps().to_string()],
    ["Work units", report.total_work_units().to_string()],
    ["Average pain", report.average_pain().to_string()],
    ["Average completion", report.average_completion().to_string()],
    ["Pain direction", report.pain_direction().label()],
    ["Completion direction", report.completion_direction().label()],
  ])
  let rows = report
    .snapshots()
    .map(item => {
      [
        item.date(),
        item.session_id(),
        item.average_pain().to_string(),
        item.average_completion().to_string(),
        item.recovery().label(),
      ]
    })
  document
  .add(section("Summary", 2, summary))
  .add(
    section(
      "Timeline",
      2,
      table(["Date", "Session", "Pain", "Completion", "Recovery"], rows),
    ),
  )
}

///|
pub fn quality_document(
  sessions : Array[@core.Session],
  title : String,
) -> MarkdownDocument {
  let scores = @quality.score_many(sessions)
  let rows = scores.map(item => {
    [
      item.session_id(),
      item.score().to_string(),
      item.grade().label(),
      item.completeness().to_string(),
      item.consistency().to_string(),
      item.validity().to_string(),
    ]
  })
  new_document(title)
  .add(
    section(
      "Quality scores",
      2,
      table(
        ["Session", "Score", "Grade", "Complete", "Consistent", "Valid"],
        rows,
      ),
    ),
  )
  .add(section("Warnings", 2, bullet(@quality.quality_warnings(sessions))))
}

///|
pub fn compare_documents(
  left : @core.Session,
  right : @core.Session,
  title : String,
) -> MarkdownDocument {
  let rows = [
    ["Date", left.date, right.date],
    ["Pain after", left.pain_after.to_string(), right.pain_after.to_string()],
    [
      "Completion",
      left.average_completion().to_string(),
      right.average_completion().to_string(),
    ],
    [
      "Repetitions",
      left.total_reps().to_string(),
      right.total_reps().to_string(),
    ],
    [
      "Work units",
      left.total_work_units().to_string(),
      right.total_work_units().to_string(),
    ],
  ]
  new_document(title)
  .add(section("Comparison", 2, table(["Metric", "Before", "After"], rows)))
  .add(
    section(
      "Interpretation",
      2,
      metric_line(
        "Pain delta",
        (right.pain_after - left.pain_after).to_string(),
      ) +
      metric_line(
        "Completion delta",
        (right.average_completion() - left.average_completion()).to_string(),
      ),
    ),
  )
}

///|
pub fn changelog(
  version : String,
  changes : Array[String],
  checks : Array[String],
) -> String {
  heading("Release " + version, 2) +
  heading("Changes", 3) +
  bullet(changes) +
  heading("Verification", 3) +
  bullet(checks)
}

///|
pub fn report_bundle(sessions : Array[@core.Session], title : String) -> String {
  let trend = @analytics.analyze(sessions)
  let document = trend_document(trend, title)
  document
  .with_footer(
    "Generated from " +
    sessions.length().to_string() +
    " deterministic session records.",
  )
  .render()
}
