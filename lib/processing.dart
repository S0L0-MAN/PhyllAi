import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  // --- CONFIGURATION ---
  // REPLACE THIS with your PC's IPv4 address from 'ipconfig'
  static const String pcIpAddress = "192.168.1.15"; 
  static const String port = "5000";

  @override
  void initState() {
    super.initState();
    _startRemoteAIProcessing();
  }

  Future<void> _startRemoteAIProcessing() async {
    try {
      debugPrint("🚀 Initializing Handshake with PC Server...");
      
      // Get the specific scan folder name (e.g., scan_123456)
      String scanId = widget.scanFolderPath.split(Platform.pathSeparator).last;

      // 1. Prepare the Network Request
      final url = Uri.parse('http://$pcIpAddress:$port/process');
      
      // 2. Send the "Ping" to your PC to start processing
      // Note: This assumes the PC can see the shared desktop folder 
      // or the file is already synced.
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"scanId": scanId}),
      ).timeout(const Duration(seconds: 45)); // AI can take time

      if (response.statusCode == 200) {
        debugPrint("🐍 PC SERVER SUCCESS: ${response.body}");
        
        // Small delay for UI smoothness
        await Future.delayed(const Duration(milliseconds: 800));

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
      } else {
        throw Exception("Server returned ${response.statusCode}: ${response.body}");
      }

    } catch (e) {
      debugPrint("🚨 Remote Processing Error: $e");
      
      if (mounted) {
        _showErrorAndPop(e.toString());
      }
    }
  }

  void _showErrorAndPop(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Connection Failed: Check if PC Server is running at $pcIpAddress"),
        backgroundColor: Colors.redAccent,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String scanId = widget.scanFolderPath.split(Platform.pathSeparator).last;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 65,
                height: 65,
                child: CircularProgressIndicator(
                  color: Color(0xFF0D986A),
                  strokeWidth: 5,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "REMOTE ${widget.modelUsed.toUpperCase()} ENGINE", 
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 18,
                  letterSpacing: 1.2,
                )
              ),
              const SizedBox(height: 15),
              const Text(
                "Your phone is communicating with the PC GPU to analyze the leaf pathology...",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.5, fontSize: 14),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    const Text(
                      "ACTIVE WORKSPACE",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scanId,
                      style: const TextStyle(fontSize: 11, color: Colors.black87, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}