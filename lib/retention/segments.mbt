///|
/// Retention segments provide operational buckets for deciding what to keep
/// hot, archive, review, or export.  They are descriptive and do not delete
/// data by themselves.
pub(all) enum RetentionSegmentKind {
  Recent
  Active
  Stable
  NeedsReview
  Sparse
  Duplicate
  ArchiveCandidate
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RetentionSegmentKind::label(self : RetentionSegmentKind) -> String {
  match self {
    Recent => "recent"
    Active => "active"
    Stable => "stable"
    NeedsReview => "needs_review"
    Sparse => "sparse"
    Duplicate => "duplicate"
    ArchiveCandidate => "archive_candidate"
  }
}

///|
pub(all) struct RetentionSegment {
  session_id : String
  kind : RetentionSegmentKind
  score : Int
  reasons : Array[String]
  fingerprint : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn RetentionSegment::session_id(self : RetentionSegment) -> String {
  self.session_id
}

///|
pub fn RetentionSegment::kind(self : RetentionSegment) -> RetentionSegmentKind {
  self.kind
}

///|
pub fn RetentionSegment::score(self : RetentionSegment) -> Int {
  self.score
}

///|
pub fn RetentionSegment::reasons(self : RetentionSegment) -> Array[String] {
  self.reasons.copy()
}

///|
pub fn RetentionSegment::fingerprint(self : RetentionSegment) -> String {
  self.fingerprint
}

///|
fn segment_for(
  session : @core.Session,
  duplicate : Bool,
  recent_days : Int,
  reference_date : String,
) -> RetentionSegment {
  let reasons = []
  let mut kind = RetentionSegmentKind::Stable
  let mut score = 50
  let age_hint = match
    (@calendar.parse(session.date), @calendar.parse(reference_date)) {
    (Some(session_date), Some(reference)) =>
      Int::max(0, @calendar.days_between(session_date, reference))
    _ => if session.date >= reference_date { 0 } else { recent_days + 1 }
  }
  if duplicate {
    kind = RetentionSegmentKind::Duplicate
    score = 10
    reasons.push("same fingerprint appears more than once")
  } else if age_hint <= recent_days {
    kind = RetentionSegmentKind::Recent
    score = 90
    reasons.push("within recent import window")
  } else if session.total_sets() == 0 {
    kind = RetentionSegmentKind::Sparse
    score = 25
    reasons.push("no sets recorded")
  } else if session.pain_after >= 7 || session.pain_delta() > 2 {
    kind = RetentionSegmentKind::NeedsReview
    score = 95
    reasons.push("pain requires review")
  } else if session.average_completion() >= 0.8 {
    kind = RetentionSegmentKind::Active
    score = 75
    reasons.push("high completion indicates active treatment")
  } else {
    kind = RetentionSegmentKind::ArchiveCandidate
    score = 35
    reasons.push("low activity and older date")
  }
  RetentionSegment::{
    session_id: session.id,
    kind,
    score,
    reasons,
    fingerprint: fingerprint(session),
  }
}

///|
pub fn segment_sessions(
  sessions : Array[@core.Session],
  reference_date : String,
  recent_days : Int,
) -> Array[RetentionSegment] {
  let seen = []
  let result = []
  for session in sessions {
    let value = fingerprint(session)
    let duplicate = seen.contains(value)
    seen.push(value)
    result.push(
      segment_for(session, duplicate, Int::max(0, recent_days), reference_date),
    )
  }
  result
}

///|
pub fn segment_counts(values : Array[RetentionSegment]) -> Array[(String, Int)] {
  let counts : Array[(String, Int)] = []
  for value in values {
    let label = value.kind.label()
    match counts.search_by(item => item.0 == label) {
      Some(index) => {
        let old = counts[index]
        counts[index] = (old.0, old.1 + 1)
      }
      None => counts.push((label, 1))
    }
  }
  counts.sort_by((left, right) => right.1 - left.1)
  counts
}

///|
pub fn segment_by_kind(
  values : Array[RetentionSegment],
  kind : RetentionSegmentKind,
) -> Array[RetentionSegment] {
  values.filter(value => value.kind == kind)
}

///|
pub fn segment_score(
  values : Array[RetentionSegment],
  kind : RetentionSegmentKind,
) -> Double {
  let selected = segment_by_kind(values, kind)
  if selected.is_empty() {
    0.0
  } else {
    selected.fold(init=0, (total, value) => total + value.score).to_double() /
    selected.length().to_double()
  }
}

///|
pub(all) struct SegmentPlan {
  segments : Array[RetentionSegment]
  hot : Array[String]
  review : Array[String]
  archive : Array[String]
  duplicates : Array[String]
  export_order : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn SegmentPlan::segments(self : SegmentPlan) -> Array[RetentionSegment] {
  self.segments.copy()
}

///|
pub fn SegmentPlan::hot(self : SegmentPlan) -> Array[String] {
  self.hot.copy()
}

///|
pub fn SegmentPlan::review(self : SegmentPlan) -> Array[String] {
  self.review.copy()
}

///|
pub fn SegmentPlan::archive(self : SegmentPlan) -> Array[String] {
  self.archive.copy()
}

///|
pub fn SegmentPlan::duplicates(self : SegmentPlan) -> Array[String] {
  self.duplicates.copy()
}

///|
pub fn SegmentPlan::export_order(self : SegmentPlan) -> Array[String] {
  self.export_order.copy()
}

///|
pub fn build_segment_plan(values : Array[RetentionSegment]) -> SegmentPlan {
  let hot = []
  let review = []
  let archive = []
  let duplicates = []
  for value in values {
    match value.kind {
      RetentionSegmentKind::Recent | RetentionSegmentKind::Active =>
        hot.push(value.session_id)
      RetentionSegmentKind::NeedsReview => review.push(value.session_id)
      RetentionSegmentKind::ArchiveCandidate | RetentionSegmentKind::Sparse =>
        archive.push(value.session_id)
      RetentionSegmentKind::Duplicate => duplicates.push(value.session_id)
      RetentionSegmentKind::Stable => ()
    }
  }
  let export_order = review.copy()
  export_order.append(hot)
  export_order.append(archive)
  SegmentPlan::{
    segments: values,
    hot,
    review,
    archive,
    duplicates,
    export_order,
  }
}

///|
pub fn segment_plan_safe(value : SegmentPlan, max_archive : Int) -> Bool {
  value.duplicates.is_empty() && value.archive.length() <= max_archive
}

///|
pub fn segment_plan_text(value : SegmentPlan) -> String {
  "hot=" +
  value.hot.length().to_string() +
  ", review=" +
  value.review.length().to_string() +
  ", archive=" +
  value.archive.length().to_string() +
  ", duplicates=" +
  value.duplicates.length().to_string()
}

///|
pub fn segment_fingerprint(value : RetentionSegment) -> String {
  value.session_id + ":" + value.kind.label() + ":" + value.score.to_string()
}

///|
pub fn segment_checksum(values : Array[RetentionSegment]) -> Int {
  values.fold(init=19, (total, value) => {
    total * 31 + value.score + value.session_id.length()
  })
}

///|
pub fn segment_reasons(values : Array[RetentionSegment]) -> Array[String] {
  let reasons = []
  for value in values {
    for reason in value.reasons {
      if !reasons.contains(reason) {
        reasons.push(reason)
      }
    }
  }
  reasons
}
