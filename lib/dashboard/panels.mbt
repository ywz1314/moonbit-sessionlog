///|
/// Dashboard models keep presentation decisions typed and deterministic.
/// Renderers can map these values to a terminal, JSON API, or web client.
pub(all) enum PanelKind {
  Overview
  Trend
  Risk
  Quality
  Alerts
  Forecast
  Workload
  Table
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn PanelKind::label(self : PanelKind) -> String {
  match self {
    Overview => "overview"
    Trend => "trend"
    Risk => "risk"
    Quality => "quality"
    Alerts => "alerts"
    Forecast => "forecast"
    Workload => "workload"
    Table => "table"
  }
}

///|
pub fn PanelKind::priority(self : PanelKind) -> Int {
  match self {
    Overview => 0
    Risk => 1
    Alerts => 2
    Quality => 3
    Trend => 4
    Workload => 5
    Forecast => 6
    Table => 7
  }
}

///|
pub(all) struct PanelFilter {
  start_date : String
  end_date : String
  movement : String?
  pain_at_least : Int?
  minimum_completion : Double?
  tags : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn empty_filter() -> PanelFilter {
  PanelFilter::{
    start_date: "",
    end_date: "",
    movement: None,
    pain_at_least: None,
    minimum_completion: None,
    tags: [],
  }
}

///|
pub fn filter_dates(
  filter : PanelFilter,
  start : String,
  end : String,
) -> PanelFilter {
  PanelFilter::{
    start_date: start,
    end_date: end,
    movement: filter.movement,
    pain_at_least: filter.pain_at_least,
    minimum_completion: filter.minimum_completion,
    tags: filter.tags,
  }
}

///|
pub fn filter_movement(filter : PanelFilter, movement : String) -> PanelFilter {
  PanelFilter::{
    start_date: filter.start_date,
    end_date: filter.end_date,
    movement: Some(movement),
    pain_at_least: filter.pain_at_least,
    minimum_completion: filter.minimum_completion,
    tags: filter.tags,
  }
}

///|
pub fn filter_pain(filter : PanelFilter, threshold : Int) -> PanelFilter {
  PanelFilter::{
    start_date: filter.start_date,
    end_date: filter.end_date,
    movement: filter.movement,
    pain_at_least: Some(threshold.clamp(min=0, max=10)),
    minimum_completion: filter.minimum_completion,
    tags: filter.tags,
  }
}

///|
pub fn filter_completion(
  filter : PanelFilter,
  threshold : Double,
) -> PanelFilter {
  PanelFilter::{
    start_date: filter.start_date,
    end_date: filter.end_date,
    movement: filter.movement,
    pain_at_least: filter.pain_at_least,
    minimum_completion: Some(threshold.clamp(min=0.0, max=1.0)),
    tags: filter.tags,
  }
}

///|
pub fn filter_add_tag(filter : PanelFilter, tag : String) -> PanelFilter {
  let tags = filter.tags.copy()
  if !tag.trim().is_empty() && !tags.contains(tag) {
    tags.push(tag)
  }
  PanelFilter::{
    start_date: filter.start_date,
    end_date: filter.end_date,
    movement: filter.movement,
    pain_at_least: filter.pain_at_least,
    minimum_completion: filter.minimum_completion,
    tags,
  }
}

///|
pub fn filter_matches(filter : PanelFilter, session : @core.Session) -> Bool {
  if !filter.start_date.is_empty() && session.date < filter.start_date {
    return false
  }
  if !filter.end_date.is_empty() && session.date > filter.end_date {
    return false
  }
  match filter.movement {
    Some(name) => if session.movement(name) is None { return false }
    None => ()
  }
  match filter.pain_at_least {
    Some(value) =>
      if session.average_pain_during() < value.to_double() {
        return false
      }
    None => ()
  }
  match filter.minimum_completion {
    Some(value) => if session.average_completion() < value { return false }
    None => ()
  }
  true
}

///|
pub fn filter_sessions(
  filter : PanelFilter,
  sessions : Array[@core.Session],
) -> Array[@core.Session] {
  sessions.filter(session => filter_matches(filter, session))
}

///|
pub fn filter_text(filter : PanelFilter) -> String {
  let parts = []
  if !filter.start_date.is_empty() {
    parts.push("from=" + filter.start_date)
  }
  if !filter.end_date.is_empty() {
    parts.push("to=" + filter.end_date)
  }
  match filter.movement {
    Some(value) => parts.push("movement=" + value)
    None => ()
  }
  match filter.pain_at_least {
    Some(value) => parts.push("pain>=" + value.to_string())
    None => ()
  }
  match filter.minimum_completion {
    Some(value) => parts.push("completion>=" + value.to_string())
    None => ()
  }
  if !filter.tags.is_empty() {
    parts.push("tags=" + filter.tags.join("|"))
  }
  if parts.is_empty() {
    "all"
  } else {
    parts.join(", ")
  }
}

///|
pub(all) struct MetricCard {
  key : String
  label : String
  value : String
  unit : String
  status : String
  delta : String
  description : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn MetricCard::key(self : MetricCard) -> String {
  self.key
}

///|
pub fn MetricCard::label(self : MetricCard) -> String {
  self.label
}

///|
pub fn MetricCard::value(self : MetricCard) -> String {
  self.value
}

///|
pub fn MetricCard::unit(self : MetricCard) -> String {
  self.unit
}

///|
pub fn MetricCard::status(self : MetricCard) -> String {
  self.status
}

///|
pub fn MetricCard::delta(self : MetricCard) -> String {
  self.delta
}

///|
pub fn MetricCard::description(self : MetricCard) -> String {
  self.description
}

///|
pub fn metric_card(
  key : String,
  label : String,
  value : String,
  unit : String,
  status : String,
  delta : String,
  description : String,
) -> MetricCard {
  MetricCard::{ key, label, value, unit, status, delta, description }
}

///|
pub fn card_from_summary(summary : @analytics.TrendReport) -> Array[MetricCard] {
  [
    metric_card(
      "sessions",
      "Sessions",
      summary.session_count().to_string(),
      "",
      "normal",
      "",
      "Recorded sessions",
    ),
    metric_card(
      "pain",
      "Average pain",
      summary.average_pain().to_string(),
      "/10",
      if summary.average_pain() >= 7.0 {
        "critical"
      } else {
        "normal"
      },
      "",
      "Mean session pain",
    ),
    metric_card(
      "completion",
      "Completion",
      summary.average_completion().to_string(),
      "%",
      if summary.average_completion() < 0.5 {
        "attention"
      } else {
        "normal"
      },
      "",
      "Average set completion",
    ),
    metric_card(
      "work",
      "Work units",
      summary.total_work_units().to_string(),
      "",
      "normal",
      "",
      "Total recorded work",
    ),
  ]
}

///|
pub(all) struct DashboardPanel {
  id : String
  kind : PanelKind
  title : String
  subtitle : String
  filter : PanelFilter
  cards : Array[MetricCard]
  rows : Array[Array[String]]
  warnings : Array[String]
  order : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn DashboardPanel::id(self : DashboardPanel) -> String {
  self.id
}

///|
pub fn DashboardPanel::kind(self : DashboardPanel) -> PanelKind {
  self.kind
}

///|
pub fn DashboardPanel::title(self : DashboardPanel) -> String {
  self.title
}

///|
pub fn DashboardPanel::subtitle(self : DashboardPanel) -> String {
  self.subtitle
}

///|
pub fn DashboardPanel::filter(self : DashboardPanel) -> PanelFilter {
  self.filter
}

///|
pub fn DashboardPanel::cards(self : DashboardPanel) -> Array[MetricCard] {
  self.cards.copy()
}

///|
pub fn DashboardPanel::rows(self : DashboardPanel) -> Array[Array[String]] {
  self.rows.copy()
}

///|
pub fn DashboardPanel::warnings(self : DashboardPanel) -> Array[String] {
  self.warnings.copy()
}

///|
pub fn DashboardPanel::order(self : DashboardPanel) -> Int {
  self.order
}

///|
pub fn panel(
  id : String,
  kind : PanelKind,
  title : String,
  subtitle : String,
  filter : PanelFilter,
) -> DashboardPanel {
  DashboardPanel::{
    id,
    kind,
    title,
    subtitle,
    filter,
    cards: [],
    rows: [],
    warnings: [],
    order: kind.priority(),
  }
}

///|
pub fn panel_with_cards(
  value : DashboardPanel,
  cards : Array[MetricCard],
) -> DashboardPanel {
  DashboardPanel::{
    id: value.id,
    kind: value.kind,
    title: value.title,
    subtitle: value.subtitle,
    filter: value.filter,
    cards,
    rows: value.rows,
    warnings: value.warnings,
    order: value.order,
  }
}

///|
pub fn panel_with_rows(
  value : DashboardPanel,
  rows : Array[Array[String]],
) -> DashboardPanel {
  DashboardPanel::{
    id: value.id,
    kind: value.kind,
    title: value.title,
    subtitle: value.subtitle,
    filter: value.filter,
    cards: value.cards,
    rows,
    warnings: value.warnings,
    order: value.order,
  }
}

///|
pub fn panel_add_warning(
  value : DashboardPanel,
  warning : String,
) -> DashboardPanel {
  let warnings = value.warnings.copy()
  if !warnings.contains(warning) {
    warnings.push(warning)
  }
  DashboardPanel::{
    id: value.id,
    kind: value.kind,
    title: value.title,
    subtitle: value.subtitle,
    filter: value.filter,
    cards: value.cards,
    rows: value.rows,
    warnings,
    order: value.order,
  }
}

///|
pub(all) struct PanelDashboard {
  title : String
  generated_for : String
  filter : PanelFilter
  panels : Array[DashboardPanel]
  session_count : Int
  warning_count : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn PanelDashboard::title(self : PanelDashboard) -> String {
  self.title
}

///|
pub fn PanelDashboard::generated_for(self : PanelDashboard) -> String {
  self.generated_for
}

///|
pub fn PanelDashboard::filter(self : PanelDashboard) -> PanelFilter {
  self.filter
}

///|
pub fn PanelDashboard::panels(self : PanelDashboard) -> Array[DashboardPanel] {
  self.panels.copy()
}

///|
pub fn PanelDashboard::session_count(self : PanelDashboard) -> Int {
  self.session_count
}

///|
pub fn PanelDashboard::warning_count(self : PanelDashboard) -> Int {
  self.warning_count
}

///|
pub fn build_dashboard(
  title : String,
  generated_for : String,
  sessions : Array[@core.Session],
  filter : PanelFilter,
) -> PanelDashboard {
  let selected = filter_sessions(filter, sessions)
  let summary = @analytics.analyze(selected)
  let overview = panel(
      "overview",
      PanelKind::Overview,
      "Overview",
      filter_text(filter),
      filter,
    )
    |> panel_with_cards(card_from_summary(summary))
  let trend_rows = selected.map(session => {
    [
      session.date,
      session.id,
      session.total_reps().to_string(),
      session.average_completion().to_string(),
      session.average_pain_during().to_string(),
    ]
  })
  let trend = panel(
      "trend",
      PanelKind::Trend,
      "Session trend",
      "Recent sessions",
      filter,
    )
    |> panel_with_rows(trend_rows)
  let panels = [overview, trend]
  panels.sort_by((left, right) => left.order - right.order)
  PanelDashboard::{
    title,
    generated_for,
    filter,
    panels,
    session_count: selected.length(),
    warning_count: 0,
  }
}

///|
pub fn dashboard_panel(value : PanelDashboard, id : String) -> DashboardPanel? {
  match value.panels.search_by(panel => panel.id == id) {
    Some(index) => Some(value.panels[index])
    None => None
  }
}

///|
pub fn dashboard_panel_ids(value : PanelDashboard) -> Array[String] {
  value.panels.map(panel => panel.id)
}

///|
pub fn dashboard_warning_count(value : PanelDashboard) -> Int {
  value.panels.fold(init=0, (total, panel) => total + panel.warnings.length())
}

///|
pub fn dashboard_text(value : PanelDashboard) -> String {
  let output = StringBuilder()
  output.write_string(value.title + " (" + value.generated_for + ")\n")
  output.write_string("filter: " + filter_text(value.filter) + "\n")
  output.write_string("sessions: " + value.session_count.to_string() + "\n")
  for panel in value.panels {
    output.write_string("\n[" + panel.kind.label() + "] " + panel.title + "\n")
    for card in panel.cards {
      output.write_string(card.label + ": " + card.value + card.unit + "\n")
    }
    for row in panel.rows {
      output.write_string(row.join(" | ") + "\n")
    }
  }
  output.to_string()
}
