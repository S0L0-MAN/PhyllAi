import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

class DiagnosisPage extends StatelessWidget {
  final String scanFolderPath;
  final String modelUsed;

  const DiagnosisPage({super.key, required this.scanFolderPath, required this.modelUsed});

  static const Color primaryColor = Color(0xFF0D986A);

  Future<Map<String, dynamic>> _loadReport() async {
    final file = File(p.join(scanFolderPath, "report.json"));
    if (await file.exists()) {
      final String contents = await file.readAsString();
      return json.decode(contents);
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final File inputFile = File(p.join(scanFolderPath, "input.jpg"));
    final File gradCamFile = File(p.join(scanFolderPath, "grad_cam.png"));
    final File heatmapFile = File(p.join(scanFolderPath, "heatmap.png"));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text("DIAGNOSIS REPORT", style: GoogleFonts.chakraPetch(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadReport(),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {};
          final String diseaseName = data['disease_name'] ?? "Analyzing...";
          final double confidence = data['confidence'] ?? 0.0;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text("EXPLAINABILITY MAPS (GRAD-CAM)", 
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54, letterSpacing: 1.2)),
                ),

                SizedBox(
                  height: 340,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    children: [
                      _buildHeatmapCard("ORIGINAL", "Raw input photo", Icons.image, displayImage: inputFile, isBaseLayer: true),
                      _buildHeatmapCard("GRAD-CAM OVERLAY", "Visualizing neural focus", Icons.layers, displayImage: gradCamFile),
                      _buildHeatmapCard("FEATURE INTENSITY", "Raw attribution heatmap", Icons.grid_view_rounded, displayImage: heatmapFile),
                    ],
                  ),
                ),

                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("DIAGNOSIS", style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: primaryColor, fontSize: 12)),
                      const SizedBox(height: 10),
                      Text(diseaseName, style: GoogleFonts.chakraPetch(fontSize: 26, fontWeight: FontWeight.bold)),
                      Text("${(confidence * 100).toStringAsFixed(1)}% Confidence", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      const Divider(height: 40),
                      _reportRow("Severity:", data['severity'] ?? "N/A"),
                      _reportRow("Engine:", "MobileNetV2 (GPU)"),
                      const SizedBox(height: 20),
                      Text("RECOMMENDED ACTION", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange[900])),
                      const SizedBox(height: 10),
                      Text(data['recommendation'] ?? "N/A", style: GoogleFonts.inter(color: Colors.black87, height: 1.6)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeatmapCard(String title, String subtitle, IconData icon, {required File displayImage, bool isBaseLayer = false}) {
    bool exists = displayImage.existsSync();
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(22)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            if (exists) Image.file(displayImage, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))),
            Positioned(
              bottom: 20, left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(width: 10),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}