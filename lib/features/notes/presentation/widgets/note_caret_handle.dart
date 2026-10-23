/// ============================================================
/// NOTE CARET HANDLE — a draggable teardrop under the text cursor
/// ============================================================
///
/// What: flutter_quill shows selection handles only for a *range*; for a
/// plain caret it disposes its overlay, so on Android the cursor could only
/// be moved by tapping a new spot. This wraps the editor and, whenever the
/// caret is collapsed and the editor is focused, shows the familiar teardrop
/// handle beneath it — behaving like Android's own text handle:
///   * the caret keeps the offset at which the handle was grabbed (no jump
///     on touch-down) and aims at the line above the finger;
///   * the handle moves in the same frame as the caret (its position is
///     computed directly — the text layout doesn't change while dragging);
///   * a magnifier shows the text around the caret while dragging;
///   * holding the finger near the top / bottom edge keeps scrolling, faster
///     the closer it gets (a ticker, not only on pointer moves).
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
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_caret_parts.dart';

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

  /// Edge band (from the visible note's top / bottom) that auto-scrolls,
  /// and the top speed in points per second.
  static const double edgeBand = 56;
  static const double maxScrollSpeed = 900;

  /// Magnifier lens (Android's is ~100 × 48 at 1.25×).
  static const Size lens = Size(100, 46);
  static const double lensScale = 1.25;
  static const double lensGap = 10;

  static const Duration idleHide = Duration(seconds: 4);

  static bool get platformDefault =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  State<NoteCaretHandle> createState() => _NoteCaretHandleState();
}

class _NoteCaretHandleState extends State<NoteCaretHandle>
    with SingleTickerProviderStateMixin {
  /// Caret bottom / top in this widget's coordinates.
  Offset? _tip;
  double _lineHeight = 0;
  bool _visible = false;
  bool _dragging = false;
  bool _docChanged = false;
  late int _lastLength = widget.controller.document.length;
  Timer? _hide;
  StreamSubscription<DocChange>? _changes;

  /// Finger → caret-line-middle offset fixed at touch-down.
  Offset _grab = Offset.zero;
  Offset? _finger;
  late final Ticker _scroller;
  Duration _lastTick = Duration.zero;

  bool get _enabled => widget.enabled ?? NoteCaretHandle.platformDefault;

  RenderEditor? get _render {
    final raw = widget.editorKey.currentState?.editableTextKey.currentState;
    if (raw == null) return null;
    final render = raw.renderEditor;
    return render.attached ? render : null;
  }

  @override
  void initState() {
    super.initState();
    _scroller = createTicker(_onScrollTick);
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
    _scroller.dispose();
    widget.controller.removeListener(_onSelection);
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (!widget.focusNode.hasFocus) _hideHandle();
  }

  void _onSelection() {
    if (!_enabled || _dragging) return; // a drag places the handle itself
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
    // After a tap the editor may still relayout (a format toggle), so
    // measure once this frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _place());
  }

  bool get _canShow {
    final sel = widget.controller.selection;
    return !widget.readOnly &&
        widget.focusNode.hasFocus &&
        sel.isValid &&
        sel.isCollapsed;
  }

  /// Measures the caret of the current selection. Returns false when the
  /// handle can't be shown.
  bool _measure() {
    final render = _render;
    final box = context.findRenderObject();
    if (render == null || box is! RenderBox || !_canShow) return false;
    final sel = widget.controller.selection;
    final points = render.getEndpointsForSelection(sel);
    if (points.isEmpty) return false;
    _tip = box.globalToLocal(render.localToGlobal(points.first.point));
    _lineHeight = render.preferredLineHeight(sel.extent);
    return true;
  }

  void _place() {
    if (!mounted) return;
    if (!_measure()) {
      _hideHandle();
      return;
    }
    setState(() => _visible = true);
    _restartTimer();
  }

  void _restartTimer() {
    _hide?.cancel();
    if (_dragging) return;
    _hide = Timer(NoteCaretHandle.idleHide, _hideHandle);
  }

  void _hideHandle() {
    _hide?.cancel();
    if (_visible && mounted) setState(() => _visible = false);
  }

  // ── drag ──────────────────────────────────────────────────

  void _dragStart(Offset globalFinger) {
    final box = context.findRenderObject();
    final tip = _tip;
    if (box is RenderBox && tip != null) {
      // Middle of the caret's line, so the aim lands inside the line.
      final caretMid = box.localToGlobal(tip - Offset(0, _lineHeight / 2));
      _grab = caretMid - globalFinger;
    }
    _dragging = true;
    _finger = globalFinger;
    _hide?.cancel();
    HapticFeedback.selectionClick();
    setState(() {}); // show the magnifier
  }

  void _drag(DragUpdateDetails d) {
    _finger = d.globalPosition;
    _moveCaret();
    final band = _edgeSpeed() != 0;
    if (band && !_scroller.isActive) {
      _lastTick = Duration.zero;
      _scroller.start();
    } else if (!band && _scroller.isActive) {
      _scroller.stop();
    }
  }

  /// Moves the caret to the text under the (grab-corrected) finger, clamped
  /// into the visible note so Quill never scrolls on its own and fights the
  /// auto-scroll.
  void _moveCaret() {
    final render = _render;
    final finger = _finger;
    if (render == null || finger == null) return;
    var target = finger + _grab;
    final view = _viewport();
    if (view != null) {
      final margin = _lineHeight / 2 + AppSpacing.sm;
      target = Offset(
        target.dx,
        target.dy.clamp(view.top + margin, view.bottom - margin),
      );
    }
    final position = render.getPositionForOffset(target);
    final sel = widget.controller.selection;
    if (position.offset != sel.baseOffset || !sel.isCollapsed) {
      widget.controller.updateSelection(
        TextSelection.collapsed(offset: position.offset),
        ChangeSource.local,
      );
      HapticFeedback.selectionClick();
    }
    // Selection only: the layout is unchanged, so measure right away and
    // move the handle in this same frame.
    if (_measure()) setState(() => _visible = true);
  }

  /// The visible part of the note's scroll view, in global coordinates.
  Rect? _viewport() {
    final scrollable = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (scrollable is! RenderBox || !scrollable.attached) return null;
    return scrollable.localToGlobal(Offset.zero) & scrollable.size;
  }

  /// Auto-scroll speed for the finger position (pt/s, negative = up).
  double _edgeSpeed() {
    final finger = _finger;
    final view = _viewport();
    if (finger == null || view == null) return 0;
    const band = NoteCaretHandle.edgeBand;
    final y = finger.dy + _grab.dy;
    if (y < view.top + band) {
      return -NoteCaretHandle.maxScrollSpeed *
          ((view.top + band - y) / band).clamp(0.15, 1.0);
    }
    if (y > view.bottom - band) {
      return NoteCaretHandle.maxScrollSpeed *
          ((y - view.bottom + band) / band).clamp(0.15, 1.0);
    }
    return 0;
  }

  void _onScrollTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final scroll = widget.scrollController;
    final speed = _edgeSpeed();
    if (!_dragging || speed == 0 || !scroll.hasClients) {
      _scroller.stop();
      return;
    }
    final p = scroll.position;
    final next = (p.pixels + speed * dt).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (next == p.pixels) return;
    scroll.jumpTo(next);
    _moveCaret(); // the text moved under a still finger
  }

  void _dragEnd() {
    _dragging = false;
    _finger = null;
    _scroller.stop();
    if (mounted) setState(() {}); // drop the magnifier
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    final tip = _tip;
    final ff = context.ff;
    const lens = NoteCaretHandle.lens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: NoteCaretHandle.reserve),
          child: widget.child,
        ),
        if (_visible && tip != null && _dragging)
          Positioned(
            left: tip.dx - lens.width / 2,
            top: tip.dy - _lineHeight - NoteCaretHandle.lensGap - lens.height,
            child: IgnorePointer(
              child: RawMagnifier(
                size: lens,
                magnificationScale: NoteCaretHandle.lensScale,
                // From the lens centre down to the caret line's middle.
                focalPointOffset: Offset(
                  0,
                  lens.height / 2 + NoteCaretHandle.lensGap + _lineHeight / 2,
                ),
                decoration: MagnifierDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(lens.height / 2),
                    side: BorderSide(color: ff.surfaceBorder),
                  ),
                  shadows: ff.cardShadow,
                ),
              ),
            ),
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
                        if (_dragging) return null; // one finger at a time
                        _dragStart(position);
                        return NoteHandleDrag(onUpdate: _drag, onEnd: _dragEnd);
                      },
                    ),
              },
              child: Semantics(
                label: tr('Move cursor'),
                child: CustomPaint(
                  painter: NoteTeardropPainter(
                    color: ff.primary,
                    shadow: ff.cardShadow.firstOrNull?.color ?? ff.divider,
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
