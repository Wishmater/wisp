import 'dart:io';

import 'package:fast_copy/src/operation.dart';

abstract class ICopy {
  static void checkPathDoesNotExists(String path) {
    if (File(path).existsSync()) {
      throw Exception("TODO: create exception for checkPathDoesNotExists");
    }
  }

  Future<void> copyFile(FileCopyOperation operation);

  void makeDirectorySync(String dest) {
    Directory(dest).createSync(recursive: true);
  }

  void makeLinkSync(Link link, String dest) {
    final target = link.targetSync();
    Link(dest).createSync(target);
  }
}
