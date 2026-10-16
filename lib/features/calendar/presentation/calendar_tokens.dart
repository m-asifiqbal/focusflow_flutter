/// ============================================================
/// CALENDAR TOKENS — measurements of the calendar (mockup 26)
/// ============================================================
///
/// What: the sizes specific to the calendar, measured on
/// design/26_calendar.png (390 pt wide). Everything else comes from
/// AppSpacing / AppRadii / AppSizes and the text styles.
/// Why: one place to tune the screen against the mockup; widgets never
/// hard-code numbers.
/// ============================================================
library;

abstract final class CalendarDimens {
  // Header
  static const double title = 20;
  static const double segmentedHeight = 44;

  // Grid card
  static const double gridPaddingH = 12;
  static const double gridPaddingTop = 16;
  static const double gridPaddingBottom = 20;
  static const double weekdayGap = 12;
  static const double weekdayLetterSpacing = 0.6;
  static const double rowHeight = 48;
  static const double dayCircle = 32;
  static const double dayCircleBox = 36;
  static const double dayNumber = 16;
  static const double dot = 4.5;
  static const double dotGap = 3;
  static const double dotsTop = 3;
  static const double legendGapTop = 16;
  static const double legendDot = 8;
  static const double legendDotGap = 6;
  static const double legendItemGap = 16;

  // Day agenda
  static const double sectionGap = 28;
  static const double dayTitle = 20;
  static const double itemCount = 14;
  static const double titleGap = 14;
  static const double timeColumn = 56;
  static const double timeGap = 11;
  static const double time = 13;
  static const double cardRadius = 20;
  static const double cardStripe = 4;
  static const double cardPaddingH = 16;
  static const double cardPaddingV = 13;
  static const double cardTitle = 16;
  static const double cardMeta = 13;
  static const double cardMetaGap = 4;
  static const double cardGap = 10;
  static const double metaCheck = 11;

  /// Agenda mode lists this many days per page.
  static const int agendaDays = 7;
}
