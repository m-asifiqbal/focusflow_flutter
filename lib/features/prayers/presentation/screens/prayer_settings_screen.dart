/// ============================================================
/// PRAYER SETTINGS — location, calculation, Hijri, tab, reminders
/// ============================================================
///
/// What:
///   * LOCATION — the saved place ("Near Dhaka · precise · today"), Update
///     location (explain → precise location), Search a city;
///   * CALCULATION — method (the suggested one for the place first), Asr
///     school, high-latitude rule — only for sun-based prayers;
///   * HIJRI DATE — a ±2 day correction for local moon sighting (Islam);
///   * GENERAL — Prayer reminders on / off, discreet notification titles,
///     and Set up from a tradition again.
/// Why: everything that changes "what time is Asr today" in one place,
/// with today's times shown next to the choices that move them.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/prayer_prefs.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/hijri_date.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_sun.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_location_sheets.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class PrayerSettingsScreen extends ConsumerWidget {
  const PrayerSettingsScreen({super.key});

  static Widget _tile(IconData icon) => FFIconTile.soft(
    icon: icon,
    colors: PrayerStyle.module,
    size: AppSizes.iconTileSm,
  );

  Future<void> _edit(WidgetRef ref, PrayerPrefs Function(PrayerPrefs) f) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(prayer: f(s.prayer)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prayerPrefsProvider);
    final today = ref.watch(todayProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final sun = ref.watch(prayerSunProvider)(today);
    final method = PrayerSun.methodOf(prefs);
    final suggested = prefs.hasLocation
        ? PrayerCalcMethod.suggestedFor(
            GeoPoint(prefs.latitude!, prefs.longitude!),
          )
        : null;
    final asr =
        AsrSchool.values.asNameMap()[prefs.asrSchool] ?? AsrSchool.standard;
    final high =
        HighLatitudeRule.values.asNameMap()[prefs.highLatitudeRule] ??
        HighLatitudeRule.angleBased;
    final islam =
        PrayerTradition.fromKey(prefs.tradition) == PrayerTradition.islam;
    String time(SolarEvent e) =>
        sun == null ? '' : PrayerFormat.time(sun.at(e), use24h: use24h);
    final located = prefs.locatedAt;
    const gap = SizedBox(height: AppSpacing.section);
    return FFScaffold(
      body: Column(
        children: [
          FFNavHeader(
            leading: FFBackButton(label: tr('Prayer')),
            title: tr('Prayer settings'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.grouped,
                AppSpacing.sm,
                AppSpacing.grouped,
                AppSpacing.xxl,
              ),
              children: [
                FFGroupedList(
                  label: tr('Location'),
                  footer: tr(
                    'Used only on this phone to calculate prayer times. Never sent anywhere.',
                  ),
                  children: [
                    FFListRow(
                      leading: _tile(FontAwesomeIcons.locationDot),
                      title: prefs.hasLocation
                          ? prefs.placeLabel
                          : tr('No location yet'),
                      subtitle: prefs.hasLocation
                          ? [
                              '${prefs.latitude!.toStringAsFixed(4)}, '
                                  '${prefs.longitude!.toStringAsFixed(4)}',
                              prefs.precise ? tr('precise') : tr('approximate'),
                              if (located != null)
                                DateFormats.of('d MMM').format(located),
                            ].join(' · ')
                          : tr('Sun-based prayers use their usual times'),
                    ),
                    FFListRow(
                      leading: _tile(FontAwesomeIcons.locationCrosshairs),
                      title: prefs.hasLocation
                          ? tr('Update location')
                          : tr('Use my location'),
                      chevron: true,
                      onTap: () =>
                          unawaited(showPrayerLocationSheet(context, ref)),
                    ),
                    FFListRow(
                      leading: _tile(FontAwesomeIcons.magnifyingGlass),
                      title: tr('Search a city'),
                      chevron: true,
                      onTap: () => unawaited(showPrayerCitySheet(context, ref)),
                    ),
                  ],
                ),
                gap,
                FFGroupedList(
                  label: tr('Calculation'),
                  footer: sun == null
                      ? null
                      : tr(
                          'Today: dawn {dawn} · noon {noon} · Asr {asr} · sunset {sunset}',
                          {
                            'dawn': time(SolarEvent.dawn),
                            'noon': time(SolarEvent.noon),
                            'asr': time(SolarEvent.asr),
                            'sunset': time(SolarEvent.sunset),
                          },
                        ),
                  children: [
                    FFListRow(
                      leading: _tile(FontAwesomeIcons.calculator),
                      title: tr('Method'),
                      value: method.label,
                      chevron: true,
                      onTap: () async {
                        final picked = await showOptionSheet<PrayerCalcMethod>(
                          context,
                          title: tr('Calculation method'),
                          subtitle: suggested == null
                              ? null
                              : tr('Suggested for your place: {method}', {
                                  'method': suggested.label,
                                }),
                          options: [
                            for (final m in [
                              ?suggested,
                              for (final m in PrayerCalcMethod.values)
                                if (m != suggested) m,
                            ])
                              OptionItem(
                                value: m,
                                label: m.label,
                                subtitle: m.ishaMinutes != null
                                    ? tr(
                                        'Fajr {f}° · Isha {i} min after sunset',
                                        {'f': m.fajrAngle, 'i': m.ishaMinutes},
                                      )
                                    : tr('Fajr {f}° · Isha {i}°', {
                                        'f': m.fajrAngle,
                                        'i': m.ishaAngle ?? 0,
                                      }),
                                icon: FontAwesomeIcons.calculator,
                                colors: PrayerStyle.module,
                              ),
                          ],
                          selected: method,
                          accent: PrayerStyle.module.solid,
                        );
                        if (picked != null) {
                          await _edit(
                            ref,
                            (p) => p.copyWith(method: picked.value.name),
                          );
                        }
                      },
                    ),
                    FFListRow(
                      leading: _tile(FontAwesomeIcons.sun),
                      title: tr('Asr'),
                      value: asr.label,
                      chevron: true,
                      onTap: () async {
                        final picked = await showOptionSheet<AsrSchool>(
                          context,
                          title: tr('Asr time'),
                          options: [
                            for (final a in AsrSchool.values)
                              OptionItem(
                                value: a,
                                label: a.label,
                                icon: FontAwesomeIcons.sun,
                                colors: PrayerStyle.module,
                              ),
                          ],
                          selected: asr,
                          accent: PrayerStyle.module.solid,
                        );
                        if (picked != null) {
                          await _edit(
                            ref,
                            (p) => p.copyWith(asrSchool: picked.value.name),
                          );
                        }
                      },
                    ),
                    FFListRow(
                      leading: _tile(FontAwesomeIcons.globe),
                      title: tr('High latitudes'),
                      value: high.label,
                      chevron: true,
                      onTap: () async {
                        final picked = await showOptionSheet<HighLatitudeRule>(
                          context,
                          title: tr('High latitudes'),
                          subtitle: tr(
                            'Where dawn or nightfall never quite happen in summer',
                          ),
                          options: [
                            for (final r in HighLatitudeRule.values)
                              OptionItem(
                                value: r,
                                label: r.label,
                                icon: FontAwesomeIcons.globe,
                                colors: PrayerStyle.module,
                              ),
                          ],
                          selected: high,
                          accent: PrayerStyle.module.solid,
                        );
                        if (picked != null) {
                          await _edit(
                            ref,
                            (p) =>
                                p.copyWith(highLatitudeRule: picked.value.name),
                          );
                        }
                      },
                    ),
                  ],
                ),
                if (islam) ...[
                  gap,
                  FFGroupedList(
                    label: tr('Hijri date'),
                    footer: tr(
                      'Moon sighting differs by country: move the date by a day or two to match yours.',
                    ),
                    children: [
                      FFListRow(
                        leading: _tile(FontAwesomeIcons.solidMoon),
                        title: HijriDate.fromGregorian(
                          today,
                          adjustDays: prefs.hijriAdjust,
                        ).format(),
                        value: prefs.hijriAdjust == 0
                            ? tr('No correction')
                            : tr('{n, plural, one {# day} other {# days}}', {
                                'n': prefs.hijriAdjust,
                              }),
                        chevron: true,
                        onTap: () async {
                          final picked = await showOptionSheet<int>(
                            context,
                            title: tr('Hijri correction'),
                            options: [
                              for (final n in const [-2, -1, 0, 1, 2])
                                OptionItem(
                                  value: n,
                                  label: HijriDate.fromGregorian(
                                    today,
                                    adjustDays: n,
                                  ).format(),
                                  subtitle: n == 0
                                      ? tr('No correction')
                                      : (n > 0 ? '+$n' : '$n'),
                                  icon: FontAwesomeIcons.solidMoon,
                                  colors: PrayerStyle.module,
                                ),
                            ],
                            selected: prefs.hijriAdjust,
                            accent: PrayerStyle.module.solid,
                          );
                          if (picked != null) {
                            await _edit(
                              ref,
                              (p) => p.copyWith(hijriAdjust: picked.value),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
                gap,
                FFGroupedList(
                  label: tr('General'),
                  children: [
                    FFListRow.toggle(
                      leading: _tile(FontAwesomeIcons.solidBell),
                      title: tr('Prayer reminders'),
                      value: prefs.notify,
                      onChanged: (v) =>
                          unawaited(_edit(ref, (p) => p.copyWith(notify: v))),
                    ),
                    FFListRow.toggle(
                      leading: _tile(FontAwesomeIcons.eyeSlash),
                      title: tr('Discreet notifications'),
                      subtitle: tr('Title shows "Reminder" and the time only'),
                      value: prefs.discreet,
                      onChanged: (v) =>
                          unawaited(_edit(ref, (p) => p.copyWith(discreet: v))),
                    ),
                    FFListRow(
                      leading: _tile(FontAwesomeIcons.wandMagicSparkles),
                      title: tr('Add prayers from a tradition'),
                      chevron: true,
                      onTap: () => context.push(AppRoutes.prayerSetup),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
