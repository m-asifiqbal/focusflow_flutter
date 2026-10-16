/// ============================================================
/// QUICK ADD FLOWS — what happens after the "What's next?" sheet closes
/// ============================================================
///
/// What: the sheet pops with a [QuickAddResult]; [runQuickAddResult] opens
/// the matching editor with prefilled query parameters (AppRoutes
/// builders), unlocks the vault first for Password, and runs Quick Scan
/// (camera / library → on-device OCR → new note prefilled).
/// Why: navigation runs on the caller's context, which outlives the sheet.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/platform/text_scanner.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/quick_add/domain/entities/quick_capture.dart';
import 'package:focusflow/features/quick_add/domain/services/capture_inputs.dart';
import 'package:focusflow/features/quick_add/presentation/providers/quick_add_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:go_router/go_router.dart';

/// What the sheet asks for when it closes.
sealed class QuickAddResult {
  const QuickAddResult();
}

/// A module tile was tapped.
final class QuickAddModule extends QuickAddResult {
  const QuickAddModule(this.module);
  final AppModule module;
}

/// The capture field was submitted.
final class QuickAddCaptured extends QuickAddResult {
  const QuickAddCaptured(this.capture);
  final QuickCapture capture;
}

/// Default time for a reminder started from a pre-selected day.
const int _defaultReminderMinutes = 9 * 60;

/// Editor location for a parsed capture.
String quickCaptureLocation(QuickCapture c) {
  final title = c.title.isEmpty ? null : c.title;
  return switch (c.kind) {
    QuickCaptureKind.note => AppRoutes.newNoteWith(
      text: title,
      tag: c.savedTag,
    ),
    QuickCaptureKind.task => AppRoutes.newTask(
      title: title,
      date: c.dayKey,
      priority: c.priority,
      tag: c.savedTag,
      repeatRule: c.repeatRule,
    ),
    QuickCaptureKind.reminder => AppRoutes.newReminder(
      title: title,
      at: c.at,
      repeatRule: c.repeatRule,
    ),
  };
}

/// Editor location for a module tile ([AppModule.scan] has none).
String? quickModuleLocation(AppModule module, DateTime? date) =>
    switch (module) {
      AppModule.notes => AppRoutes.newNote,
      AppModule.tasks => AppRoutes.newTask(
        date: date == null ? null : DateUtilsX.dayKey(date),
      ),
      AppModule.reminders => AppRoutes.newReminder(
        at: date == null
            ? null
            : DateUtilsX.atMinutes(date, _defaultReminderMinutes),
      ),
      AppModule.habits => AppRoutes.newHabitPath,
      AppModule.vault => AppRoutes.newVaultItem(),
      AppModule.scan => null,
    };

/// Performs [result] on [context] (the page that opened the sheet).
Future<void> runQuickAddResult(
  BuildContext context,
  QuickAddResult result, {
  DateTime? date,
}) async {
  switch (result) {
    case QuickAddCaptured(:final capture):
      context.push(quickCaptureLocation(capture));
    case QuickAddModule(module: AppModule.scan):
      await runQuickScan(context);
    case QuickAddModule(module: AppModule.vault):
      if (!await ensureVaultUnlocked(context) || !context.mounted) return;
      context.push(quickModuleLocation(AppModule.vault, date)!);
    case QuickAddModule(:final module):
      context.push(quickModuleLocation(module, date)!);
  }
}

/// Quick Scan: choose camera or library, recognise text on device, then
/// open a new note with it. The temporary photo is deleted afterwards.
///
/// Every plugin failure — a [PlatformException] (permission denied, no
/// camera), a [MissingPluginException] (plugin not registered in this
/// build) or anything unexpected — ends in a friendly toast, never an
/// unhandled error. Nothing recognised is logged.
Future<void> runQuickScan(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final source = await _chooseScanSource(context);
  if (source == null || !context.mounted) return;
  final images = container.read(scanImageSourceProvider);
  String? path;
  try {
    path = await images.pick(source);
  } catch (_) {
    if (context.mounted) {
      showFFToast(
        context,
        source == ScanSource.camera
            ? "Couldn't open the camera"
            : "Couldn't open your photos",
        icon: FontAwesomeIcons.circleExclamation,
      );
    }
    return;
  }
  if (path == null) return;
  var text = '';
  var failed = false;
  try {
    text = await container.read(textScannerProvider).recognizeText(path);
  } catch (_) {
    failed = true;
  } finally {
    await _discardQuietly(images, path);
  }
  if (!context.mounted) return;
  if (text.isEmpty) {
    showFFToast(
      context,
      failed ? "Couldn't read that photo" : 'No text found in that photo',
      icon: FontAwesomeIcons.circleExclamation,
    );
    return;
  }
  context.push(AppRoutes.newNoteWith(text: text));
}

/// Deleting the temp photo is best effort; a failure must not hide the
/// scan result.
Future<void> _discardQuietly(ScanImageSource images, String path) async {
  try {
    await images.discard(path);
  } catch (_) {
    // The OS may already have cleared the picker's temp directory.
  }
}

Future<ScanSource?> _chooseScanSource(BuildContext context) async {
  ScanSource? picked;
  await showFFActionSheet(
    context,
    FFActionSheetData(
      header: FFActionSheetHeader(
        title: 'Quick Scan',
        icon: ModuleStyle.scan.icon,
        colors: ModuleStyle.scan.colors,
        meta: 'Turn printed text into a note',
      ),
      actions: [
        FFActionItem(
          icon: FontAwesomeIcons.camera,
          label: 'Take photo',
          colors: ModuleStyle.scan.colors,
          onTap: () => picked = ScanSource.camera,
        ),
        FFActionItem(
          icon: FontAwesomeIcons.solidImages,
          label: 'Choose from library',
          colors: ModuleStyle.notes.colors,
          onTap: () => picked = ScanSource.gallery,
        ),
      ],
    ),
  );
  return picked;
}
