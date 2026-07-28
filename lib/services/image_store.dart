import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies a picked image into the app's persistent documents directory so it
/// survives after the picker's temp/cache file is cleared by the OS.
class ImageStore {
  static const _uuid = Uuid();

  static Future<File> persist(File source) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(docsDir.path, 'wardrobe_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final ext = p.extension(source.path);
    final fileName = '${_uuid.v4()}$ext';
    final destination = p.join(imagesDir.path, fileName);
    return source.copy(destination);
  }
}
