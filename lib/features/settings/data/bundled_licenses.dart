/// ============================================================
/// BUNDLED LICENSES — fonts and icons shipped in assets/licenses/
/// ============================================================
///
/// What: adds the licence texts of the bundled Font Awesome, Lexend Deca
/// and Nunito Sans files to Flutter's [LicenseRegistry], once.
/// Why: package licences are collected automatically, asset licences are
/// not; Settings › About shows both on one licence page.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A bundled third-party asset and the file holding its licence.
typedef BundledLicense = ({
  String name,
  String use,
  String license,
  String asset,
});

/// Every bundled asset family credited on the About page.
const bundledLicenses = <BundledLicense>[
  (
    name: 'Font Awesome Free 6',
    use: 'Icons',
    license: 'CC BY 4.0 · SIL OFL 1.1 · MIT',
    asset: 'assets/licenses/FontAwesome-LICENSE.txt',
  ),
  (
    name: 'Lexend Deca',
    use: 'Headings & numbers',
    license: 'SIL OFL 1.1',
    asset: 'assets/licenses/OFL-LexendDeca.txt',
  ),
  (
    name: 'Nunito Sans',
    use: 'Body text',
    license: 'SIL OFL 1.1',
    asset: 'assets/licenses/OFL-NunitoSans.txt',
  ),
];

bool _registered = false;

/// Registers [bundledLicenses] with [LicenseRegistry] (idempotent).
void registerBundledLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    for (final l in bundledLicenses) {
      try {
        final text = await rootBundle.loadString(l.asset);
        yield LicenseEntryWithLineBreaks([l.name], text);
      } on Object {
        // Missing asset in a trimmed build — skip rather than break the page.
      }
    }
  });
}
