import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'model_provider.dart';

class ModelManagerPage extends StatefulWidget {
  const ModelManagerPage({super.key});

  @override
  State<ModelManagerPage> createState() => _ModelManagerPageState();
}

class _ModelManagerPageState extends State<ModelManagerPage> {
  // 1. Manually list the models you have in assets/models/ here
  final List<String> _modelRegistry = [
    'assets/models/mobile_net_applerandomized.onnx',
    'assets/models/mobile_net_apple_XAI.onnx',
    // 'assets/models/crop_disease_v1.onnx',
  ];

  List<String> _verifiedModels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _verifyModels();
  }

  /// Physically checks if the registered models exist in the bundle
  Future<void> _verifyModels() async {
    List<String> validModels = [];

    for (String path in _modelRegistry) {
      try {
        // We attempt to load the first byte of the file. 
        // If this succeeds, the file is physically present and accessible.
        await rootBundle.load(path);
        validModels.add(path);
      } catch (e) {
        debugPrint("Model not found in assets: $path");
      }
    }

    setState(() {
      _verifiedModels = validModels;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final modelProvider = Provider.of<ModelProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D986A),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "MODEL REGISTRY",
          style: GoogleFonts.chakraPetch(
            fontWeight: FontWeight.bold, 
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D986A)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(_verifiedModels.length),
                Expanded(
                  child: _verifiedModels.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _verifiedModels.length,
                          itemBuilder: (context, index) {
                            final modelPath = _verifiedModels[index];
                            final bool isSelected = modelProvider.selectedModel == modelPath;
                            final String fileName = p.basename(modelPath);

                            return _buildModelCard(fileName, modelPath, isSelected, modelProvider);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildModelCard(String name, String path, bool isSelected, ModelProvider provider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF0D986A) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        onTap: () => provider.setModel(path),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0D986A).withOpacity(0.1) : Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.memory_rounded,
            color: isSelected ? const Color(0xFF0D986A) : Colors.grey,
          ),
        ),
        title: Text(
          name.replaceAll('.onnx', '').replaceAll('_', ' ').toUpperCase(),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isSelected ? const Color(0xFF0D986A) : Colors.black87,
          ),
        ),
        subtitle: Text(
          isSelected ? "ACTIVE ENGINE" : "READY",
          style: TextStyle(
            color: isSelected ? const Color(0xFF0D986A) : Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: isSelected 
          ? const Icon(Icons.check_circle, color: Color(0xFF0D986A))
          : const Icon(Icons.circle_outlined, color: Colors.black12),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Available Architectures",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            "Found $count valid ONNX models in system assets.",
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange[300]),
            const SizedBox(height: 16),
            const Text(
              "No Assets Verified",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              "The app couldn't physically locate the files. Ensure the names in 'modelRegistry' exactly match your files.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}