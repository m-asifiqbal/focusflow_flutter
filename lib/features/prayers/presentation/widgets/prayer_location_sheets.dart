/// ============================================================
/// PRAYER LOCATION SHEETS — ask with a reason, search a city, travel
/// ============================================================
///
/// What:
///   * [showPrayerLocationSheet] — "Use your precise location?" with why
///     (times are calculated on this phone, never sent, never read in the
///     background) BEFORE the system prompt; then the outcome: saved,
///     "Don't ask again" (→ app settings), location off (→ location
///     settings), or no fix — each with "Search a city instead".
///   * [showPrayerCitySheet] — the offline city search (WorldCities) and
///     latitude / longitude entry.
///   * [PrayerTravelBanner] — "You seem to be in a new place … Update?"
/// Why: a cold system prompt gets refused; a one-screen reason first is
/// what earns "Allow". Every path ends with a usable location.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/data/location/prayer_locator.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/domain/services/world_cities.dart';
import 'package:focusflow/features/prayers/presentation/prayer_flows.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';

/// The explanation + request. Resolves when a location was saved (true)
/// or the user gave up (false).
Future<bool> showPrayerLocationSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final choice = await showFFBottomSheet<bool>(
    context,
    builder: (_) => const _ExplainSheet(),
  );
  if (choice == null || !context.mounted) return false;
  if (!choice) return showPrayerCitySheet(context, ref);
  final outcome = await locatePrayerPlace(context, ref);
  if (outcome == LocateOutcome.ok || !context.mounted) {
    return outcome == LocateOutcome.ok;
  }
  final next = await showFFBottomSheet<_Next>(
    context,
    builder: (_) => _OutcomeSheet(outcome: outcome),
  );
  if (!context.mounted) return false;
  final locator = ref.read(prayerLocatorProvider);
  switch (next) {
    case _Next.appSettings:
      await locator.openAppSettings();
    case _Next.locationSettings:
      await locator.openLocationSettings();
    case _Next.retry:
      if (context.mounted) return showPrayerLocationSheet(context, ref);
    case _Next.city:
      if (context.mounted) return showPrayerCitySheet(context, ref);
    case null:
      break;
  }
  return false;
}

enum _Next { appSettings, locationSettings, retry, city }

class _ExplainSheet extends StatelessWidget {
  const _ExplainSheet();

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    Widget point(IconData icon, String line) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: PrayerStyle.module.solid),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(line, style: text.body)),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: FFIconTile.soft(
            icon: FontAwesomeIcons.locationCrosshairs,
            colors: PrayerStyle.module,
            size: AppSizes.iconTileLg,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          tr('Use your precise location?'),
          textAlign: TextAlign.center,
          style: text.title,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tr('Prayer times depend on exactly where you are.'),
          textAlign: TextAlign.center,
          style: text.bodySmall.copyWith(color: ff.inkMuted),
        ),
        const SizedBox(height: AppSpacing.xl),
        point(
          FontAwesomeIcons.mobileScreen,
          tr('Times are calculated on this phone.'),
        ),
        point(
          FontAwesomeIcons.shieldHalved,
          tr('Your location is never sent anywhere.'),
        ),
        point(
          FontAwesomeIcons.pause,
          tr('It is read only when you ask — never in the background.'),
        ),
        const SizedBox(height: AppSpacing.md),
        FFPrimaryButton(
          label: tr('Allow precise location'),
          icon: FontAwesomeIcons.locationCrosshairs,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpacing.sm),
        FFSecondaryButton(
          label: tr('Search a city instead'),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          tr(
            'Next, your phone asks: choose "Precise" and "While using the app".',
          ),
          textAlign: TextAlign.center,
          style: text.meta.copyWith(
            color: ff.inkFaint,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _OutcomeSheet extends StatelessWidget {
  const _OutcomeSheet({required this.outcome});

  final LocateOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final (title, body, action, next) = switch (outcome) {
      LocateOutcome.deniedForever => (
        tr('Location is turned off for FocusFlow'),
        tr('Allow it in the app settings, or search your city instead.'),
        tr('Open settings'),
        _Next.appSettings,
      ),
      LocateOutcome.serviceOff => (
        tr('Location is off on this phone'),
        tr('Turn on location, or search your city instead.'),
        tr('Turn on location'),
        _Next.locationSettings,
      ),
      LocateOutcome.denied => (
        tr('No location yet'),
        tr(
          'Prayer times need your location. You can ask again or search your city.',
        ),
        tr('Ask again'),
        _Next.retry,
      ),
      _ => (
        tr('Could not find your location'),
        tr('Try again near a window, or search your city instead.'),
        tr('Try again'),
        _Next.retry,
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: text.title),
        const SizedBox(height: AppSpacing.sm),
        Text(body, style: text.body),
        const SizedBox(height: AppSpacing.xl),
        FFPrimaryButton(
          label: action,
          onPressed: () => Navigator.of(context).pop(next),
        ),
        const SizedBox(height: AppSpacing.sm),
        FFSecondaryButton(
          label: tr('Search a city instead'),
          onPressed: () => Navigator.of(context).pop(_Next.city),
        ),
      ],
    );
  }
}

/// The offline city search. Resolves true when a city / coordinates were
/// saved.
Future<bool> showPrayerCitySheet(BuildContext context, WidgetRef ref) async {
  final picked = await showFFBottomSheet<(GeoPoint, String)>(
    context,
    wrap: false,
    builder: (_) => const _CitySheet(),
  );
  if (picked == null) return false;
  await savePrayerLocation(ref, picked.$1, label: picked.$2, precise: false);
  return true;
}

class _CitySheet extends StatefulWidget {
  const _CitySheet();

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  final _query = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  bool _coordinates = false;

  @override
  void dispose() {
    _query.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  GeoPoint? get _point {
    final lat = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(_lng.text.trim().replaceAll(',', '.'));
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return GeoPoint(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final results = WorldCities.search(_query.text);
    return FFBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Set your location'), style: text.title),
          const SizedBox(height: AppSpacing.md),
          FFSegmented<bool>(
            segments: [
              FFSegment(value: false, label: tr('City')),
              FFSegment(value: true, label: tr('Coordinates')),
            ],
            value: _coordinates,
            onChanged: (v) => setState(() => _coordinates = v),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!_coordinates) ...[
            FFSearchField(
              controller: _query,
              hint: tr('Search a city'),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_query.text.trim().isNotEmpty && results.isEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Text(
                  tr('No city found — try coordinates instead.'),
                  style: text.bodySmall.copyWith(color: ff.inkMuted),
                ),
              ),
            for (final c in results)
              FFListRow(
                title: c.label,
                leading: Icon(
                  FontAwesomeIcons.locationDot,
                  size: 15,
                  color: PrayerStyle.module.solid,
                ),
                chevron: true,
                onTap: () => Navigator.of(context).pop((c.point, c.label)),
              ),
          ] else ...[
            TextField(
              controller: _lat,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('Latitude (−90 to 90)'),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _lng,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('Longitude (−180 to 180)'),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            FFPrimaryButton(
              label: tr('Use these coordinates'),
              onPressed: _point == null
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop((_point!, prayerPlaceLabel(_point!))),
            ),
          ],
        ],
      ),
    );
  }
}

/// "You seem to be in a new place" on the Prayer page.
class PrayerTravelBanner extends StatelessWidget {
  const PrayerTravelBanner({
    required this.km,
    required this.onUpdate,
    required this.onDismiss,
    super.key,
  });

  final double km;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    return FFCard(
      color: ff.primarySoft,
      shadow: false,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(FontAwesomeIcons.route, size: 18, color: ff.primaryStrong),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('You seem to be in a new place'),
                      style: text.rowTitle.copyWith(color: ff.primaryStrong),
                    ),
                    Text(
                      tr(
                        'About {km} km from your saved location. Update prayer times?',
                        {'km': km.round()},
                      ),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FFTextButton(label: tr('Not now'), onPressed: onDismiss),
              const SizedBox(width: AppSpacing.sm),
              FFTextButton(
                label: tr('Update'),
                color: ff.primaryStrong,
                onPressed: onUpdate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
