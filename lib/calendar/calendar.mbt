///|
pub(all) struct CalendarDate {
  mut year : Int
  mut month : Int
  mut day : Int
} derive(Debug, Eq)

///|
pub fn CalendarDate::year(self : CalendarDate) -> Int {
  self.year
}

///|
pub fn CalendarDate::month(self : CalendarDate) -> Int {
  self.month
}

///|
pub fn CalendarDate::day(self : CalendarDate) -> Int {
  self.day
}

///|
pub fn CalendarDate::to_string(self : CalendarDate) -> String {
  self.year.to_string().pad_start(4, '0') +
  "-" +
  self.month.to_string().pad_start(2, '0') +
  "-" +
  self.day.to_string().pad_start(2, '0')
}

///|
fn digit(value : String, index : Int) -> Int? {
  match value.get(index) {
    Some(code) =>
      if code >= 48 && code <= 57 {
        Some(code.to_int() - 48)
      } else {
        None
      }
    None => None
  }
}

///|
fn digits(value : String, start : Int, length : Int) -> Int? {
  let mut result = 0
  for index in start..<(start + length) {
    match digit(value, index) {
      Some(value) => result = result * 10 + value
      None => return None
    }
  }
  Some(result)
}

///|
pub fn is_leap(year : Int) -> Bool {
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
}

///|
pub fn month_days(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap(year) { 29 } else { 28 }
    _ => 0
  }
}

///|
pub fn valid(date : CalendarDate) -> Bool {
  date.year >= 1 &&
  date.month >= 1 &&
  date.month <= 12 &&
  date.day >= 1 &&
  date.day <= month_days(date.year, date.month)
}

///|
pub fn parse(value : String) -> CalendarDate? {
  if value.length() != 10 || value[4] != '-' || value[7] != '-' {
    None
  } else {
    match (digits(value, 0, 4), digits(value, 5, 2), digits(value, 8, 2)) {
      (Some(year), Some(month), Some(day)) => {
        let result = CalendarDate::{ year, month, day }
        if valid(result) {
          Some(result)
        } else {
          None
        }
      }
      _ => None
    }
  }
}

///|
pub fn compare(left : CalendarDate, right : CalendarDate) -> Int {
  if left.year != right.year {
    left.year - right.year
  } else if left.month != right.month {
    left.month - right.month
  } else {
    left.day - right.day
  }
}

///|
pub fn weekday(date : CalendarDate) -> Int {
  // Sakamoto's algorithm: 0 = Sunday, 1 = Monday, ..., 6 = Saturday.
  let table = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
  let year = if date.month < 3 { date.year - 1 } else { date.year }
  (year + year / 4 - year / 100 + year / 400 + table[date.month - 1] + date.day) %
  7
}

///|
pub fn add_days(date : CalendarDate, days : Int) -> CalendarDate {
  let result : CalendarDate = {
    year: date.year,
    month: date.month,
    day: date.day,
  }
  if days >= 0 {
    for _ in 0..<days {
      if result.day < month_days(result.year, result.month) {
        result.day += 1
      } else if result.month < 12 {
        result.month += 1
        result.day = 1
      } else {
        result.year += 1
        result.month = 1
        result.day = 1
      }
    }
  } else {
    for _ in 0..<(0 - days) {
      if result.day > 1 {
        result.day -= 1
      } else if result.month > 1 {
        result.month -= 1
        result.day = month_days(result.year, result.month)
      } else {
        result.year -= 1
        result.month = 12
        result.day = 31
      }
    }
  }
  result
}

///|
pub fn days_between(left : CalendarDate, right : CalendarDate) -> Int {
  let mut cursor = left
  let mut distance = 0
  let direction = if compare(left, right) <= 0 { 1 } else { -1 }
  while compare(cursor, right) != 0 {
    cursor = add_days(cursor, direction)
    distance += direction
  }
  distance
}

///|
pub fn dates_between(
  start : CalendarDate,
  end : CalendarDate,
) -> Array[CalendarDate] {
  let dates = []
  let mut cursor = start
  if compare(start, end) <= 0 {
    while compare(cursor, end) <= 0 {
      dates.push(cursor)
      cursor = add_days(cursor, 1)
    }
  } else {
    while compare(cursor, end) >= 0 {
      dates.push(cursor)
      cursor = add_days(cursor, -1)
    }
  }
  dates
}

///|
pub fn is_weekend(date : CalendarDate) -> Bool {
  let day = weekday(date)
  day == 0 || day == 6
}

///|
pub fn month_start(date : CalendarDate) -> CalendarDate {
  CalendarDate::{ year: date.year, month: date.month, day: 1 }
}

///|
pub fn month_end(date : CalendarDate) -> CalendarDate {
  CalendarDate::{
    year: date.year,
    month: date.month,
    day: month_days(date.year, date.month),
  }
}
