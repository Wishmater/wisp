import 'package:path/path.dart' as p;

class FileData {
  String path;
  int size;

  FileData({
    required this.path,
    required this.size,
  });

  @override
  String toString() => path;

  @override
  bool operator ==(Object other) => other is FileData && path == other.path;
  @override
  int get hashCode => path.hashCode;

  String get filename => p.basename(path);
}

class DirectoryData extends FileData {
  DirectoryData({
    required super.path,
    required super.size,
  });
}
