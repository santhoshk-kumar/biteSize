/// Pure-Dart date, unit conversion, and ID helpers (avoids `intl` pin conflicts).
class ZenDateUtils {
  static const List<String> _weekdaysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _monthsShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static int _idCounter = 0;

  /// Generates a collision-resistant local unique ID.
  static String newId([String prefix = 'zc']) {
    _idCounter = (_idCounter + 1) % 100000;
    final micros = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${micros}_$_idCounter';
  }

  /// Formats a [DateTime] as a canonical local `YYYY-MM-DD` key.
  static String toDateKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses `YYYY-MM-DD` into a local midnight [DateTime].
  static DateTime fromDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return DateTime.now();
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final d = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(y, m, d);
  }

  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String weekdayShort(DateTime date) =>
      _weekdaysShort[date.weekday - 1];

  static String formatWeekdayShort(DateTime date) => weekdayShort(date);

  static String monthShort(DateTime date) => _monthsShort[date.month - 1];

  static String friendlyDateLabel(DateTime date, {DateTime? now}) {
    final target = dateOnly(date);
    final today = dateOnly(now ?? DateTime.now());
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return '${weekdayShort(target)}, ${monthShort(target)} ${target.day}';
  }

  static String shortMonthDay(DateTime date) =>
      '${monthShort(date)} ${date.day}';

  static String formatTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$min $period';
  }

  /// Returns the 7 days (Monday through Sunday) containing [anchorDate].
  static List<DateTime> weekDatesFor(DateTime anchorDate) {
    final d = dateOnly(anchorDate);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  /// Returns [count] consecutive dates ending on [endDate] inclusive.
  static List<DateTime> trailingDates(DateTime endDate, int count) {
    final end = dateOnly(endDate);
    return List.generate(
      count,
      (i) => end.subtract(Duration(days: count - 1 - i)),
    );
  }

  static String greetingForHour(int hour) {
    if (hour < 5) return 'Late night check-in';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 22) return 'Good evening';
    return 'Night rhythm';
  }

  /// Dynamic context-aware greeting reflecting time of day and selected calendar day.
  static String dynamicGreeting(DateTime selectedDate, {DateTime? now}) {
    final currentNow = now ?? DateTime.now();
    final today = dateOnly(currentNow);
    final selected = dateOnly(selectedDate);
    final diff = selected.difference(today).inDays;

    if (diff == 0) {
      final hour = currentNow.hour;
      if (hour < 5) return '🌙 Late Night · Rest & Recover';
      if (hour < 12) return '☀️ Good Morning · Fuel Your Day';
      if (hour < 17) return '⚡ Good Afternoon · Power On';
      if (hour < 22) return '🌆 Good Evening · Wrap Up Macros';
      return '✨ Night Rhythm · Stay Consistent';
    } else if (diff == -1) {
      return '📅 Yesterday · ${monthShort(selected)} ${selected.day}';
    } else if (diff == 1) {
      return '🚀 Planning Tomorrow · ${weekdayShort(selected)}';
    } else {
      return '🗓️ ${weekdayShort(selected)}, ${monthShort(selected)} ${selected.day}';
    }
  }

  /// Format 24h hour and minute as friendly 12h time (e.g. "8:30 AM", "1:00 PM").
  static String formatHourMinute(int hour, int minute) {
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final minStr = minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minStr $period';
  }

  // Unit conversion helpers
  static double kgToLb(double kg) => kg * 2.2046226218;
  static double lbToKg(double lb) => lb / 2.2046226218;
  static double mlToFlOz(num ml) => ml / 29.5735295625;
  static int flOzToMl(double flOz) => (flOz * 29.5735295625).round();

  static String formatWeight(double kg, {required bool useKg}) {
    if (useKg) return '${kg.toStringAsFixed(1)} kg';
    return '${kgToLb(kg).toStringAsFixed(1)} lb';
  }

  static String formatWater(int ml, {required bool useMl}) {
    if (useMl) return '$ml ml';
    return '${mlToFlOz(ml).toStringAsFixed(1)} oz';
  }
}
