import 'dart:io';
import 'package:flutter/material.dart';
import 'diagnosis.dart';

class ProcessingPage extends StatefulWidget {
  final String scanFolderPath;
  final String modelUsed;

  const ProcessingPage({
    super.key, 
    required this.scanFolderPath, 
    required this.modelUsed
  });

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  @override
  void initState() {
    super.initState();
    _startAIProcessing();
  }

  Future<void> _startAIProcessing() async {
    try {
      debugPrint("🚀 Initializing Handshake with Python...");
      debugPrint("Workspace: ${widget.scanFolderPath}");

      // 1. Define the paths
      // Assuming you have 'python' in your Windows environment variables (PATH)
      const String pythonPath = 'python'; 
      
      // Path to your new script inside the python folder
      const String scriptPath = r'C:\Users\mails\Desktop\PhyllAI\phyllai\python\processor_watchdog.py';
      
      // Get the specific folder name to pass as an argument
      String scanId = widget.scanFolderPath.split(Platform.pathSeparator).last;

      // 2. Execute the Python script with the --hello flag
      // This is the "Bridge" between Flutter and your Python function
      final result = await Process.run(
        pythonPath, 
        [scriptPath, '--hello', scanId],
      );

      // 3. Log the Python Output to the Flutter Debug Console
      if (result.stdout.toString().isNotEmpty) {
        debugPrint("🐍 PYTHON STDOUT: ${result.stdout}");
      }
      
      if (result.stderr.toString().isNotEmpty) {
        debugPrint("❌ PYTHON STDERR: ${result.stderr}");
      }

      // 4. Navigate to DiagnosisPage
      // We keep a tiny delay just to let the user see the UI transitions
      await Future.delayed(const Duration(milliseconds: 500));

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
      debugPrint("🚨 Failed to execute Python: $e");
      
      // Fallback: If Python fails, we still go to the page but show an error in console
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Process Error: Ensure Python is installed.")),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: Color(0xFF0D986A),
                  strokeWidth: 5,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                "RUNNING ${widget.modelUsed.toUpperCase()} ENGINE", 
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  letterSpacing: 1.1,
                )
              ),
              const SizedBox(height: 10),
              const Text(
                "Python is processing your request in the background...",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "ID: ${widget.scanFolderPath.split(Platform.pathSeparator).last}",
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}