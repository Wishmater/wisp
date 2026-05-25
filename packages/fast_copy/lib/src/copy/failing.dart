
import 'package:fast_copy/src/copy.dart';
import 'package:fast_copy/src/operation.dart';

class FailingCopy implements ICopy {
  @override
  Future<void> copyFile(FileCopyOperation operation) {
    throw Exception("Test Fail");
  }
}
