import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phyllai/camera.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'history.dart';
import 'gallery.dart'; 
import 'model_manager.dart'; // Import the new manager
import 'model_provider.dart'; // Import the provider

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0D986A);
    
    // Listen to the provider to get the current active model name
    final modelProvider = Provider.of<ModelProvider>(context);
    final String activeModelName = p.basename(modelProvider.selectedModel)
        .replaceAll('.onnx', '')
        .toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Center(
              child: Hero(
                tag: 'logo_text',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    "PHYLL AI",
                    style: GoogleFonts.chakraPetch(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "DASHBOARD CONTROLS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black45,
                    letterSpacing: 1.5,
                  ),
                ),
                // Small indicator for the active model
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    activeModelName,
                    style: const TextStyle(color: primaryColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            _dashboardCard(
              context, 
              "Open Gallery", 
              Icons.collections_outlined, 
              primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // Now passing the actual active model name dynamically
                    builder: (context) => GalleryPage(activeModel: activeModelName),
                  ),
                );
              },
            ),

            _dashboardCard(
              context, 
              "Camera Scan", 
              Icons.camera_alt_outlined, 
              Colors.blueGrey,
              onTap: ()  {
                Navigator.push(context,
                MaterialPageRoute(builder: (context)=> const CameraPage()));
              },
            ),

            _dashboardCard(
              context, 
              "Analysis History", 
              Icons.history_rounded, 
              Colors.orange,
              onTap: () {
                Navigator.push(context,
                MaterialPageRoute(builder: (context)=> const HistoryPage()));
              },
            ),

            _dashboardCard(
              context, 
              "Model Manager", 
              Icons.cloud_download_outlined, 
              Colors.deepPurple,
              onTap: () {
                // Navigate to the real Model Manager Page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ModelManagerPage()),
                );
              },
            ),
            
            _dashboardCard(
              context, 
              "Settings", 
              Icons.settings_outlined, 
              Colors.grey,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardCard(BuildContext context, String title, IconData icon, Color color, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }
}