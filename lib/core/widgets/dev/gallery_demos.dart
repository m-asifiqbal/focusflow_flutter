/// ============================================================
/// GALLERY DEMOS — one self-contained demo per FF component
/// ============================================================
///
/// Shared by the dev [WidgetGalleryScreen] and the widget tests (which pump
/// every demo in light + dark, at text scale 1.3 on a 360 pt surface).
/// Debug/dev only — never shipped in feature screens.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/widgets/dev/gallery_demos_atoms.dart';
import 'package:focusflow/core/widgets/dev/gallery_demos_composites.dart';

/// A named demo.
@immutable
class GalleryDemo {
  const GalleryDemo(this.name, this.builder);

  final String name;
  final WidgetBuilder builder;
}

/// Every demo, in gallery order.
List<GalleryDemo> get galleryDemos => [...atomDemos, ...compositeDemos];

/// Minimal local state holder for interactive demos.
class GalleryState<T> extends StatefulWidget {
  const GalleryState({required this.initial, required this.builder, super.key});

  final T initial;
  final Widget Function(BuildContext context, T value, ValueChanged<T> set)
  builder;

  @override
  State<GalleryState<T>> createState() => _GalleryStateState<T>();
}

class _GalleryStateState<T> extends State<GalleryState<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _value, (v) => setState(() => _value = v));
}
