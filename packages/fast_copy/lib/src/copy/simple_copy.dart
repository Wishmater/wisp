import 'dart:io';
import 'dart:typed_data';

import 'package:fast_copy/src/copy.dart';
import 'package:fast_copy/src/operation.dart';

class UserlandReadWriteCopy extends ICopy {
  @override
  Future<void> copyFile(FileCopyOperation operation) async {
    final preferedBlockSize = operation.source.stat.preferedIOSize;

    final sourceFile = File(operation.source.path).openSync();
    final destFile = File(operation.dest).openWrite(mode: FileMode.writeOnly);

    final buffer = Uint8List(preferedBlockSize);
    while (true) {
      if (!operation.waitPaused.isCompleted) {
        await operation.waitPaused.future;
      }

      final readed = await sourceFile.readInto(buffer);
      if (readed == 0) {
        break;
      }
      destFile.add(Uint8List.sublistView(buffer, 0, readed));
      operation.report(FCOEvent.copied(readed));

      if (readed < preferedBlockSize) {
        break;
      }
    }
    await destFile.flush();
    operation.report(FCOEvent.finish());
  }
}
