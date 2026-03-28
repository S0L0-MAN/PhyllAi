import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'diagnosis.dart';

class ProcessingPage extends StatefulWidget {
  final String scanFolderPath;
  final String modelUsed;

  const ProcessingPage({super.key, required this.scanFolderPath, required this.modelUsed});

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      if (Platform.isWindows) {
        // 1. Path to your Virtual Environment Python
        final pythonPath = r"C:\Users\mails\Desktop\PhyllAI\.venv\Scripts\python.exe";
        final scriptPath = r"C:\Users\mails\Desktop\PhyllAI\phyllai\python\xai_engine.py";

        // 2. Run Python and pass the current scan folder path
        final result = await Process.run(
          pythonPath,
          [scriptPath, widget.scanFolderPath],
          runInShell: true,
        );

        if (result.exitCode != 0 || !result.stdout.toString().contains("COMPLETED")) {
          throw Exception("Python XAI Failed: ${result.stderr}");
        }
      } else {
        // Mobile fallback (Local Occlusion or simple report)
        final report = {"disease_name": "Mobile Logic", "confidence": 0.0, "status": "completed"};
        await File(p.join(widget.scanFolderPath, "report.json")).writeAsString(jsonEncode(report));
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DiagnosisPage(
              scanFolderPath: widget.scanFolderPath,
              modelUsed: widget.modelUsed,
            ),
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0D986A)),
            SizedBox(height: 25),
            Text("RESEARCH-GRADE XAI ENGINE", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Processing via Windows CUDA..."),
          ],
        ),
      ),
    );
  }
}