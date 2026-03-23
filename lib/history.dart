import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'diagnosis.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final String _scansPath = r'C:\Users\mails\Desktop\PhyllAI\phyllai\scans';
  List<FileSystemEntity> _scanFolders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final directory = Directory(_scansPath);
      if (await directory.exists()) {
        // 1. Get all subdirectories in the scans folder
        List<FileSystemEntity> entities = await directory.list().toList();
        
        // 2. Filter to only include directories that start with 'scan_'
        _scanFolders = entities.whereType<Directory>().where((dir) {
          return p.basename(dir.path).startsWith('scan_');
        }).toList();

        // 3. Sort by creation time (Newest first)
        _scanFolders.sort((a, b) {
          return b.statSync().changed.compareTo(a.statSync().changed);
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0D986A);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          "SCAN HISTORY",
          style: GoogleFonts.chakraPetch(
            fontWeight: FontWeight.bold, 
            color: Colors.black, 
            fontSize: 22
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryColor),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _scanFolders.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(15),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 items per row like Android Gallery
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _scanFolders.length,
                  itemBuilder: (context, index) {
                    return _buildHistoryCard(_scanFolders[index]);
                  },
                ),
    );
  }

  Widget _buildHistoryCard(FileSystemEntity folder) {
    final String folderPath = folder.path;
    final File inputFile = File(p.join(folderPath, "input.jpg"));
    final String folderName = p.basename(folderPath);
    
    // Formatting the date from the folder's timestamp or stat
    final DateTime date = folder.statSync().changed;
    final String formattedDate = "${date.day}/${date.month} - ${date.hour}:${date.minute}";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiagnosisPage(
              scanFolderPath: folderPath,
              modelUsed: "RETRIVED", // Or store the model name in a json file later
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.grey[100],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Image Thumbnail
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: inputFile.existsSync()
                    ? Image.file(inputFile, width: double.infinity, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported, color: Colors.white),
                      ),
              ),
            ),
            // 2. Info Bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    folderName.substring(0, folderName.length > 15 ? 15 : folderName.length),
                    style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 15),
          const Text("No previous scans found", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}