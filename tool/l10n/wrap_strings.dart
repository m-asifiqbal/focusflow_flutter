// One-off migration: wraps the user-facing string literals of lib/ in
// `tr(...)` (core/l10n/tr.dart) so they can be translated.
//
//   dart run tool/l10n/wrap_strings.dart            # rewrite lib/ in place
//   dart run tool/l10n/wrap_strings.dart --dry-run  # only report
//
// Conservative on purpose: it only touches literals in contexts that are
// user-facing beyond doubt (Text(...), `label:` / `title:` / `hint:` … named
// arguments, a few widget helpers), follows ternaries / `??` / switch
// expressions to find that context, turns `$x` interpolations into `{x}`
// placeholders, and drops the `const` of every enclosing expression (the
// call is not constant). Literals it cannot make safe — constants, static
// and instance field initialisers, enum arguments, default parameter values —
// are listed in `build/l10n_skipped.txt` for hand work. Run
// `dart fix --apply` and `dart format` on the changed files afterwards (it
// prints them): the removed `const`s leave `prefer_const_constructors` hints.
//
// Needs the project's package config: dart run (not a bare `dart script`).
// ignore_for_file: depend_on_referenced_packages, curly_braces_in_flow_control_structures
// (A migration script run through the project's package config: it uses the
// analyzer that build_runner already brings in, so pubspec stays untouched.)
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

const _namedArgs = {
  'label',
  'title',
  'subtitle',
  'body',
  'message',
  'hint',
  'hintText',
  'labelText',
  'helperText',
  'semanticLabel',
  'semanticHint',
  'ctaLabel',
  'confirmLabel',
  'cancelLabel',
  'actionLabel',
  'retryLabel',
  'deleteLabel',
  'completeLabel',
  'archiveLabel',
  'undoLabel',
  'caption',
  'footer',
  'tooltip',
  'suffixText',
  'titleLead',
  'titleAccent',
  'titleError',
  'text',
  'placeholder',
  'notice',
  'helpText',
  'barrierLabel',
  'filterSemanticLabel',
  'onLongPressHint',
  'lockLabel',
  'stopButton',
  'androidSnoozeButton',
  'deleteButtonTooltipMessage',
  'biometricPromptTitle',
  'biometricPromptSubtitle',
  'biometricPromptNegativeButton',
};

const _positionalCalls = {
  'Text',
  'showFFToast',
  'FFSectionLabel',
  'VaultSectionLabel',
  'SearchSectionLabel',
  'VaultFieldLabel',
  'FFTag',
  'FFBadge',
  'SheetHeader',
  '_SheetLabel',
  '_SheetTitle',
  '_toast',
};

const _skipDirs = ['lib/core/l10n/', 'lib/core/widgets/dev/'];

/// Declarations whose initialisers run once (or are constant): a `tr()` there
/// would go stale on a language switch, or not compile.
const _unsafeAncestors = [
  'FieldDeclaration',
  'TopLevelVariableDeclaration',
  'EnumConstant',
  'Annotation',
  'DefaultClause',
  'ConstantPattern',
  'SwitchCase',
  'ConstructorFieldInitializer',
  'SuperConstructorInvocation',
  'RedirectingConstructorInvocation',
];

class _Edit {
  _Edit(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
}

class _Skip {
  _Skip(this.file, this.line, this.text, this.why);
  final String file;
  final int line;
  final String text;
  final String why;
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this.file, this.src, this.lineOf, this.edits, this.skips);

  final String file;
  final String src;
  final int Function(int offset) lineOf;
  final Map<int, _Edit> edits;
  final List<_Skip> skips;
  int wrapped = 0;

  @override
  void visitAdjacentStrings(AdjacentStrings node) => _consider(node);

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.parent is! AdjacentStrings) _consider(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    if (node.parent is! AdjacentStrings) _consider(node);
    // Literals inside `${…}` are left for hand work.
  }

  @override
  void visitImportDirective(ImportDirective node) {}
  @override
  void visitExportDirective(ExportDirective node) {}
  @override
  void visitPartDirective(PartDirective node) {}

  void _consider(StringLiteral node) {
    final ctx = _context(node);
    if (ctx == null) return;
    final built = _build(node);
    if (built == null) return;
    final (key, args) = built;
    if (!_looksTranslatable(key, inUiContext: true)) return;
    final reason = _unsafe(node);
    if (reason != null) {
      skips.add(_Skip(file, lineOf(node.offset), key, reason));
      return;
    }
    final call = args.isEmpty
        ? "tr('$key')"
        : "tr('$key', {${args.entries.map((e) => "'${e.key}': ${e.value}").join(', ')}})";
    edits[node.offset] = _Edit(node.offset, node.end, call);
    wrapped++;
    _dropConsts(node);
  }

  /// The user-facing context of [node], or null: climbs ternaries, `??`,
  /// parentheses and switch expressions to the argument that receives it.
  String? _context(AstNode node) {
    AstNode child = node;
    var parent = node.parent;
    while (parent != null) {
      if (parent is ParenthesizedExpression) {
        // up
      } else if (parent is ConditionalExpression) {
        if (parent.condition == child) return null;
      } else if (parent is BinaryExpression) {
        if (parent.operator.lexeme != '??') return null;
      } else if (parent is SwitchExpressionCase) {
        if (parent.expression != child) return null;
      } else if (parent is SwitchExpression) {
        // up
      } else if (parent is NamedArgument) {
        return _namedArgs.contains(parent.name.lexeme) ? 'named' : null;
      } else if (parent is ArgumentList) {
        final call = parent.parent;
        if (parent.arguments.isEmpty || parent.arguments.first != child) {
          return null;
        }
        final name = switch (call) {
          MethodInvocation() => call.methodName.name,
          InstanceCreationExpression() => call.constructorName.type.name.lexeme,
          _ => null,
        };
        return name != null && _positionalCalls.contains(name)
            ? 'positional'
            : null;
      } else {
        return null;
      }
      child = parent;
      parent = parent.parent;
    }
    return null;
  }

  /// Why [node] cannot simply become a `tr()` call, or null.
  String? _unsafe(AstNode node) {
    for (AstNode? n = node.parent; n != null; n = n.parent) {
      final t = n.runtimeType.toString();
      for (final bad in _unsafeAncestors) {
        if (t.contains(bad)) return 'in $bad';
      }
      if (n is VariableDeclarationList && n.isConst) return 'in const variable';
      if (n is MethodDeclaration ||
          n is FunctionDeclaration ||
          n is FunctionExpression) {
        // Reached a body: everything above is not an initialiser we care about.
        return null;
      }
    }
    return null;
  }

  /// Removes the `const` of every enclosing expression: it now holds a call.
  void _dropConsts(AstNode node) {
    for (AstNode? n = node.parent; n != null; n = n.parent) {
      Token? kw;
      if (n is InstanceCreationExpression) kw = n.keyword;
      if (n is ListLiteral) kw = n.constKeyword;
      if (n is SetOrMapLiteral) kw = n.constKeyword;
      if (n is RecordLiteral) kw = n.constKeyword;
      if (kw != null && kw.lexeme == 'const') {
        var end = kw.end;
        while (end < src.length &&
            (src[end] == ' ' || src[end] == '\n' || src[end] == '\r')) {
          end++;
        }
        edits.putIfAbsent(kw.offset, () => _Edit(kw!.offset, end, ''));
      }
      if (n is MethodDeclaration || n is FunctionDeclaration) break;
    }
  }

  /// (key source without quotes, placeholder → expression source), or null
  /// when the literal is raw, multi-line or already uses braces.
  (String, Map<String, String>)? _build(StringLiteral node) {
    final parts = node is AdjacentStrings ? node.strings : [node];
    final key = StringBuffer();
    final args = <String, String>{};
    final names = <String, String>{}; // expression source → placeholder
    for (final p in parts) {
      if (p is SimpleStringLiteral) {
        if (p.isRaw || p.isMultiline) return null;
        final body = _body(p.literal.lexeme, p);
        if (body == null || body.contains('{') || body.contains('}'))
          return null;
        key.write(body);
      } else if (p is StringInterpolation) {
        if (p.isRaw || p.isMultiline) return null;
        final elements = p.elements;
        for (var i = 0; i < elements.length; i++) {
          final e = elements[i];
          if (e is InterpolationString) {
            // The first piece starts with the opening quote, the last one
            // ends with the closing quote: neither belongs to the text.
            var raw = e.contents.lexeme;
            if (i == 0) raw = raw.substring(1);
            if (i == elements.length - 1)
              raw = raw.substring(0, raw.length - 1);
            final body = _fragment(raw, p);
            if (body == null || body.contains('{') || body.contains('}'))
              return null;
            key.write(body);
          } else if (e is InterpolationExpression) {
            final expr = e.expression;
            final text = src.substring(expr.offset, expr.end);
            final name = names.putIfAbsent(text, () {
              var base = _nameFor(expr);
              var candidate = base;
              var i = 2;
              while (args.containsKey(candidate)) {
                candidate = '$base$i';
                i++;
              }
              args[candidate] = text;
              return candidate;
            });
            key.write('{$name}');
          }
        }
      } else {
        return null;
      }
    }
    return (key.toString(), args);
  }

  /// Contents of a one-line literal token as single-quoted source.
  String? _body(String lexeme, StringLiteral node) {
    final quote = lexeme[0];
    if (lexeme.length < 2) return null;
    return _fragment(
      lexeme.substring(1, lexeme.length - 1),
      node,
      quote: quote,
    );
  }

  String? _fragment(String raw, StringLiteral node, {String? quote}) {
    final q = quote ?? src[node.offset];
    if (q == '"') {
      return raw
          .replaceAll(r'\"', '"')
          .replaceAllMapped(RegExp(r"(?<!\\)'"), (_) => r"\'");
    }
    return raw;
  }

  String _nameFor(Expression e) {
    var x = e;
    while (x is ParenthesizedExpression) {
      x = x.expression;
    }
    final name = switch (x) {
      SimpleIdentifier() => x.name,
      PrefixedIdentifier() => x.identifier.name,
      PropertyAccess() => x.propertyName.name,
      MethodInvocation() => x.methodName.name,
      _ => 'v',
    };
    // `$2` (record field) and friends are not placeholder names.
    return RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(name) ? name : 'v';
  }
}

/// Letters in the text with the placeholders removed, and not an identifier.
bool _looksTranslatable(String key, {required bool inUiContext}) {
  final text = key
      .replaceAll(RegExp(r'\{[A-Za-z0-9_]+\}'), '')
      .replaceAll(RegExp(r'\\.'), '');
  if (!RegExp(r'[A-Za-z]{2}').hasMatch(text)) return false;
  if (text.contains('://')) return false;
  // snake_case / camelCase / dotted ids and paths with no space.
  if (!text.contains(' ') && RegExp(r'^[a-z][A-Za-z0-9_./\-]*$').hasMatch(text))
    return false;
  return true;
}

const _importLine = "import 'package:focusflow/core/l10n/tr.dart';";

void main(List<String> args) {
  final dry = args.contains('--dry-run');
  final skips = <_Skip>[];
  final changed = <String>[];
  var wrapped = 0;

  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final path = f.path.replaceAll('\\', '/');
    if (path.endsWith('.g.dart') || path.contains('fa_icons')) continue;
    if (_skipDirs.any(path.startsWith)) continue;

    var src = f.readAsStringSync();
    final crlf = src.contains('\r\n');
    src = src.replaceAll('\r\n', '\n');
    final unit = parseString(content: src, throwIfDiagnostics: false).unit;
    final lineStarts = <int>[0];
    for (var i = 0; i < src.length; i++) {
      if (src[i] == '\n') lineStarts.add(i + 1);
    }
    int lineOf(int offset) {
      var lo = 0, hi = lineStarts.length - 1;
      while (lo < hi) {
        final mid = (lo + hi + 1) ~/ 2;
        if (lineStarts[mid] <= offset) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      return lo + 1;
    }

    final edits = <int, _Edit>{};
    final v = _Visitor(path, src, lineOf, edits, skips);
    unit.accept(v);
    if (edits.isEmpty) continue;

    var out = src;
    final ordered = edits.values.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    for (final e in ordered) {
      out = out.replaceRange(e.start, e.end, e.text);
    }
    if (!out.contains(_importLine)) out = _withImport(out);
    wrapped += v.wrapped;
    changed.add(path);
    if (!dry) f.writeAsStringSync(crlf ? out.replaceAll('\n', '\r\n') : out);
  }

  final report = StringBuffer();
  for (final s in skips) {
    report.writeln('${s.file}:${s.line}\t${s.why}\t${s.text}');
  }
  Directory('build').createSync(recursive: true);
  File('build/l10n_skipped.txt').writeAsStringSync(report.toString());
  File('build/l10n_changed.txt').writeAsStringSync(changed.join('\n'));
  stdout.writeln(
    '${dry ? "[dry run] " : ""}wrapped $wrapped literals in ${changed.length} files; '
    '${skips.length} left for hand work (build/l10n_skipped.txt).',
  );
}

/// Adds the tr import among the package:focusflow imports, in order.
String _withImport(String src) {
  final lines = src.split('\n');
  var firstFocus = -1, lastImport = -1, insertAt = -1;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.startsWith('import ')) lastImport = i;
    if (l.startsWith("import 'package:focusflow/")) {
      if (firstFocus < 0) firstFocus = i;
      if (insertAt < 0 && l.compareTo(_importLine) > 0) insertAt = i;
    }
  }
  if (insertAt >= 0) {
    lines.insert(insertAt, _importLine);
  } else if (firstFocus >= 0) {
    // After the last package:focusflow import.
    var last = firstFocus;
    for (var i = firstFocus; i < lines.length; i++) {
      if (lines[i].startsWith("import 'package:focusflow/")) last = i;
    }
    lines.insert(last + 1, _importLine);
  } else if (lastImport >= 0) {
    lines.insert(lastImport + 1, _importLine);
  } else {
    // No imports yet: after the library directive / header comment.
    var at = 0;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('library') ||
          lines[i].startsWith('///') ||
          lines[i].startsWith('//')) {
        at = i + 1;
      } else if (lines[i].trim().isNotEmpty) {
        break;
      }
    }
    lines.insertAll(at, ['', _importLine]);
  }
  return lines.join('\n');
}
