class FFileStat {
  final int mode;
  final int byteSize;
  final int preferedIOSize;
  final DateTime change;
  final DateTime access;
  final DateTime modification;

  const FFileStat({
    required this.mode,
    required this.byteSize,
    required this.change,
    required this.access,
    required this.modification,
    required this.preferedIOSize,
  });
}

sealed class CopySource {
  final String path;

  const CopySource({required this.path});
}

class FileSource extends CopySource {
  final FFileStat stat;

  const FileSource({required super.path, required this.stat});
}

class DirectorySource extends CopySource {
  DirectorySource({required super.path});
}

class FileFailure {
  final String sourcePath;
  final String destPath;
  final Object error;

  const FileFailure({required this.sourcePath, required this.destPath, required this.error});

  @override
  String toString() {
    return "Copy from $sourcePath to $destPath failed with $error";
  }
}

sealed class CopyState {
  int totalFiles;
  int totalBytes;
  bool paused;

  CopyState({required this.totalBytes, required this.totalFiles, required this.paused});

  factory CopyState.pending({
    required int totalBytes,
    required int totalFiles,
    required bool paused,
  }) = CopyPending;

  factory CopyState.active({
    required int totalFiles,
    required int totalBytes,
    required bool paused,
    required int completedFiles,
    required int completedBytes,
    required List<FileFailure> failures,
  }) = CopyActive;

  factory CopyState.done({
    required int totalFiles,
    required int totalBytes,
    required bool paused,
    required int completedFiles,
    required int completedBytes,
    required List<FileFailure> failures,
  }) = CopyDone;
}

class CopyPending extends CopyState {
  CopyPending({required super.totalBytes, required super.totalFiles, required super.paused});

  CopyActive toActive() {
    return CopyActive(
      totalBytes: totalBytes,
      totalFiles: totalFiles,
      paused: paused,
      completedBytes: 0,
      completedFiles: 0,
      failures: [],
    );
  }
}

class CopyActive extends CopyState {
  int completedFiles;
  int completedBytes;
  final List<FileFailure> failures;

  CopyActive({
    required super.totalFiles,
    required super.totalBytes,
    required super.paused,
    required this.completedFiles,
    required this.completedBytes,
    required this.failures,
  });

  CopyDone toDone() {
    return CopyDone(
      completedBytes: completedBytes,
      completedFiles: completedFiles,
      paused: paused,
      failures: failures,
      totalBytes: totalBytes,
      totalFiles: totalFiles,
    );
  }
}

class CopyDone extends CopyState {
  int completedFiles;
  int completedBytes;
  final List<FileFailure> failures;

  CopyDone({
    required super.totalFiles,
    required super.totalBytes,
    required super.paused,
    required this.completedFiles,
    required this.completedBytes,
    required this.failures,
  });
}
