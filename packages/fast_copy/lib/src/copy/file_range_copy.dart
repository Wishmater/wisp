import 'package:fast_copy/fast_copy.dart';
import 'package:native_file/native_file.dart';

class CopyFileRange implements ICopy {
  final int blockSizeMultipier;

  CopyFileRange([this.blockSizeMultipier = 1024]);

  @override
  Future<void> copyFile(FileCopyOperation operation) async {
    await Future.delayed(Duration(microseconds: 1));
    final preferedBlockSize = operation.source.stat.preferedIOSize * blockSizeMultipier;

    final sourceFile = NativeFile.open(
      operation.source.path,
      OpenFlags.readOnly | OpenFlags.noATime,
    );
    final destFile = NativeFile.open(
      operation.dest,
      OpenFlags.writeOnly | OpenFlags.create,
      mode: operation.source.stat.mode,
    );

    destFile.fallocate(0, operation.source.stat.byteSize);

    int loops = 0;
    while (true) {
      loops += 1;
      if (!operation.waitPaused.isCompleted) {
        await operation.waitPaused.future;
      }

      final copied = sourceFile.copyFileRange(destFile, preferedBlockSize);
      if (loops * preferedBlockSize > 1 << 20) {
        loops = 0;
        await Future.delayed(Duration.zero);
      }
      if (copied == 0) {
        break;
      }
      operation.report(FCOEvent.copied(copied));
    }
    destFile.fsync();
    operation.report(FCOEvent.finish());
  }
}
