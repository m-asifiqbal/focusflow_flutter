/// ============================================================
/// INSIGHTS SHARE SERVICE — "Share" of the Insights header (screen 25)
/// ============================================================
///
/// Writes the rendered Insights page (PNG bytes from a RepaintBoundary)
/// into the temporary directory and hands it to the platform share sheet
/// (share_plus), like HabitCsvShareService. Nothing leaves the device
/// unless the user picks a target; the file is deleted once the sheet
/// completes.
/// ============================================================
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class InsightsShareService {
  const InsightsShareService();

  /// Shares [png] as `<app>-insights-<stamp>.png`. Returns false when
  /// the user dismissed the sheet.
  Future<bool> sharePng(Uint8List png, {required String fileStamp}) async {
    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'exports'),
    );
    await dir.create(recursive: true);
    final file = File(
      p.join(dir.path, '${AppInfo.name.toLowerCase()}-insights-$fileStamp.png'),
    );
    try {
      await file.writeAsBytes(png, flush: true);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: tr('My {app} insights', {'app': AppInfo.name}),
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    } finally {
      try {
        if (file.existsSync()) await file.delete();
      } on FileSystemException {
        // Best effort: the OS clears the temporary directory eventually.
      }
    }
  }
}
