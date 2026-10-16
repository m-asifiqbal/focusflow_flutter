/// ============================================================
/// WIDGET GALLERY — debug-only page showing every FF component
/// ============================================================
///
/// Routed in debug builds only. Lets designers/devs eyeball each component
/// in light, dark and every accent, side by side with the mockups.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/dev/gallery_demos.dart';
import 'package:focusflow/core/widgets/widgets.dart';

class WidgetGalleryScreen extends StatefulWidget {
  const WidgetGalleryScreen({super.key});

  @override
  State<WidgetGalleryScreen> createState() => _WidgetGalleryScreenState();
}

enum _Mode { light, dark }

class _WidgetGalleryScreenState extends State<WidgetGalleryScreen> {
  _Mode _mode = _Mode.light;
  AccentColor _accent = AccentColor.emerald;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = _mode == _Mode.light
        ? AppTheme.light(_accent)
        : AppTheme.dark(_accent);
    final demos = galleryDemos;
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => FFScaffold(
          bottomBar: FFBottomNav(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            onFab: () => showFFToast(context, 'FAB tapped'),
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: FFNavHeader(
                  leading: Navigator.canPop(context)
                      ? const FFBackButton()
                      : null,
                  title: 'Widget gallery',
                  subtitle: '${demos.length} components',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                sliver: SliverList.list(
                  children: [
                    FFSegmented<_Mode>(
                      value: _mode,
                      onChanged: (m) => setState(() => _mode = m),
                      segments: const [
                        FFSegment(value: _Mode.light, label: 'Light'),
                        FFSegment(value: _Mode.dark, label: 'Dark'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FFColorSwatchRow(
                      colors: [for (final a in AccentColor.values) a.primary],
                      selected: _accent.primary,
                      labels: [for (final a in AccentColor.values) a.label],
                      onSelected: (c) => setState(
                        () => _accent = AccentColor.values.firstWhere(
                          (a) => a.primary == c,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.sm,
                  AppSpacing.screen,
                  AppSpacing.bottomBarClearance,
                ),
                sliver: SliverList.builder(
                  itemCount: demos.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.section),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FFSectionLabel(demos[i].name),
                        demos[i].builder(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
