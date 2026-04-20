import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class PythonRuntime {
  static String resolvePythonExecutable() {
    final projectRoot = Directory.current.path;
    final candidates = [
      p.join(projectRoot, '.venv', 'Scripts', 'python.exe'),
      p.join(p.dirname(projectRoot), '.venv', 'Scripts', 'python.exe'), // Look one level up
      p.join(projectRoot, 'python', '.venv', 'Scripts', 'python.exe'),
      p.join(projectRoot, '.venv', 'bin', 'python'),
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return 'python';
  }

  static String resolveScriptPath(String scriptName) {
    return p.join(Directory.current.path, 'python', scriptName);
  }

  static Future<ProcessResult> runScript(
    String scriptName,
    List<String> arguments,
    {Map<String, String>? environment,}
  ) async {
    final python = resolvePythonExecutable();
    final scriptPath = resolveScriptPath(scriptName);

    debugPrint('Running Python script: $scriptPath');

    return Process.run(
      python,
      [scriptPath, ...arguments],
      runInShell: true,
      environment: environment,
    );
  }
}
