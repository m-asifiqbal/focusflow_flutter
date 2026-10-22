/// ============================================================
/// NOTE CARET HANDLE — a draggable teardrop under the text cursor
/// ============================================================
///
/// What: flutter_quill shows selection handles only for a *range*; for a
/// plain caret it disposes its overlay, so on Android the cursor could only
/// be moved by tapping a new spot. This wraps the editor and, whenever the
/// caret is collapsed and the editor is focused, shows the familiar teardrop
/// handle beneath it. Drag it and the caret follows your finger (kept just
/// above it so it stays visible), scrolling the note when you reach the top
/// or bottom of the screen.
///
/// How: purely through Quill's public API — caret geometry from
/// `RenderEditor.getEndpointsForSelection`, the drag target from
/// `getPositionForOffset`, and the move via
/// `QuillController.updateSelection`. The handle lives in a Stack *inside*
/// the scrolled content, so it scrolls with the text and needs no per-frame
/// tracking.
///
/// Behaviour: appears after a tap / selection move, hides while typing, after
/// 4 s idle, on focus loss and in read-only notes. Touch-handle platforms
/// only (Android): iOS keeps its native "long-press then drag" caret.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_theme.dart';

class NoteCaretHandle extends StatefulWidget {
  const NoteCaretHandle({
    required this.controller,
    required this.focusNode,
    required this.editorKey,
    required this.scrollController,
    required this.child,
    this.readOnly = false,
    this.enabled,
    super.key,
  });

  final QuillController controller;
  final FocusNode focusNode;

  /// Key of the wrapped [QuillEditor] (gives access to its render object).
  final GlobalKey<QuillEditorState> editorKey;

  /// The scroll view the note sits in (auto-scroll while dragging).
  final ScrollController scrollController;
  final bool readOnly;

  /// Defaults to Android only.
  final bool? enabled;
  final Widget child;

  /// Handle hit area / drawn size.
  static const double hitSize = 44;
  static const double drawSize = 24;

  /// Room under the editor so a handle at the last line stays hit-testable.
  static const double reserve = 34;

  static bool get platformDefault =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  State<NoteCaretHandle> createState() => _NoteCaretHandleState();
}

class _NoteCaretHandleState extends State<NoteCaretHandle> {
  Offset? _tip;
  bool _visible = false;
  bool _dragging = false;
  bool _docChanged = false;
  late int _lastLength = widget.controller.document.length;
  Timer? _hide;
  StreamSubscription<DocChange>? _changes;

  bool get _enabled => widget.enabled ?? NoteCaretHandle.platformDefault;

  RenderBox? get _editorBox {
    final raw = widget.editorKey.currentState?.editableTextKey.currentState;
    if (raw == null) return null;
    final render = raw.renderEditor;
    return render.attached ? render : null;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSelection);
    widget.focusNode.addListener(_onFocus);
    _changes = widget.controller.document.changes.listen(
      (_) => _docChanged = true,
    );
  }

  @override
  void dispose() {
    _hide?.cancel();
    _changes?.cancel();
    widget.controller.removeListener(_onSelection);
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (!widget.focusNode.hasFocus) _hideHandle();
  }

  void _onSelection() {
    if (!_enabled) return;
    // Typing changes the document: keep the handle out of the way. The
    // length check is synchronous (the change stream fires a tick later).
    final length = widget.controller.document.length;
    final edited = _docChanged || length != _lastLength;
    _docChanged = false;
    _lastLength = length;
    if (edited) {
      _hideHandle();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _place());
  }

  void _place() {
    if (!mounted) return;
    final sel = widget.controller.selection;
    final editor = _editorBox;
    final box = context.findRenderObject();
    if (editor == null ||
        box is! RenderBox ||
        widget.readOnly ||
        !widget.focusNode.hasFocus ||
        !sel.isValid ||
        !sel.isCollapsed) {
      _hideHandle();
      return;
    }
    final raw = widget.editorKey.currentState!.editableTextKey.currentState!;
    final points = raw.renderEditor.getEndpointsForSelection(sel);
    if (points.isEmpty) return;
    // Caret bottom, editor → this widget's coordinates.
    final tip = box.globalToLocal(editor.localToGlobal(points.first.point));
    setState(() {
      _tip = tip;
      _visible = true;
    });
    _restartTimer();
  }

  void _restartTimer() {
    _hide?.cancel();
    if (_dragging) return;
    _hide = Timer(const Duration(seconds: 4), _hideHandle);
  }

  void _hideHandle() {
    _hide?.cancel();
    if (_visible && mounted) setState(() => _visible = false);
  }

  // ── drag ──────────────────────────────────────────────────

  void _dragStart() {
    _dragging = true;
    _hide?.cancel();
    HapticFeedback.selectionClick();
  }

  void _drag(DragUpdateDetails d) {
    final editor = _editorBox;
    if (editor == null) return;
    final raw = widget.editorKey.currentState!.editableTextKey.currentState!;
    final render = raw.renderEditor;
    final lineHeight = render.preferredLineHeight(
      widget.controller.selection.extent,
    );
    // The finger holds the teardrop body, a bit below the caret: aim the
    // caret at the text line above the finger so it stays visible.
    final target =
        d.globalPosition -
        Offset(0, NoteCaretHandle.drawSize * 0.7 + lineHeight * 0.5);
    final position = render.getPositionForOffset(target);
    if (position.offset != widget.controller.selection.baseOffset) {
      widget.controller.updateSelection(
        TextSelection.collapsed(offset: position.offset),
        ChangeSource.local,
      );
    }
    _autoScroll(d.globalPosition.dy);
  }

  /// Nudges the note while the finger is near the top or bottom edge.
  void _autoScroll(double fingerY) {
    final scroll = widget.scrollController;
    if (!scroll.hasClients) return;
    final media = MediaQuery.of(context);
    final bottom = media.size.height - media.viewInsets.bottom - 150;
    const top = 150.0;
    var delta = 0.0;
    if (fingerY > bottom) delta = 10;
    if (fingerY < top) delta = -10;
    if (delta == 0) return;
    final p = scroll.position;
    scroll.jumpTo(
      (p.pixels + delta).clamp(p.minScrollExtent, p.maxScrollExtent),
    );
  }

  void _dragEnd() {
    _dragging = false;
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    final tip = _tip;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: NoteCaretHandle.reserve),
          child: widget.child,
        ),
        if (_visible && tip != null)
          Positioned(
            left: tip.dx - NoteCaretHandle.hitSize / 2,
            top: tip.dy - 2,
            width: NoteCaretHandle.hitSize,
            height: NoteCaretHandle.hitSize,
            // Claims the gesture on touch-down: the handle sits inside the
            // scrolling note, and a normal pan would lose the arena to the
            // page's own vertical drag (scrolling instead of moving).
            child: RawGestureDetector(
              key: const ValueKey('note-caret-handle'),
              behavior: HitTestBehavior.opaque,
              gestures: {
                ImmediateMultiDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      ImmediateMultiDragGestureRecognizer
                    >(
                      ImmediateMultiDragGestureRecognizer.new,
                      (r) => r.onStart = (position) {
                        _dragStart();
                        return _HandleDrag(onUpdate: _drag, onEnd: _dragEnd);
                      },
                    ),
              },
              child: Semantics(
                label: tr('Move cursor'),
                child: CustomPaint(
                  painter: _TeardropPainter(
                    color: context.ff.primary,
                    size: NoteCaretHandle.drawSize,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The [Drag] handed to Flutter by the handle's recogniser.
class _HandleDrag implements Drag {
  _HandleDrag({required this.onUpdate, required this.onEnd});

  final ValueChanged<DragUpdateDetails> onUpdate;
  final VoidCallback onEnd;

  @override
  void update(DragUpdateDetails details) => onUpdate(details);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onEnd();
}

/// A teardrop with its point up, top-centre of the box.
class _TeardropPainter extends CustomPainter {
  const _TeardropPainter({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  void paint(Canvas canvas, Size box) {
    final r = size / 2;
    final cx = box.width / 2;
    final cy = 2 + r + 5;
    final body = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    // Pointed top: a triangle from the tip to the circle's upper tangents.
    final tip = Offset(cx, 2);
    final k = r * 0.72;
    final point = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(cx - k, cy - k)
      ..lineTo(cx + k, cy - k)
      ..close();
    final drop = Path.combine(PathOperation.union, body, point);
    canvas.drawShadow(drop, const Color(0x55000000), 3, true);
    canvas.drawPath(drop, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TeardropPainter old) =>
      old.color != color || old.size != size;
}
