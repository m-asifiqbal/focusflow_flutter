/// Switching language rebuilds the running UI — const widgets included — and
/// Arabic mirrors the layout; nothing else (state, navigation) is lost.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/l10n/app_language.dart';
import 'package:focusflow/core/l10n/language_service.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

/// A const widget: nothing but a rebuild of the whole tree re-reads `tr`.
class _Label extends StatelessWidget {
  const _Label();

  @override
  Widget build(BuildContext context) => Text(tr('Archive'));
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => taps++), child: Text('$taps'));
}

void main() {
  setUp(L10n.reset);
  tearDown(L10n.reset);

  testWidgets('a switch rebuilds const widgets and keeps their state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final bundle = _Bundle({
      'assets/l10n/de.json': jsonEncode({'Archive': 'Archiv'}),
      'assets/l10n/ar.json': jsonEncode({'Archive': 'الأرشيف'}),
    });
    final controllerProvider = Provider(
      (ref) => LanguageController(ref, bundle: bundle),
    );
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final language = ref.watch(settingsProvider.select(storedLanguage));
            return MaterialApp(
              locale: language.locale,
              supportedLocales: [for (final l in AppLanguage.values) l.locale],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const Scaffold(
                body: Column(children: [_Label(), _Counter()]),
              ),
            );
          },
        ),
      ),
    );
    expect(find.text('Archive'), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    final controller = container.read(controllerProvider);
    await tester.runAsync(() async {
      await controller.add(AppLanguage.de);
      await controller.add(AppLanguage.ar);
      await controller.select(AppLanguage.de);
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('Archiv'), findsOneWidget);
    expect(find.text('Archive'), findsNothing);
    expect(
      find.text('1'),
      findsOneWidget,
      reason: 'state survives the rebuild',
    );
    expect(
      Directionality.of(tester.element(find.text('Archiv'))),
      TextDirection.ltr,
    );

    await tester.runAsync(() => controller.select(AppLanguage.ar));
    await tester.pump();
    await tester.pump();
    expect(find.text('الأرشيف'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('الأرشيف'))),
      TextDirection.rtl,
    );

    await tester.runAsync(() => controller.select(AppLanguage.en));
    await tester.pump();
    await tester.pump();
    expect(find.text('Archive'), findsOneWidget);
  });
}
