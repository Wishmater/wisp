import 'dart:io';

import 'package:fast_copy/src/operation.dart';

abstract interface class ICopy {
  static void checkPathDoesNotExists(String path) {
    if (File(path).existsSync()) {
      throw Exception("TODO: create exception for checkPathDoesNotExists");
    }
  }

  Future<void> copyFile(FileCopyOperation operation);
}
