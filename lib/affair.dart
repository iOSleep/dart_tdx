import 'dart:io';
import 'dart:typed_data';

import 'src/constants.dart';
import 'src/socket_client.dart';

/// Financial data download and parsing API.
class Affair {
  Affair._();

  /// Get list of available financial files.
  /// Returns raw bytes from the server.
  static Future<Uint8List> files() async {
    final server = gpHosts.first;
    final client = TdxSocketClient();

    try {
      final ok = await client.connect(server.host, server.port);
      if (!ok) return Uint8List(0);

      await client.setup();

      // Request file list (filename: 'gpcw.txt')
      final result = await client.getReportFile('gpcw.txt', 0);
      return result;
    } finally {
      client.disconnect();
    }
  }

  /// Download a single financial data file.
  static Future<bool> fetch({
    required String downloadDir,
    required String filename,
    void Function(int count, int blockSize)? onProgress,
  }) async {
    final server = gpHosts.first;
    final client = TdxSocketClient();

    try {
      final ok = await client.connect(server.host, server.port);
      if (!ok) return false;

      await client.setup();

      // Download file in chunks
      final filePath = '$downloadDir/$filename';
      final dir = Directory(downloadDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final file = File(filePath);
      final sink = file.openWrite();

      int offset = 0;
      while (true) {
        final chunk = await client.getReportFile(filename, offset);
        if (chunk.isEmpty || chunk.length <= 1) break;

        // First 2 bytes indicate chunk size
        if (chunk.length > 2) {
          final data = Uint8List.view(
              chunk.buffer, chunk.offsetInBytes + 2, chunk.length - 2);

          if (data.isEmpty) break;

          sink.add(data);
          offset += data.length;
          onProgress?.call(offset, 0);
        } else {
          break;
        }
      }

      await sink.flush();
      await sink.close();
      return true;
    } finally {
      client.disconnect();
    }
  }

  /// Download all financial data files.
  static Future<void> fetchAll({
    required String downloadDir,
  }) async {
    final dir = Directory(downloadDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final fileList = await files();
    if (fileList.isEmpty) return;

    // Parse the file list to get filenames
    final content = String.fromCharCodes(fileList);
    final lines = content.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.trim().split(',');
      if (parts.isNotEmpty) {
        final filename = parts[0].trim();
        if (filename.isNotEmpty && filename.endsWith('.zip')) {
          await fetch(downloadDir: downloadDir, filename: filename);
        }
      }
    }
  }
}
