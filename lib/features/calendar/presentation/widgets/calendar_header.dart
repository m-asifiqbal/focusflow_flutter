/// ============================================================
/// CALENDAR HEADER — back · "June 2023" · search · accent "+" (mockup 26)
/// ============================================================
///
/// What: the nav row of the calendar. The title is the visible month; "+"
/// opens Quick Add on the selected day.
/// Why: a centred month title that never overflows (scales down at 360 pt
/// and text scale 1.3) between 44-pt round buttons.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/calendar/presentation/calendar_tokens.dart';

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    required this.title,
    required this.onSearch,
    required this.onAdd,
    super.key,
  });

  /// "June 2023".
  final String title;
  final VoidCallback onSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return FFNavHeader(
      leading: const FFBackButton(),
      titleWidget: Semantics(
        header: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            maxLines: 1,
            style: context.text.title.copyWith(fontSize: CalendarDimens.title),
          ),
        ),
      ),
      trailing: [
        FFRoundIconButton(
          icon: FontAwesomeIcons.magnifyingGlass,
          semanticLabel: tr('Search'),
          onPressed: onSearch,
        ),
        FFRoundIconButton(
          icon: FontAwesomeIcons.plus,
          semanticLabel: tr('Add on selected day'),
          variant: FFRoundIconButtonVariant.accent,
          iconSize: AppSizes.heroGlyph,
          onPressed: onAdd,
        ),
      ],
    );
  }
}
