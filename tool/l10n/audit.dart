// Lists the string literals of lib/ that look like user-facing text and are
// not translated yet (not inside `tr(...)`), so nothing slips through.
//
//   dart run --packages=.dart_tool/package_config.json tool/l10n/audit.dart [dir-prefix]
//
// Prints `path:line  context  text`, grouped by file, and writes the same to
// build/l10n_audit.txt. Exit code 1 while anything is left.
//
// A literal that is NOT shown to the user (an id, a pattern, a log line…) is
// declared in tool/l10n/ignore/<area>.txt, one `path<TAB>text` per line
// (`*` as the path = anywhere). Everything else gets `tr()`: either at the
// place the text is shown or, for const data, registered in
// lib/core/l10n/static_keys.dart and translated where it is displayed.
//
// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

const _devCalls = {
  'customSelect',
  'customStatement',
  'customUpdate',
  'read',
  'readNullable',
  'RegExp',
  'join',
  'contains',
  'startsWith',
  'endsWith',
  'split',
  'debugPrint',
  'print',
  'log',
  'getString',
  'setString',
  'getInt',
  'setInt',
  'getBool',
  'setBool',
  'containsKey',
  'remove',
  'Key',
  'ValueKey',
  'GlobalKey',
  'PageStorageKey',
  'ObjectKey',
  'fromEnvironment',
  'StateError',
  'ArgumentError',
  'UnimplementedError',
  'UnsupportedError',
  'AssertionError',
  'assert',
  'invokeMethod',
  'MethodChannel',
  'replaceAll',
  'replaceFirst',
  'indexOf',
  'DateFormat',
  'of',
  'tryParse',
  'parse',
  'jsonDecode',
  'File',
  'Directory',
  'Uri',
  'asset',
  'Duration',
  'RegExpMatch',
};

const _devReceivers = {'AppLogger', 'Intl', 'jsonEncode', 'Platform'};

final _sql = RegExp(
  r'^\s*(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|PRAGMA|WITH|UNION|CASE|FROM|WHERE|ORDER|JOIN|LEFT|AND|OR|ON|SET|VALUES|GROUP|LIMIT|CAST|COALESCE|EXISTS|NOT|IN|AS|BEGIN|COMMIT|VACUUM|REINDEX)\b',
);

bool _candidate(String s) {
  final t = s.trim();
  if (t.length < 2) return false;
  if (!RegExp(r'[A-Za-z]{2}').hasMatch(t)) return false;
  if (_sql.hasMatch(t) && t.contains(RegExp(r'[A-Z]{3,}'))) return false;
  if (t.contains('://') || t.startsWith('/') || t.contains('.dart') || t.contains('.json')) {
    return false;
  }
  if (RegExp(r'^[A-Z][A-Za-z0-9_]*\(.*\)$').hasMatch(t)) return false; // toString()
  if (RegExp(r'^[A-Z][A-Za-z0-9_]*(Exception|Failure|Error)$').hasMatch(t)) return false;
  // identifiers, hex colours, mime types, date patterns without words
  if (!t.contains(' ') && RegExp(r'^[a-z][A-Za-z0-9_./\-:+=#%]*$').hasMatch(t)) return false;
  if (!t.contains(' ') && RegExp(r'^[A-Z0-9_]+$').hasMatch(t)) return false; // CONSTANTS
  if (RegExp(r'^[A-Za-z]+(, |-|/)?[A-Za-z]*\s?[dMyHhmsaEL]+[ ,:.\-/dMyHhmsaEL]*$').hasMatch(t) &&
      !t.contains(RegExp(r'[a-z]{4}'))) {
    return false; // 'EEE, MMM d', 'HH:mm'
  }
  // Shown text starts with a capital, a quote or a bracket — or is several words.
  final start = t[0];
  return RegExp(r'[A-Z“"\x27(\[¿¡]').hasMatch(start) || t.split(' ').length >= 3;
}

String _context(AstNode n) {
  final p = n.parent;
  if (p is AdjacentStrings) return _context(p);
  if (p is NamedArgument) return 'named:${p.name.lexeme}';
  if (p is ArgumentList) {
    final call = p.parent;
    if (call is InstanceCreationExpression) return 'new:${call.constructorName.type.name.lexeme}';
    if (call is MethodInvocation) return 'call:${call.methodName.name}';
    if (call is EnumConstantArguments) return 'enum';
    return 'arg';
  }
  if (p is ConditionalExpression) return _context(p);
  if (p is ListLiteral) return 'list';
  if (p is MapLiteralEntry) return 'map';
  if (p is ExpressionFunctionBody) return 'arrow';
  if (p is ReturnStatement) return 'return';
  if (p is VariableDeclaration) return 'var';
  if (p is SwitchExpressionCase) return 'switch';
  if (p is BinaryExpression) return 'binary';
  if (p is InterpolationExpression) return 'interp';
  return p.runtimeType.toString().replaceAll('Impl', '');
}

/// True when [n] sits somewhere that is never user-facing.
bool _devContext(AstNode n) {
  for (AstNode? c = n.parent; c != null; c = c.parent) {
    final t = c.runtimeType.toString();
    if (c is ImportDirective ||
        c is ExportDirective ||
        c is PartDirective ||
        c is Annotation ||
        t.contains('ConstantPattern') ||
        t.contains('SwitchCase') && !t.contains('Expression') ||
        c is IndexExpression ||
        c is AssertStatement) {
      return true;
    }
    if (c is MapLiteralEntry && c.key == n) return true;
    if (c is MethodInvocation) {
      final name = c.methodName.name;
      final target = c.target;
      if ((name == 'tr' || name == 'trPrint') && target == null) return true; // already translated
      if (_devCalls.contains(name) && !_isUiWrapper(c)) return true;
      if (target is SimpleIdentifier && _devReceivers.contains(target.name)) return true;
    }
    if (c is InstanceCreationExpression) {
      final name = c.constructorName.type.name.lexeme;
      if (_devCalls.contains(name)) return true;
    }
    if (c is MethodDeclaration || c is FunctionDeclaration) return false;
  }
  return false;
}

bool _isUiWrapper(MethodInvocation c) => false;

class _V extends RecursiveAstVisitor<void> {
  _V(this.file, this.unit, this.ignored, this.out);

  final String file;
  final CompilationUnit unit;
  final Set<String> ignored;
  final List<String> out;

  void _lit(StringLiteral n, String text) {
    if (!_candidate(text)) return;
    if (ignored.contains('$file\t$text') || ignored.contains('*\t$text')) return;
    if (_devContext(n)) return;
    final line = unit.lineInfo.getLocation(n.offset).lineNumber;
    out.add('$file:$line\t${_context(n)}\t${text.replaceAll('\n', r'\n')}');
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral n) {
    if (n.parent is! AdjacentStrings) _lit(n, n.value);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings n) {
    final b = StringBuffer();
    for (final s in n.strings) {
      if (s is SimpleStringLiteral) {
        b.write(s.value);
      } else if (s is StringInterpolation) {
        for (final e in s.elements) {
          if (e is InterpolationString) b.write(e.value);
          if (e is InterpolationExpression) b.write('{}');
        }
      }
    }
    _lit(n, b.toString());
  }

  @override
  void visitStringInterpolation(StringInterpolation n) {
    if (n.parent is! AdjacentStrings) {
      final b = StringBuffer();
      for (final e in n.elements) {
        if (e is InterpolationString) b.write(e.value);
        if (e is InterpolationExpression) b.write('{}');
      }
      _lit(n, b.toString());
    }
    // Literals inside `${…}` are looked at too.
    for (final e in n.elements) {
      if (e is InterpolationExpression) e.expression.accept(this);
    }
  }

  @override
  void visitImportDirective(ImportDirective node) {}
  @override
  void visitExportDirective(ExportDirective node) {}
  @override
  void visitPartDirective(PartDirective node) {}
}

Set<String> _ignored() {
  final set = <String>{};
  final dir = Directory('tool/l10n/ignore');
  if (!dir.existsSync()) return set;
  for (final f in dir.listSync()) {
    if (f is! File || !f.path.endsWith('.txt')) continue;
    for (final line in f.readAsLinesSync()) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      set.add(line);
    }
  }
  return set;
}

void main(List<String> args) {
  final prefix = args.isEmpty ? 'lib/' : args.first;
  final ignored = _ignored();
  final out = <String>[];
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final path = f.path.replaceAll('\\', '/');
    if (!path.startsWith(prefix)) continue;
    if (path.endsWith('.g.dart') || path.contains('fa_icons')) continue;
    if (path.startsWith('lib/core/l10n/') || path.startsWith('lib/core/widgets/dev/')) continue;
    final unit = parseString(content: f.readAsStringSync(), throwIfDiagnostics: false).unit;
    unit.accept(_V(path, unit, ignored, out));
  }
  Directory('build').createSync(recursive: true);
  File('build/l10n_audit.txt').writeAsStringSync('${out.join('\n')}\n');
  var last = '';
  for (final l in out) {
    final file = l.split(':').first;
    if (file != last) {
      print('\n$file');
      last = file;
    }
    print('  ${l.substring(file.length + 1)}');
  }
  print('\n${out.length} untranslated user-facing-looking literals under $prefix');
  exit(out.isEmpty ? 0 : 1);
}
