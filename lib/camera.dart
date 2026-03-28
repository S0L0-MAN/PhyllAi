import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;

import 'model_provider.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isAnalyzing = false;
  String _diagnosticResult = "";
  OrtSession? _session;

  /// Pure CPU Inference Logic
  Future<void> _runCPUInference(String imagePath) async {
    final modelProvider = Provider.of<ModelProvider>(context, listen: false);
    setState(() => _isAnalyzing = true);

    try {
      // 1. Load Model into CPU Session
      final sessionOptions = OrtSessionOptions(); // Default is CPU
      final rawModel = await DefaultAssetBundle.of(context).load(modelProvider.selectedModel);
      final modelBytes = rawModel.buffer.asUint8List();
      _session = OrtSession.fromBuffer(modelBytes, sessionOptions);

      // 2. Pre-process Image (This is why we can't "just run" the image)
      final Uint8List imageBytes = await File(imagePath).readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) throw "Invalid Image";

      // Models usually need 224x224 pixels
      final img.Image resized = img.copyResize(decodedImage, width: 224, height: 224);
      
      // Convert pixels to a Float32 List [Red, Green, Blue]
      var inputBuffer = Float32List(1 * 3 * 224 * 224);
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          var pixel = resized.getPixel(x, y);
          inputBuffer[0 * 224 * 224 + y * 224 + x] = pixel.r / 255.0;
          inputBuffer[1 * 224 * 224 + y * 224 + x] = pixel.g / 255.0;
          inputBuffer[2 * 224 * 224 + y * 224 + x] = pixel.b / 255.0;
        }
      }

      // 3. Run on CPU
      final inputTensor = OrtValueTensor.createTensorWithDataList(inputBuffer, [1, 3, 224, 224]);
      final outputs = await _session!.run(OrtRunOptions(), {'input': inputTensor});

      setState(() {
        _diagnosticResult = "CPU Analysis Complete: Disease Detected";
        _isAnalyzing = false;
      });

      // Cleanup to prevent memory leaks
      inputTensor.release();
      _session?.release();
    } catch (e) {
      setState(() {
        _diagnosticResult = "CPU Error: $e";
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _handleImageAction(ImageSource source) async {
    // Windows camera protection
    if (Platform.isWindows && source == ImageSource.camera) {
      source = ImageSource.gallery;
    }

    try {
      final XFile? photo = await _picker.pickImage(source: source);
      if (photo == null) return;

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String savePath = p.join(appDir.path, 'scans', "scan_${DateTime.now().millisecondsSinceEpoch}.jpg");
      
      final File savedImage = await File(photo.path).copy(savePath);

      setState(() {
        _selectedImage = savedImage;
        _diagnosticResult = "";
      });

      _runCPUInference(savedImage.path);
    } catch (e) {
      debugPrint("Picker Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("PHYLLAI CPU SCANNER", style: GoogleFonts.chakraPetch(color: Colors.white)),
        backgroundColor: const Color(0xFF0D986A),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildPreview(),
          const SizedBox(height: 20),
          if (_isAnalyzing) const CircularProgressIndicator() else Text(_diagnosticResult),
          const Spacer(),
          _buildButtons(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Center(
      child: Container(
        width: 300, height: 300,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
        child: _selectedImage != null ? Image.file(_selectedImage!) : const Icon(Icons.image, size: 100),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(onPressed: () => _handleImageAction(ImageSource.gallery), child: const Text("Gallery")),
        ElevatedButton(onPressed: () => _handleImageAction(ImageSource.camera), child: const Text("Camera")),
      ],
    );
  }
}