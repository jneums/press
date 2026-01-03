import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

module {
  /// Convert nanoseconds since Unix epoch to UTC ISO 8601 string
  /// Example: 1734480000000000000 -> "2024-12-17T20:00:00Z"
  public func nanosToUtcString(nanos : Int) : Text {
    // Convert nanoseconds to seconds
    let seconds = nanos / 1_000_000_000;

    // Calculate date components
    let SECONDS_PER_DAY = 86400;
    let SECONDS_PER_HOUR = 3600;
    let SECONDS_PER_MINUTE = 60;

    // Days since Unix epoch (Jan 1, 1970)
    let days = seconds / SECONDS_PER_DAY;
    let remainingSeconds = seconds % SECONDS_PER_DAY;

    // Calculate time components
    let hours = remainingSeconds / SECONDS_PER_HOUR;
    let minutes = (remainingSeconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE;
    let secs = remainingSeconds % SECONDS_PER_MINUTE;

    // Calculate year, month, day using simplified algorithm
    let (year, month, day) = calculateDate(Int.abs(days));

    // Format with zero-padding
    let yearStr = Nat.toText(year);
    let monthStr = zeroPad(month);
    let dayStr = zeroPad(day);
    let hoursStr = zeroPad(Int.abs(hours));
    let minutesStr = zeroPad(Int.abs(minutes));
    let secsStr = zeroPad(Int.abs(secs));

    yearStr # "-" # monthStr # "-" # dayStr # "T" # hoursStr # ":" # minutesStr # ":" # secsStr # "Z";
  };

  /// Zero-pad a number to 2 digits
  private func zeroPad(n : Int) : Text {
    let nat = Int.abs(n);
    if (nat < 10) {
      "0" # Nat.toText(nat);
    } else {
      Nat.toText(nat);
    };
  };

  /// Calculate year, month, day from days since Unix epoch
  /// Uses a simplified Gregorian calendar algorithm
  private func calculateDate(days : Nat) : (Nat, Nat, Nat) {
    var remainingDays = days;
    var year = 1970;

    // Account for leap years and regular years
    // This is a simplified calculation
    loop {
      let daysInYear = if (isLeapYear(year)) { 366 } else { 365 };
      if (remainingDays >= daysInYear) {
        remainingDays -= daysInYear;
        year += 1;
      } else {
        // Found the year
        let (month, day) = dayOfYear(remainingDays + 1, isLeapYear(year));
        return (year, month, day);
      };
    };
  };

  /// Check if a year is a leap year
  private func isLeapYear(year : Nat) : Bool {
    (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
  };

  /// Convert day of year (1-366) to month and day
  private func dayOfYear(dayOfYear : Nat, isLeap : Bool) : (Nat, Nat) {
    let daysInMonth = if (isLeap) {
      [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    } else { [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] };

    var remaining = dayOfYear;
    var month = 1;

    for (days in daysInMonth.vals()) {
      if (remaining <= days) {
        return (month, remaining);
      };
      remaining -= days;
      month += 1;
    };

    // Should never reach here
    (12, 31);
  };
};
