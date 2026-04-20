import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'diagnosis.dart';
import 'python_runtime.dart';

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
        final prefs = await SharedPreferences.getInstance();
        final disableVlmRag = prefs.getBool('disable_vlm_rag') ?? false;
        final ollamaModel = prefs.getString('ollama_model');

        final result = await PythonRuntime.runScript(
          'xai_engine.py',
          [widget.scanFolderPath],
          environment: {
            'PHYLLAI_DISABLE_VLM_RAG': disableVlmRag ? '1' : '0',
            if (ollamaModel != null && ollamaModel.isNotEmpty)
              'PHYLLAI_VLM_MODEL': ollamaModel,
          },
        );

        if (result.exitCode != 0) {
          String errorMsg = result.stderr.toString();
          if (errorMsg.contains("ModuleNotFoundError")) {
            errorMsg = "AI Engine Error: Missing Python dependencies.\n"
                "Please run: pip install -r python/requirements.txt torch torchvision ollama langchain-community sentence-transformers faiss-cpu";
          }
          throw Exception("Python XAI Failed:\n$errorMsg");
        }
        
        if (!result.stdout.toString().contains("COMPLETED")) {
           throw Exception("Python XAI did not complete correctly.\nSTDOUT: ${result.stdout}");
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
            Text("MULTI-STAGE DIAGNOSTIC PIPELINE", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Saving MobileNet + VLM + RAG artifacts..."),
          ],
        ),
      ),
    );
  }
}
