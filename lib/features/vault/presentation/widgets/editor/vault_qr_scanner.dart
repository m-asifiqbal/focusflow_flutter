/// ============================================================
/// VAULT QR SCANNER — scan an `otpauth://` QR for the 2FA secret (20)
/// ============================================================
///
/// Full-screen camera (mobile_scanner, on-device, no network) that pops
/// the first QR whose text is a valid TOTP setup URI. The vault session is
/// kept open while the camera runs (permission prompts can background the
/// app). The scanned secret is returned in memory only — never logged.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/crypto/totp.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// The scanned `otpauth://` URI, or null when cancelled.
Future<String?> scanVaultTotpQr(BuildContext context, WidgetRef ref) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return ref
      .read(vaultSessionProvider.notifier)
      .keepUnlockedDuring(
        () => navigator.push<String>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const VaultTheme(child: _ScannerPage()),
          ),
        ),
      );
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue?.trim();
      if (raw == null) continue;
      if (raw.toLowerCase().startsWith('otpauth://') &&
          TotpConfig.parse(raw) != null) {
        _done = true;
        Navigator.of(context).pop(raw);
        return;
      }
      if (!_invalid) setState(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final caption = context.text.body.copyWith(color: ff.vaultInk);
    return Scaffold(
      backgroundColor: ff.vaultCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? tr(
                          'Camera access is off. Allow it in Settings, or paste the key instead.',
                        )
                      : tr(
                          'The camera isn\'t available. Paste the key instead.',
                        ),
                  textAlign: TextAlign.center,
                  style: caption,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: VaultSizes.scanner,
              height: VaultSizes.scanner,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.hero),
                border: Border.all(
                  color: ff.vaultAccent,
                  width: VaultSizes.scannerBorder,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.sm),
                    child: VaultRoundButton(
                      icon: FontAwesomeIcons.xmark,
                      semanticLabel: tr('Close scanner'),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
                  child: Text(
                    _invalid
                        ? tr('That QR code isn\'t a 2FA setup code.')
                        : tr(
                            'Point the camera at the 2FA QR code shown by the website.',
                          ),
                    textAlign: TextAlign.center,
                    style: caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
