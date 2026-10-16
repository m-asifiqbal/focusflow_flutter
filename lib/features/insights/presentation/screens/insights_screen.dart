/// ============================================================
/// INSIGHTS SCREEN — productivity analytics, tab 3 (screen 25)
/// ============================================================
///
/// What: large header "Insights" + share button, range chips, then the
/// live [InsightsContent] of the selected range (skeleton on first load,
/// retry on error). Share renders the whole page (not just the visible
/// part) to a PNG through a RepaintBoundary around the scroll content and
/// hands it to the share sheet.
/// Why: a SingleChildScrollView lays the full page out, so the boundary
/// paints everything for the share image; the page is short enough that
/// lazy building would gain nothing.
/// ============================================================
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/data/share/insights_share_service.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/providers/insights_providers.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_content.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_range_bar.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';

/// The share sheet integration (override in tests).
final insightsShareServiceProvider = Provider<InsightsShareService>(
  (ref) => const InsightsShareService(),
);

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  final _boundary = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    final box = _boundary.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || _sharing) return;
    setState(() => _sharing = true);
    try {
      final ratio = MediaQuery.devicePixelRatioOf(context);
      final image = await box.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('PNG encoding failed');
      final stamp = DateUtilsX.dayKey(ref.read(todayProvider));
      await ref
          .read(insightsShareServiceProvider)
          .sharePng(data.buffer.asUint8List(), fileStamp: stamp);
    } on Object {
      if (mounted) showFFToast(context, "Couldn't share your insights");
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(insightsRangeProvider);
    final async = ref.watch(insightsProvider(range));
    final ff = context.ff;
    const pad = EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.screen);

    final Widget body = switch (async) {
      AsyncValue(:final value?) => InsightsContent(snapshot: value),
      AsyncError() => FFEmptyState.compact(
        colors: ModuleStyle.notes.colors,
        icon: FontAwesomeIcons.chartPie,
        title: "Couldn't load insights",
        body: 'Something went wrong while reading your data.',
        ctaLabel: 'Try again',
        ctaIcon: FontAwesomeIcons.arrowRotateRight,
        onCta: () => ref.invalidate(insightsProvider(range)),
      ),
      _ => const InsightsSkeleton(),
    };

    return MinuteTicker(
      child: FFScaffold(
        safeBottom: false,
        // Title + share stay fixed; the charts scroll beneath them.
        body: Column(
          children: [
            FFLargeHeader(
              title: 'Insights',
              subtitle: 'Your productivity at a glance',
              fitTitle: true,
              actions: [
                FFRoundIconButton(
                  icon: FontAwesomeIcons.shareNodes,
                  semanticLabel: 'Share insights',
                  iconColor: ff.primary,
                  onPressed: async.hasValue && !_sharing ? _share : null,
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsetsDirectional.only(
                  bottom: context.barClearance,
                ),
                child: RepaintBoundary(
                  key: _boundary,
                  child: ColoredBox(
                    color: ff.canvas,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: InsightsDimens.chipsGap),
                        const InsightsRangeBar(),
                        const SizedBox(height: InsightsDimens.chipsGap),
                        Padding(
                          padding: pad.add(
                            const EdgeInsetsDirectional.only(
                              bottom: AppSpacing.xxl,
                            ),
                          ),
                          child: body,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
