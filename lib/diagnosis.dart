import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

class DiagnosisPage extends StatelessWidget {
  final String scanFolderPath;
  final String modelUsed; // Receives the full path to the .pth file

  const DiagnosisPage({
    super.key,
    required this.scanFolderPath,
    required this.modelUsed,
  });

  static const Color primaryColor = Color(0xFF0D986A);

  /// Logic to extract "MOBILENET" from "best_mobilenet_apple_background_randomized.pth"
  String _parseModelName() {
    try {
      String fileName = p.basename(modelUsed); // Get filename only
      List<String> parts = fileName.split('_'); // Split by underscore
      
      // Based on your naming: [0]best, [1]modelname, [2]dataset...
      if (parts.length > 1) {
        return parts[1].toUpperCase();
      }
      return "AI ENGINE";
    } catch (e) {
      return "STANDARD MODEL";
    }
  }

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
    final File heatmapFile = File(p.join(scanFolderPath, "heatmap.png"));
    final File gradCamFile = File(p.join(scanFolderPath, "grad_cam.png"));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "DIAGNOSIS REPORT",
          style: GoogleFonts.chakraPetch(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadReport(),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {};
          final bool isLoaded = data.isNotEmpty;

          final String diseaseName = data['disease_name'] ?? "Analyzing...";
          final String confidence = data['confidence'] != null 
              ? "${(data['confidence'] * 100).toStringAsFixed(1)}% CONFIDENCE"
              : "CALCULATING...";
          final String detection = data['detection'] ?? data['scientific_name'] ?? "Processing...";
          final String severity = data['severity'] ?? "Assessing...";
          final String recommendation = data['recommendation'] ?? "Please wait while our AI generates a treatment plan...";

          return SingleChildScrollView(
            // Added physics to prevent conflict with horizontal list
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. XAI HEATMAP SECTION
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
                  child: Text(
                    "EXPLAINABILITY MAPS (XAI)",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black54,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                SizedBox(
                  height: 340,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    // BouncingScrollPhysics fixes the "no-scroll" issue
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    children: [
                      _buildHeatmapCard(
                        "ORIGINAL",
                        "Raw input for comparison",
                        Icons.image,
                        displayImage: inputFile,
                      ),
                      _buildHeatmapCard(
                        "GRAD-CAM",
                        "Highlights localized leaf lesions",
                        Icons.api,
                        displayImage: gradCamFile,
                      ),
                      _buildHeatmapCard(
                        "PIXEL ATTRIBUTION",
                        "Feature importance heatmap",
                        Icons.layers,
                        displayImage: heatmapFile,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 2. ANALYSIS REPORT CARD
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "DIAGNOSIS",
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                color: primaryColor,
                                fontSize: 12),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLoaded ? primaryColor.withOpacity(0.1) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              confidence,
                              style: TextStyle(
                                  color: isLoaded ? primaryColor : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        diseaseName,
                        style: GoogleFonts.chakraPetch(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 35),
                      
                      _reportRow("Engine:", _parseModelName()),
                      _reportRow("Detection:", detection),
                      _reportRow("Severity:", severity),
                      _reportRow("Workspace:", p.basename(scanFolderPath)),

                      const SizedBox(height: 25),
                      Text(
                        "RECOMMENDED ACTION",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.orange[900],
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        recommendation,
                        style: GoogleFonts.inter(color: Colors.black87, height: 1.6, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. ACTION BUTTONS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("NEW SCAN"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Container(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: IconButton(
                          onPressed: () {}, // You can implement sharing later
                          icon: const Icon(Icons.share_outlined, color: Colors.white),
                          padding: const EdgeInsets.all(18),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeatmapCard(String title, String subtitle, IconData icon, {required File displayImage}) {
    bool exists = displayImage.existsSync();

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            if (exists)
              Image.file(
                displayImage,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.8),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white.withOpacity(0.2), size: 50),
                    const SizedBox(height: 10),
                    const CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
                    const SizedBox(height: 10),
                    Text("Result pending...",
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                ],
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Icon(icon, color: exists ? Colors.white : Colors.white24, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}