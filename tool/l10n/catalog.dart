// ignore_for_file: depend_on_referenced_packages
// The translation catalogue, read from the source: every string literal that
// is the first argument of `tr(...)`, plus the labels registered in
// lib/core/l10n/static_keys.dart (const data whose text is translated where
// it is shown: `tr(entry.label)`). Used by `extract.dart` (writes
// assets/l10n/en.json) and test/core/l10n/catalog_test.dart.
//
// Runs on the analyzer that build_runner already brings in (the project's
// package config), so pubspec stays untouched.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class CatalogScan {
  /// key → files using it.
  final Map<String, Set<String>> keys = {};

  /// `tr(x)` calls whose first argument is not a plain literal (file:line).
  final List<String> dynamicCalls = [];

  /// `tr('...$x...')`: an interpolated key can never match a pack.
  final List<String> interpolated = [];
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this.file, this.unit, this.scan);

  final String file;
  final CompilationUnit unit;
  final CatalogScan scan;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    final name = node.methodName.name;
    if ((name != 'tr' && name != 'trPrint') || node.target != null) return;
    final args = node.argumentList.arguments;
    if (args.isEmpty) return;
    final first = args.first;
    if (first is! Expression) return;
    final where = '$file:${unit.lineInfo.getLocation(node.offset).lineNumber}';
    final value = _plain(first);
    if (value != null) {
      scan.keys.putIfAbsent(value, () => {}).add(file);
    } else if (first is StringInterpolation ||
        (first is AdjacentStrings && first.strings.any((s) => s is StringInterpolation))) {
      scan.interpolated.add(where);
    } else {
      scan.dynamicCalls.add(where);
    }
  }
}

/// The value of a literal without interpolation, or null.
String? _plain(Expression e) {
  if (e is SimpleStringLiteral) return e.value;
  if (e is AdjacentStrings) {
    final b = StringBuffer();
    for (final s in e.strings) {
      final v = s is SimpleStringLiteral ? s.value : null;
      if (v == null) return null;
      b.write(v);
    }
    return b.toString();
  }
  return null;
}

class _Literals extends RecursiveAstVisitor<void> {
  _Literals(this.out);
  final List<String> out;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.parent is! AdjacentStrings) out.add(node.value);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    final v = _plain(node);
    if (v != null) out.add(v);
  }
}

/// Scans [root] (default lib/) and the static key list.
CatalogScan scanCatalog({String root = 'lib'}) {
  final scan = CatalogScan();
  for (final f in Directory(root).listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final path = f.path.replaceAll('\\', '/');
    if (path.endsWith('.g.dart')) continue;
    final unit = parseString(content: f.readAsStringSync(), throwIfDiagnostics: false).unit;
    if (path.endsWith('core/l10n/static_keys.dart')) {
      final lits = <String>[];
      unit.accept(_Literals(lits));
      for (final k in lits) {
        scan.keys.putIfAbsent(k, () => {}).add(path);
      }
      continue;
    }
    if (path.contains('core/l10n/')) continue;
    unit.accept(_Visitor(path, unit, scan));
  }
  return scan;
}
