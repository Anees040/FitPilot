import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('No raw color literals or AppTheme statics outside of theme files', () {
    final libDir = Directory('lib');
    final files = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    final allowedFiles = ['app_theme.dart'];
    final issues = <String>[];

    final colorRegex = RegExp(r'\b(Colors\.[a-zA-Z0-9_]+|Color\(0x[A-Fa-f0-9]+\))\b');
    final appThemeRegex = RegExp(r'\bAppTheme\.(?!lightTheme|darkTheme)[a-zA-Z0-9_]+\b');

    for (final file in files) {
      if (allowedFiles.any((allowed) => file.path.endsWith(allowed))) {
        continue;
      }

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (colorRegex.hasMatch(line) &&
            !line.contains('Colors.transparent') &&
            !line.contains('Colors.white') && // allowed: ShaderMask blend mask only
            !line.contains('Color(0x00FFFFFF)')) { // allowed: transparent white for ShaderMask
          issues.add('${file.path}:${i + 1}: Found raw color: ${line.trim()}');
        }
        if (appThemeRegex.hasMatch(line)) {
          issues.add('${file.path}:${i + 1}: Found AppTheme static color: ${line.trim()}');
        }
      }
    }

    if (issues.isNotEmpty) {
      for (var issue in issues) {
        printOnFailure(issue);
      }
      fail('Found ${issues.length} hard-coded color usages. All UI files must use Theme.of(context).');
    }
  });
}
