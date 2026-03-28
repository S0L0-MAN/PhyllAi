import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart'; 
import 'package:path/path.dart' as p;            
import 'processing.dart';                       

class GalleryPage extends StatefulWidget {
  final String activeModel;

  const GalleryPage({super.key, required this.activeModel});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  File? _selectedImage;
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();
  static const Color primaryColor = Color(0xFF0D986A);

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _retrieveLostData();
    }
  }

  Future<void> _retrieveLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty || response.file == null) return;
    setState(() => _selectedImage = File(response.file!.path));
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  // --- UPDATED LOGIC: Windows Project Root Storage ---
  void _handleAnalysis() async {
    if (_selectedImage == null) return;

    setState(() => _isAnalyzing = true);

    try {
      String folderPath;
      
      if (Platform.isWindows) {
        // 1. Direct path to your Desktop Project folder
        String projectPath = r'C:\Users\mails\Desktop\PhyllAI\phyllai';
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        folderPath = p.join(projectPath, 'scans', 'scan_$timestamp');
      } else {
        // Fallback for Mobile/Emulator testing
        final directory = await getApplicationDocumentsDirectory();
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        folderPath = p.join(directory.path, 'scans', 'scan_$timestamp');
      }

      // 2. Create the physical directory
      final Directory scanFolder = Directory(folderPath);
      await scanFolder.create(recursive: true);

      // 3. Copy image to the new workspace
      final String filePath = p.join(folderPath, "input.jpg");
      await _selectedImage!.copy(filePath);

      debugPrint("Workspace created at: $folderPath");

      // // Optional: Open the folder automatically in Windows Explorer
      // if (Platform.isWindows) {
      //   await Process.run('explorer.exe', [folderPath]);
      // }

      if (mounted) {
        setState(() => _isAnalyzing = false);

        // 4. Navigate to Processing Page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProcessingPage(
              scanFolderPath: folderPath,
              modelUsed: widget.activeModel,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      debugPrint("Error creating workspace: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.activeModel.toUpperCase(),
          style: GoogleFonts.chakraPetch(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 25),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade200, width: 2),
              ),
              child: _selectedImage != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(23),
                          child: Image.file(
                            _selectedImage!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (!_isAnalyzing)
                          Positioned(
                            top: 15,
                            right: 15,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.black54, 
                                  shape: BoxShape.circle
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        if (_isAnalyzing)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_search_rounded, size: 70, color: Colors.grey[300]),
                        const SizedBox(height: 15),
                        const Text("No image selected", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 30),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _pickImage,
                  icon: Icon(isDesktop ? Icons.folder_open : Icons.photo_library_outlined),
                  label: Text(isDesktop ? "SELECT FROM PC" : "SELECT FROM GALLERY"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),

                const SizedBox(height: 15),

                if (_selectedImage != null)
                  OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : _handleAnalysis,
                    icon: _isAnalyzing 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)
                          )
                        : const Icon(Icons.analytics_outlined, color: primaryColor),
                    label: Text(_isAnalyzing ? "INITIALIZING..." : "RUN ${widget.activeModel} DIAGNOSTICS"),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primaryColor, width: 2),
                      foregroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}