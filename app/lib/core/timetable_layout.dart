/// Shared layout constants for weekly timetable grids (plan + room views).
/// Mirrors `--tt-*` tokens in [src/components/Timetable/Timetable.css].
class TimetableLayout {
  TimetableLayout._();

  static const int startHour = 7;
  static const int endHour = 21;
  static const double rowHeight = 58;
  static const double railWidth = 40;
  static const double headerHeight = 26;
  static const double blockInset = 1.5;

  static int get hourCount => endHour - startHour;

  static double get plotHeight => hourCount * rowHeight;

  static double lineTopForHour(int hour) => (hour - startHour) * rowHeight;

  static double hourOffset(String start) {
    final hour = int.parse(start.substring(0, 2));
    final minute = int.parse(start.substring(2, 4));
    return (hour - startHour) + minute / 60.0;
  }

  static double durationHours(String start, String end) {
    final sh = int.parse(start.substring(0, 2));
    final sm = int.parse(start.substring(2, 4));
    final eh = int.parse(end.substring(0, 2));
    final em = int.parse(end.substring(2, 4));
    return (eh - sh) + (em - sm) / 60.0;
  }

  /// Top edge of a timed block — aligned to hour gridlines (no vertical inset).
  static double blockTop(String start) => hourOffset(start) * rowHeight;

  /// Height of a timed block spanning [start]–[end].
  static double blockHeight(String start, String end) =>
      durationHours(start, end) * rowHeight;
}
