
import 'package:fast_copy/src/copy.dart';
import 'package:fast_copy/src/operation.dart';

class FailingCopy extends ICopy {
  @override
  Future<void> copyFile(FileCopyOperation operation) {
    throw Exception("Test Fail");
  }

  @override
    void makeDirectorySync(String dest) {
      throw Exception("Test Fail");
    }
}
