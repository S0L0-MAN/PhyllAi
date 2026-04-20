import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> getScansRootPath() async {
  if (Platform.isWindows) {
    return p.join(Directory.current.path, 'scans');
  }

  final directory = await getApplicationDocumentsDirectory();
  return p.join(directory.path, 'scans');
}

Future<String> createScanFolder() async {
  final scansRoot = await getScansRootPath();
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final folderPath = p.join(scansRoot, 'scan_$timestamp');
  final scanFolder = Directory(folderPath);

  if (!await scanFolder.exists()) {
    await scanFolder.create(recursive: true);
  }

  return folderPath;
}
