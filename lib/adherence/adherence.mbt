///|
/// Operational adherence state for a scheduled rehabilitation day.
pub(all) enum AdherenceStatus {
  Unscheduled
  Completed
  Partial
  Missed
  Overdue
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn AdherenceStatus::label(self : AdherenceStatus) -> String {
  match self {
    Unscheduled => "unscheduled"
    Completed => "completed"
    Partial => "partial"
    Missed => "missed"
    Overdue => "overdue"
  }
}

///|
pub fn AdherenceStatus::counts_as_completed(self : AdherenceStatus) -> Bool {
  self == AdherenceStatus::Completed
}

///|
pub fn AdherenceStatus::counts_as_attempted(self : AdherenceStatus) -> Bool {
  self == AdherenceStatus::Completed || self == AdherenceStatus::Partial
}

///|
pub(all) struct AdherenceOptions {
  include_unscheduled_days : Bool
  include_weekends : Bool
  treat_partial_as_attempt : Bool
  overdue_after_days : Int
  minimum_adherence : Double
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_adherence_options() -> AdherenceOptions {
  AdherenceOptions::{
    include_unscheduled_days: false,
    include_weekends: true,
    treat_partial_as_attempt: true,
    overdue_after_days: 2,
    minimum_adherence: 80.0,
  }
}

///|
pub fn AdherenceOptions::include_unscheduled_days(
  self : AdherenceOptions,
) -> Bool {
  self.include_unscheduled_days
}

///|
pub fn AdherenceOptions::include_weekends(self : AdherenceOptions) -> Bool {
  self.include_weekends
}

///|
pub fn AdherenceOptions::treat_partial_as_attempt(
  self : AdherenceOptions,
) -> Bool {
  self.treat_partial_as_attempt
}

///|
pub fn AdherenceOptions::overdue_after_days(self : AdherenceOptions) -> Int {
  self.overdue_after_days
}

///|
pub fn AdherenceOptions::minimum_adherence(self : AdherenceOptions) -> Double {
  self.minimum_adherence
}

///|
pub fn with_weekends(
  options : AdherenceOptions,
  enabled : Bool,
) -> AdherenceOptions {
  AdherenceOptions::{
    include_unscheduled_days: options.include_unscheduled_days,
    include_weekends: enabled,
    treat_partial_as_attempt: options.treat_partial_as_attempt,
    overdue_after_days: options.overdue_after_days,
    minimum_adherence: options.minimum_adherence,
  }
}

///|
pub fn with_unscheduled(
  options : AdherenceOptions,
  enabled : Bool,
) -> AdherenceOptions {
  AdherenceOptions::{
    include_unscheduled_days: enabled,
    include_weekends: options.include_weekends,
    treat_partial_as_attempt: options.treat_partial_as_attempt,
    overdue_after_days: options.overdue_after_days,
    minimum_adherence: options.minimum_adherence,
  }
}

///|
pub fn with_partial_attempt(
  options : AdherenceOptions,
  enabled : Bool,
) -> AdherenceOptions {
  AdherenceOptions::{
    include_unscheduled_days: options.include_unscheduled_days,
    include_weekends: options.include_weekends,
    treat_partial_as_attempt: enabled,
    overdue_after_days: options.overdue_after_days,
    minimum_adherence: options.minimum_adherence,
  }
}

///|
pub fn with_minimum_adherence(
  options : AdherenceOptions,
  percent : Double,
) -> AdherenceOptions {
  AdherenceOptions::{
    include_unscheduled_days: options.include_unscheduled_days,
    include_weekends: options.include_weekends,
    treat_partial_as_attempt: options.treat_partial_as_attempt,
    overdue_after_days: Int::max(0, options.overdue_after_days),
    minimum_adherence: Double::max(0.0, Double::min(100.0, percent)),
  }
}

///|
pub(all) struct DayRecord {
  date : String
  day : @planning.PlanDay
  scheduled_count : Int
  completed_count : Int
  partial_count : Int
  missed_count : Int
  session_count : Int
  adherence : Double
  status : AdherenceStatus
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn DayRecord::date(self : DayRecord) -> String {
  self.date
}

///|
pub fn DayRecord::day(self : DayRecord) -> @planning.PlanDay {
  self.day
}

///|
pub fn DayRecord::scheduled_count(self : DayRecord) -> Int {
  self.scheduled_count
}

///|
pub fn DayRecord::completed_count(self : DayRecord) -> Int {
  self.completed_count
}

///|
pub fn DayRecord::partial_count(self : DayRecord) -> Int {
  self.partial_count
}

///|
pub fn DayRecord::missed_count(self : DayRecord) -> Int {
  self.missed_count
}

///|
pub fn DayRecord::session_count(self : DayRecord) -> Int {
  self.session_count
}

///|
pub fn DayRecord::adherence(self : DayRecord) -> Double {
  self.adherence
}

///|
pub fn DayRecord::status(self : DayRecord) -> AdherenceStatus {
  self.status
}

///|
pub fn DayRecord::is_successful(
  self : DayRecord,
  minimum? : Double = 80.0,
) -> Bool {
  self.adherence >= minimum && self.status != AdherenceStatus::Missed
}

///|
pub(all) struct AdherenceReport {
  plan_name : String
  start_date : String
  end_date : String
  days : Array[DayRecord]
  scheduled_count : Int
  completed_count : Int
  partial_count : Int
  missed_count : Int
  adherence : Double
  attempted_days : Int
  successful_days : Int
  current_streak : Int
  longest_streak : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn AdherenceReport::plan_name(self : AdherenceReport) -> String {
  self.plan_name
}

///|
pub fn AdherenceReport::start_date(self : AdherenceReport) -> String {
  self.start_date
}

///|
pub fn AdherenceReport::end_date(self : AdherenceReport) -> String {
  self.end_date
}

///|
pub fn AdherenceReport::days(self : AdherenceReport) -> Array[DayRecord] {
  self.days
}

///|
pub fn AdherenceReport::scheduled_count(self : AdherenceReport) -> Int {
  self.scheduled_count
}

///|
pub fn AdherenceReport::completed_count(self : AdherenceReport) -> Int {
  self.completed_count
}

///|
pub fn AdherenceReport::partial_count(self : AdherenceReport) -> Int {
  self.partial_count
}

///|
pub fn AdherenceReport::missed_count(self : AdherenceReport) -> Int {
  self.missed_count
}

///|
pub fn AdherenceReport::adherence(self : AdherenceReport) -> Double {
  self.adherence
}

///|
pub fn AdherenceReport::attempted_days(self : AdherenceReport) -> Int {
  self.attempted_days
}

///|
pub fn AdherenceReport::successful_days(self : AdherenceReport) -> Int {
  self.successful_days
}

///|
pub fn AdherenceReport::current_streak(self : AdherenceReport) -> Int {
  self.current_streak
}

///|
pub fn AdherenceReport::longest_streak(self : AdherenceReport) -> Int {
  self.longest_streak
}

///|
fn plan_day_for(date : @calendar.CalendarDate) -> @planning.PlanDay {
  match @calendar.weekday(date) {
    1 => @planning.PlanDay::Monday
    2 => @planning.PlanDay::Tuesday
    3 => @planning.PlanDay::Wednesday
    4 => @planning.PlanDay::Thursday
    5 => @planning.PlanDay::Friday
    6 => @planning.PlanDay::Saturday
    _ => @planning.PlanDay::Sunday
  }
}

///|
pub fn plan_day(date : String) -> @planning.PlanDay? {
  @calendar.parse(date).map(plan_day_for)
}

///|
pub fn sessions_on(
  sessions : Array[@core.Session],
  date : String,
) -> Array[@core.Session] {
  sessions.filter(session => session.date == date)
}

///|
pub fn scheduled_on(plan : @planning.TrainingPlan, date : String) -> Int {
  match plan_day(date) {
    Some(day) => plan.for_day(day).length()
    None => 0
  }
}

///|
fn classify_day(
  plan : @planning.TrainingPlan,
  date : String,
  sessions : Array[@core.Session],
  options : AdherenceOptions,
) -> DayRecord? {
  match plan_day(date) {
    None => None
    Some(day) => {
      let items = plan.for_day(day)
      if items.is_empty() && !options.include_unscheduled_days {
        None
      } else {
        let statuses = if sessions.is_empty() {
          []
        } else {
          let statuses = []
          for session in sessions {
            statuses.append(@planning.execute_day(plan, day, session))
          }
          statuses
        }
        let scheduled = items.length()
        let completed = statuses.count_if(item => {
          item == @planning.PlanItemStatus::Completed
        })
        let partial = statuses.count_if(item => {
          item == @planning.PlanItemStatus::PartiallyCompleted
        })
        let missed = Int::max(0, scheduled - completed - partial)
        let adherence = if scheduled == 0 {
          0.0
        } else {
          completed.to_double() * 100.0 / scheduled.to_double()
        }
        let status = if scheduled == 0 {
          AdherenceStatus::Unscheduled
        } else if completed == scheduled {
          AdherenceStatus::Completed
        } else if completed > 0 || partial > 0 {
          AdherenceStatus::Partial
        } else {
          AdherenceStatus::Missed
        }
        Some(DayRecord::{
          date,
          day,
          scheduled_count: scheduled,
          completed_count: completed,
          partial_count: partial,
          missed_count: missed,
          session_count: sessions.length(),
          adherence,
          status,
        })
      }
    }
  }
}

///|
pub fn evaluate_day(
  plan : @planning.TrainingPlan,
  date : String,
  sessions : Array[@core.Session],
  options? : AdherenceOptions = default_adherence_options(),
) -> DayRecord? {
  classify_day(plan, date, sessions_on(sessions, date), options)
}

///|
pub fn date_range(start_date : String, end_date : String) -> Array[String] {
  match (@calendar.parse(start_date), @calendar.parse(end_date)) {
    (Some(start), Some(end)) =>
      @calendar.dates_between(start, end).map(item => item.to_string())
    _ => []
  }
}

///|
pub fn evaluate_range(
  plan : @planning.TrainingPlan,
  sessions : Array[@core.Session],
  start_date : String,
  end_date : String,
  options? : AdherenceOptions = default_adherence_options(),
) -> Array[DayRecord] {
  let result = []
  for date in date_range(start_date, end_date) {
    if options.include_weekends ||
      (
        plan_day(date) is Some(_) &&
        !@calendar.is_weekend(@calendar.parse(date).unwrap())
      ) {
      match classify_day(plan, date, sessions_on(sessions, date), options) {
        Some(record) => result.push(record)
        None => ()
      }
    }
  }
  result
}

///|
fn streaks(days : Array[DayRecord], minimum : Double) -> (Int, Int) {
  let mut current = 0
  let mut longest = 0
  for day in days {
    if day.is_successful(minimum~) {
      current += 1
      longest = Int::max(longest, current)
    } else {
      current = 0
    }
  }
  (current, longest)
}

///|
fn make_report(
  plan : @planning.TrainingPlan,
  days : Array[DayRecord],
  start_date : String,
  end_date : String,
  options : AdherenceOptions,
) -> AdherenceReport {
  let scheduled = days.fold(init=0, (total, item) => {
    total + item.scheduled_count
  })
  let completed = days.fold(init=0, (total, item) => {
    total + item.completed_count
  })
  let partial = days.fold(init=0, (total, item) => total + item.partial_count)
  let missed = days.fold(init=0, (total, item) => total + item.missed_count)
  let attempted_days = days.count_if(item => item.status.counts_as_attempted())
  let successful_days = days.count_if(item => {
    item.is_successful(minimum=options.minimum_adherence)
  })
  let (current, longest) = streaks(days, options.minimum_adherence)
  AdherenceReport::{
    plan_name: plan.name(),
    start_date,
    end_date,
    days,
    scheduled_count: scheduled,
    completed_count: completed,
    partial_count: partial,
    missed_count: missed,
    adherence: if scheduled == 0 {
      0.0
    } else {
      completed.to_double() * 100.0 / scheduled.to_double()
    },
    attempted_days,
    successful_days,
    current_streak: current,
    longest_streak: longest,
  }
}

///|
pub fn evaluate(
  plan : @planning.TrainingPlan,
  sessions : Array[@core.Session],
  start_date : String,
  end_date : String,
  options? : AdherenceOptions = default_adherence_options(),
) -> AdherenceReport {
  make_report(
    plan,
    evaluate_range(plan, sessions, start_date, end_date, options~),
    start_date,
    end_date,
    options,
  )
}

///|
pub fn weekly(
  plan : @planning.TrainingPlan,
  sessions : Array[@core.Session],
  anchor : String,
  options? : AdherenceOptions = default_adherence_options(),
) -> AdherenceReport {
  let start = match @calendar.parse(anchor) {
    Some(date) => @calendar.add_days(date, -6).to_string()
    None => anchor
  }
  evaluate(plan, sessions, start, anchor, options~)
}

///|
pub fn monthly(
  plan : @planning.TrainingPlan,
  sessions : Array[@core.Session],
  year : Int,
  month : Int,
  options? : AdherenceOptions = default_adherence_options(),
) -> AdherenceReport {
  let first = @calendar.CalendarDate::{ year, month, day: 1 }
  let last = @calendar.month_end(first)
  evaluate(plan, sessions, first.to_string(), last.to_string(), options~)
}

///|
pub fn daily_adherence(report : AdherenceReport) -> Array[Double] {
  report.days.map(item => item.adherence)
}

///|
pub fn adherence_summary(report : AdherenceReport) -> @statistics.Summary {
  @statistics.describe(daily_adherence(report))
}

///|
pub fn missed_days(report : AdherenceReport) -> Array[DayRecord] {
  report.days.filter(item => item.status == AdherenceStatus::Missed)
}

///|
pub fn partial_days(report : AdherenceReport) -> Array[DayRecord] {
  report.days.filter(item => item.status == AdherenceStatus::Partial)
}

///|
pub fn successful_days(report : AdherenceReport) -> Array[DayRecord] {
  report.days.filter(item => item.status == AdherenceStatus::Completed)
}

///|
pub fn needs_follow_up(
  report : AdherenceReport,
  threshold? : Double = 80.0,
) -> Bool {
  report.adherence < threshold || report.missed_count > 0
}

///|
pub fn completion_ratio(record : DayRecord) -> Double {
  if record.scheduled_count == 0 {
    0.0
  } else {
    record.completed_count.to_double() / record.scheduled_count.to_double()
  }
}

///|
pub fn attempt_ratio(record : DayRecord) -> Double {
  if record.scheduled_count == 0 {
    0.0
  } else {
    (record.completed_count + record.partial_count).to_double() /
    record.scheduled_count.to_double()
  }
}

///|
pub fn expected_items(report : AdherenceReport) -> Int {
  report.scheduled_count
}

///|
pub fn missed_movement_names(
  plan : @planning.TrainingPlan,
  record : DayRecord,
  sessions : Array[@core.Session],
) -> Array[String] {
  let names = []
  let session = sessions_on(sessions, record.date).get(0)
  for item in plan.for_day(record.day) {
    let found = match session {
      Some(value) => value.movement(item.movement_name()) is Some(_)
      None => false
    }
    if !found {
      names.push(item.movement_name())
    }
  }
  names
}

///|
pub fn recommendation(report : AdherenceReport) -> String {
  if report.scheduled_count == 0 {
    "No scheduled activities in this window."
  } else if report.missed_count > 0 {
    "Review missed days and simplify the next scheduled dose."
  } else if report.adherence < 80.0 {
    "Keep the plan visible and use shorter, repeatable sessions."
  } else if report.current_streak >= 7 {
    "Maintain the current cadence and review progression safely."
  } else {
    "Adherence is on track; continue collecting complete observations."
  }
}

///|
pub fn report_text(report : AdherenceReport) -> String {
  let output = StringBuilder()
  output.write_string(
    report.plan_name + " " + report.start_date + ".." + report.end_date + "\n",
  )
  output.write_string("adherence=" + report.adherence.to_string() + "%\n")
  output.write_string(
    "completed=" +
    report.completed_count.to_string() +
    "/" +
    report.scheduled_count.to_string() +
    "\n",
  )
  output.write_string(
    "streak=" +
    report.current_streak.to_string() +
    ", longest=" +
    report.longest_streak.to_string() +
    "\n",
  )
  output.write_string(recommendation(report) + "\n")
  output.to_string()
}
