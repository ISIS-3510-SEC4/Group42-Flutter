const _weekdays = {
  'monday': DateTime.monday,
  'lunes': DateTime.monday,
  'tuesday': DateTime.tuesday,
  'martes': DateTime.tuesday,
  'wednesday': DateTime.wednesday,
  'miercoles': DateTime.wednesday,
  'miércoles': DateTime.wednesday,
  'thursday': DateTime.thursday,
  'jueves': DateTime.thursday,
  'friday': DateTime.friday,
  'viernes': DateTime.friday,
  'saturday': DateTime.saturday,
  'sabado': DateTime.saturday,
  'sábado': DateTime.saturday,
  'sunday': DateTime.sunday,
  'domingo': DateTime.sunday,
};

/// Turns the free-text day ("Sunday", "mañana") and time ("2:00 pm", "14:30")
/// of the meeting form into the next matching moment, or null if unreadable.
DateTime? parseMeetingDateTime(String day, String time, {DateTime? now}) {
  final current = now ?? DateTime.now();

  final match = RegExp(r'^\s*(\d{1,2})(?::(\d{2}))?\s*([ap])?\.?\s*(?:m\.?)?\s*$',
          caseSensitive: false)
      .firstMatch(time);
  if (match == null) return null;

  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2) ?? '0');
  final meridiem = match.group(3)?.toLowerCase();
  if (meridiem != null) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (meridiem == 'p' ? 12 : 0);
  }
  if (hour > 23 || minute > 59) return null;

  final today = DateTime(current.year, current.month, current.day);
  final normalizedDay = day.trim().toLowerCase();

  DateTime date;
  if (normalizedDay.isEmpty || normalizedDay == 'today' || normalizedDay == 'hoy') {
    date = today;
  } else if (normalizedDay == 'tomorrow' ||
      normalizedDay == 'mañana' ||
      normalizedDay == 'manana') {
    date = today.add(const Duration(days: 1));
  } else {
    final weekday = _weekdays[normalizedDay];
    if (weekday == null) return null;
    final daysAhead = (weekday - current.weekday) % 7;
    date = today.add(Duration(days: daysAhead));
  }

  var moment = DateTime(date.year, date.month, date.day, hour, minute);
  // Same weekday but the hour already passed: it means next week.
  if (moment.isBefore(current) && _weekdays.containsKey(normalizedDay)) {
    moment = moment.add(const Duration(days: 7));
  }
  return moment;
}
