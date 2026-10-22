/// ============================================================
/// PROFILE PHOTO PREVIEW — the picture, full screen
/// ============================================================
///
/// Opened from the profile photo pop-up ("View photo"): the whole picture on
/// a dark backdrop (never cropped to the avatar circle), pinch to zoom,
/// double-tap to zoom in / out, tap the backdrop, the close button or go back
/// to leave.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_round_icon_button.dart';

Future<void> showProfilePhotoPreview(BuildContext context, Uint8List bytes) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: tr('Close photo'),
    barrierColor: const Color(0xF2000000),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => _PhotoViewer(bytes: bytes),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.bytes});

  final Uint8List bytes;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  Offset _doubleTapAt = Offset.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _zoomed => _controller.value.getMaxScaleOnAxis() > 1.05;

  /// Double-tap: zoom to 2.5× around the finger, or back to fit.
  void _toggleZoom() {
    if (_zoomed) {
      _controller.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    final p = _doubleTapAt;
    _controller.value = Matrix4.identity()
      ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Tapping the dark area (not the picture) closes the viewer.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox.expand(),
            ),
            SafeArea(
              child: Center(
                child: GestureDetector(
                  onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                  onDoubleTap: _toggleZoom,
                  child: Semantics(
                    image: true,
                    label: tr('Profile photo, full view'),
                    child: InteractiveViewer(
                      transformationController: _controller,
                      minScale: 1,
                      maxScale: 5,
                      child: Image.memory(
                        widget.bytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 0,
              end: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: FFRoundIconButton(
                    icon: FontAwesomeIcons.xmark,
                    semanticLabel: tr('Close photo'),
                    variant: FFRoundIconButtonVariant.dark,
                    onPressed: () => Navigator.of(context).maybePop(),
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
